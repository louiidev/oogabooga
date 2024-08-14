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
    ROLLING,
}

enum EntType {
    PLAYER,
    BAT,
    SKULL,
    MAX_ENT_TYPE
}


def Timer = float;

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
    Timer current_animation_timer;
    int current_animation_frame;

    int walk_animation_frame_start;
    int walk_animation_count;
    float walk_animation_play_time;

    int idle_animation_frame_start_x;
    int idle_animation_frame_start_y;
    int idle_animation_count;
    float idle_animation_play_time;

    int rolling_animation_frame_start_x;
    int rolling_animation_frame_start_y;
    int rolling_animation_count;
    float rolling_animation_play_time;
    
    // handles collisions from center of ent
    float collision_radius;

    Timer attack_timer;
    Timer knockback_timer;
    Vector2 knockback_velocity;

    EntType entity_type;
    EntAnimation animation;


    // when player gets hurt, we give them i frames
    // or when they roll
    Timer invisible_timer;

    Timer dodge_roll_cooldown_timer;
    Timer dodge_roll_timer;
    Timer weapon_cooldown_timer;
    Vector2 dodge_velocity;
}

def COLOR_WHITE = engine::COLOR_WHITE;
def Vector2 = engine::Vector2;
def Vector3 = engine::Vector3;
def Vector4 = engine::Vector4;
def Matrix4 = engine::Matrix4;
def m4_translate = engine::m4_translate;
def m4_rotate_z = engine::m4_rotate_z;
def InputKeyCode = engine::InputKeyCode;


fn void Entity.new(Entity *ent) {
    ent.active = true;
    ent.collision_radius = 5;
    
}

fn void Entity.update_timers(Entity *ent, float delta_t) {
    ent.invisible_timer = $$max(0f, ent.invisible_timer - delta_t);
    ent.dodge_roll_cooldown_timer = $$max(0f, ent.dodge_roll_cooldown_timer - delta_t);
    ent.dodge_roll_timer = $$max(0f, ent.dodge_roll_timer - delta_t);
    ent.attack_timer = $$max(0.0f, ent.attack_timer - delta_t);
    ent.knockback_timer = $$max(0.0f, ent.knockback_timer - delta_t);
    ent.weapon_cooldown_timer = $$max(0.0f, ent.weapon_cooldown_timer - delta_t);
    ent.current_animation_timer+= delta_t;
}


const float PLAYER_I_FRAMES_TIME = 0.5f;
fn void Entity.damage_player(Entity *ent, Vector2 attack_direction, int damage_amount) {
    if (ent.is_invinsible()) {
        return;
    }
    ent.invisible_timer = PLAYER_I_FRAMES_TIME;
    ent.knockback(attack_direction);
    ent.health-= damage_amount;
}

fn bool Entity.is_invinsible(Entity *ent) {
    return ent.invisible_timer > 0 || ent.dodge_roll_timer > 0;
}

fn void Entity.knockback(Entity *ent, Vector2 attack_direction) {
    if (ent.entity_type == EntType.PLAYER && ent.knockback_timer > 0) {
        return;
    }

    ent.knockback_timer = ENEMY_KNOCKBACK_TIME;
    ent.knockback_velocity = attack_direction.mulf(engine::get_random_float32_in_range(150, 200));

    switch(ent.entity_type) {
        case EntType.PLAYER:
        break;
        case EntType.SKULL:
            ent.attack_timer = SKULL_ATTACK_TIME + ENEMY_KNOCKBACK_TIME;
        case EntType.BAT:
            ent.attack_timer = BAT_ATTACK_TIME + ENEMY_KNOCKBACK_TIME;
        default:
			unreachable();
    }

    

}


const float TARGET_OFFSET_AMOUNT = 10;
fn void update_entity(Entity *ent, Game *game, double delta_t, ) {
    if (!ent.active) {
        return;
    } 

    if (ent.health <= 0) {
        ent.active = false;
        return;
    }


    ent.flip_x = ent.position.x > game.player.position.x;
    ent.update_timers((float)delta_t);
    

    float sub_amount = ent.flip_x ? -TARGET_OFFSET_AMOUNT : TARGET_OFFSET_AMOUNT;

    if (ent.entity_type == EntType.SKULL) {
        sub_amount = 0;
    }


    Vector2 target = game.player.position;

    float distance_from_target = ent.position.distance(target);
    Vector2 target_center = game.player.position.add({{ 16 / 2, 16 / 2}});
    Vector2 center_pos = ent.position.add({{ 16/2, 16/2  }});

    Vector2 target_offset = target.sub({{ sub_amount, 0 }});
    float x = (float)engine::lerpf(ent.position.x, target_offset.x, delta_t * ent.speed);
    float y = (float)engine::lerpf(ent.position.y, target_offset.y, delta_t * ent.speed);
    bool can_move_x = true;
    bool can_move_y = true;
    Vector2 potential_pos = {{ x, y }};

    Vector2 move_direction = potential_pos.sub(ent.position).normalize();


    foreach (&enemy : game.room_enemies)
    {
        if (!enemy.active || enemy.position.equals(ent.position) || enemy.knockback_timer > 0 || ent.speed > enemy.speed) {
            // lets assume if the position is the same, its the same enemy
            continue;
        }


      

        Vector2 enem_center = enemy.position.add({{ 16/2, 16/2  }});
        if (collisions::circles_overlap({{ x + 16/2, ent.position.y + 16/2 }}, 5, {{ enem_center.x, enem_center.y }}, 5)) {
            float enemy_distance_to_target = enemy.position.distance(target);
            // give presidence to closest enemy
            if (enemy_distance_to_target >= distance_from_target) {
                continue;
            }
                
            can_move_x = false;   
        }

        if (collisions::circles_overlap({{ ent.position.x + 16/2, y + 16/2 }}, 5, {{ enem_center.x, enem_center.y }}, 5)) {
            float enemy_distance_to_target = enemy.position.distance(target);
            // give presidence to closest enemy
            if (enemy_distance_to_target >= distance_from_target) {
                continue;
            }
                
            can_move_y = false;
        }
    }

     if ((ent.knockback_velocity.x != 0 || ent.knockback_velocity.y != 0) && ent.knockback_timer > 0) {
        float t = ent.knockback_timer / ENEMY_KNOCKBACK_TIME;
        ent.knockback_velocity.x = (float)engine::lerpf(ent.knockback_velocity.x, 0, 1.0 - t);
        ent.knockback_velocity.y = (float)engine::lerpf(ent.knockback_velocity.y, 0, 1.0 - t);
        ent.position.x += ent.knockback_velocity.x * (float)delta_t;
        ent.position.y += ent.knockback_velocity.y * (float)delta_t;
        can_move_x = false;
        can_move_y = false;
    } 


    switch(ent.entity_type) {
        case EntType.SKULL:
        if (collisions::ents_overlap(ent, &game.player, SPRITE_PIXEL_SIZE)) {
            game.player.damage_player(move_direction, ent.strength);
        }

        case EntType.BAT:
        if (ent.attack_timer <= 0) {   
            // spawn projectile
            ent.attack_timer = BAT_ATTACK_TIME;

            SpriteParticle proj;
            proj.new_projectile(false);
            float sub = ent.flip_x ? -2 : 2;
            Vector2 pos = ent.position.sub(@v2(sub, 0));
            proj.position = pos.add({{ 0, 16/2 }});
            proj.velocity = game.player.position.sub(ent.position).normalize().mulf(50);
            proj.rotation = -utils::calc_rotation_to_target(game.player.position, pos);
            game.projectiles.push(
                proj
            );
            
        } else if (distance_from_target < engine::get_random_float32_in_range(25, 35)) {
            can_move_x = false;
            can_move_y = false;
        }

        default:
        break;
    }


    if (ent.current_animation_timer >= ent.idle_animation_play_time) {
        ent.current_animation_timer = 0.0f;
        if (ent.current_animation_frame >= ent.idle_animation_count) {
            ent.current_animation_frame = 0;
        } else {
            ent.current_animation_frame+= 1;
        }
    }


    if (can_move_x) {
        ent.position.x = x;
    }

    if (can_move_y) {
        ent.position.y = y;
    }
}

const float ANIMATE_DOWN_VALUE = 65;
const float ANIMATE_SPEED = 20;
fn void update_weapon_logic(Game *game, Vector2 player_velocity, double delta_t) {
    Entity *player = &game.player;

    float rotation_z = -utils::calc_rotation_to_target(game::world_frame.world_mouse_pos, player.position);
    float moveDistance = 15.0f;
    float delta_x = moveDistance * $$cos(rotation_z);
    float delta_y = moveDistance * $$sin(rotation_z);

    Vector2 attack_direction = game::world_frame.world_mouse_pos.sub(player.position).normalize();
    Vector2 attack_position = player.position.add({{ delta_x, -delta_y }});
    
    float attack_length = 10;
    Vector2 attack_position_centered = attack_position.add({{ 16 * 0.5f, 16 * 0.5f }}).sub(attack_direction.mulf(attack_length));
    


    if (game.player.weapon_cooldown_timer <= 0 && engine::is_key_down(InputKeyCode.MOUSE_BUTTON_LEFT.value)) {
        game.camera.shake(0.5f);
        SpriteParticle projectile;
        projectile.new_projectile(true);
        projectile.position = player.position.add({{ delta_x + SPRITE_PIXEL_SIZE * 0.5f, -delta_y + SPRITE_PIXEL_SIZE * 0.5f }});
        projectile.velocity = attack_direction.mulf(300);
        projectile.sprite_cell_start_x = 0;
        projectile.sprite_cell_start_y = 1;
        projectile.current_frame = 0;
        projectile.time_per_frame = 0.015f;
        projectile.animation_frame_count = 2;
        projectile.rotation = rotation_z;
        game.projectiles.push(
            projectile
        );
        game.player.weapon_cooldown_timer = 0.3f;
    }

    if (player.flip_x) {
        float angle_to_target = utils::calc_rotation_to_target(@v2(player.position.x + SPRITE_PIXEL_SIZE * 0.5f, player.position.y), game::world_frame.world_mouse_pos);
        player.weapon_angle = angle_to_target;
    } else {
        float angle_to_target = utils::calc_rotation_to_target(game::world_frame.world_mouse_pos, player.position);
        player.weapon_angle = -angle_to_target;
    }
}

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

    if (entity.knockback_timer > 0) {
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


fn void update_player_animation(Entity *entity, double delta_t) {
    switch (entity.animation) {
        case EntAnimation.WALK:
            if (entity.current_animation_timer >= entity.walk_animation_play_time) {
                entity.current_animation_timer = 0.0f;
                if (entity.current_animation_frame >= entity.walk_animation_count) {
                    entity.current_animation_frame = 0;
                } else {
                    entity.current_animation_frame+= 1;
                }
            }
        case EntAnimation.ROLLING:
            if (entity.current_animation_timer >= entity.rolling_animation_play_time) {
                entity.current_animation_timer = 0.0f;
                if (entity.current_animation_frame >= entity.rolling_animation_count) {
                    entity.current_animation_frame = 0;
                } else {
                    entity.current_animation_frame+= 1;
                }
            }
        default:
            entity.current_animation_timer = 0.0f;
            entity.current_animation_frame = 0;
        break;
    }
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

    switch (entity.animation) {
        case EntAnimation.WALK:
            quad.uv = utils::get_uv_coords(sprite_size, @v2(entity.current_animation_frame + entity.walk_animation_frame_start, 0));
        case EntAnimation.ROLLING:
            quad.uv = utils::get_uv_coords(sprite_size, @v2(entity.current_animation_frame + entity.rolling_animation_frame_start_x, entity.rolling_animation_frame_start_y));
        default:
            quad.uv = utils::get_uv_coords(sprite_size, @v2(0, 0));
    }

	return weapon_xform;
}



fn void render_weapons(Entity *player, Matrix4 player_xform, engine::GfxImage* weapons_sprite, double delta_t) {


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
        xform = m4_translate(xform, @v3(-SPRITE_PIXEL_SIZE * 0.15f, 0, 0));

        Vector2 center_pos = player.position.add(@v2(16 *0.5f, 16 *0.5f));
        bool mouse_above = game::world_frame.world_mouse_pos.y > center_pos.y;

        if (mouse_above) {
            engine::push_z_layer(0);
        }
      
        engine::DrawQuad *quad = engine::draw_image_xform(weapons_sprite, xform, @v2(SPRITE_PIXEL_SIZE, SPRITE_PIXEL_SIZE), engine::COLOR_WHITE);
        quad.uv = utils::get_uv_coords(sprite_size, @v2((int)player.equipped_weapon, 0));
        if (mouse_above) {
            engine::pop_z_layer();
        }
    }
}