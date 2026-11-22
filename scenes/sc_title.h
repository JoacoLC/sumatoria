#ifndef SC_TITLE_H_INCLUDED
#define SC_TITLE_H_INCLUDED

void sc_title() {
    music_play(MUSIC_SONG1_START);
    const char* title = "SUMATORIA\n\nUn juego arcade\nde puzzles\npor Joaquin Labanda\n\nCC-BY-NC 2026\n";
    
    text_spacingy = CELL_SIZE / 2;

    #ifdef DEBUG
    clear_buf();
    draw_f(0,0, title, 70);
    #endif // DEBUG

    render_clear();
    text_render(0, 0, title);
    render();

    while (events.gameon) {
        events_chk();
        if (events.anykpress && !events.pause) {
            curr_scene = &sc_game1p;
            return;
        }
    }
}

#endif // SC_TITLE_H_INCLUDED