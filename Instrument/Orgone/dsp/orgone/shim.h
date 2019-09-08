#ifndef _SHIM_H_
#define _SHIM_H_

// all values 0 to 1023
typedef struct {
	uint16_t freq;
	uint16_t index;
	uint16_t effect;
	uint16_t mod;
	uint16_t waveHi;
	uint16_t waveMid;
	uint16_t pos;
	uint16_t tuneFine;
	uint16_t waveLo;
	uint16_t tune;
} orgone_patch_t;

extern orgone_patch_t patch;

void init_patch();

#define A0 0
#define A1 1
#define A2 2
#define A3 3
#define A4 4
#define A5 5
#define A6 6
#define A7 7
#define A8 8
#define A9 9
#define A10 10
#define A11 11
#define A12 12
#define A13 13
#define A14 14
#define A15 15
#define A16 16
#define A17 17
#define A18 18
#define A19 19
#define A20 20

// 0 to 1023
uint16_t analogRead(int pin);
void analogWrite(int pin, int value);

uint8_t digitalReadFast(int pin);
void digitalWriteFast(int pin, uint8_t value);
int millis();

#endif