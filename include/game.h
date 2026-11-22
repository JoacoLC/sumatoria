#ifndef GAME_H_INCLUDED
#define GAME_H_INCLUDED

#define LEFT		 -1
#define RIGHT 		 1
#define EMPTY_SPACE  ' '

#define SIDEBLOCK1_STARTX 3
#define SIDEBLOCK1_STARTY 0
#define CENTERBLOCK_STARTX 4
#define CENTERBLOCK_STARTY 0
#define SIDEBLOCK2_STARTX 5
#define SIDEBLOCK2_STARTY 0

#define ROTATETIME 50
#define LOCKTIME   1000

#define PLAYAREA_W   9
#define PLAYAREA_H   10

#define BLOCK_MAXVAL  5
#define BLOCK_MAXCHAR '0' + BLOCK_MAXVAL

#define CURR_BLOCK playarea[y][x].visual

#define PLAYFIELD_RAISE     40
#define DIFFICULTY_INCREASE 2
#define DIFFICULTY_DECREASE 4
#define FALLSPEED_MIN       300
#define FALLSPEED_MAX       2000
#define COMBO_MAX           9

typedef struct {
	int8_t x;
	int8_t y;
} position_t;

typedef struct {
	int8_t side1x;
	int8_t side1y;
	int8_t side2x;
	int8_t side2y;
} rotate_state_t;

typedef struct {
    int8_t curr_frame;
    float position_x;
    float position_y;
    float hspeed;
    float vspeed;
} quadtiny_t;

typedef struct {
    // TODO: Change visual from char to char* so the
    // \0 character at the end prevents an odd visual bug
    // where text_render() renders random bullshit in memory
    // past the actual visual for the block.
	char          visual;
	uint8_t       val;
	metasprite_t* msprite;
    metasprite_t* msprite_txt; 
} block_t;

typedef struct {
	block_t sideblock1;
    block_t centerblock;
    block_t sideblock2;

	position_t sideblock1_pos;
    position_t centerblock_pos;
    position_t sideblock2_pos;

    rotate_state_t rotation;
} piece_t;

typedef struct game_s {
    uint32_t score;

    block_t  playarea[PLAYAREA_H][PLAYAREA_W];
    piece_t  piece;
    // Amount of time until the piece
    // locks to the stack once it's hit it.
    int16_t  lock_time;
    // Speed at which pieces currently fall.
    int16_t	 fall_speed;
    // Amount subtraced from fall_speed on difficulty increase.
    int16_t  fall_sub;
    // Amount added to fall_speed on difficulty decrease.
    int16_t	 fall_add;
    // Current level. Higher levels aren't necessarily harder.
    uint16_t level;

    bool     piecehitstack   :1;
    bool     playfieldraise  :1;
    bool     on              :1;
    bool     blocks_fell     :1;
    bool     operations_done :1;
    int                      :3;
    uint8_t  combo;

    int8_t   result;
    
    uintptr_t (*state)(struct game_s*);

	position_t operation_startpos;
	position_t operation_signpos;
	position_t operation_endpos;

    #define QUADTINY_AMT        8

    quadtiny_t quadtiny[QUADTINY_AMT];
} game_t;

void block_changeval(block_t*, uint8_t);
void block_makesign(block_t*);
void block_clear(block_t*);
void populate_playarea(block_t[PLAYAREA_H][PLAYAREA_W]);
void piece_new(piece_t*);
void piece_move(piece_t*, int, int);
bool piece_rotate(game_t*, int);
void next_level(game_t*);
bool block_isempty(game_t*, int, int);
bool space_tomove(game_t*, int, int);
bool space_torotate(game_t*, int);
bool is_sign(game_t*, int, int);
bool is_number(game_t*, int, int);
void playfield_raise(game_t*);

void block_changeval(block_t* block, uint8_t new_val) {
	if (new_val >= 0 && new_val <= BLOCK_MAXVAL) {
        block->val         = new_val;
        block->visual      = new_val + '0';
        block->msprite     = &mspr_quadnumber;
        block->msprite_txt = &numbers[new_val];
	} else block_clear(block);
}

void block_makesign(block_t* block) {
    block->val         = BLOCK_MAXVAL + 1;
    block->visual      = '-';
    block->msprite     = &mspr_quadsign;
    block->msprite_txt = &mspr_minussign;
}

void block_clear(block_t* block) {
    block->visual      = EMPTY_SPACE;
    block->val         = BLOCK_MAXVAL + 1;
    block->msprite     = &mspr_quadempty;
    block->msprite_txt = NULL;
}

void populate_playarea(block_t playarea[PLAYAREA_H][PLAYAREA_W]) {
    for (uint8_t y = 0; y < PLAYAREA_H; y++) for (uint8_t x = 0; x < PLAYAREA_W; x++) {
        playarea[y][x].msprite_txt = NULL;
        if (y < PLAYAREA_H - 1 && x == 0) {
            playarea[y][x].visual  = SIDE_BORDER;
            playarea[y][x].val     = BLOCK_MAXVAL + 1;
            playarea[y][x].msprite = &mspr_leftborder;
        } else if (y < PLAYAREA_H - 1 && x == PLAYAREA_W - 1) {
            playarea[y][x].visual  = SIDE_BORDER;
            playarea[y][x].val     = BLOCK_MAXVAL + 1;
            playarea[y][x].msprite = &mspr_rightborder;
        } else if (y == PLAYAREA_H - 1 && x == 0) {
            playarea[y][x].visual  = LEFT_BORDER;
            playarea[y][x].val     = BLOCK_MAXVAL + 1;
            playarea[y][x].msprite = &mspr_leftcorner;
        } else if (y == PLAYAREA_H - 1 && x == PLAYAREA_W - 1) {
            playarea[y][x].visual  = RIGHT_BORDER;
            playarea[y][x].val     = BLOCK_MAXVAL + 1;
            playarea[y][x].msprite = &mspr_rightcorner;
        } else if (y == PLAYAREA_H - 1) {
            playarea[y][x].visual  = LOW_BORDER;
            playarea[y][x].val     = BLOCK_MAXVAL + 1;
            playarea[y][x].msprite = &mspr_lowborder;
        } else {
            block_clear(&playarea[y][x]);
            playarea[y][x].msprite = &mspr_quadempty;
        }
    }
}

void piece_new(piece_t* piece) {
    piece->sideblock1_pos.x  = SIDEBLOCK1_STARTX; // Reset piece to original position
    piece->sideblock1_pos.y  = SIDEBLOCK1_STARTY;
    piece->centerblock_pos.x = CENTERBLOCK_STARTX;
    piece->centerblock_pos.y = CENTERBLOCK_STARTY;
    piece->sideblock2_pos.x  = SIDEBLOCK2_STARTX;
    piece->sideblock2_pos.y  = SIDEBLOCK2_STARTY;
    piece->rotation.side1x   = -1;
    piece->rotation.side1y   = 0;
    piece->rotation.side2x   = 1;
    piece->rotation.side2y   = 0;


    block_makesign(&piece->sideblock1);
    block_changeval(&piece->centerblock, randint() % 3 + 1);
    block_changeval(&piece->sideblock2, randint() % 3 + 1);
}

void piece_move(piece_t* piece, int x, int y) {
    piece->sideblock1_pos.x += x;
    piece->sideblock1_pos.y += y;
    piece->centerblock_pos.x += x;
    piece->centerblock_pos.y += y;
    piece->sideblock2_pos.x += x;
    piece->sideblock2_pos.y += y;
}

bool piece_rotate(game_t* g, int leftorright) {
    piece_t temp = g->piece;

    if (leftorright == RIGHT) {
        temp.rotation.side1x = g->piece.rotation.side1y * -1;
        temp.rotation.side1y = g->piece.rotation.side1x;
        temp.rotation.side2x = g->piece.rotation.side2y * -1;
        temp.rotation.side2y = g->piece.rotation.side2x;
    } else if (leftorright == LEFT) {
        temp.rotation.side1x = g->piece.rotation.side1y;
        temp.rotation.side1y = g->piece.rotation.side1x * -1;
        temp.rotation.side2x = g->piece.rotation.side2y;
        temp.rotation.side2y = g->piece.rotation.side2x * -1;
    } else return false;

    // Wall kicks.
    if (!block_isempty(g, temp.centerblock_pos.x + temp.rotation.side1x, temp.centerblock_pos.y + temp.rotation.side1y)) {
        piece_move(&temp, temp.rotation.side1x * -1, temp.rotation.side1y * -1);
    }
    if (!block_isempty(g, temp.centerblock_pos.x + temp.rotation.side2x, temp.centerblock_pos.y + temp.rotation.side2y)) {
        piece_move(&temp, temp.rotation.side2x * -1, temp.rotation.side2y * -1);
    }

    temp.sideblock1_pos.x = temp.centerblock_pos.x + temp.rotation.side1x;
    temp.sideblock1_pos.y = temp.centerblock_pos.y + temp.rotation.side1y;
    temp.sideblock2_pos.x = temp.centerblock_pos.x + temp.rotation.side2x;
    temp.sideblock2_pos.y = temp.centerblock_pos.y + temp.rotation.side2y;

    // Check if the wall kick would leave the piece in an impossible state (e.g., inside non-empty blocks).
    if (
        !block_isempty(g, temp.sideblock1_pos.x, temp.sideblock1_pos.y) ||
        !block_isempty(g, temp.centerblock_pos.x, temp.centerblock_pos.y) ||
        !block_isempty(g, temp.sideblock2_pos.x, temp.sideblock2_pos.y)
    ) {
        return false;
    }

    g->piece = temp;

    timer_set(TIMER_P1ROTATION, ROTATETIME);

    return true;
}

bool block_isempty(game_t* g, int x, int y) {
    return g->playarea[y][x].visual == EMPTY_SPACE;
}

bool space_tomove(game_t* g, int x, int y) {
    return (
        block_isempty(g, g->piece.centerblock_pos.x + x, g->piece.centerblock_pos.y + y) &&
        block_isempty(g, g->piece.sideblock1_pos.x + x, g->piece.sideblock1_pos.y + y) &&
        block_isempty(g, g->piece.sideblock2_pos.x + x, g->piece.sideblock2_pos.y + y)
    );
}

bool space_torotate(game_t* g, int leftorright) {
    if (leftorright == RIGHT) {
        return block_isempty (
            g,
            g->piece.centerblock_pos.x + g->piece.rotation.side1y * -1,
            g->piece.centerblock_pos.y + g->piece.rotation.side1x
        )
        &&
        block_isempty (
            g,
            g->piece.centerblock_pos.x + g->piece.rotation.side2y * -1,
            g->piece.centerblock_pos.y + g->piece.rotation.side2x
        );
    }

    return block_isempty (
        g,
        g->piece.centerblock_pos.x + g->piece.rotation.side1y,
        g->piece.centerblock_pos.y + g->piece.rotation.side1x * -1
    ) &&
    block_isempty (
        g,
        g->piece.centerblock_pos.x + g->piece.rotation.side2y,
        g->piece.centerblock_pos.y + g->piece.rotation.side2x * -1
    );

}


bool is_number(game_t* g, int x, int y) {
    return g->playarea[y][x].visual >= '0' && g->playarea[y][x].visual <= BLOCK_MAXCHAR;
}


bool is_sign(game_t* g, int x, int y) {
    return g->playarea[y][x].visual == '-';
}

void playfield_raise(game_t* g) {
    // if(!g->playfieldraise) return;
    // for (uint8_t y = 0; y < PLAYAREA_H - 1; y++) for (uint8_t x = 1; x < PLAYAREA_W - 1; x++) {
    //     if (block_isempty(g, x, y + 1)) continue;

    //     if (y < PLAYAREA_H - 2) g->playarea[y][x] = g->playarea[y + 1][x];
    //     else block_changeval(&g->playarea[y][x], randint() % BLOCK_MAXVAL + 1);
    // }

    // g->playfieldraise = false;
}

void next_level(game_t* g) {
    g->level++;

    // Give players a break every few levels,
    // decreasing difficulty instead of increasing it.
    if (g->level % 30 >= 20 && g->level < 255) {
        g->fall_speed += g->fall_add;
        g->fall_add   += DIFFICULTY_DECREASE;
    } else {
        g->fall_speed -= g->fall_sub;
        g->fall_sub   += DIFFICULTY_INCREASE;
    }

    if (g->fall_speed < FALLSPEED_MIN) {
        g->fall_speed = FALLSPEED_MIN;
        g->lock_time -= 10;
    } else if (g->fall_speed > FALLSPEED_MAX) {
        g->fall_speed = FALLSPEED_MAX;
    }

    if (g->level % PLAYFIELD_RAISE == PLAYFIELD_RAISE - 1) {
        g->playfieldraise = true;
    }
}

#endif // GAME_H_INCLUDED
