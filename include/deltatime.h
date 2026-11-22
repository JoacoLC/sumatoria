#ifndef DELTATIME_H_INCLUDED
#define DELTATIME_H_INCLUDED

//extern uint64_t frame_start;
//extern uint64_t frame_end;
//extern uint64_t deltatime_mill;

//extern void deltatime_start();
//extern void deltatime_end();
//extern void deltatime_get();

uint64_t func_start;
uint64_t func_end;
uint64_t functime;
extern void functime_start();
extern void functime_end();
extern void functime_get();

#endif // DELTATIME_H_INCLUDED
