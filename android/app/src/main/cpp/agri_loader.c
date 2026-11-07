#include <jni.h>
#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <sys/mman.h>

#define MAX_INSTANCES 8

typedef uint64_t (*agri_entry)(uint64_t, uint64_t, uint64_t, uint64_t, uint64_t, uint64_t, uint64_t, uint64_t);

static uint8_t *bases[MAX_INSTANCES];
static size_t spans[MAX_INSTANCES];

static size_t round_up(size_t v, size_t a) {
    return (v + a - 1) / a * a;
}

JNIEXPORT jint JNICALL Java_ie_corkathon_phone_AgriModel_nativeLoad(JNIEnv *env, jclass cls, jobject image, jint length, jlong bss) {
    uint8_t *src = (uint8_t *)(*env)->GetDirectBufferAddress(env, image);
    if (src == NULL || length <= 0 || bss <= 0) {
        return -1;
    }
    int slot = -1;
    for (int i = 0; i < MAX_INSTANCES; i++) {
        if (bases[i] == NULL) {
            slot = i;
            break;
        }
    }
    if (slot < 0) {
        return -3;
    }
    size_t code = round_up((size_t)length, 16384);
    size_t span = round_up(code + (size_t)bss, 65536);
    void *p = mmap(NULL, span, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_NORESERVE, -1, 0);
    if (p == MAP_FAILED) {
        return -1000 - errno;
    }
    memcpy(p, src, (size_t)length);
    if (mprotect(p, code, PROT_READ | PROT_WRITE | PROT_EXEC) != 0) {
        int e = errno;
        munmap(p, span);
        return -2000 - e;
    }
    __builtin___clear_cache((char *)p, (char *)p + length);
    bases[slot] = (uint8_t *)p;
    spans[slot] = span;
    return slot;
}

JNIEXPORT jlong JNICALL Java_ie_corkathon_phone_AgriModel_nativeRun(JNIEnv *env, jclass cls, jint slot, jobject model, jint modelLength,
        jobject heads, jint headsLength, jobject refl, jobject out, jint size, jint doy) {
    if (slot < 0 || slot >= MAX_INSTANCES || bases[slot] == NULL) {
        return -1;
    }
    uint64_t mp = (uint64_t)(uintptr_t)(*env)->GetDirectBufferAddress(env, model);
    uint64_t hp = heads == NULL ? 0 : (uint64_t)(uintptr_t)(*env)->GetDirectBufferAddress(env, heads);
    uint64_t rp = (uint64_t)(uintptr_t)(*env)->GetDirectBufferAddress(env, refl);
    uint64_t op = (uint64_t)(uintptr_t)(*env)->GetDirectBufferAddress(env, out);
    if (mp == 0 || rp == 0 || op == 0) {
        return -2;
    }
    uint64_t hl = hp == 0 ? 0 : (uint64_t)headsLength;
    agri_entry entry = (agri_entry)(void *)bases[slot];
    return (jlong)entry(mp, (uint64_t)modelLength, hp, hl, rp, op, (uint64_t)size, (uint64_t)doy);
}
