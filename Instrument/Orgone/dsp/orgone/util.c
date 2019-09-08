

int randomVal(int min, int max) {
  int range = max - min;
  return (random() % range) + min;
}

int constrain(int value, int min, int max) {
	return (value > max ? max : value) < min ? min : value;
}

int map(int value, int fromLow, int fromHigh, int toLow, int toHigh) {
	int fromRange = fromHigh - fromLow;
	int toRange = toHigh - toLow;

	return toLow + (((float) (value - fromLow) / (float) fromRange) * toRange);
}

int max(int a, int b) {
	return (a > b) ? a : b;
}

int min(int a, int b) {
	return (a < b) ? a : b;
}
