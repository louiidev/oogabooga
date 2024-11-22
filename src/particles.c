

#define SPRITE_PIXEL_SIZE 16

void render_particle(SpriteParticle *particle, Gfx_Image* sprite) {
    Matrix4 xform = m4_scalar(1.0);
    xform = m4_translate(xform, (Vector3){particle->position.x, particle->position.y, 0});
    xform = m4_translate(xform, (Vector3){-SPRITE_PIXEL_SIZE * 0.5f , -SPRITE_PIXEL_SIZE  * 0.5f, 0});

    xform = m4_translate(xform, (Vector3){SPRITE_PIXEL_SIZE / 2, SPRITE_PIXEL_SIZE / 2, 0});
    xform = m4_rotate_z(xform, particle->rotation);
    xform = m4_translate(xform, (Vector3){-SPRITE_PIXEL_SIZE / 2, -SPRITE_PIXEL_SIZE / 2, 0});

    Draw_Quad* quad = draw_image_xform(
        sprite,
        xform,
        (Vector2){16, 16},
        COLOR_WHITE
    );
    quad->uv = get_uv_coords(
        get_image_size(sprite),
        (Vector2){particle->sprite_cell_start_x + (float)particle->current_frame, particle->sprite_cell_start_y},
        SPRITE_PIXEL_SIZE
    );
}

void new_sprite_particle(SpriteParticle *p) {
    p->active = true;
}

void spawn_projectile_particle(Game* game, SpriteParticle* proj, int sprite_cell_start_y) {
    SpriteParticle particle = {0};
    new_sprite_particle(&particle);
    particle.position = proj->position;
    particle.sprite_cell_start_y = sprite_cell_start_y;
    particle.animation_frame_count = 4;
    particle.time_per_frame = 0.025f;
    particle.rotation = proj->rotation;
    growing_array_add((void**)&game->particles, &particle);
}

void update_and_draw_projectiles(Gfx_Image *sprite, Game *game, double delta_t) {
    for (int i = 0; i < growing_array_get_valid_count(game->projectiles); i++) {
        SpriteParticle *proj = &game->projectiles[i];
        if (!proj->active) {
            continue;
        }

        proj->current_animation_timer += (float)delta_t;

        if (proj->current_animation_timer >= proj->time_per_frame) {
            proj->current_animation_timer = 0.0f;
            if (proj->current_frame < proj->animation_frame_count - 1) {
                proj->current_frame++;
            }
        }

        Vector2 frame_positon_velocity = {
            proj->velocity.x * (float)delta_t,
            proj->velocity.y * (float)delta_t
        };
        proj->current_distance += v2_length(frame_positon_velocity);

        if (proj->current_distance >= proj->distance_limit) {
            proj->active = false;
        }

        proj->position = v2_add(proj->position, frame_positon_velocity);

        Vector2 center_pos = v2_add(game->player.position, (Vector2){SPRITE_PIXEL_SIZE * 0.5f, SPRITE_PIXEL_SIZE * 0.5f});

        if (!proj->player_projectile) {
            if (!is_entity_invinsible(&game->player) && circles_overlap(center_pos, game->player.collision_radius, proj->position, 4)) {
                proj->active = false;
                spawn_projectile_particle(game, proj, 0);
                damage_player(&game->player, v2_normalize(proj->velocity), proj->damage);
            }
        } else {
            for (int j = 0; j < growing_array_get_valid_count(game->room_enemies); j++) {
                Entity *enemy = &game->room_enemies[j];
                if (!enemy->active) {
                    continue;
                }
                Vector2 center_position = v2_add(enemy->position, (Vector2){SPRITE_PIXEL_SIZE * 0.5f, SPRITE_PIXEL_SIZE * 0.5f});
                if (circles_overlap(proj->position, 6, center_position, 6)) {
                    knockback_entity(enemy, v2_normalize(proj->velocity));
                    proj->active = false;
                    enemy->health -= proj->damage;
                    spawn_projectile_particle(game, proj, 1);
                    break;
                }
            }
        }

        if (proj->active) {
            for (int j = 0; j < growing_array_get_valid_count(game->walls); j++) {
                if (rect_circle_collision(game->walls[j], proj->position, 4)) {
                    proj->active = false;
                    spawn_projectile_particle(game, proj, 1);
                }
            }

            for (int j = 0; j < growing_array_get_valid_count(game->doors); j++) {
                Vector4 door_rect = (Vector4) {(int)game->doors[j].position.x, (int)game->doors[j].position.y, 12, 12};
                if (rect_circle_collision(door_rect, proj->position, 4)) {
                    proj->active = false;
                    spawn_projectile_particle(game, proj, 1);
                }
            }
        }

        render_particle(proj, sprite);
    }

    for (int i = growing_array_get_valid_count(game->projectiles); i >= 0;
               i--) {
            SpriteParticle projectile = game->projectiles[i];
            if (!projectile.active) {
              growing_array_ordered_remove_by_index((void**)game->projectiles, i);
            }
          }
}

void update_and_draw_particles(Gfx_Image *sprite, SpriteParticle *particles, double delta_t) {
    for (int i = 0; i < growing_array_get_valid_count(particles); i++) {
        SpriteParticle *particle = &particles[i];
        if (!particle->active) {
            continue;
        }

        particle->current_animation_timer += (float)delta_t;

        if (particle->current_animation_timer >= particle->time_per_frame) {
            particle->current_animation_timer = 0.0f;
            if (particle->current_frame >= particle->animation_frame_count - 1) {
                particle->active = false;
            } else {
                particle->current_frame++;
            }
        }

        particle->position.x += particle->velocity.x * (float)delta_t;
        particle->position.y += particle->velocity.y * (float)delta_t;
        render_particle(particle, sprite);
    }


    for (int i = growing_array_get_valid_count(particles); i >= 0;
                i--) {
            SpriteParticle particle = particles[i];
             if (!particle.active) {
               growing_array_ordered_remove_by_index((void**)particles, i);
             }
           }
}
