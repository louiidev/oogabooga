module entity;

import engine;
import utils;
import std::math;
import game;
import std::io;
import particles;
import draw;
import weapons;
import collisions;

const float ENEMY_KNOCKBACK_TIME = 0.4f;
const float BAT_ATTACK_TIME = 4f;
const float SKULL_ATTACK_TIME = 0.5f;


enum EntAnimation {
    IDLE,
    WALK,
    ATTACK,
}

enum EntType {
    PLAYER,
    BAT,
    SKULL,
}

struct Entity
{
    bool active;
    bool flip_x;
    int health;
    int max_health;
    float speed;
    float weapon_angle;
    float current_weapon_angle_offset;
    bool flip_weapon;
    /* Player specific data, we will just set to -1 for enemy ents*/
    engine::Vector2 position;

    int strength;

    int sprite_cell_count_x;
    int sprite_cell_count_y;

	weapons::Weapons equipped_weapon;
    float current_animation_time;
    int current_animation_frame;

    int walk_animation_frame_start;
    int walk_animation_count;
    float walk_animation_play_time;

    int idle_animation_frame_start_x;
    int idle_animation_frame_start_y;
    int idle_animation_count;
    float idle_animation_play_time;
    
    Vector2 hitbox_size;
    Vector2 hitbox_offset;

    float attack_timer;
    float knockback_timer;
    Vector2 knockback_velocity;

    float hurt_timer;


    EntType entity_type;
    EntAnimation animation;
}

def COLOR_WHITE = engine::COLOR_WHITE;
def Vector2 = engine::Vector2;
def Vector3 = engine::Vector3;
def Vector4 = engine::Vector4;
def Matrix4 = engine::Matrix4;
def m4_translate = engine::m4_translate;
def m4_rotate_z = engine::m4_rotate_z;
def InputKeyCode = engine::InputKeyCode;




fn void Entity.knockback(Entity *ent, Vector2 attack_direction) {
    if (ent.entity_type == EntType.PLAYER && ent.hurt_timer > 0) {
        return;
    }

    ent.knockback_timer = ENEMY_KNOCKBACK_TIME;
    ent.knockback_velocity = attack_direction.mulf(engine::get_random_float32_in_range(300, 350));
    ent.hurt_timer = HURT_TIMER;

    switch(ent.entity_type) {
        case EntType.PLAYER:
        break;
        case EntType.SKULL:
            ent.attack_timer = SKULL_ATTACK_TIME + ENEMY_KNOCKBACK_TIME;
        case EntType.BAT:
            ent.attack_timer = BAT_ATTACK_TIME + ENEMY_KNOCKBACK_TIME;
    }

    

}



fn void update_player_animation(Entity *entity, double delta_t) {
    if (entity.animation == EntAnimation.IDLE) {
        return;
    }

    entity.current_animation_time+= (float)delta_t;

    switch (entity.animation) {
        case EntAnimation.WALK:
            if (entity.current_animation_time >= entity.walk_animation_play_time) {
                entity.current_animation_time = 0.0f;
                if (entity.current_animation_frame >= entity.walk_animation_count) {
                    entity.current_animation_frame = 0;
                } else {
                    entity.current_animation_frame+= 1;
                }
            }
        default:
        break;
    }
}

fn void update_entity(Entity *ent, Game *game, double delta_t, ) {
    if (!ent.active) {
        return;
    } 

    if (ent.health <= 0) {
        ent.active = false;
        return;
    }


    ent.flip_x = ent.position.x > game.player_entity.position.x;
    ent.current_animation_time+= (float)delta_t;
    if (ent.attack_timer > 0) {
        ent.attack_timer-= (float)delta_t;
    }
    if (ent.hurt_timer) {
        ent.hurt_timer-= (float)delta_t;
    }
    

    float sub_amount = ent.flip_x ? -10 : 10;
    Vector2 target = game.player_entity.position;


    float distance_from_target = ent.position.distance(target);
    Vector2 target_center = game.player_entity.position.add({{ 16 / 2, 16 / 2}});
    Vector2 center_pos = ent.position.add({{ 16/2, 16/2  }});

    Vector2 target_offset = target.sub({{ sub_amount, 0 }});
    float x = (float)engine::lerpf(ent.position.x, target_offset.x, delta_t * ent.speed);
    float y = (float)engine::lerpf(ent.position.y, target_offset.y, delta_t * ent.speed);
    bool can_move = true;



    foreach (&enemy : game.room_enemies)
    {
        if (!enemy.active || enemy.position.equals(ent.position)) {
            // lets assume if the position is the same, its the same enemy
            continue;
        }


        

        Vector2 enem_center = enemy.position.add({{ 16/2, 16/2  }});
        if (collisions::circles_overlap({{ x + 16/2, y + 16/2 }}, 5, {{ enem_center.x, enem_center.y }}, 5)) {
            float enemy_distance_to_target = enemy.position.distance(target);
            // give presidence to closest enemy
            if (enemy_distance_to_target >= distance_from_target) {
                continue;
            }
                
            can_move = false;
            break;
        }
    }

     if ((ent.knockback_velocity.x != 0 || ent.knockback_velocity.y != 0) && ent.knockback_timer > 0) {
        ent.knockback_timer-= (float)delta_t;
        float t = ent.knockback_timer / ENEMY_KNOCKBACK_TIME;
        ent.knockback_velocity.x = (float)engine::lerpf(ent.knockback_velocity.x, 0, 1.0 - t);
        ent.knockback_velocity.y = (float)engine::lerpf(ent.knockback_velocity.y, 0, 1.0 - t);
        ent.position.x += ent.knockback_velocity.x * (float)delta_t;
        ent.position.y += ent.knockback_velocity.y * (float)delta_t;
        can_move = false;
    } 


    switch(ent.entity_type) {
        case EntType.SKULL:


        if (distance_from_target <= SPRITE_PIXEL_SIZE && ent.attack_timer <= 0) {
            ent.attack_timer = SKULL_ATTACK_TIME;
            game.player_entity.health-= ent.strength * 2;
            Vector2 knock_dir = ent.flip_x ? Vector2 {{ -1, 0 }} : Vector2 {{ 1, 0 }};
            game.player_entity.knockback(knock_dir);
        }

        case EntType.BAT:
        if (ent.attack_timer <= 0) {   
            // spawn projectile
            ent.attack_timer = BAT_ATTACK_TIME;

            Particle proj;
            proj.new_projectile(false);
            float sub = ent.flip_x ? -2 : 2;
            Vector2 pos = ent.position.sub(@v2(sub, 0));
            proj.position = pos.add({{ 0, 16/2 }});
            proj.velocity = game.player_entity.position.sub(ent.position).normalize().mulf(50);
            proj.rotation = -utils::calc_rotation_to_target(game.player_entity.position, pos);
            game.projectiles.push(
                proj
            );
            
        } else if (distance_from_target < engine::get_random_float32_in_range(25, 35)) {
            can_move = false;
        }

        default:
        break;
    }


    if (ent.current_animation_time >= ent.idle_animation_play_time) {
        ent.current_animation_time = 0.0f;
        if (ent.current_animation_frame >= ent.idle_animation_count) {
            ent.current_animation_frame = 0;
        } else {
            ent.current_animation_frame+= 1;
        }
    }


    if (can_move) {
        ent.position = {{x,y}};
    }
}

const float ANIMATE_DOWN_VALUE = 65;
const float ANIMATE_SPEED = 20;
fn void update_weapon_logic(Game *game, Vector2 player_velocity, double delta_t) {
    Entity *player = &game.player_entity;

    float rotation_z = -utils::calc_rotation_to_target(game::world_frame.world_mouse_pos, player.position);
    float moveDistance = 15.0f;
    float delta_x = moveDistance * $$cos(rotation_z);
    float delta_y = moveDistance * $$sin(rotation_z);

    Vector2 attack_direction = game::world_frame.world_mouse_pos.sub(player.position).normalize();
    Vector2 attack_position = player.position.add({{ delta_x, -delta_y }});
    
    float attack_length = 10;
    Vector2 attack_position_centered = attack_position.add({{ 16 * 0.5f, 16 * 0.5f }}).sub(attack_direction.mulf(attack_length));
    

    if (game::draw_hitboxes) {
        engine::draw_line(attack_position_centered, attack_position_centered.add(attack_direction.mulf(attack_length * 2)), 1.0f, {{ 1, 0, 0, 1}});
    }


    if (engine::is_key_just_pressed(InputKeyCode.MOUSE_BUTTON_LEFT.value)) {
        game.camera.shake(0.5f);
        Particle projectile;
        projectile.new_projectile(true);
        projectile.position = player.position.add({{ delta_x + SPRITE_PIXEL_SIZE * 0.5f, -delta_y + SPRITE_PIXEL_SIZE * 0.5f }});
        projectile.velocity = attack_direction.mulf(120);
        projectile.sprite_cell_start_x = 0;
        projectile.sprite_cell_start_y = 1;
        projectile.current_frame = 0;
        projectile.time_per_frame = 0.015f;
        projectile.animation_frame_count = 2;
        projectile.rotation = rotation_z;
        game.projectiles.push(
            projectile
        );

    }

    if (player.flip_x) {
        float angle_to_target = utils::calc_rotation_to_target(@v2(player.position.x + SPRITE_PIXEL_SIZE * 0.5f, player.position.y), game::world_frame.world_mouse_pos);
        player.weapon_angle = angle_to_target;
    } else {
        float angle_to_target = utils::calc_rotation_to_target(game::world_frame.world_mouse_pos, player.position);
        player.weapon_angle = -angle_to_target;
    }
}

const float HURT_TIMER = 0.5f;
fn void render_entity(Entity entity) {
    if (!entity.active) {
        return;
    }

    Vector2 sprite_size = utils::get_image_size(game::sprites.enemies);
    Matrix4 xform = engine::m4_scalar(1.0f);
	xform = engine::m4_translate(xform, @v3(entity.position.x, entity.position.y, 0.0f));
    Matrix4 xform_before_flip = xform;
    if (entity.flip_x) {
       xform = utils::flip_sprite_x(xform);
    } 
    
    engine::DrawQuad *quad = engine::draw_image_xform(game::sprites.enemies, xform, @v2(SPRITE_PIXEL_SIZE, SPRITE_PIXEL_SIZE), engine::COLOR_WHITE);
    quad.userdata[0].x = 1;
    quad.userdata[0].y = 0;

    if (entity.hurt_timer > 0) {
        quad.userdata[0].y = 1;
    }


    // @TODO: Maybe we should just store this as a v2?
    if (entity.animation == EntAnimation.IDLE) {
        quad.uv = utils::get_uv_coords(sprite_size, @v2(entity.current_animation_frame + entity.idle_animation_frame_start_x, entity.idle_animation_frame_start_y));
    } else {
        quad.uv = utils::get_uv_coords(sprite_size, @v2(0, 0));
        unreachable();
    }

    draw::draw_health_bar(xform_before_flip, entity.max_health, entity.health);
}



fn engine::Matrix4 render_player(Entity *entity, engine::GfxImage* player_sprite) {
    Vector2 sprite_size = utils::get_image_size(player_sprite);
    Matrix4 player_xform = engine::m4_scalar(1.0f);

	player_xform = engine::m4_translate(player_xform, @v3(entity.position.x, entity.position.y, 0.0f));

    Matrix4 weapon_xform = player_xform;

    if (entity.flip_x) {
       player_xform = utils::flip_sprite_x(player_xform);
    }
    engine::DrawQuad *quad = engine::draw_image_xform(player_sprite, player_xform, @v2(SPRITE_PIXEL_SIZE, SPRITE_PIXEL_SIZE), engine::COLOR_WHITE);
    if (entity.animation == EntAnimation.WALK) {
        quad.uv = utils::get_uv_coords(sprite_size, @v2(entity.current_animation_frame + entity.walk_animation_frame_start, 0));
    } else {
        quad.uv = utils::get_uv_coords(sprite_size, @v2(0, 0));
    }

    if (game::draw_hitboxes) {
        Matrix4 debug_xform = engine::m4_scalar(1.0f);
        debug_xform = engine::m4_translate(debug_xform, @v3(entity.position.x + entity.hitbox_offset.x, entity.position.y + entity.hitbox_offset.y, 0.0f));
        engine::draw_rect_xform(debug_xform, entity.hitbox_size, {{ 1, 0, 0, 0.5f}});
    }
    
    
    
	return weapon_xform;
}



fn void render_weapons(Entity *player, Matrix4 player_xform, engine::GfxImage* weapons_sprite, double delta_t) {

    bool flip_y = utils::almost_equals(player.current_weapon_angle_offset, utils::deg_to_rad(ANIMATE_DOWN_VALUE), utils::deg_to_rad(10));

    Vector2 sprite_size = utils::get_image_size(weapons_sprite);
    if (player.equipped_weapon != Weapons.NIL)
    {
        Matrix4 xform = player_xform;
        xform = m4_translate(xform, @v3(SPRITE_PIXEL_SIZE * 0.5f, 0, 0));

        float x_scale = 1.0;
        float y_scale = 1.0;

        if (player.flip_x)
        {
            x_scale = -1.0;
        }

        float angle = player.weapon_angle + player.current_weapon_angle_offset;

        xform = m4_translate(xform, @v3(0, SPRITE_PIXEL_SIZE * 0.5f, 0));
        xform = engine::m4_scale(xform, @v3(x_scale, y_scale, 1));

        xform = m4_rotate_z(xform, angle);
        xform = m4_translate(xform, @v3(0, -SPRITE_PIXEL_SIZE * 0.5f, 0));
        xform = m4_translate(xform, @v3(SPRITE_PIXEL_SIZE * 0.2f, 0, 0));

        engine::DrawQuad *quad = engine::draw_image_xform(weapons_sprite, xform, @v2(SPRITE_PIXEL_SIZE, SPRITE_PIXEL_SIZE), engine::COLOR_WHITE);
        quad.uv = utils::get_uv_coords(sprite_size, @v2((int)player.equipped_weapon, 0));
        
    }
}