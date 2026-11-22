#ifndef PRINT_H_INCLUDED
#define PRINT_H_INCLUDED

#ifdef DEBUG
bool str_same(char* str1, char* str2);
extern void draw_f(int x, int y, const char* text, int buf_size, ...);
extern void clear_buf();

bool str_same(char* str1, char* str2) {
    int  i    = 0;
    bool same = true;

    while(str1[i] != '\0' || str2[i] != '\0') {
        if (str1[i] != str2[i]) {
            same = false;
            break;
        }
        i++;
    }

    return same;
}
#endif // DEBUG

#endif // header guard

