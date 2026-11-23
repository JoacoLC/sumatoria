#ifndef GRAPHICS_H_INCLUDED
#define GRAPHICS_H_INCLUDED

#define TEXTURE_AMT    1
#define CELL_SIZE	   64
#define MAX_QUAD_COOR  CELL_SIZE / 2
#define PIXEL_BYTESIZE 4
#define PIXEL_BITSIZE  4
#define SPRITE_W	   64
#define SPRITE_H	   64
#define SPRITE_SIZE    SPRITE_W * SPRITE_H

#define SPRITESHEET_DIV 12.0

#ifdef UNICODE
	#define SIDE_BORDER	 '║'
	#define LOW_BORDER	 '═'
	#define LEFT_BORDER	 '╚'
	#define	RIGHT_BORDER '╜'
#else
	#define SIDE_BORDER	 '|'
	#define LOW_BORDER	 '_'
	#define LEFT_BORDER	 '\\'
	#define	RIGHT_BORDER '/'
#endif

#define COLOR_WHITE {1.0, 1.0, 1.0}

#define NUM_RENDER(s, startx, starty, endx, endy, x, y) texture_render(s, startx, starty, endx, endy, (x * CELL_SIZE) + (CELL_SIZE / 8), (y * CELL_SIZE) + (CELL_SIZE / 8), SPRITE_W / 1.5, SPRITE_H / 1.5)

typedef struct {
	GLuint  	   name;
	unsigned char* tex;
} texture_t;

typedef struct {
	unsigned startx :4;
	unsigned starty :4;
	unsigned endx   :4;
	unsigned endy   :4;
} rect_t;

typedef struct {
	rect_t 	 areas[4];
	float	 color3f[3];
} metasprite_t;

typedef struct {
	int 		  curr_frame;
	metasprite_t* frames;
} metasprite_anim_t;

uint16_t text_size 	   = CELL_SIZE / 2;
uint16_t text_spacingx = CELL_SIZE / 3;
uint16_t text_spacingy = CELL_SIZE / 2;

extern void  graphics_init();
extern void  render();
extern void  render_clear();
extern void  texture_free(texture_t*);
extern float spritesheet_pos(int p, int div);
extern void  metasprite_render(metasprite_t*, float x, float y, uint8_t _size);
extern void  text_render(float x, float y, const char* text, ...);
extern void  number_render(float x, float y, int length, int number);
void 		 metasprite_anim(int num_frames, int speed, bool looping, metasprite_anim_t*);

void metasprite_anim(int num_frames, int speed, bool looping, metasprite_anim_t* mspr_anim) {
	
}

extern metasprite_t letters[26];
extern metasprite_t numbers[10];
extern metasprite_t mspr_minussign;
extern metasprite_t mspr_tilde;
extern metasprite_t mspr_dot;

extern metasprite_t mspr_quadnumber;
extern metasprite_t mspr_quadsign;
extern metasprite_t mspr_quadempty;
extern metasprite_t mspr_leftborder;
extern metasprite_t mspr_rightborder;
extern metasprite_t mspr_leftcorner;
extern metasprite_t mspr_rightcorner;
extern metasprite_t mspr_lowborder;

metasprite_t mspr_quadtiny[3];

#endif // GRAPHICS_H_INCLUDED