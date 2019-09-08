#ifndef _BISTROMATH_H_
#define _BISTROMATH_H_

void SUBMULOC();
void DECLICK_CHECK();
void NOISELIVE1();
void NOISELIVE0();
int16_t Interp512(int16_t wave, int16_t wavenext, uint32_t phase);

int32_t ssat13(int32_t a);
int32_t multiply_32x32_rshift32(int32_t a, int32_t b);
int32_t signed_multiply_32x16t(int32_t a, uint32_t b);
float fastpow2(float p);

#endif