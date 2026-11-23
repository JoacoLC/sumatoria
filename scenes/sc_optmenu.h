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
void menucontrol_render(menu_t*);

void menu_unpause();
void menu_gotocontrols();
    void menu_selectcontrol();
    void menu_changecontrol();
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

menuitem_t menumain_items[] = {
    { &menu_unpause,      " CONTINUAR" },
    { &menu_gotocontrols, " CONTROLES" },
    { NULL,               " GRAFICOS"  },
    { &menu_gotosound,    " SONIDO"    },
    { NULL,               " IDIOMA"    },
    { &menu_exitgame,     " SALIR"     }
};

menuitem_t menusound_items[] = {
    { &menu_musicvolume, " MUSICA"     },
    { &menu_sfxvolume,   " EFECTOS"    },
    { NULL,              " BUFFER"     },
    { NULL,              " SAMPLERATE" }
};

menuitem_t menucontrol_items[] = {
    { &menu_selectcontrol, " PAUSA"      },
    { &menu_selectcontrol, " INSTACAIDA" },
    { &menu_selectcontrol, " IZQUIERDA"  },
    { &menu_selectcontrol, " DERECHA"    },
    { &menu_selectcontrol, " ABAJO"      },
    { &menu_selectcontrol, " ACCION 1"   },
    { &menu_selectcontrol, " ACCION 2"   }
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

menu_t menu_control = {
    .curr_item   = 0,
    .item_amount = 7,
    .prev_menu   = &menu_main,
    .items       = menucontrol_items,
    .render_func = menucontrol_render
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
        if (!gameon) return;

        if (curr_menu == NULL) goto exit_menu;

        if (inputs_key_p1[INP_ACTION2].pressed) {
            curr_menu = curr_menu->prev_menu;
        } else {
            if (curr_menu->items[curr_menu->curr_item].action != NULL)
                curr_menu->items[curr_menu->curr_item].action();
        }

        if (curr_menu == NULL) goto exit_menu;

        if (curr_menu->items[curr_menu->curr_item].action == &menu_changecontrol) {
            curr_menu->render_func(curr_menu);
            continue;
        }

        if (inputs_key_p1[INP_DOWN].pressed) { // Move cursor through the item list.
            if (curr_menu->curr_item < curr_menu->item_amount - 1) curr_menu->curr_item++;
            else curr_menu->curr_item = 0;
            sfx_play(SFX_MOVE, SONG_LENGTH_MS(1));
        } else if (inputs_key_p1[INP_UP].pressed) {
            if (curr_menu->curr_item > 0) curr_menu->curr_item--;
            else curr_menu->curr_item = curr_menu->item_amount - 1;
            sfx_play(SFX_MOVE, SONG_LENGTH_MS(1));
        }

        if (inputs_key_p1[INP_PAUSE].pressed) {
            curr_menu = NULL;
            goto exit_menu;
        }

        curr_menu->render_func(curr_menu);

        continue;

    exit_menu:
        music_setvolume(music_getvolume() + OPTMENU_VOLUME_DIP);
        sfx_setvolume(sfx_getvolume() + OPTMENU_VOLUME_DIP);
        return;
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

void menucontrol_render(menu_t* m) {
    #ifdef DEBUG
    clear_buf();
    #endif // DEBUG
    render_clear();

    menu_render(m);
    for (int i = 0; i < m->item_amount; i++) {
        // text_render(CELL_SIZE * 5, CELL_SIZE * i, &inputs_key_p1[i].name);
        number_render(CELL_SIZE * 5, CELL_SIZE * i, 4, inputs_key_p1[i].key);
    }
    
    render();
}

void menu_unpause() {
    if (inputs_key_p1[INP_PAUSE].pressed) curr_menu = NULL;
}

void menu_exitgame() {
    if (inputs_key_p1[INP_ACTION2].pressed) {
        curr_scene = &sc_title;
        curr_menu  = NULL;
    }
}

void menu_gotosound() {
    if (inputs_key_p1[INP_ACTION1].pressed) curr_menu = &menu_sound;
}

void menu_musicvolume() {
    music_getvolume();
    if      (inputs_key_p1[INP_LEFT].pressed) music_setvolume(music_volume - 50);
    else if (inputs_key_p1[INP_RIGHT].pressed) music_setvolume(music_volume + 50);
}

void menu_sfxvolume() {
    sfx_getvolume();
    if      (inputs_key_p1[INP_LEFT].pressed) sfx_setvolume(sfx_volume - 50);
    else if (inputs_key_p2[INP_RIGHT].pressed) sfx_setvolume(sfx_volume + 50);
}

void menu_gotocontrols() {
    if (inputs_key_p1[INP_ACTION1].pressed) {
        curr_menu = &menu_control;
    }
}

void menu_selectcontrol() {
    if (inputs_key_p1[INP_ACTION1].pressed) {
        curr_menu->items[curr_menu->curr_item].action = &menu_changecontrol;
    }
}

void menu_changecontrol() {
    if (inputs_key_p1[INP_ANYKEY].pressed) {
        bool key_already_used = false;
        for (int8_t i = 0; i < INPUTS_AMT - 1; i++) {
            if (inputs_key_p1[i].key == lastkeypressed) key_already_used = true; 
        }
        if (!key_already_used) inputs_key_p1[curr_menu->curr_item].key = lastkeypressed;
        curr_menu->items[curr_menu->curr_item].action = &menu_selectcontrol;
    }
}

#endif // SC_OPTMENU_H_INCLUDED
