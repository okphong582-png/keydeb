#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <curl/curl.h>
#include "keycheck.h"
#include "firebase.h"

static char g_database_url[512] = {0};

struct MemoryBuffer {
    char *data;
    size_t size;
};

static size_t write_callback(void *ptr, size_t size, size_t nmemb, void *userdata)
{
    size_t total = size * nmemb;
    struct MemoryBuffer *buf = (struct MemoryBuffer *)userdata;

    char *newdata = realloc(buf->data, buf->size + total + 1);
    if (!newdata) return 0;

    buf->data = newdata;
    memcpy(buf->data + buf->size, ptr, total);
    buf->size += total;
    buf->data[buf->size] = 0;
    return total;
}

int firebase_init(const char *database_url)
{
    strncpy(g_database_url, database_url, sizeof(g_database_url) - 1);
    curl_global_init(CURL_GLOBAL_ALL);
    return 0;
}

static int firebase_request(const char *path, const char *method, const char *json_data, char **response)
{
    CURL *curl = curl_easy_init();
    if (!curl) return -1;

    char url[1024];
    snprintf(url, sizeof(url), "%s%s.json", g_database_url, path);

    struct MemoryBuffer buf = {0};
    struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, "Content-Type: application/json");

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &buf);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 15L);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

    if (json_data) {
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, json_data);
        if (strcmp(method, "PUT") == 0) {
            curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "PUT");
        } else if (strcmp(method, "PATCH") == 0) {
            curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "PATCH");
        } else if (strcmp(method, "DELETE") == 0) {
            curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "DELETE");
        } else {
            curl_easy_setopt(curl, CURLOPT_POST, 1L);
        }
    } else if (strcmp(method, "DELETE") == 0) {
        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "DELETE");
    }

    CURLcode res = curl_easy_perform(curl);
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    if (res != CURLE_OK) {
        free(buf.data);
        return -1;
    }

    *response = buf.data;
    return 0;
}

static char* json_get_string(const char *json, const char *key)
{
    if (!json) return NULL;
    char pattern[256];
    snprintf(pattern, sizeof(pattern), "\"%s\"", key);
    const char *p = strstr(json, pattern);
    if (!p) return NULL;

    p = strchr(p + strlen(key) + 2, ':');
    if (!p) return NULL;
    p++;
    while (*p && (*p == ' ' || *p == '\t')) p++;

    if (*p == '"') {
        p++;
        const char *end = strchr(p, '"');
        if (!end) return NULL;
        size_t len = end - p;
        char *val = malloc(len + 1);
        strncpy(val, p, len);
        val[len] = 0;
        return val;
    }
    if (*p == 't' && strncmp(p, "true", 4) == 0) return strdup("true");
    if (*p == 'f' && strncmp(p, "false", 5) == 0) return strdup("false");

    const char *end = p;
    while (*end && *end != ',' && *end != '}' && *end != ' ') end++;
    size_t len = end - p;
    char *val = malloc(len + 1);
    strncpy(val, p, len);
    val[len] = 0;
    return val;
}

static long json_get_long(const char *json, const char *key)
{
    char *val = json_get_string(json, key);
    if (!val) return 0;
    long result = atol(val);
    free(val);
    return result;
}

int firebase_get_key(const char *key, FirebaseKeyData *out)
{
    char path[512];
    snprintf(path, sizeof(path), "/keys/%s", key);

    char *response = NULL;
    if (firebase_request(path, "GET", NULL, &response) != 0) {
        return -1;
    }

    if (!response || strcmp(response, "null") == 0) {
        free(response);
        return -1;
    }

    char *duration = json_get_string(response, "duration");
    char *status = json_get_string(response, "status");
    char *device_id = json_get_string(response, "deviceId");
    long created_at = json_get_long(response, "createdAt");

    strncpy(out->key, key, sizeof(out->key) - 1);
    if (duration) { strncpy(out->duration, duration, sizeof(out->duration) - 1); free(duration); }
    if (status) { strncpy(out->status, status, sizeof(out->status) - 1); free(status); }
    if (device_id) { strncpy(out->device_id, device_id, sizeof(out->device_id) - 1); free(device_id); }
    out->created_at = created_at;

    free(response);
    return 0;
}

int firebase_mark_key_used(const char *key, const char *device_id)
{
    char path[512];
    snprintf(path, sizeof(path), "/keys/%s", key);

    char json[512];
    snprintf(json, sizeof(json),
        "{\"status\":\"used\",\"deviceId\":\"%s\",\"usedAt\":%ld}",
        device_id, (long)time(NULL));

    char *response = NULL;
    int ret = firebase_request(path, "PATCH", json, &response);
    free(response);
    return ret;
}

int firebase_delete_key(const char *key)
{
    char path[512];
    snprintf(path, sizeof(path), "/keys/%s", key);

    char *response = NULL;
    int ret = firebase_request(path, "DELETE", NULL, &response);
    free(response);
    return ret;
}

int firebase_register_device(const char *device_id, const char *key, long expires_at)
{
    char path[512];
    snprintf(path, sizeof(path), "/devices/%s", device_id);

    char json[512];
    snprintf(json, sizeof(json),
        "{\"key\":\"%s\",\"activatedAt\":%ld,\"expiresAt\":%ld}",
        key, (long)time(NULL), expires_at);

    char *response = NULL;
    int ret = firebase_request(path, "PUT", json, &response);
    free(response);
    return ret;
}

int firebase_get_device(const char *device_id, ActivationData *out)
{
    char path[512];
    snprintf(path, sizeof(path), "/devices/%s", device_id);

    char *response = NULL;
    if (firebase_request(path, "GET", NULL, &response) != 0) {
        return -1;
    }

    if (!response || strcmp(response, "null") == 0) {
        free(response);
        return -1;
    }

    char *key = json_get_string(response, "key");
    long activated_at = json_get_long(response, "activatedAt");
    long expires_at = json_get_long(response, "expiresAt");

    if (key) { strncpy(out->key, key, sizeof(out->key) - 1); free(key); }
    out->activated_at = activated_at;
    out->expires_at = expires_at;

    free(response);
    return 0;
}
