/**
 * MyFrame ESP32 — random playlist index (reference).
 *
 * Cloud playlists are primarily advanced by the VPS (`photo_queue` + MQTT `play`).
 * If firmware also advances a local queue (e.g. offline / cached album), use the
 * same rules so Random never falls back to (current + 1) % n.
 */

#include <stdlib.h>
#include <stdint.h>

/** strategy: 1 = sequential, 2 = random */
int myframe_next_playback_index(int strategy, int current_index, int total)
{
    if (total <= 0) return 0;
    if (total == 1) return 0;

    if (strategy == 2) {
        /* First play / sentinel: any index, including 0. */
        if (current_index < 0 || current_index >= total) {
            return (int)(rand() % total);
        }
        int next;
        int guard = 0;
        do {
            next = (int)(rand() % total);
        } while (next == current_index && ++guard < 24);
        return next;
    }

    /* Sequential */
    if (current_index < 0) return 0;
    return (current_index + 1) % total;
}

/**
 * On starting random playback with nothing shown yet:
 *   current_index = -1;
 *   next = myframe_next_playback_index(2, current_index, n); // true random first photo
 *
 * Do NOT seed current_index = n-1 for random (that is sequential's trick to start at 0).
 */
