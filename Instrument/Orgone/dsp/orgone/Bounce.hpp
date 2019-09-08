#ifndef _BOUNCE_H_
#define _BOUNCE_H_

class Bounce {
public:

	Bounce(int pin, int ms) {
		this->pin = pin;
	}
	
	bool update() {
		return false;
	}

	bool fallingEdge() {
		return false;
	}

	bool risingEdge() {
		return false;
	}

private:
	int pin;
};

#endif