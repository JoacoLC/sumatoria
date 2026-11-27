#ifndef SC_GAME1P_H_INCLUDED
#define SC_GAME1P_H_INCLUDED

typedef uintptr_t (*game_state_t)(game_t*);

static uintptr_t piece_fall(game_t*);
static uintptr_t operation_calc(game_t*);
static uintptr_t operation_anim(game_t*);
static uintptr_t explosion_anim(game_t*);
static uintptr_t blocks_fall(game_t*);
static uintptr_t check_combostillgoing(game_t*);

static void game_render(game_t*);

#ifdef DEBUG
static void cmd_render(game_t*);
#endif // DEBUG

// Each game state function returns a function pointer
// to the next state. Having a function return a pointer
// to it's own type would cause infinite recursion, so
// it must be cast to uintptr_t first, then cast back
// to the correct pointer type.
#define gamestate_update(game) game.state = (game_state_t)game.state(&game)

void sc_game1p() {
    game_t game1p = {
        .level      = 0,
        .fall_speed = FALLSPEED_MAX,
        .level      = 0,
        .piece.sideblock1.msprite  = &mspr_quadsign,
        .piece.centerblock.msprite = &mspr_quadnumber,
        .piece.sideblock2.msprite  = &mspr_quadnumber,
        .bag = {
            {1, 1},
            {1, 2},
            {1, 3},
            {2, 2},
            {2, 3},
            {3, 3},
            {randint() % BLOCK_MAXVAL + 1, randint() % BLOCK_MAXVAL + 1},
            {randint() % BLOCK_MAXVAL + 1, randint() % BLOCK_MAXVAL + 1}
        },
        .curr_piece = BAG_MAX - 1,
        .fall_sub  = 10,
        .fall_add  = 10,
        .lock_time = LOCKTIME,
        .blocks_fell     = false,
        .operations_done = 0,

        .state = &piece_fall,

        .score = 0,
        .on    = true
    };

    populate_playarea(game1p.playarea);
    timer_set(TIMER_P1PIECEFALL, game1p.fall_speed);
    piece_new(&game1p);

    while (game1p.on) {
        if (!gameon) {
            game1p.on  = false;
            curr_scene = &sc_gameover;
            return;
        }

        if (inputs_key_p1[INP_PAUSE].pressed) {
            sfx_play(SFX_PAUSE, SONG_LENGTH_MS(1));
            sc_optmenu();
            if (curr_scene == sc_title) return;
        }

        gamestate_update(game1p);
        game_render(&game1p);
        #ifdef DEBUG
        cmd_render(&game1p);
        #endif // DEBUG
    }
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

    if (inputs_key_p1[INP_UP].pressed) {
        if (!space_tomove(g, 0, 1)) timers[TIMER_P1PIECELOCK] = true;
        else while (space_tomove(g, 0, 1)) piece_move(&g->piece, 0, 1);
    } else if (inputs_key_p1[INP_DOWN].pressed) {
        if (!space_tomove(g, 0, 1)) timers[TIMER_P1PIECELOCK] = true;
        else piece_movedir.y = 1;
    }

    if      (inputs_key_p1[INP_LEFT].pressed && space_tomove(g, -1, 0)) piece_movedir.x = -1;
    else if (inputs_key_p1[INP_RIGHT].pressed && space_tomove(g, 1,  0)) piece_movedir.x = 1;

    if (piece_movedir.x != 0 || piece_movedir.y != 0) {
        sfx_play(SFX_MOVE, SONG_LENGTH_MS(1));
    }

    piece_move(&g->piece, piece_movedir.x, piece_movedir.y);

    if (inputs_key_p1[INP_ACTION1].pressed)  {
        if (piece_rotate(g, LEFT)) sfx_play(SFX_ROTATION, SONG_LENGTH_MS(1));
    }
    if (inputs_key_p1[INP_ACTION2].pressed) {
        if (piece_rotate(g, INP_RIGHT)) sfx_play(SFX_ROTATION, SONG_LENGTH_MS(1));
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
    g->operations_done = 0;
    g->operationinfo[0].result = BLOCK_MAXVAL;
    g->operationinfo[1].result = BLOCK_MAXVAL;

    for (uint8_t y = PLAYAREA_YSTART; y <= PLAYAREA_YEND; y++) for (uint8_t x = PLAYAREA_XSTART; x <= PLAYAREA_XEND; x++) { // Operation.
        if(!(is_number(g, x, y))) continue;

        if (is_sign(g, x+1, y) && is_number(g, x+2, y)) {
            g->operationinfo[g->operations_done].signpos.x = x + 1;
            g->operationinfo[g->operations_done].signpos.y = y;
            g->operationinfo[g->operations_done].endpos.x = x + 2;
            g->operationinfo[g->operations_done].endpos.y = y;
        } else if (is_sign(g, x, y+1) && is_number(g, x, y+2)) {
            g->operationinfo[g->operations_done].signpos.x = x;
            g->operationinfo[g->operations_done].signpos.y = y + 1;
            g->operationinfo[g->operations_done].endpos.x = x;
            g->operationinfo[g->operations_done].endpos.y = y + 2;
        } else continue;

        g->operationinfo[g->operations_done].startpos.x = x;
        g->operationinfo[g->operations_done].startpos.y = y;

        if (g->playarea[y][x].val <= g->playarea[g->operationinfo[g->operations_done].endpos.y][g->operationinfo[g->operations_done].endpos.x].val) {
            g->operationinfo[g->operations_done].result = g->playarea[g->operationinfo[g->operations_done].endpos.y][g->operationinfo[g->operations_done].endpos.x].val - g->playarea[y][x].val;
        } else g->operationinfo[g->operations_done].result = g->playarea[y][x].val - g->playarea[g->operationinfo[g->operations_done].endpos.y][g->operationinfo[g->operations_done].endpos.x].val;

        // Eliminate zeroes and add score accordingly
        if (g->operationinfo[g->operations_done].result == 0) {
            if (g->combo < COMBO_MAX) g->combo++;

            // The bigger the eliminated number, the bigger the score.
            g->score += (g->playarea[y][x].val * 10) * g->combo;
            next_level(g);
        }

        g->operationinfo[g->operations_done].startpos.x = x;
        g->operationinfo[g->operations_done].startpos.y = y;
        g->operations_done++;
    }

    if (g->operations_done > 0) {
        timer_set(TIMER_P1CLEARNUM, OPERATIONSPEED);
        return (uintptr_t)&operation_anim;
    }
    timer_set(TIMER_P1BLOCKFALL, BLOCKFALLSPEED);
    return (uintptr_t)&check_combostillgoing;
}

static uintptr_t operation_anim(game_t* g) {
    events_chk();

    if (timers[TIMER_P1CLEARNUM]) {
        sfx_play(SFX_OPERATION, SONG_LENGTH_MS(1));
        for (int i = 0; i < g->operations_done; i++) {
            g->playarea[g->operationinfo[i].signpos.y][g->operationinfo[i].signpos.x] = g->playarea[g->operationinfo[i].startpos.y][g->operationinfo[i].startpos.x];
            block_clear(&g->playarea[g->operationinfo[i].startpos.y][g->operationinfo[i].startpos.x]);
        }   
        timer_kill(TIMER_P1CLEARNUM);
        timer_set(TIMER_P1CLEARSIGN, OPERATIONSPEED);
        return (uintptr_t)&operation_anim;
    } else if (timers[TIMER_P1CLEARSIGN]) {
        uintptr_t retval = (uintptr_t)&blocks_fall;

        for (int i = 0; i < g->operations_done; i++) {
            block_changeval (
                &g->playarea[g->operationinfo[i].endpos.y][g->operationinfo[i].endpos.x],
                g->operationinfo[i].result
            );
            block_clear(&g->playarea[g->operationinfo[i].signpos.y][g->operationinfo[i].signpos.x]);
                    timer_kill(TIMER_P1CLEARSIGN);
            if (g->operationinfo[i].result == 0) {
                timer_set(TIMER_P1REMOVEZERO, OPERATIONSPEED * 2);
                retval = (uintptr_t)&explosion_anim;
            }
        }

        return retval;
    }

    return (uintptr_t)&operation_anim;
}

static uintptr_t explosion_anim(game_t* g) {
    #define GRAVITY 10
    #define EXPLOSIONSPEED 200

    events_chk();

    if (timers[TIMER_P1REMOVEZERO]) {
        for (int i = 0; i < g->operations_done; i++) if (g->operationinfo[i].result == 0) {
            block_clear(&g->playarea[g->operationinfo[i].endpos.y][g->operationinfo[i].endpos.x]);
        }
        timer_kill(TIMER_P1REMOVEZERO);
        timer_set(TIMER_P1EXPLOSIONFALL, EXPLOSIONSPEED / 75);
        timer_set(TIMER_P1EXPLOSIONFRAMESTEP, EXPLOSIONSPEED / 5);
        timer_set(TIMER_P1EXPLOSION, EXPLOSIONSPEED);
        
        uint8_t j = 0;
        for (uint8_t i = 0; i < QUADTINY_AMT; i++) {
            if (i >= QUADTINY_AMT / 2) j = 1;
            if (g->operationinfo[j].result != 0) continue;
            g->quadtiny[i].position_x = g->operationinfo[j].endpos.x * CELL_SIZE + randint() % CELL_SIZE / 2;
            g->quadtiny[i].position_y = g->operationinfo[j].endpos.y * CELL_SIZE + randint() % CELL_SIZE / 2;
            g->quadtiny[i].vspeed     = -32;
            g->quadtiny[i].hspeed     = -64 + randint() % 64;
            g->quadtiny[i].curr_frame = 0;
        }

        sfx_play(SFX_EXPLOSION, SONG_LENGTH_MS(1));
    }

    if (timers[TIMER_P1EXPLOSIONFALL]) {
        uint8_t j = 0;
        for (uint8_t i = 0; i < QUADTINY_AMT; i++) {
            if (i >= QUADTINY_AMT / 2) j = 1;
            if (g->operationinfo[j].result != 0) continue;
            g->quadtiny[i].position_y += g->quadtiny[i].vspeed;
            // g->quadtiny[i].position_x += g->quadtiny[i].hspeed;
            g->quadtiny[i].vspeed += GRAVITY;
        }
    }

    if (timers[TIMER_P1EXPLOSIONFRAMESTEP]) {
        uint8_t j = 0;
        for (uint8_t i = 0; i < QUADTINY_AMT; i++) {
            if (i >= QUADTINY_AMT / 2) j = 1;
            if (g->operationinfo[j].result != 0) continue;
            g->quadtiny[i].curr_frame++;
        }
    }

    if (timers[TIMER_P1EXPLOSION]) {
        timer_kill(TIMER_P1EXPLOSION);
        timer_kill(TIMER_P1EXPLOSIONFALL);
        timer_kill(TIMER_P1EXPLOSIONFRAMESTEP);
        return (uintptr_t)&blocks_fall;
    }

    return (uintptr_t)&explosion_anim;
}

static uintptr_t blocks_fall(game_t* g) {        
    bool blocks_falling = false;
    events_chk();
    
    if (timers[TIMER_P1BLOCKFALL]) {
        for (int8_t x = PLAYAREA_XSTART; x <= PLAYAREA_XEND; x++) for (int8_t y = PLAYAREA_YEND; y >= PLAYAREA_YSTART; y--) {
            if (!block_isempty(g, x, y) && block_isempty(g, x, y + 1)) {
                g->playarea[y + 1][x] = g->playarea[y][x];
                block_clear(&g->playarea[y][x]);
                blocks_falling = true;
                g->blocks_fell = true;
                timer_set(TIMER_P1BLOCKFALL, BLOCKFALLSPEED);
            }
        }

        if (!blocks_falling) return (uintptr_t)&operation_calc;
    } 
    
    return (uintptr_t)&blocks_fall;
}

static uintptr_t check_combostillgoing(game_t* g) {
    if (g->operations_done || g->blocks_fell) {
        g->blocks_fell = false;
        return (uintptr_t)&operation_calc;
    }

    g->blocks_fell = false;

    piece_new(g);
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

static void game_render(game_t* g) {
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

    text_spacingy = CELL_SIZE / 4;
    text_render(CELL_SIZE * 2 + text_spacingx / 2, 0, "PROXIMA");  
    text_spacingy = CELL_SIZE / 2;
    number_render(CELL_SIZE / 4, (PLAYAREA_H - 1) * CELL_SIZE, 15, g->score);

    text_spacingx = CELL_SIZE / 3;
    text_spacingy = CELL_SIZE / 2;

    if (g->state == &explosion_anim) {
        int8_t j = 0;
        for (int8_t i = 0; i < QUADTINY_AMT; i++) {
            if (i >= QUADTINY_AMT / 2) j = 1;
            if (g->operationinfo[j].result != 0) continue;
            if (g->quadtiny[i].curr_frame >= 3) continue;
            metasprite_render(
                &mspr_quadtiny[g->quadtiny[i].curr_frame],
                g->quadtiny[i].position_x,
                g->quadtiny[i].position_y,
                CELL_SIZE
            );
        }
    }

    if (g->state != &piece_fall) {
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