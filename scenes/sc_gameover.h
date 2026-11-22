#ifndef SC_GAMEOVER_H_INCLUDED
#define SC_GAMEOVER_H_INCLUDED

void sc_gameover() {
	const char* que_mal = "QUE MAL!\nARRIBA:REINTENTAR\nABAJO: INICIO";

	text_spacingy = CELL_SIZE / 2;

	music_stop();
	#ifdef DEBUG
	clear_buf();

	draw_f(7,1, que_mal, lstrlen(que_mal));
	#endif // DEBUG

	render_clear();
	text_render(0, 0, que_mal);
	render();

	while (events.gameon) {
		events_chk();
		if (events.uppress) {
			curr_scene = &sc_game1p;
			goto end;
		} else if (events.dwpress) {
			curr_scene = &sc_title;
			goto end;
		}
	end:
		music_play(MUSIC_SONG1_START);
		return;
	}
}

#endif // SC_GAMEOVER_H_INCLUDED