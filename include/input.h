#ifndef INPUT_H_INCLUDED
#define INPUT_H_INCLUDED

extern void events_chk();

typedef struct {
	uintptr_t vk_pause;
	uintptr_t vk_uppress;
	uintptr_t vk_lfpress;
	uintptr_t vk_dwpress;
	uintptr_t vk_ripress;
	uintptr_t sc_rotleft;
	uintptr_t sc_rotright;

	bool anykpress;

	bool uppress;
	bool lfpress;
	bool dwpress;
	bool ripress;

	bool rotleft;
	bool rotright;

	bool pause;
	
	bool gameon;
} events_t;

#ifdef WINDOWS
	#define SCANCODE_Z 0x002C
	#define SCANCODE_X 0x001B
	#define SCANCODE_C 0x002E
	#define SCANCODE_V 0x002F

	#define KEYCODE_W 0x57
	#define KEYCODE_A 0x41
	#define KEYCODE_S 0x53
	#define KEYCODE_D 0x44
#endif // WINDOWS

events_t events = {
	#ifdef WINDOWS
	.vk_uppress = VK_UP,
	.vk_lfpress = VK_LEFT,
	.vk_dwpress = VK_DOWN,
	.vk_ripress = VK_RIGHT,

	.sc_rotleft  = SCANCODE_C,
	.sc_rotright = SCANCODE_V,

	.vk_pause = VK_ESCAPE,
	#endif // WINDOWS

	.anykpress = false,
	.uppress = false, .lfpress = false, .dwpress = false, .ripress = false,
	.rotleft = false, .rotright = false,
	.pause = false,
	.gameon = true
};

#endif // INPUT_H_INCLUDED
