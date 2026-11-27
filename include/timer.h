#ifndef TIMER_H_INCLUDED
#define TIMER_H_INCLUDED

#define TIMERS_AMT 20

#define TIMER_P1PIECEFALL           0
#define TIMER_P2PIECEFALL           1
#define TIMER_P1PIECELOCK           2
#define TIMER_P2PIECELOCK           3
#define TIMER_P1ROTATION            4
#define TIMER_P2ROTATION            5
#define TIMER_P1BLOCKFALL           6
#define TIMER_P2BLOCKFALL           7
#define TIMER_P1CLEARNUM            8
#define TIMER_P2CLEARNUM            9
#define TIMER_P1CLEARSIGN          10
#define TIMER_P2CLEARSIGN          11
#define TIMER_P1REMOVEZERO         12
#define TIMER_P2REMOVEZERO         13
#define TIMER_SONG1LOOP            14
#define TIMER_SFXCUT               15
#define TIMER_P1EXPLOSIONFALL      16
#define TIMER_P1EXPLOSIONFRAMESTEP 17
#define TIMER_P1EXPLOSION          18
#define TIMER_FLASHTEXT            19

#define BLOCKFALLSPEED 50
#define OPERATIONSPEED 75


bool timers[TIMERS_AMT];

extern void timer_set(uintptr_t, uint32_t);
extern void timer_kill(uintptr_t);

#endif // TIMER_H_INCLUDED
