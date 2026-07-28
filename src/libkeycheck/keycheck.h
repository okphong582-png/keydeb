#ifndef KEYCHECK_H
#define KEYCHECK_H

#include <stddef.h>

typedef enum {
    KEY_VALID = 0,
    KEY_INVALID = -1,
    KEY_EXPIRED = -2,
    KEY_ALREADY_USED = -3,
    KEY_NETWORK_ERROR = -4,
    KEY_ACTIVATED = 1
} KeyStatus;

typedef struct {
    char device_id[128];
    char key[256];
    char duration[16];
    long activated_at;
    long expires_at;
} ActivationData;

int keycheck_init(const char *firebase_url);
int keycheck_validate_key(const char *key, ActivationData *out);
int keycheck_check_activation(ActivationData *out);
int keycheck_save_activation(const ActivationData *data);
int keycheck_clear_activation(void);
int keycheck_get_device_id(char *out, size_t out_size);
int keycheck_is_debugged(void);
int keycheck_verify_integrity(void);

#endif
