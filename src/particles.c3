
module particles;
import engine;
import utils;
import std::collections;
import std::io;
import game;
import collisions;

def Vector2 = engine::Vector2;


// We use these for projectiles
// basically they can have physical interactions if we store them in the projectiles array list
struct Particle {
    bool active;
    Vector2 position;
    Vector2 velocity;
    int sprite_cell_start_x;
	int sprite_cell_start_y;
    int animation_frame_count;
    int current_frame;
    float current_animation_time;
    float time_per_frame;
    float rotation;

    // Projectile properties
    bool player_projectile;
    float distance_limit;
    float current_distance;
    int damage;
}



const float DEFAULT_DISTANCE_LIMIT = 300;

fn void Particle.new_projectile(Particle *p, bool player_projectile) {
    p.active = true;
    p.distance_limit = DEFAULT_DISTANCE_LIMIT;
    p.player_projectile = player_projectile;
}

fn void Particle.new(Particle *p) {
    p.active = true;
}   

fn void update_and_draw_projectiles(engine::GfxImage *sprite, game::Game *game, double delta_t) {
    foreach (&proj : game.projectiles)
    {   
        if (!proj.active) {
            continue;
        }

        proj.current_animation_time+= (float)delta_t;

        if (proj.current_animation_time >= proj.time_per_frame) {
            proj.current_animation_time = 0.0f;
            if (proj.current_frame < proj.animation_frame_count - 1) {
                proj.current_frame+= 1;
            }
        }


        Vector2 frame_positon_velocity = {{ proj.velocity.x * (float)delta_t,proj.velocity.y * (float)delta_t}};
        proj.current_distance+= frame_positon_velocity.length();

        if (proj.current_distance >= proj.distance_limit) {
            proj.active = false;
        }

        proj.position = proj.position.add(frame_positon_velocity);
    

        Vector2 bottom_left = game.player_entity.position.add(game.player_entity.hitbox_offset);

		// engine::draw_circle_xform(xform, {{ 16, 16 }}, {{ 1, 0, 1, 1 }});
        if (!proj.player_projectile) {
            if (utils::rect_circle_collision(bottom_left, game.player_entity.hitbox_size, proj.position, 4)) {
                proj.active = false;
                Particle particle;
                particle.new();
                particle.position = proj.position;
                particle.sprite_cell_start_y = 0;
                particle.animation_frame_count = 4;
                particle.time_per_frame = 0.025f;
                particle.rotation = proj.rotation;
                game.particles.push(particle);
                game.player_entity.knockback(proj.velocity.normalize());
                game.player_entity.health-= proj.damage * 2;
            }
        } else {
            foreach (&enemy : game.room_enemies)
            {
                if (!enemy.active) {
                    continue;
                }
                Vector2 center_position = enemy.position.add({{ SPRITE_PIXEL_SIZE * 0.5f, SPRITE_PIXEL_SIZE * 0.5f }});
                if (collisions::circles_overlap(proj.position, 6, center_position, 6)) {
                    enemy.knockback(proj.velocity.normalize());
                    proj.active = false;
                    enemy.health-= game.player_entity.strength * 2;
                    
                    Particle particle;
                    particle.new();
                    particle.position = proj.position;
                    particle.sprite_cell_start_y = 1;
                    particle.animation_frame_count = 4;
                    particle.time_per_frame = 0.025f;
                    particle.rotation = proj.rotation;
                    game.particles.push(particle);
                    break;
                }
            }
        }

        render_particle(proj, sprite);
    }

    game.projectiles.remove_if(fn (p) => !p.active);

}

fn void update_and_draw_particles(engine::GfxImage *sprite, List(<Particle>)* particles, double delta_t) {
    foreach (&particle : particles)
    {   
        if (!particle.active) {
            continue;
        }

        particle.current_animation_time+= (float)delta_t;

        if (particle.current_animation_time >= particle.time_per_frame) {
            particle.current_animation_time = 0.0f;
            if (particle.current_frame >= particle.animation_frame_count - 1) {
                particle.active = false;
            } else {
                particle.current_frame+= 1;
            }   
        }



        particle.position.x+= particle.velocity.x * (float)delta_t;
        particle.position.y+= particle.velocity.y * (float)delta_t;
        render_particle(particle, sprite);
    }

    particles.remove_if(fn (p) => !p.active);

}


fn void render_particle(Particle *particle, engine::GfxImage* sprite) {
    engine::Matrix4 xform = engine::m4_scalar(1.0);
    xform  = engine::m4_translate(xform, {{ particle.position.x, particle.position.y, 0 }});
    xform  = engine::m4_translate(xform, {{-SPRITE_PIXEL_SIZE * 0.5f , -SPRITE_PIXEL_SIZE  * 0.5f, 0}});
    
    xform = engine::m4_translate(xform, {{SPRITE_PIXEL_SIZE / 2, SPRITE_PIXEL_SIZE / 2, 0}});
    xform  = engine::m4_rotate_z(xform, particle.rotation);
    xform = engine::m4_translate(xform, {{-SPRITE_PIXEL_SIZE / 2, -SPRITE_PIXEL_SIZE / 2, 0}});

    DrawQuad* quad = engine::draw_image_xform(
        sprite,
        xform,
        {{ 16, 16 }},
        engine::COLOR_WHITE
    );
    quad.uv = utils::get_uv_coords(
            utils::get_image_size(sprite),
            {{ particle.sprite_cell_start_x + (float)particle.current_frame, particle.sprite_cell_start_y }}
    );
}
