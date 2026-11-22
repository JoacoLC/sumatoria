#ifndef RANDOM_H_INCLUDED
#define RANDOM_H_INCLUDED

extern void  seed_set();
unsigned int randint();

uint32_t seed = 1;

unsigned int randint() {
	register uint32_t mod  = seed + 149876235;
	register uint32_t mult = mod  - 592487631;
	register uint32_t inc  = mod  - 129748365;
	seed = (mult * seed + inc) % mod;
	return seed;
}


#endif // RANDOM_H_INCLUDED