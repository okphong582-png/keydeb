#ifndef FIREBASE_H
#define FIREBASE_H

#include <stddef.h>
#include "keycheck.h"

typedef struct {
    char key[256];
    char duration[16];
    char status[16];
    char device_id[128];
    long created_at;
} FirebaseKeyData;

int firebase_init(const char *database_url);
int firebase_get_key(const char *key, FirebaseKeyData *out);
int firebase_mark_key_used(const char *key, const char *device_id);
int firebase_delete_key(const char *key);
int firebase_register_device(const char *device_id, const char *key, long expires_at);
int firebase_get_device(const char *device_id, ActivationData *out);

#endif
