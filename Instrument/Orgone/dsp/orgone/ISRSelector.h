#ifndef _ISRSelector_h_
#define _ISRSelector_h_

class ISRSelector {
public:
	void begin(void (*ptr)(), int rate) {
		isr = ptr;
	}

	void end() {

	}

	void (*isr)();
};

#endif