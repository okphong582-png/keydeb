#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <sys/stat.h>
#include <dlfcn.h>
#include "keycheck.h"
#include "antidebug.h"
#include "firebase.h"

static char g_firebase_url[512] = {0};
static char g_activation_path[1024] = {0};

static const char *get_config_dir(void)
{
    static char path[1024];
    const char *home = getenv("HOME");
    if (!home) home = "/var/root";

    const char *xdg = getenv("XDG_CONFIG_HOME");
    if (xdg) {
        snprintf(path, sizeof(path), "%s/glorystore", xdg);
    } else {
        snprintf(path, sizeof(path), "%s/.config/glorystore", home);
    }
    return path;
}

static void ensure_dir(const char *path)
{
    struct stat st = {0};
    if (stat(path, &st) == -1) {
        mkdir(path, 0700);
    }
}

int keycheck_init(const char *firebase_url)
{
    strncpy(g_firebase_url, firebase_url, sizeof(g_firebase_url) - 1);

    const char *config_dir = get_config_dir();
    ensure_dir(config_dir);
    snprintf(g_activation_path, sizeof(g_activation_path), "%s/activation.dat", config_dir);

    firebase_init(firebase_url);
    return 0;
}

int keycheck_get_device_id(char *out, size_t out_size)
{
    char hostname[256] = {0};
    gethostname(hostname, sizeof(hostname) - 1);

    char buf[512];
    snprintf(buf, sizeof(buf), "%s-%d-%ld", hostname, getuid(), (long)time(NULL));

    unsigned char hash[32];
    SHA256_CTX ctx;
    SHA256_Init(&ctx);
    SHA256_Update(&ctx, buf, strlen(buf));

    unsigned char extra[64];
    FILE *f = fopen("/etc/machine-id", "rb");
    if (f) {
        size_t n = fread(extra, 1, sizeof(extra), f);
        SHA256_Update(&ctx, extra, n);
        fclose(f);
    }
    SHA256_Final(hash, &ctx);

    char hex[65];
    for (int i = 0; i < 32; i++) {
        sprintf(hex + i * 2, "%02x", hash[i]);
    }
    hex[64] = 0;

    strncpy(out, hex, out_size - 1);
    return 0;
}

static long get_expiry_seconds(const char *duration)
{
    if (strcmp(duration, "1day") == 0) return 86400L;
    if (strcmp(duration, "7day") == 0) return 604800L;
    if (strcmp(duration, "30day") == 0) return 2592000L;
    return 86400L;
}

int keycheck_validate_key(const char *key, ActivationData *out)
{
    FirebaseKeyData key_data;

    if (firebase_get_key(key, &key_data) != 0) {
        return KEY_INVALID;
    }

    if (strcmp(key_data.status, "used") == 0) {
        return KEY_ALREADY_USED;
    }

    long expires_at = time(NULL) + get_expiry_seconds(key_data.duration);

    firebase_delete_key(key);

    char device_id[128];
    keycheck_get_device_id(device_id, sizeof(device_id));
    firebase_register_device(device_id, key, expires_at);

    memset(out, 0, sizeof(ActivationData));
    strncpy(out->device_id, device_id, sizeof(out->device_id) - 1);
    strncpy(out->key, key, sizeof(out->key) - 1);
    strncpy(out->duration, key_data.duration, sizeof(out->duration) - 1);
    out->activated_at = time(NULL);
    out->expires_at = expires_at;

    return KEY_ACTIVATED;
}

int keycheck_check_activation(ActivationData *out)
{
    FILE *f = fopen(g_activation_path, "rb");
    if (!f) return KEY_INVALID;

    char buf[512];
    size_t n = fread(buf, 1, sizeof(buf), f);
    fclose(f);

    char device_id[128];
    keycheck_get_device_id(device_id, sizeof(device_id));

    char line[512];
    char saved_device[128];
    char saved_key[256];
    long saved_expires = 0;

    buf[n] = 0;
    if (sscanf(buf, "%127s %255s %ld", saved_device, saved_key, &saved_expires) < 3) {
        return KEY_INVALID;
    }

    if (strcmp(saved_device, device_id) != 0) {
        return KEY_INVALID;
    }

    if (time(NULL) > saved_expires) {
        remove(g_activation_path);
        return KEY_EXPIRED;
    }

    memset(out, 0, sizeof(ActivationData));
    strncpy(out->device_id, saved_device, sizeof(out->device_id) - 1);
    strncpy(out->key, saved_key, sizeof(out->key) - 1);
    out->expires_at = saved_expires;
    strncpy(out->duration, "custom", sizeof(out->duration) - 1);

    return KEY_VALID;
}

int keycheck_save_activation(const ActivationData *data)
{
    FILE *f = fopen(g_activation_path, "wb");
    if (!f) return -1;

    fprintf(f, "%s %s %ld\n", data->device_id, data->key, data->expires_at);
    fclose(f);

    chmod(g_activation_path, 0600);
    return 0;
}

int keycheck_clear_activation(void)
{
    return remove(g_activation_path);
}

__attribute__((constructor))
static void auto_init(void)
{
    const char *url = "https://appchatai-313e3-default-rtdb.firebaseio.com";
    keycheck_init(url);

    if (antidebug_check_integrity("/proc/self/exe") == 0) {
        exit(-1);
    }
}
