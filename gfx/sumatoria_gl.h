#ifndef SUMATORIA_GL_INCLUDED
#define SUMATORIA_GL_INCLUDED

#include <wingdi.h>
#include <GL/gl.h>
#include <GL/glu.h>
#include "graphics.h"
#include "lodepng.c"

#ifdef WINDOWS
	HGLRC gl_rendercontext = NULL;
	HDC   dev_context	   = NULL;
#endif // WINDOWS

texture_t spritesheet;

const unsigned char* gl_errorget();

void init_graphics() {
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();

	glOrtho(0.0, WIN_WIDTH, WIN_HEIGHT, 0.0, 1.0, -1.0);
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();

	glClearColor(0.0, 0.0, 0.0, 1.0);

	glEnable(GL_TEXTURE_2D);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glDisable(GL_DEPTH_TEST);

	texture_free(&spritesheet);

	unsigned width = 192, height = 128;
	#ifdef DEBUG
	unsigned error =
	#endif // DEBUG
	lodepng_decode32_file(&spritesheet.tex, &width, &height, "gfx\\spritesheet_v2.png");
	#ifdef DEBUG
	draw_f(0, 16, lodepng_error_text(error), 128);
	#endif // DEBUG

	glGenTextures(1, &spritesheet.name);
	glBindTexture(GL_TEXTURE_2D, spritesheet.name);

	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, spritesheet.tex);
}

void render() {
	SwapBuffers(dev_context);
}

void render_clear() {
	glClear(GL_COLOR_BUFFER_BIT);
}

void texture_free(texture_t* s) {
	glDeleteTextures(1, &s->name);
	s->name = 0;
}

float spritesheet_pos(int p, int div) {
	return (1.0 / div) * p;
}

#define RECT_EMPTY(rect) (rect.startx == 0 && rect.starty == 0 && rect.endx == 0 && rect.endy == 0)

void metasprite_render(metasprite_t* ms, float x, float y, uint8_t _size) {
	uint8_t i = 0;
	if (ms == NULL) return;
	for (uint8_t j = 0; j < _size; j += _size / 2) for (uint8_t h = 0; h < _size; h += _size / 2) {
		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();
		glTranslatef(x + h, y + j, 0.0);

		if (RECT_EMPTY(ms->areas[i])) {
			i++;
			continue;
		}

		glColor3f(ms->color3f[0], ms->color3f[1], ms->color3f[2]);

		glBegin(GL_QUADS);
			glTexCoord2f(spritesheet_pos(ms->areas[i].startx, 12), spritesheet_pos(ms->areas[i].starty, 8));
			glVertex2f(0.0, 0.0);
			glTexCoord2f(spritesheet_pos(ms->areas[i].startx, 12), spritesheet_pos(ms->areas[i].endy, 8));
			glVertex2f(0.0, _size / 2);
			glTexCoord2f(spritesheet_pos(ms->areas[i].endx, 12), spritesheet_pos(ms->areas[i].endy, 8));
			glVertex2f(_size / 2, _size / 2);
			glTexCoord2f(spritesheet_pos(ms->areas[i].endx, 12), spritesheet_pos(ms->areas[i].starty, 8));
			glVertex2f(_size / 2, 0.0);
		glEnd();

		i++;
	}
}

void text_render(float x, float y, const char* text, ...) {
    va_list args;
    va_start(args, text);

    int xi = 1;
	int yi = 1;
	for (int i = 0; text[i] != '\0'; i++, xi++) {
		if (text[i] == '-') {
			metasprite_render(&mspr_minussign, x + text_spacingx * xi, y + text_spacingy * yi, text_size);
		} else if (text[i] >= 'A' && text[i] <= 'Z') {
			metasprite_render(&letters[text[i] - 'A'], x + text_spacingx * xi, y + text_spacingy * yi, text_size);
		} else if (text[i] >= 'a' && text[i] <= 'z') {
			metasprite_render(&letters[text[i] - 'a'], x + text_spacingx * xi, y + text_spacingy * yi, text_size);
		} else if (text[i] == '\n') {
			yi++;
			xi = 0;
		}
	}

	va_end(args);
}

void number_render(float x, float y, int length, int number) {
	for(uint64_t div = pow(10, length) / 10, xi = 1; div > 0; div /= 10, xi++) {
		metasprite_render (
			&numbers[number % (div * 10) / div],
			x + text_spacingx * xi,
			y + text_spacingy,
			text_size
		);
	}
}


const unsigned char* gl_errorget() {
	GLenum error = glGetError();

	if (error != GL_NO_ERROR) {
		return gluErrorString(error);
	} else return NULL;
}

metasprite_t mspr_quadnumber = {
	.areas = {
		{8, 4, 10, 6}, 	{10, 4, 8, 6},
		{8, 6, 10,  4}, {10, 6, 8, 4}
	},
	.color3f = {1.0, 0.25, 0.15}
};

metasprite_t mspr_quadsign = {
	.areas = {
		{8, 4, 10, 6}, {10, 4, 8, 6},
		{8, 6, 10,  4}, {10, 6, 8, 4}
	},
	.color3f = {0.15, 0.25, 0.50}
};

metasprite_t mspr_quadempty = {
	.areas = {
		{8, 4, 10, 6}, {10, 4, 8, 6},
		{8, 6, 10, 4}, {10, 6, 8, 4}
	},
	.color3f = {0.12, 0.12, 0.12}
};

metasprite_t mspr_quadtiny[3] = {
    {
        .areas = {
            {1, 1, 2, 2}, {2, 1, 1, 2},
            {1, 2, 2, 1}, {2, 2, 1, 2}
        },
        .color3f = {0.1, 0.5, 0.0}
    },
    {
        .areas = {
            {2, 6, 3, 7}, {3, 6, 2, 7},
            {2, 7, 3, 6}, {3, 7, 2, 6}
        },
        .color3f = {0.0, 0.1, 0.5}
    },
    {
        .areas = {
            {3, 6, 4, 7}, {4, 6, 3, 7},
            {3, 7, 4, 6}, {4, 7, 3, 6}
        },
        .color3f = {0.5, 0.0, 0.1}
    }
};

metasprite_t mspr_leftborder = {
	.areas = {
		{},{10, 4, 12, 5},
		{},{10, 5, 12, 6}
	},
	.color3f = COLOR_WHITE
};

metasprite_t mspr_rightborder = {
	.areas = {
		{10, 4, 12, 5}, {},
		{10, 5, 12, 6}, {}
	},
	.color3f = COLOR_WHITE
};

metasprite_t mspr_lowborder = {
	.areas = {
		{10, 6, 12, 8}, {10, 6, 12, 8},
		{}, 			{},
	},
	.color3f = COLOR_WHITE
};

metasprite_t mspr_leftcorner = {
	.areas = {
		{0, 0, 0, 0}, {8, 6, 10, 8},
		{0, 0, 0, 0}, {0, 0, 0,  0}
	},
	.color3f = COLOR_WHITE
};

metasprite_t mspr_rightcorner = {
	.areas = {
		{10, 6, 8, 8}, {0, 0, 0, 0},
		{0, 0, 0, 0},  {0, 0, 0, 0}
	},
	.color3f = COLOR_WHITE
};

//=============//
// ----------- //
// - NUMBERS - //
// ----------- //
//=============//

metasprite_t numbers[10] = {{
	.areas = { // 0
		{8, 0, 7, 1}, {7, 0, 8, 1},
		{8, 1, 7, 0}, {7, 1, 8, 0}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // 1
		{0, 0, 1, 1}, {1, 0, 2, 1},
		{0, 1, 1, 2}, {1, 1, 0, 2}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // 2
		{2, 0, 3, 1}, {3, 0, 4, 1},
		{2, 1, 3, 2}, {3, 1, 4, 2}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // 3
		{0, 2, 1, 3}, {1, 2, 2, 3},
		{0, 3, 1, 2}, {1, 3, 2, 2}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // 4
		{2, 2, 3, 3}, {3, 2, 2, 3},
		{2, 3, 3, 4}, {3, 3, 4, 4}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // 5
		{4, 0, 5, 1}, {5, 0, 6, 1},
		{4, 1, 5, 2}, {5, 1, 6, 2}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // 6
		{0, 3, 1, 4}, {1, 3, 2, 4},
		{3, 2, 4, 3}, {4, 2, 3, 3}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // 7
		{4, 2, 5, 3},  {5, 2, 6, 3},
		{4, 3, 5, 4}, {5, 3, 4, 4}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // 8
		{3, 3, 4, 2}, {4, 3, 3, 2},
		{3, 2, 4, 3}, {4, 2, 3, 3}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // 9
		{3, 3, 4, 2}, {4, 3, 3, 2},
		{2, 4, 1, 3}, {1, 4, 0, 3}
	},
	.color3f = COLOR_WHITE
}};

metasprite_t mspr_minussign = {
	.areas = {
		{3, 7, 4, 8}, {4, 7, 3, 8},
		{3, 8, 4, 7}, {4, 8, 3, 7}
	},
	.color3f = COLOR_WHITE
};

metasprite_t letters[26] = {
{
	.areas = { // A
		{6, 0, 7, 1}, {7, 0, 6, 1},
		{6, 1, 7, 2}, {7, 1, 6, 2}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // B
		{8, 3, 9, 4}, {9, 3, 10, 4},
		{8, 4, 9, 3}, {9, 4, 10, 3}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // C
		{8, 2, 9, 3}, {9, 2, 10, 3},
		{8, 3, 9, 2}, {9, 3, 10, 2}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // D
		{6, 2, 7, 3}, {7, 2, 8, 3},
		{6, 3, 7, 2}, {7, 3, 8, 2}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // E
		{8, 0, 9, 1}, {9, 0, 10, 1},
		{8, 1, 9, 0}, {9, 1, 10, 0}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // F
		{8, 0, 9, 1}, {9, 0, 10, 1},
		{8, 1, 9, 2}, {9, 1, 10, 2}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // G
		{10, 0, 11, 1}, {11, 0, 12, 1},
		{10, 1, 11, 2}, {11, 1, 12, 2}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // H
		{2, 2, 3, 3}, {3, 2, 2, 3},
		{2, 3, 3, 2}, {3, 3, 2, 2}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // I
		{0, 2, 1, 1}, {1, 2, 0, 1},
		{0, 1, 1, 2}, {1, 1, 0, 2}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // J
		{4, 4, 5, 5}, {5, 4, 6, 5},
		{4, 5, 5, 6}, {5, 5, 6, 6}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // K
		{10, 4, 11, 3}, {11, 4, 12, 3},
		{10, 3, 11, 4}, {11, 3, 12, 4}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // L
		{4, 6, 5, 7}, {5, 6, 6, 7},
		{4, 7, 5, 8}, {5, 7, 6, 8}

	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // M
		{6, 4, 7, 5}, {7, 4, 6, 5},
		{6, 5, 7, 6}, {7, 5, 6, 6}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // N
		{7, 4, 8, 5}, {8, 4, 7, 5},
		{7, 5, 8, 4}, {8, 5, 7, 4}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // O
		{8, 0, 7, 1}, {7, 0, 8, 1},
		{8, 1, 7, 0}, {7, 1, 8, 0}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // P
		{0, 4, 1, 5}, {1, 4, 2, 5},
		{0, 5, 1, 6}, {1, 5, 2, 6}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // Q
		{8, 0, 7, 1}, {7, 0, 8, 1},
		{8, 1, 7, 0}, {7, 1, 8, 2}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // R
		{10, 2, 11, 3}, {11, 2, 12, 3},
		{10, 3, 11, 4}, {11, 3, 12, 4}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // S
		{2, 5, 3, 6}, {3, 5, 4, 6},
		{4, 6, 3, 5}, {3, 6, 2, 5}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // T
		{6, 6, 7, 7}, {7, 6, 6, 7},
		{0, 1, 1, 2}, {1, 1, 0, 2}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // U
		{8, 6, 7, 7}, {7, 6, 8, 7},
		{8, 7, 7, 8}, {7, 7, 8, 8}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // V
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // W
		{6, 6, 7, 5}, {7, 6, 6, 5},
		{6, 5, 7, 4}, {7, 5, 6, 4}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // X
		{0, 6, 1, 7}, {1, 6, 0, 7},
		{0, 7, 1, 6}, {1, 7, 0, 6}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // Y
		{0, 6, 1, 7}, {1, 6, 0, 7},
		{0, 1, 1, 2}, {1, 1, 0, 2}
	},
	.color3f = COLOR_WHITE
},
{
	.areas = { // Z
		{2, 4, 3, 5}, {3, 4, 4, 5},
		{4, 5, 3, 4}, {3, 5, 2, 4}
	},
	.color3f = COLOR_WHITE
}
};

#endif //SUMATORIA_GL_INCLUDED