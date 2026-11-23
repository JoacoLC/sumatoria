#ifndef INPUT_H_INCLUDED
#define INPUT_H_INCLUDED

extern void events_chk();
extern void keyname_get(uintptr_t, char buffer[2]);
void inputs_init();

typedef struct {
	uintptr_t key;
	bool 	  pressed;
	char  	  name[2];
} input_t;

#define INPUTS_AMT 8

#define INP_PAUSE 	0
#define INP_UP    	1
#define INP_LEFT  	2
#define INP_RIGHT 	3
#define INP_DOWN  	4
#define INP_ACTION1 5
#define INP_ACTION2 6
#define INP_ANYKEY  7

input_t inputs_key_p1[INPUTS_AMT];
input_t inputs_joy_p1[INPUTS_AMT];
input_t inputs_key_p2[INPUTS_AMT];
input_t inputs_joy_p2[INPUTS_AMT];

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

bool gameon = true;

void inputs_init() {
	inputs_key_p1[INP_PAUSE].key   = VK_ESCAPE;
	inputs_key_p1[INP_UP].key 	   = VK_UP;
	inputs_key_p1[INP_LEFT].key    = VK_LEFT;
	inputs_key_p1[INP_DOWN].key    = VK_DOWN;
	inputs_key_p1[INP_RIGHT].key   = VK_RIGHT;
	inputs_key_p1[INP_ACTION1].key = SCANCODE_C;
	inputs_key_p1[INP_ACTION2].key = SCANCODE_V;
}


// {
	// #ifdef WINDOWS
	// .VK_UPpress = VK_UP,
	// .vk_lfpress = VK_LEFT,
	// .vk_dwpress = VK_DOWN,
	// .vk_ripress = VK_RIGHT,

	// .sc_rotINP_LEFT  = SCANCODE_C,
	// .sc_rotINP_RIGHT = SCANCODE_V,

	// .vk_INP_pause = VK_ESCAPE,
	// #endif // WINDOWS

	// .anykpress = false,
	// .INP_UPpress = false, .lfpress = false, .dwpress = false, .ripress = false,
	// .rotINP_LEFT = false, .rotINP_RIGHT = false,
	// .INP_pause = false,
	// .gameon = true
// };

#endif // INPUT_H_INCLUDED
