#ifndef SC_GAME1P_H_INCLUDED
#define SC_GAME1P_H_INCLUDED

typedef uintptr_t (*game_state_t)(game_t*);

static void game_setup(game_t*);
static void game_render(game_t*, game_state_t);

#ifdef DEBUG
static void cmd_render(game_t*);
#endif // DEBUG

static uintptr_t piece_fall(game_t*);
static uintptr_t operation_calc(game_t*);
static uintptr_t operation_anim(game_t*);
static uintptr_t explosion_anim(game_t*);
static uintptr_t blocks_fall(game_t*);
static uintptr_t check_combostillgoing(game_t*);

// Each game state function returns a function pointer
// to the next state. Having a function return a pointer
// to it's own type would cause infinite recursion, so
// it must be cast to uintptr_t first, then cast back
// to the correct pointer type.
#define gamestate_update(state, game) state = (game_state_t)state(game)

void sc_game1p() { // Setup the main game.
    game_t game1p = {
        .level = 0,
        .fall_speed = 2000,
        .level      = 0,
        .fall_speed = 2000,
        .piece.sideblock1.msprite  = &mspr_quadsign,
        .piece.centerblock.msprite = &mspr_quadnumber,
        .piece.sideblock2.msprite  = &mspr_quadnumber,
        .fall_sub  = 10,
        .fall_add  = 10,
        .lock_time = LOCKTIME,
        .blocks_fell     = false,
        .operations_done = false,

        .score = 0,
        .on    = true
    };

    game_setup(&game1p);

    game_state_t game_state = &piece_fall;

    while (game1p.on) {
        if (!events.gameon) {
            game1p.on  = false;
            curr_scene = &sc_gameover;
            return;
        }

        if (events.pause) {
            sfx_play(SFX_PAUSE, SONG_LENGTH_MS(1));
            sc_optmenu();
            if (curr_scene == sc_title) return;
        }

        gamestate_update(game_state, &game1p);
        game_render(&game1p, game_state);
        #ifdef DEBUG
        cmd_render(&game1p);
        #endif // DEBUG
    }
}

static void game_setup(game_t* g) {
    populate_playarea(g->playarea);
    timer_set(TIMER_P1PIECEFALL, g->fall_speed);
    piece_new(&g->piece);
}

static uintptr_t piece_fall(game_t* g) {
    events_chk();

    position_t piece_movedir = {0, 0};

    if (space_tomove(g, 0, 1)) {
        if (timers[TIMER_P1PIECEFALL]) if (space_tomove(g, 0, 1)) piece_move(&g->piece, 0, 1);
        timer_kill(TIMER_P1PIECELOCK);
        g->piecehitstack = false;
    } else if (!g->piecehitstack) {
        timer_set(TIMER_P1PIECELOCK, g->lock_time);
        g->piecehitstack = true;
    }

    if (events.uppress) {
        if (!space_tomove(g, 0, 1)) timers[TIMER_P1PIECELOCK] = true;
        else while (space_tomove(g, 0, 1)) piece_move(&g->piece, 0, 1);
    } else if (events.dwpress) {
        if (!space_tomove(g, 0, 1)) timers[TIMER_P1PIECELOCK] = true;
        else piece_movedir.y = 1;
    }

    if      (events.lfpress && space_tomove(g, -1, 0)) piece_movedir.x = -1;
    else if (events.ripress && space_tomove(g, 1,  0)) piece_movedir.x = 1;

    if (piece_movedir.x != 0 || piece_movedir.y != 0) {
        sfx_play(SFX_MOVE, SONG_LENGTH_MS(1));
    }

    piece_move(&g->piece, piece_movedir.x, piece_movedir.y);

    if (events.rotleft)  {
        if (piece_rotate(g, LEFT)) sfx_play(SFX_ROTATION, SONG_LENGTH_MS(1));
    }
    if (events.rotright) {
        if (piece_rotate(g, RIGHT)) sfx_play(SFX_ROTATION, SONG_LENGTH_MS(1));
    }

    if (timers[TIMER_P1PIECELOCK]) {
        sfx_play(SFX_PIECELOCK, SONG_LENGTH_MS(1));
        next_level(g);
        g->piecehitstack = false;
        timer_kill(TIMER_P1PIECELOCK);
        timer_kill(TIMER_P1PIECEFALL);
        g->playarea[g->piece.sideblock1_pos.y][g->piece.sideblock1_pos.x] = g->piece.sideblock1;
        g->playarea[g->piece.centerblock_pos.y][g->piece.centerblock_pos.x] = g->piece.centerblock;
        g->playarea[g->piece.sideblock2_pos.y][g->piece.sideblock2_pos.x] = g->piece.sideblock2;
        playfield_raise(g);
        timer_set(TIMER_P1BLOCKFALL, BLOCKFALLSPEED);
        return (uintptr_t)&blocks_fall;
    }

    return (uintptr_t)&piece_fall;
}

static uintptr_t operation_calc(game_t* g) {
    g->operations_done = true;

    for (uint8_t y = 0; y < PLAYAREA_H - 1; y++) for (uint8_t x = 1; x < PLAYAREA_W - 1; x++) { // Operation.
        if(!(is_number(g, x, y))) continue;

        if (is_sign(g, x+1, y) && is_number(g, x+2, y)) {
            g->operation_signpos.x = x + 1;
            g->operation_signpos.y = y;
            g->operation_endpos.x = x + 2;
            g->operation_endpos.y = y;
        } else if (is_sign(g, x, y+1) && is_number(g, x, y+2)) {
            g->operation_signpos.x = x;
            g->operation_signpos.y = y + 1;
            g->operation_endpos.x = x;
            g->operation_endpos.y = y + 2;
        } else continue;

        g->operation_startpos.x = x;
        g->operation_startpos.y = y;

        if (g->playarea[y][x].val <= g->playarea[g->operation_endpos.y][g->operation_endpos.x].val) {
            g->result = g->playarea[g->operation_endpos.y][g->operation_endpos.x].val - g->playarea[y][x].val;
        } else g->result = g->playarea[y][x].val - g->playarea[g->operation_endpos.y][g->operation_endpos.x].val;

        // Eliminate zeroes and add score accordingly
        if (g->result == 0) {
            if (g->combo < COMBO_MAX) g->combo++;

            // The bigger the eliminated number, the bigger the score.
            g->score += (g->playarea[y][x].val * 10) * g->combo;
            next_level(g);
        }

        g->operation_startpos.x = x;
        g->operation_startpos.y = y;
        timer_set(TIMER_P1CLEARNUM, OPERATIONSPEED);
        return (uintptr_t)&operation_anim;
    }

    timer_set(TIMER_P1BLOCKFALL, BLOCKFALLSPEED);
    return (uintptr_t)&blocks_fall;
}

static uintptr_t operation_anim(game_t* g) {
    events_chk();

    if (timers[TIMER_P1CLEARNUM]) {
        sfx_play(SFX_OPERATION, SONG_LENGTH_MS(1));
        g->playarea[g->operation_signpos.y][g->operation_signpos.x] = 
            g->playarea[g->operation_startpos.y][g->operation_startpos.x];
        block_clear(&g->playarea[g->operation_startpos.y][g->operation_startpos.x]);
        timer_kill(TIMER_P1CLEARNUM);
        timer_set(TIMER_P1CLEARSIGN, OPERATIONSPEED);
        return (uintptr_t)&operation_anim;
    } else if (timers[TIMER_P1CLEARSIGN]) {
        block_changeval (
            &g->playarea[g->operation_endpos.y][g->operation_endpos.x],
            g->result
        );
        block_clear(&g->playarea[g->operation_signpos.y][g->operation_signpos.x]);
        timer_kill(TIMER_P1CLEARSIGN);
        if (g->result == 0) {
            timer_set(TIMER_P1REMOVEZERO, OPERATIONSPEED * 2);
            return (uintptr_t)&explosion_anim;
        } else return (uintptr_t)&operation_calc;
    }

    return (uintptr_t)&operation_anim;
}

static uintptr_t explosion_anim(game_t* g) {
    #define GRAVITY 10
    #define EXPLOSIONSPEED 200

    events_chk();

    if (timers[TIMER_P1REMOVEZERO]) {
        block_clear(&g->playarea[g->operation_endpos.y][g->operation_endpos.x]);
        timer_kill(TIMER_P1REMOVEZERO);
        timer_set(TIMER_P1EXPLOSIONFALL, EXPLOSIONSPEED / 75);
        timer_set(TIMER_P1EXPLOSIONFRAMESTEP, EXPLOSIONSPEED / 5);
        timer_set(TIMER_P1EXPLOSION, EXPLOSIONSPEED);
                
        for (uint8_t i = 0; i < QUADTINY_AMT; i++) {
            g->quadtiny[i].position_x = g->operation_endpos.x * CELL_SIZE + randint() % CELL_SIZE / 2;
            g->quadtiny[i].position_y = g->operation_endpos.y * CELL_SIZE + randint() % CELL_SIZE / 2;
            g->quadtiny[i].vspeed     = -32;
            g->quadtiny[i].hspeed     = -64 + randint() % 64;
            g->quadtiny[i].curr_frame = 0;
        }

        sfx_play(SFX_EXPLOSION, SONG_LENGTH_MS(1));
    }

    if (timers[TIMER_P1EXPLOSIONFALL]) {
        for (uint8_t i = 0; i < QUADTINY_AMT; i++) {
            g->quadtiny[i].position_y += g->quadtiny[i].vspeed;
            // g->quadtiny[i].position_x += g->quadtiny[i].hspeed;
            g->quadtiny[i].vspeed += GRAVITY;
        }
    }

    if (timers[TIMER_P1EXPLOSIONFRAMESTEP]) {
        for (uint8_t i = 0; i < QUADTINY_AMT; i++) {
            g->quadtiny[i].curr_frame++;
        }
    }

    if (timers[TIMER_P1EXPLOSION]) {
        timer_kill(TIMER_P1EXPLOSION);
        timer_kill(TIMER_P1EXPLOSIONFALL);
        timer_kill(TIMER_P1EXPLOSIONFRAMESTEP);
        return (uintptr_t)&operation_calc;
    }

    return (uintptr_t)&explosion_anim;
}

static uintptr_t blocks_fall(game_t* g) {        
    bool blocks_falling = false;
    events_chk();
    
    if (timers[TIMER_P1BLOCKFALL]) {
        for (int8_t x = 1; x < PLAYAREA_W - 1; x++) for (int8_t y = PLAYAREA_H - 3; y >= 0; y--) {
            if (!block_isempty(g, x, y) && block_isempty(g, x, y + 1)) {
                g->playarea[y + 1][x] = g->playarea[y][x];
                block_clear(&g->playarea[y][x]);
                blocks_falling = true;
                g->blocks_fell = true;
                timer_set(TIMER_P1BLOCKFALL, BLOCKFALLSPEED);
            }
        }

        if (!blocks_falling) return (uintptr_t)&check_combostillgoing;
    } 
    
    return (uintptr_t)&blocks_fall;
}

static uintptr_t check_combostillgoing(game_t* g) {
    if (!g->operations_done || g->blocks_fell) {
        g->blocks_fell     = false;
        return (uintptr_t)&operation_calc;
    }
    g->operations_done = false;
    g->blocks_fell     = false;

    piece_new(&g->piece);
    g->combo = 0;

    if (!space_tomove(g, 0, 0)) {
        sfx_play(SFX_GAMEOVER, SONG_LENGTH_MS(1));
        curr_scene = &sc_gameover;
        g->on = false;
        return (uintptr_t)&piece_fall;
    }

    timer_set(TIMER_P1PIECEFALL, g->fall_speed);
    return (uintptr_t)&piece_fall; 
}

static void game_render(game_t* g, game_state_t state) {
    render_clear();

    text_spacingx = CELL_SIZE / 2;
    text_spacingy = CELL_SIZE / 2;
    
    for (uint8_t y = 0; y < PLAYAREA_H; y++) for (uint8_t x = 0; x < PLAYAREA_W; x++) {
        metasprite_render (
            g->playarea[y][x].msprite,
            x * CELL_SIZE,
            y * CELL_SIZE,
            CELL_SIZE
        );
        metasprite_render (
            g->playarea[y][x].msprite_txt,
            x * CELL_SIZE + CELL_SIZE / 4,
            y * CELL_SIZE + CELL_SIZE / 4,
            CELL_SIZE / 2
        );
    }

    text_spacingy = CELL_SIZE;

    number_render(CELL_SIZE / 4, (PLAYAREA_H - 1) * CELL_SIZE, 15, g->score);

    text_spacingx = CELL_SIZE / 3;
    text_spacingy = CELL_SIZE / 2;

    if (state == &explosion_anim) {
        for (int8_t i = 0; i < QUADTINY_AMT; i++) {
            if (g->quadtiny[i].curr_frame >= 3) continue;
            metasprite_render(
                &mspr_quadtiny[g->quadtiny[i].curr_frame],
                g->quadtiny[i].position_x,
                g->quadtiny[i].position_y,
                CELL_SIZE
            );
        }
    }

    if (state != &piece_fall) {
        render();
        return;
    }

    metasprite_render (
        g->piece.sideblock1.msprite, 
        g->piece.sideblock1_pos.x * CELL_SIZE,
        g->piece.sideblock1_pos.y * CELL_SIZE,
        CELL_SIZE
    );
    metasprite_render (
        g->piece.centerblock.msprite,
        g->piece.centerblock_pos.x * CELL_SIZE,
        g->piece.centerblock_pos.y * CELL_SIZE,
        CELL_SIZE
    );
    metasprite_render (
        g->piece.sideblock2.msprite,
        g->piece.sideblock2_pos.x * CELL_SIZE,
        g->piece.sideblock2_pos.y * CELL_SIZE,
        CELL_SIZE
    );
    metasprite_render (
        g->piece.sideblock1.msprite_txt,
        g->piece.sideblock1_pos.x * CELL_SIZE + CELL_SIZE / 4,
        g->piece.sideblock1_pos.y * CELL_SIZE + CELL_SIZE / 4,
        CELL_SIZE / 2
    );
    metasprite_render (
        g->piece.centerblock.msprite_txt,
        g->piece.centerblock_pos.x * CELL_SIZE + CELL_SIZE / 4,
        g->piece.centerblock_pos.y * CELL_SIZE + CELL_SIZE / 4,
        CELL_SIZE / 2
    );
    metasprite_render (
        g->piece.sideblock2.msprite_txt,
        g->piece.sideblock2_pos.x * CELL_SIZE + CELL_SIZE / 4,
        g->piece.sideblock2_pos.y * CELL_SIZE + CELL_SIZE / 4,
        CELL_SIZE / 2
    );

    render();
}

#ifdef DEBUG
static void cmd_render(game_t* g) {
    clear_buf();
    for (uint8_t y = 0; y < PLAYAREA_H; y++) for (uint8_t x = 0; x < PLAYAREA_W; x++) {
        if (g->piece.sideblock1_pos.x == x && g->piece.sideblock1_pos.y == y) {
            draw_f(x, y, &g->piece.sideblock1.visual, 1);
        } else if (g->piece.centerblock_pos.x == x && g->piece.centerblock_pos.y == y) {
            draw_f(x, y, &g->piece.centerblock.visual, 1);
        } else if (g->piece.sideblock2_pos.x == x && g->piece.sideblock2_pos.y == y) {
            draw_f(x, y, &g->piece.sideblock2.visual, 1);
        } else draw_f(x, y, &g->playarea[y][x].visual, 1);
    }
}
#endif // DEBUG

#endif // SC_GAME1P_H_INCLUDED