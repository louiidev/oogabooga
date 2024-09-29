

///
// Build config stuff

// To enable extensions:
// #define OOGABOOGA_ENABLE_EXTENSIONS   1
// #define OOGABOOGA_EXTENSION_PARTICLES 1

#define INITIAL_PROGRAM_MEMORY_SIZE MB(5)

typedef struct Context_Extra
{
	int monkee;
} Context_Extra;
// This needs to be defined before oogabooga if we want extra stuff in context
#define CONTEXT_EXTRA Context_Extra

// This defaults to "entry", but we can set it to anything (except "main" or other existing proc names"
#define ENTRY_PROC entry

// Ooga booga needs to be included AFTER configuration and BEFORE the program code
#include "oogabooga/oogabooga.c"


//
// Comment & Uncomment these to swap projects (only include one at a time)
//

// This is a minimal starting point for new projects. Copy & rename to get started
// #include "oogabooga/examples/minimal_game_loop.c"

// #include "oogabooga/examples/text_rendering.c"
// #include "oogabooga/examples/custom_logger.c"
// #include "oogabooga/examples/renderer_stress_test.c"
// #include "oogabooga/examples/audio_test.c"
// #include "oogabooga/examples/custom_shader.c"
// #include "oogabooga/examples/growing_array_example.c"
// #include "oogabooga/examples/input_example.c"
// #include "oogabooga/examples/sprite_animation.c"
// #include "oogabooga/examples/window_test.c"
// #include "oogabooga/examples/offscreen_drawing.c"
// #include "oogabooga/examples/threaded_drawing.c"
#include "oogabooga/examples/bloom.c"

// These examples require some extensions to be enabled. See top respective files for more info.
// #include "oogabooga/examples/particles_example.c" // Requires OOGABOOGA_EXTENSION_PARTICLES

// #include "oogabooga/examples/sanity_tests.c"

// This is where you swap in your own project!
// #include "entry_yourepicgamename.c"

// #include "entry_randygame.c"
