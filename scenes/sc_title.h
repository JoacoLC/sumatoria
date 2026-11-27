#ifndef SC_TITLE_H_INCLUDED
#define SC_TITLE_H_INCLUDED

void sc_title() {
    music_play(MUSIC_SONG1_START);
    const char* title = "SUMATORIA";
    const char* prompt = "APRETA CUALQUIER TECLA";
    const char* subtitle = "Un juego arcade\nde puzzles\npor Joaquin Labanda\n\nCC-BY-NC-SA 2026\n";

    text_spacingy = CELL_SIZE / 2;

    #ifdef DEBUG
    // clear_buf();
    draw_f(0,0, title, 70);
    #endif // DEBUG

    bool prompt_on = true;
    timer_set(TIMER_FLASHTEXT, 200);
    while (gameon) {
        events_chk();
        if (inputs_key_p1[INP_ANYKEY].pressed) {
            timer_kill(TIMER_FLASHTEXT);
            sfx_play(SFX_PAUSE, SONG_LENGTH_MS(1));
            curr_scene = &sc_game1p;
            return;
        }
        if (timers[TIMER_FLASHTEXT]) prompt_on = !prompt_on;
        render_clear();
        text_size = CELL_SIZE;
        text_spacingx = CELL_SIZE;
        text_render(-CELL_SIZE, CELL_SIZE / 2, title);
        text_size     = CELL_SIZE / 2;
        text_spacingx = CELL_SIZE / 3;
        if (prompt_on) text_render(CELL_SIZE / 2, CELL_SIZE * 2.5, prompt);
        text_render(0, CELL_SIZE * 4, subtitle);
        render();
    }
}

#endif // SC_TITLE_H_INCLUDED