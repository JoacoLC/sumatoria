// Using unity / single translation unit build.

#define WIN32_LEAN_AND_MEAN
#define WIN32_EXTRA_LEAN

// Use the DirectSound C interface.
#ifndef CINTERFACE
#define CINTERFACE
#endif // CINTERFACE

#include <stdint.h>
#include <math.h>
#include <windows.h>
#include <mmreg.h>
#include <mmsystem.h>
#include <dsound.h>
#include "gameinfo.h"
#include "timer.h"
#include "input.h"
#include "print.h"
#include "random.h"
#include "deltatime.h"
#include "sumatoria_gl.h"
#include "ost.h"
#include "sound.h"
#include "game.h"
#include "scenes.h"

MSG  _msg = {};
WORD key_flags;
WORD scan_code;
HWND win_handle;
RECT client_rect;
LARGE_INTEGER p;

const char *noooo = "NOOOOOO";

LRESULT CALLBACK window_proc(HWND handle, UINT _msg, WPARAM w_param, LPARAM l_param);
void             setup_pxformat(HDC _dev_context);
DWORD WINAPI     sound_proc(LPVOID parameter);

int WINAPI WinMain(HINSTANCE currinst_hnd, HINSTANCE previnst_hnd, PSTR cmd_args, int cmd_show) {
    const char* class_name  = "WinName";
    WNDCLASS win_class      = {};

    win_class.lpfnWndProc   = window_proc;
    win_class.hInstance     = currinst_hnd;
    win_class.lpszClassName = class_name;

    RegisterClass(&win_class);

    win_handle = CreateWindowEx (
        0,                                // Optional window styles.
        class_name,                       // Window class
        GAMENAME,                         // Window text
        WS_OVERLAPPEDWINDOW | WS_VISIBLE |
        CS_OWNDC | WS_CLIPSIBLINGS | WS_CLIPCHILDREN, // Window style

        CW_USEDEFAULT, CW_USEDEFAULT, WIN_WIDTH, WIN_HEIGHT, // Size and position

        NULL,         // Parent window
        NULL,         // Menu
        currinst_hnd, // Instance handle
        NULL          // Additional application data
    );

    seed_set();
    init_graphics();
    sound_init();

    curr_scene = &sc_title;

    while (events.gameon) curr_scene();

    return 0;
}

//  =======================
//  ||...................||
//  ||.....S.O.U.N.D.....||
//  ||.....S.O.U.N.D.....||
//  ||.....S.O.U.N.D.....||
//  ||...................||
//  =======================

#ifndef DSBCAPS_TRUEPLAYPOSITION // Not defined in MinGW dsound headers, so let's add it!
#define DSBCAPS_TRUEPLAYPOSITION 0x00080000
#endif

SUsample su_buffer[SU_BUFFER_LENGTH];

WAVEFORMATEX wave_format = {
#ifdef SU_SAMPLE_FLOAT
	.wFormatTag = WAVE_FORMAT_IEEE_FLOAT,
#else
	.wFormatTag = WAVE_FORMAT_PCM,
#endif
	.nChannels       = SU_CHANNEL_COUNT,
	.nSamplesPerSec  = SU_SAMPLE_RATE,
	.nAvgBytesPerSec = SU_SAMPLE_RATE * SU_SAMPLE_SIZE * SU_CHANNEL_COUNT,
	.nBlockAlign     = SU_SAMPLE_SIZE * SU_CHANNEL_COUNT,
	.wBitsPerSample  = SU_SAMPLE_SIZE*8,
	.cbSize          = 0
};

DSBUFFERDESC musicbuf_description = {
	.dwSize          = sizeof(DSBUFFERDESC),
	.dwFlags         = DSBCAPS_GETCURRENTPOSITION2 | DSBCAPS_GLOBALFOCUS | DSBCAPS_TRUEPLAYPOSITION | DSBCAPS_CTRLVOLUME,
	.dwBufferBytes   = SU_PATTERN_BYTES,
	.dwReserved      = 0,
	.lpwfxFormat     = &wave_format,
	.guid3DAlgorithm = {0}
};

DSBUFFERDESC sfxbuf_description = {
    .dwSize          = sizeof(DSBUFFERDESC),
	.dwFlags         = DSBCAPS_GETCURRENTPOSITION2 | DSBCAPS_GLOBALFOCUS | DSBCAPS_TRUEPLAYPOSITION | DSBCAPS_CTRLVOLUME,
	.dwBufferBytes   = SU_PATTERN_BYTES * 8,
	.dwReserved      = 0,
	.lpwfxFormat     = &wave_format,
	.guid3DAlgorithm = {0}
};

LPDIRECTSOUND       direct_sound;
LPDIRECTSOUNDBUFFER music_buffer;
LPVOID              music_bufstart;
DWORD               music_bufsize;
LPDIRECTSOUNDBUFFER sfx_buffer;
LPVOID              sfx_bufstart;
DWORD               sfx_bufsize;
DWORD               audio_whereplaycursor;

void sound_init() {
    render_clear();
    text_render(0, 0, "CARGANDO TEMONES...");
    render();

    #ifdef SU_LOAD_GMDLS
	su_load_gmdls();
    #endif // SU_LOAD_GMDLS

    CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)su_render_song, su_buffer, 0, NULL);
    
    // TODO: Replace this by a CPU speed agnostic version.             
    // And improve the loading times so it's ideally not needed anyways.
    Sleep(5000); 

    DirectSoundCreate(NULL, &direct_sound, NULL);
	IDirectSound_SetCooperativeLevel(direct_sound, win_handle, DSSCL_PRIORITY);

    IDirectSound_CreateSoundBuffer(direct_sound, &sfxbuf_description, &sfx_buffer, NULL);
    IDirectSoundBuffer_Lock (
        sfx_buffer,
        0,
        SU_PATTERN_BYTES * 8,
        &sfx_bufstart,
        &sfx_bufsize,
        NULL,
        NULL,
        0
    );
    memcpy(sfx_bufstart, su_buffer, SU_PATTERN_BYTES * 8);
    IDirectSoundBuffer_Unlock(sfx_buffer, &sfx_bufstart, sfx_bufsize, NULL, 0);
    #ifdef DEBUG
        if (!sfx_setvolume(DEFAULT_SFX_VOLUME)) {
            MessageBox(win_handle, "Couldn't change volume!", noooo, MB_OK);
        }
    #else
        sfx_setvolume(DEFAULT_SFX_VOLUME);
    #endif // DEBUG

    IDirectSound_CreateSoundBuffer(direct_sound, &musicbuf_description, &music_buffer, NULL);

    CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)sound_proc, NULL, 0, NULL);
}

DWORD    write_cursor;
DWORD    write_cursor_last;
DWORD    play_cursor;
uint16_t pattern_n = 8;

DWORD WINAPI sound_proc(LPVOID parameter) {  
    IDirectSoundBuffer_Lock (
        music_buffer,
        0,
        SU_PATTERN_BYTES,
        &music_bufstart,
        &music_bufsize,
        NULL,
        NULL,
        0
    );

    while (true) {
        IDirectSoundBuffer_GetCurrentPosition(music_buffer, &play_cursor, &write_cursor);
        memcpy (
            (int8_t*)music_bufstart + write_cursor,
            &su_buffer[(PATTERN(pattern_n) + write_cursor) / SU_SAMPLE_SIZE],
            SU_PATTERN_BYTES - write_cursor
        );
        if (write_cursor < write_cursor_last) {
            if (pattern_n < song_end) pattern_n++;
            else pattern_n = 9;
        }

        write_cursor_last = write_cursor;
    }

    IDirectSoundBuffer_Unlock(music_buffer, &music_bufstart, music_bufsize, NULL, 0);
    return DS_OK;
}

void music_play(uint32_t position) {
    pattern_n = 8;
    IDirectSoundBuffer_Play(music_buffer, 0, 0, DSBPLAY_LOOPING);
}

void music_stop() {
    IDirectSoundBuffer_Stop(music_buffer);
}

bool music_setvolume(int32_t v) {
    HRESULT h = IDirectSoundBuffer_SetVolume(music_buffer, v);
    if (h == DS_OK) return true;
    else return false;
}

long music_getvolume() {
    IDirectSoundBuffer_GetVolume(music_buffer, &music_volume);
    return music_volume;
}

void sfx_play(uint32_t position, uint32_t milliseconds) {
    if(position != UINT32_MAX) IDirectSoundBuffer_SetCurrentPosition(sfx_buffer, position);
    IDirectSoundBuffer_Play(sfx_buffer, 0, 0, 0);
    timer_set(TIMER_SFXCUT, milliseconds);
}

bool sfx_setvolume(int32_t v) {
    HRESULT h = IDirectSoundBuffer_SetVolume(sfx_buffer, v);
    if (h == DS_OK) return true;
    else return false;
}

long sfx_getvolume() {
    IDirectSoundBuffer_GetVolume(sfx_buffer, &sfx_volume);
    return sfx_volume;
}

void events_chk() {
    events.anykpress = false;
    events.uppress   = false;
    events.lfpress   = false;
    events.dwpress   = false;
    events.ripress   = false;
    events.rotleft   = false;
    events.rotright  = false;
    events.pause     = false;

    for (uint8_t i = 0; i < TIMERS_AMT; i++) timers[i] = false;

    if (GetMessage(&_msg, NULL, 0, 0) > 0) {
        TranslateMessage(&_msg);
        DispatchMessage(&_msg);
    }
}

LRESULT CALLBACK window_proc(HWND handle, UINT msg, WPARAM w_param, LPARAM l_param) {
    if (msg == WM_CREATE) {
        dev_context = GetDC(handle);
        setup_pxformat(dev_context);

        gl_rendercontext = wglCreateContext(dev_context);
        if (gl_rendercontext == NULL) MessageBox(handle, "No se pudo crear un contexto de OpenGL. :(", noooo, MB_OK);
        wglMakeCurrent(dev_context, gl_rendercontext);
        GetClientRect(handle, &client_rect);
    } else if (msg == WM_QUIT) {
        return 0;
    } else if (msg == WM_CLOSE) {
        DestroyWindow(handle);
        return 0;
    } else if (msg == WM_DESTROY) {
        events.gameon = false;
        wglMakeCurrent(NULL, NULL);
        wglDeleteContext(gl_rendercontext);
        PostQuitMessage(0);
        return 0;
    } else if (msg == WM_KEYDOWN) {
        events.anykpress = true;
        events.pause     = w_param == events.vk_pause;
        events.uppress   = w_param == events.vk_uppress;
        events.lfpress   = w_param == events.vk_lfpress;
        events.dwpress   = w_param == events.vk_dwpress;
        events.ripress   = w_param == events.vk_ripress;
        events.rotleft   = LOBYTE(HIWORD(l_param)) == events.sc_rotleft;
        events.rotright  = LOBYTE(HIWORD(l_param)) == events.sc_rotright;
    } else if (msg == WM_TIMER) {
         timers[w_param] = true;
         if (timers[TIMER_SFXCUT]) {
            IDirectSoundBuffer_Stop(sfx_buffer);
            timer_kill(TIMER_SFXCUT);
         }
    }

    return DefWindowProc(handle, msg, w_param, l_param);
}

void setup_pxformat(HDC _dev_context) {
    PIXELFORMATDESCRIPTOR pxformat_desc = {
        .nSize        = sizeof(PIXELFORMATDESCRIPTOR),
        .nVersion     = 1,
        .dwFlags      = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL |
                        PFD_GENERIC_FORMAT | PFD_GENERIC_ACCELERATED |
                        PFD_DOUBLEBUFFER   | PFD_SWAP_LAYER_BUFFERS,
        .iPixelType   = PFD_TYPE_RGBA,
        .cColorBits   = 24,
        .cAccumBits   = 0,
        .cDepthBits   = 1,
        .cStencilBits = 0
    };

    int px_format = ChoosePixelFormat(_dev_context, &pxformat_desc);

    SetPixelFormat(_dev_context, px_format, &pxformat_desc);
}

//  =======================
//  ||...................||
//  ||.....T.I.M.E.R.....||
//  ||.....T.I.M.E.R.....||
//  ||.....T.I.M.E.R.....||
//  ||...................||
//  =======================

void timer_set(uintptr_t id, uint32_t milliseconds) {
    SetTimer(win_handle, id, milliseconds, NULL);
}

void timer_kill(uintptr_t id) {
    KillTimer(win_handle, id);
}

//void deltatime_start() {
//    QueryPerformanceCounter(&p);
//    frame_start = p.HighPart + p.LowPart;
//}
//
//void deltatime_end() {
//    QueryPerformanceCounter(&p);
//    frame_end = p.HighPart + p.LowPart;
//}

void functime_start() {
    QueryPerformanceCounter(&p);
    func_start = p.HighPart + p.LowPart;
}

void functime_end() {
    QueryPerformanceCounter(&p);
    func_start = p.HighPart + p.LowPart;
}

// Code copypasted from https://zetcode.com/gui/winapi/datetime/
// Credit where credit is due.
// I was tired and didn't wanna do this shi myself, ok?

#define WINDOWS_TICKS_PER_SEC 10000000
#define EPOCH_DIFFERENCE      11644473600LL

void seed_set() {
	FILETIME ft = {0};

	GetSystemTimeAsFileTime(&ft);

    LARGE_INTEGER li = {0};

    li.LowPart 	= ft.dwLowDateTime;
    li.HighPart = ft.dwHighDateTime;

    int64_t hns = li.QuadPart;

    seed = hns / WINDOWS_TICKS_PER_SEC - EPOCH_DIFFERENCE;
}

//  =======================
//  ||...................||
//  ||......C..M..D......||
//  ||......C..M..D......||
//  ||......C..M..D......||
//  ||...................||
//  =======================

#ifdef DEBUG
void draw_f(int x, int y, const char* text, int buf_size, ...) {
    {
        COORD position = {x, y};
        SetConsoleCursorPosition(GetStdHandle(STD_OUTPUT_HANDLE), position);
    }

    va_list args;
    va_start(args, buf_size);

    char dest[buf_size];

    wsprintf(dest, text, *args);

    va_end(args);

    WriteConsole (
        GetStdHandle(STD_OUTPUT_HANDLE), // Handle to console
        dest,
        buf_size,
        NULL,
        NULL
    );
}

void clear_buf() { // Works by writing all blank characters to the console window.
    COORD start     = {0,0};
    DWORD num_chars = 0;

    FillConsoleOutputCharacter (
        GetStdHandle(STD_OUTPUT_HANDLE), // Handle to console
        ' ',                             // Blank character
        CMD_WIDTH * CMD_HEIGHT,          // Amount of cells to fill
        start,                           // Where to start
        &num_chars                       // Pointer to variable with number of chars written
    );

    SetConsoleCursorPosition(GetStdHandle(STD_OUTPUT_HANDLE), start);
}

#endif // DEBUG