#ifndef SCENES_H_INCLUDED
#define SCENES_H_INCLUDED

void (*curr_scene)();

void sc_title();
void sc_game1p();
void sc_gameover();

void draw_menu();
void sc_optmenu();

#include "../scenes/sc_title.h"
#include "../scenes/sc_game1p.h"
#include "../scenes/sc_gameover.h"
#include "../scenes/sc_optmenu.h"

#endif // SCENES_H_INCLUDED
