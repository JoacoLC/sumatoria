#ifndef SOUND_H_INCLUDED
#define SOUND_H_INCLUDED

#define DEFAULT_MUSIC_VOLUME  0
#define DEFAULT_SFX_VOLUME   -50


void sound_init();
void music_play(uint32_t position);
void sfx_play(uint32_t position, uint32_t milliseconds);
void music_stop();

long music_volume;
bool music_setvolume(int32_t);
long music_getvolume();

long sfx_volume;
bool sfx_setvolume(int32_t);
long sfx_getvolume();

uint16_t song_patterncount = 0;
uint16_t song_end          = 168;

#define SU_SAMPLES_PER_PATTERN (SU_SAMPLES_PER_ROW * SU_CHANNEL_COUNT * SU_ROWS_PER_PATTERN)
#define SU_LENGTH_IN_BYTES (SU_BUFFER_LENGTH * SU_SAMPLE_SIZE)
#define SU_PATTERN_BYTES (SU_LENGTH_IN_BYTES / SU_LENGTH_IN_PATTERNS)
#define PATTERN(N) (SU_PATTERN_BYTES * N)
#define SONG_LENGTH_MS(PATTERN_AMT) (SU_PATTERN_BYTES * (uint32_t)1000 * PATTERN_AMT / SU_SAMPLE_SIZE / SU_SAMPLE_RATE / SU_CHANNEL_COUNT) 
#define MUSIC_SONG1_START  PATTERN(8)
#define MUSIC_SONG1_LOOP   PATTERN(9)
#define MUSIC_SONG1_PATTERNLENGTH 161
#define SFX_PIECELOCK      PATTERN(0)
#define SFX_OPERATION      PATTERN(1)
#define SFX_MOVE           PATTERN(2)
#define SFX_ROTATION       PATTERN(3)
#define SFX_RAISE          PATTERN(4)
#define SFX_GAMEOVER       PATTERN(5)
#define SFX_PAUSE          PATTERN(6)
#define SFX_EXPLOSION      PATTERN(7)

#endif // SOUND_H_INCLUDED