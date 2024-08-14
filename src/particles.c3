
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
struct SpriteParticle {
    bool active;
    Vector2 position;
    Vector2 velocity;
    int sprite_cell_start_x;
	int sprite_cell_start_y;
    int animation_frame_count;
    int current_frame;
    float current_animation_timer;
    float time_per_frame;
    float rotation;

    // Projectile properties
    bool player_projectile;
    float distance_limit;
    float current_distance;
    int damage;
}


// struct Particle {
//     float current_lifetime;
//     float lifetime;
//     float rotation;
//     float scale;
//     float target_scale;
//     Vector2 position;
//     Vector2 velocity;
//     Vector4 color;
// }


const float DEFAULT_DISTANCE_LIMIT = 300;

fn void SpriteParticle.new_projectile(SpriteParticle *p, bool player_projectile) {
    p.active = true;
    p.distance_limit = DEFAULT_DISTANCE_LIMIT;
    p.player_projectile = player_projectile;
}

fn void SpriteParticle.new(SpriteParticle *p) {
    p.active = true;
}   

fn void update_and_draw_projectiles(engine::GfxImage *sprite, game::Game *game, double delta_t) {
    foreach (&proj : game.projectiles)
    {   
        if (!proj.active) {
            continue;
        }

        proj.current_animation_timer+= (float)delta_t;

        if (proj.current_animation_timer >= proj.time_per_frame) {
            proj.current_animation_timer = 0.0f;
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
    

        Vector2 center_pos = game.player.position.add(@v2(SPRITE_PIXEL_SIZE * 0.5f, SPRITE_PIXEL_SIZE * 0.5f));


        if (!proj.player_projectile) {
            if (!game.player.is_invinsible() && collisions::circles_overlap(center_pos, game.player.collision_radius, proj.position, 4)) {
                proj.active = false;
                SpriteParticle particle;
                particle.new();
                particle.position = proj.position;
                particle.sprite_cell_start_y = 0;
                particle.animation_frame_count = 4;
                particle.time_per_frame = 0.025f;
                particle.rotation = proj.rotation;
                game.particles.push(particle);
                game.player.damage_player(proj.velocity.normalize(), proj.damage);
                
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
                    enemy.health-= game.player.strength;
                    
                    SpriteParticle particle;
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

fn void update_and_draw_particles(engine::GfxImage *sprite, List(<SpriteParticle>)* particles, double delta_t) {
    foreach (&particle : particles)
    {   
        if (!particle.active) {
            continue;
        }

        particle.current_animation_timer+= (float)delta_t;

        if (particle.current_animation_timer >= particle.time_per_frame) {
            particle.current_animation_timer = 0.0f;
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


fn void render_particle(SpriteParticle *particle, engine::GfxImage* sprite) {
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
