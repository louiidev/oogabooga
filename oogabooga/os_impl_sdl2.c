#include <SDL2/SDL.h>
#include <SDL2/SDL_audio.h>
#include <assert.h>
#include <string.h>
#include <dlfcn.h>

#define VIRTUAL_MEMORY_BASE ((void *)0x0000690000000000ULL)


void os_init(u64 program_memory_capacity)
{
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_TIMER) < 0)
    {
        printf("SDL initialization failed: %s\n", SDL_GetError());
        return;
    }

    // Initialize os context
    os.page_size = getpagesize();
    os.granularity = os.page_size; // On macOS, this is typically the same as page size

    // Load CRT library
    os.crt = dlopen("libSystem.dylib", RTLD_LAZY);
    if (os.crt)
    {
        os.crt_vsnprintf = (Crt_Vsnprintf_Proc)dlsym(os.crt, "vsnprintf");
    }

    // Query monitors
    os.number_of_connected_monitors = SDL_GetNumVideoDisplays();
    os.monitors = (Os_Monitor *)SDL_malloc(sizeof(Os_Monitor) * os.number_of_connected_monitors);

    for (u64 i = 0; i < os.number_of_connected_monitors; i++)
    {
        SDL_DisplayMode mode;
        if (SDL_GetCurrentDisplayMode(i, &mode) == 0)
        {
            os.monitors[i].refresh_rate = mode.refresh_rate;
            os.monitors[i].resolution_x = mode.w;
            os.monitors[i].resolution_y = mode.h;

            float ddpi, hdpi, vdpi;
            if (SDL_GetDisplayDPI(i, &ddpi, &hdpi, &vdpi) == 0)
            {
                os.monitors[i].dpi = (u64)ddpi;
                os.monitors[i].dpi_y = (u64)vdpi;
            }
            else
            {
                os.monitors[i].dpi = os.monitors[i].dpi_y = 72; // Default DPI for macOS
            }

            const char *display_name = SDL_GetDisplayName(i);
            os.monitors[i].name.data = (u8 *)SDL_strdup(display_name);
            os.monitors[i].name.count = SDL_strlen(display_name);
        }
    }

    os.primary_monitor = &os.monitors[0]; // Assuming the first monitor is primary

    // Initialize static memory (this is a placeholder, adjust as needed)
    os.static_memory_start = SDL_malloc(program_memory_capacity);
    os.static_memory_end = (u8 *)os.static_memory_start + program_memory_capacity;

    // Initialize window (you might want to make these values configurable)
    window.width = window.pixel_width = 800;
    window.height = window.pixel_height = 600;
    window.x = SDL_WINDOWPOS_CENTERED;
    window.y = SDL_WINDOWPOS_CENTERED;
    window.clear_color = (Vector4){0.0f, 0.0f, 0.0f, 1.0f};
    window.enable_vsync = true;
    window.fullscreen = false;
    window.allow_resize = true;
    window.should_close = false;

    window.title.data = (u8 *)"Game Window";
    window.title.count = 11;

    u32 window_flags = SDL_WINDOW_SHOWN | SDL_WINDOW_ALLOW_HIGHDPI;
    if (window.allow_resize)
        window_flags |= SDL_WINDOW_RESIZABLE;
    if (window.fullscreen)
        window_flags |= SDL_WINDOW_FULLSCREEN;

    window._os_handle = SDL_CreateWindow((const char *)window.title.data,
                                         window.x, window.y,
                                         window.width, window.height,
                                         window_flags);
    if (window._os_handle == NULL)
    {
        printf("Window creation failed: %s\n", SDL_GetError());
        return;
    }

    window._initialized = true;
    window.monitor = os.primary_monitor;

    // Set vsync
    if (SDL_GL_SetSwapInterval(window.enable_vsync ? 1 : 0) < 0)
    {
        printf("Warning: Unable to set VSync! SDL Error: %s\n", SDL_GetError());
    }

    // Calculate scaled dimensions (accounting for Retina displays)
    int display_w, display_h;
    SDL_GL_GetDrawableSize(window._os_handle, &display_w, &display_h);
    window.scaled_width = display_w;
    window.scaled_height = display_h;

    // You would need to initialize audio, input, and other subsystems here
}

void os_shutdown()
{
    if (window._initialized)
    {
        SDL_DestroyWindow(window._os_handle);
    }

    for (u64 i = 0; i < os.number_of_connected_monitors; i++)
    {
        SDL_free(os.monitors[i].name.data);
    }
    SDL_free(os.monitors);

    SDL_free(os.static_memory_start);

    if (os.crt)
    {
        dlclose(os.crt);
    }

    SDL_Quit();
}



bool os_grow_program_memory(u64 new_size)
{
    SDL_LockMutex(program_memory_mutex);
    
    if (program_memory_capacity >= new_size)
    {
        SDL_UnlockMutex(program_memory_mutex);
        return true;
    }

    bool is_first_time = program_memory == NULL;

    if (is_first_time)
    {
        u64 aligned_size = align_next(new_size, os.granularity);
        void* aligned_base = (void*)align_next((u64)VIRTUAL_MEMORY_BASE, os.granularity);

        program_memory = mmap(aligned_base, aligned_size, PROT_READ | PROT_WRITE, 
                              MAP_PRIVATE | MAP_ANON, -1, 0);
        if (program_memory == MAP_FAILED)
        {
            SDL_UnlockMutex(program_memory_mutex);
            return false;
        }
        program_memory_next = program_memory;
        program_memory_capacity = aligned_size;
#if CONFIGURATION == DEBUG
        memset(program_memory, 0xBA, program_memory_capacity);
        mprotect(aligned_base, aligned_size, PROT_NONE);
#endif
    }
    else
    {
        void* tail = (u8*)program_memory + program_memory_capacity;

        assert((u64)program_memory_capacity % os.granularity == 0, "program_memory_capacity is not aligned to granularity!");
        assert((u64)tail % os.granularity == 0, "Tail is not aligned to granularity!");

        u64 amount_to_allocate = align_next(new_size - program_memory_capacity, os.granularity);

        void* result = mmap(tail, amount_to_allocate, PROT_READ | PROT_WRITE, 
                            MAP_PRIVATE | MAP_ANON | MAP_FIXED, -1, 0);
#if CONFIGURATION == DEBUG
        memset(result, 0xBA, amount_to_allocate);
        mprotect(tail, amount_to_allocate, PROT_NONE);
#endif
        if (result == MAP_FAILED)
        {
            SDL_UnlockMutex(program_memory_mutex);
            return false;
        }
        assert(tail == result, "It seems tail is not aligned properly. o nein");
        assert((u64)program_memory_capacity % os.granularity == 0, "program_memory_capacity is not aligned to granularity!");

        program_memory_capacity += amount_to_allocate;
    }

    char size_str[32];
    s64_to_null_terminated_string(program_memory_capacity / 1024, size_str, 10);

    SDL_Log("Program memory grew to %s kb\n", size_str);
    SDL_UnlockMutex(program_memory_mutex);
    return true;
}

void* os_reserve_next_memory_pages(u64 size)
{
    assert(size % os.page_size == 0, "size was not aligned to page size in os_reserve_next_memory_pages");

    void* p = program_memory_next;

    program_memory_next = (u8*)program_memory_next + size;

    void* program_tail = (u8*)program_memory + program_memory_capacity;

    if ((u64)program_memory_next > (u64)program_tail)
    {
        u64 minimum_size = ((u64)program_memory_next) - (u64)program_memory + 1;
        u64 new_program_size = get_next_power_of_two(minimum_size);

        const u64 ATTEMPTS = 1000;
        for (u64 i = 0; i <= ATTEMPTS; i++)
        {
            if (program_memory_capacity >= new_program_size)
                break;
            assert(i < ATTEMPTS, "OS is not letting us allocate more memory. Maybe we are out of memory?");
            if (os_grow_program_memory(new_program_size))
                break;
        }
    }

    return p;
}

void os_unlock_program_memory_pages(void* start, u64 size)
{
#if CONFIGURATION == DEBUG
    assert((u64)start % os.page_size == 0, "When unlocking memory pages, the start address must be the start of a page");
    assert(size % os.page_size == 0, "When unlocking memory pages, the size must be aligned to page_size");
    
    int result = mprotect(start, size, PROT_READ | PROT_WRITE);
    assert(result == 0, "mprotect failed with error %d", errno);
#endif
}

void os_lock_program_memory_pages(void* start, u64 size)
{
#if CONFIGURATION == DEBUG
    assert((u64)start % os.page_size == 0, "When locking memory pages, the start address must be the start of a page");
    assert(size % os.page_size == 0, "When locking memory pages, the size must be aligned to page_size");
    
    int result = mprotect(start, size, PROT_NONE);
    assert(result == 0, "mprotect failed with error %d", errno);
#endif
}

// Mouse pointer functions

SDL_Cursor* sdl_mouse_pointer_kind_to_cursor(Mouse_Pointer_Kind k)
{
    switch (k)
    {
        case MOUSE_POINTER_DEFAULT:
            return SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_ARROW);
        case MOUSE_POINTER_TEXT_SELECT:
            return SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_IBEAM);
        case MOUSE_POINTER_BUSY:
            return SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_WAIT);
        case MOUSE_POINTER_BUSY_BACKGROUND:
            return SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_WAITARROW);
        case MOUSE_POINTER_CROSS:
            return SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_CROSSHAIR);
        case MOUSE_POINTER_ARROW_N:
            return SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_ARROW);  // No direct equivalent
        case MOUSE_POINTER_ARROWS_NW_SE:
            return SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_SIZENWSE);
        case MOUSE_POINTER_ARROWS_NE_SW:
            return SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_SIZENESW);
        case MOUSE_POINTER_ARROWS_HORIZONTAL:
            return SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_SIZEWE);
        case MOUSE_POINTER_ARROWS_VERTICAL:
            return SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_SIZENS);
        case MOUSE_POINTER_ARROWS_ALL:
            return SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_SIZEALL);
        case MOUSE_POINTER_NO:
            return SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_NO);
        case MOUSE_POINTER_POINT:
            return SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_HAND);
        default:
            break;
    }
    assert(false, "Unhandled Mouse_Pointer_Kind");
    return NULL;
}

void os_set_mouse_pointer_standard(Mouse_Pointer_Kind kind)
{
    static SDL_Cursor* loaded_pointers[MOUSE_POINTER_MAX] = {0};

    if (loaded_pointers[kind] == NULL)
    {
        loaded_pointers[kind] = sdl_mouse_pointer_kind_to_cursor(kind);
    }

    SDL_SetCursor(loaded_pointers[kind]);
}

void os_set_mouse_pointer_custom(Custom_Mouse_Pointer p)
{
    SDL_SetCursor((SDL_Cursor*)p);
}

Custom_Mouse_Pointer os_make_custom_mouse_pointer(void* image, int width, int height, int hotspot_x, int hotspot_y)
{
    SDL_Surface* surface = SDL_CreateRGBSurfaceFrom(image, width, height, 32, width * 4,
                                                    0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF);
    if (!surface)
    {
        assert(false, "Failed to create SDL surface");
        return NULL;
    }

    SDL_Cursor* cursor = SDL_CreateColorCursor(surface, hotspot_x, hotspot_y);
    SDL_FreeSurface(surface);

    if (!cursor)
    {
        assert(false, "Failed to create SDL cursor");
        return NULL;
    }

    return (Custom_Mouse_Pointer)cursor;
}
