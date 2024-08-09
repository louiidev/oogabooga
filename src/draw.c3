import engine;
import entity;
import game;

def Matrix4 = engine::Matrix4;


fn void draw_health_bar(Matrix4 xform, int max_hp, int current_hp) {
    xform = engine::m4_translate(xform, {{0, SPRITE_PIXEL_SIZE, 0}});
    engine::draw_rect_xform(xform, @v2(SPRITE_PIXEL_SIZE + 3, 3), {{ 0, 0, 0, 1 }});

    float hp_bar_width = SPRITE_PIXEL_SIZE;

    float percentage = (float)current_hp / (float)max_hp; 

    engine::draw_rect_xform(xform, @v2(SPRITE_PIXEL_SIZE * percentage, 2), {{ 1, 0, 0, 1 }});

}