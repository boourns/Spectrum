

orgone_patch_t patch;
int written;

/*
NAME                     ACTUAL INDEX        ANALOGREAD INDEX
#define POT_FREQ         analogControls[0]   13
#define POT_INDEX        analogControls[1]   3
#define POT_EFFECT       analogControls[2]   4
#define POT_MOD          analogControls[3]   5
#define POT_WAVE_HI      analogControls[4]   6
#define POT_WAVE_MID     analogControls[5]   7
#define POT_POS          analogControls[6]   8
#define POT_TUNE_FINE    analogControls[7]   11
#define POT_WAVE_LO      analogControls[8]   10
#define POT_TUNE         analogControls[9]   9

const int potPinTable_ret[] = {13, 3, 4, 5, 6, 7, 8, 11, 10, 9}; 

analogControls[X] = analogRead(potPinTable_ret[X]);

*/

uint16_t analogRead(int pin) {
	switch(pin) {
	case 13: // POT_FREQ
		return patch.freq;
	case 3:
		return patch.index;
	case 4:
		return patch.effect;
	case 5:
		return patch.mod;
	case 6:
		return patch.waveHi;
	case 7:
		return patch.waveMid;
	case 8:
		return patch.pos;
	case 11:
		return patch.tuneFine;
	case 10:
		return patch.waveLo;
	case 9:
		return patch.tune;
	default:
		//printf("UNKNOWN analogRead %d\n", pin);
		break;
	}
	return 0;
}

void analogWrite(int pin, int value) {
	//printf("analogWrite %d, %d\n", pin, value);
	if (pin == 0) {
		written = value;
	}
}

uint8_t digitalReadFast(int pin) {
	//printf("digitalReadFast %d\n", pin);
	return 0;
}

void digitalWriteFast(int pin, uint8_t value) {
	//printf("digitalWriteFast %d, %d\n", pin, value);
}

int millis() {
	return 0;
}
