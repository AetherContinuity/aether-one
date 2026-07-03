#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "golden_data.h"

typedef struct { int32_t device_type; int32_t device_id; } DLDevice;
typedef struct { uint8_t code; uint8_t bits; uint16_t lanes; } DLDataType;
typedef struct {
    void* data;
    DLDevice device;
    int32_t ndim;
    DLDataType dtype;
    int64_t* shape;
    int64_t* strides;
    uint64_t byte_offset;
} DLTensor;

typedef union {
    int64_t v_int64; double v_float64; void* v_ptr; const char* v_c_str; uint64_t v_uint64;
} TVMFFIAnyValue;

typedef struct { int32_t type_index; uint32_t zero_padding; TVMFFIAnyValue value; } TVMFFIAny;

#define KTVMFFI_DLTENSOR_PTR 7

typedef int (*SafeCallFn)(void* handle, const TVMFFIAny* args, int32_t num_args, TVMFFIAny* result);

/* Ulkoiset symbolit itse mallista (linkataan model_riscv.so:n kanssa) */
extern int __tvm_ffi_transpose(void*, const TVMFFIAny*, int32_t, TVMFFIAny*);
extern int __tvm_ffi_matmul(void*, const TVMFFIAny*, int32_t, TVMFFIAny*);
extern int __tvm_ffi_add(void*, const TVMFFIAny*, int32_t, TVMFFIAny*);

/* Stub puuttuvalle virhekasittelysymbolille */
void TVMFFIErrorSetRaisedFromCStrParts(const char* kind, const char* msg) {
    fprintf(stderr, "TVM FFI error: %s: %s\n", kind, msg);
}

static void make_tensor(DLTensor* t, void* data, int64_t* shape, int64_t* strides, int32_t ndim) {
    t->data = data;
    t->device.device_type = 1; /* kDLCPU */
    t->device.device_id = 0;
    t->ndim = ndim;
    t->dtype.code = 2; /* kDLFloat */
    t->dtype.bits = 32;
    t->dtype.lanes = 1;
    t->shape = shape;
    t->strides = strides;
    t->byte_offset = 0;
}

static void set_arg(TVMFFIAny* a, DLTensor* t) {
    a->type_index = KTVMFFI_DLTENSOR_PTR;
    a->value.v_ptr = t;
}

int main(void) {
    int64_t shape_W[2] = {2, 4}, stride_W[2] = {4, 1};
    int64_t shape_WT[2] = {4, 2}, stride_WT[2] = {2, 1};
    int64_t shape_x[2] = {1, 4}, stride_x[2] = {4, 1};
    int64_t shape_mm[2] = {1, 2}, stride_mm[2] = {2, 1};
    int64_t shape_b[1] = {2}, stride_b[1] = {1};
    int64_t shape_out[2] = {1, 2}, stride_out[2] = {2, 1};

    float W_T[8] = {0};
    float mm[2] = {0};
    float out[2] = {0};

    DLTensor t_W, t_WT, t_x, t_mm, t_b, t_out;
    make_tensor(&t_W, W_DATA, shape_W, stride_W, 2);
    make_tensor(&t_WT, W_T, shape_WT, stride_WT, 2);
    make_tensor(&t_x, X_DATA, shape_x, stride_x, 2);
    make_tensor(&t_mm, mm, shape_mm, stride_mm, 2);
    make_tensor(&t_b, B_DATA, shape_b, stride_b, 1);
    make_tensor(&t_out, out, shape_out, stride_out, 2);

    TVMFFIAny args1[2], args2[3], args3[3];
    TVMFFIAny result;

    set_arg(&args1[0], &t_W); set_arg(&args1[1], &t_WT);
    int r1 = __tvm_ffi_transpose(NULL, args1, 2, &result);

    set_arg(&args2[0], &t_x); set_arg(&args2[1], &t_WT); set_arg(&args2[2], &t_mm);
    int r2 = __tvm_ffi_matmul(NULL, args2, 3, &result);

    set_arg(&args3[0], &t_mm); set_arg(&args3[1], &t_b); set_arg(&args3[2], &t_out);
    int r3 = __tvm_ffi_add(NULL, args3, 3, &result);

    printf("return codes: %d %d %d\n", r1, r2, r3);
    printf("out: %.6f %.6f\n", out[0], out[1]);
    printf("expected: %.6f %.6f\n", EXPECTED[0], EXPECTED[1]);

    float d0 = out[0] - EXPECTED[0], d1 = out[1] - EXPECTED[1];
    if (d0 < 0) d0 = -d0;
    if (d1 < 0) d1 = -d1;
    int ok = (r1 == 0 && r2 == 0 && r3 == 0 && d0 < 1e-4f && d1 < 1e-4f);
    printf("%s\n", ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}
