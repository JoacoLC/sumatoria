#ifndef SC_OPTMENU_H_INCLUDED
#define SC_OPTMENU_H_INCLUDED

#define RESUME   		 0
#define CONTROLS 		 1
#define QUIT     		 2
#define LIST_SIZE 		 5
#define LISTELEMENT_SIZE 11

#define OPTMENU_VOLUME_DIP 500

typedef struct {
    void (*action)();
    char  text[LISTELEMENT_SIZE];
} menuitem_t;

typedef struct menu_s {
    uint8_t        curr_item;
    uint8_t        item_amount;
    struct menu_s* prev_menu;
    menuitem_t*    items;
    void           (*render_func)(struct menu_s*);
} menu_t;

void menu_render(menu_t*);
void menumain_render(menu_t*);
void menusound_render(menu_t*);

void menu_unpause();
void menu_gotocontrols();

    // All of these call menu_changecontrol() under the hood.
    void menu_setupkey();
    void menu_setdownkey();
    void menu_setleftkey();
    void menu_setrightkey();
    void menu_setrotleftkey();
    void menu_setrotrightkey();
    void menu_setpausekey();
void menu_gotographics();

    // ..., 720x1280
    void menu_resolution();
    void menu_fullscreen();
    void menu_windowsize();

    // May be software rendering or OpenGL.
    void menu_rendertype();
void menu_gotosound();
    void menu_sfxvolume();
    void menu_musicvolume();
    void menu_buffersize();
    void menu_samplerate();
void menu_gotolanguage();
    void menu_changelanguage();
void menu_exitgame();

void change_control(uintptr_t*);

menuitem_t menumain_items[] = {
    { &menu_unpause,      " CONTINUAR"  },
    { NULL,               " CONTROLES"  },
    { NULL,               " GRAFICOS"   },
    { &menu_gotosound,    " SONIDO"     },
    { NULL,               " IDIOMA"     },
    { &menu_exitgame,     " SALIR"      }
};

menuitem_t menusound_items[] = {
    { &menu_musicvolume, " MUSICA"    },
    { &menu_sfxvolume,   " EFECTOS"   },
    { NULL,              " BUFFER"    },
    { NULL,              " SAMPLERATE"}
};

menu_t menu_main = {
    .curr_item   = 0,
    .item_amount = 6,
    .prev_menu   = NULL,
    .items       = menumain_items,
    .render_func = &menumain_render
};

menu_t menu_sound = {
    .curr_item   = 0,
    .item_amount = 4,
    .prev_menu   = &menu_main,
    .items       = menusound_items,
    .render_func = menusound_render
};

menu_t* curr_menu;

void sc_optmenu() {
    curr_menu = &menu_main;

    text_spacingy = CELL_SIZE / 2;

    curr_menu->render_func(curr_menu);

    music_setvolume(music_getvolume() - OPTMENU_VOLUME_DIP);
    sfx_setvolume(sfx_getvolume() - OPTMENU_VOLUME_DIP);
    
    while (true) {
        events_chk();
        if (!events.gameon) return;
        if (events.dwpress) { // Move cursor through the item list.
            if (curr_menu->curr_item < curr_menu->item_amount - 1) curr_menu->curr_item++;
            else curr_menu->curr_item = 0;
            sfx_play(SFX_MOVE, SONG_LENGTH_MS(1));
        } else if (events.uppress) {
            if (curr_menu->curr_item > 0) curr_menu->curr_item--;
            else curr_menu->curr_item = curr_menu->item_amount - 1;
            sfx_play(SFX_MOVE, SONG_LENGTH_MS(1));
        }

        if (events.rotright) {
            curr_menu = curr_menu->prev_menu;
        } else {
            if (curr_menu->items[curr_menu->curr_item].action != NULL)
                curr_menu->items[curr_menu->curr_item].action();
        }

        if (events.pause) curr_menu = NULL;

        if (curr_menu == NULL) {
            music_setvolume(music_getvolume() + OPTMENU_VOLUME_DIP);
            sfx_setvolume(sfx_getvolume() + OPTMENU_VOLUME_DIP);
            return;
        }

        curr_menu->render_func(curr_menu);
    }
}

void menu_render(menu_t* m) {
    for (uint8_t y = 0; y < m->item_amount; y++) { // Draw menu.
        if (y == m->curr_item) m->items[y].text[0] = '-';
        else m->items[y].text[0] = ' ';

        #ifdef DEBUG
        draw_f(0, y, m->items[y].text, lstrlen(m->items[y].text));
        #endif // DEBUG
        text_render(CELL_SIZE / 2, y * CELL_SIZE, m->items[y].text);
    }
}

void menumain_render(menu_t* m) {
    #ifdef DEBUG
    clear_buf();
    #endif // DEBUG
    render_clear();

    menu_render(m);
    
    render();
}

void menusound_render(menu_t* m) {
    music_getvolume();
    sfx_getvolume();

    #ifdef DEBUG
    clear_buf();
    #endif // DEBUG
    render_clear();

    menu_render(m);
    number_render(CELL_SIZE * 5, 0, 6, music_volume);
    number_render(CELL_SIZE * 5, CELL_SIZE, 6, sfx_volume);

    render();
}

void menu_unpause() {
    if (events.rotleft) curr_menu = NULL;
}

void menu_exitgame() {
    if (events.rotleft) {
        curr_scene = &sc_title;
        curr_menu  = NULL;
    }
}

void menu_gotosound() {
    if (events.rotleft) curr_menu = &menu_sound;
}

void menu_musicvolume() {
    music_getvolume();
    if      (events.lfpress) music_setvolume(music_volume - 50);
    else if (events.ripress) music_setvolume(music_volume + 50);
}

void menu_sfxvolume() {
    sfx_getvolume();
    if      (events.lfpress) sfx_setvolume(sfx_volume - 50);
    else if (events.ripress) sfx_setvolume(sfx_volume + 50);
}

#endif // SC_OPTMENU_H_INCLUDED
