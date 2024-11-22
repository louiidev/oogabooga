const float ENEMY_KNOCKBACK_TIME = 0.4f;
const float ENEMY_KNOCKBACK_VELOCITY = 100;

const float BAT_ATTACK_TIME = 4;
const float SKULL_ATTACK_TIME = 0.5f;

WorldFrame world_frame = {0};

Entity new_entity()
{
  Entity ent;
  ent.active = true;
  ent.collision_radius = 5;

  return ent;
}

void update_entity_timers(Entity *ent, f32 delta_t)
{
  ent->invisible_timer = max(0, ent->invisible_timer - delta_t);
  ent->dodge_roll_cooldown_timer =
      max(0, ent->dodge_roll_cooldown_timer - delta_t);
  ent->dodge_roll_timer = max(0, ent->dodge_roll_timer - delta_t);
  ent->attack_timer = max(0.0, ent->attack_timer - delta_t);
  ent->knockback_timer = max(0.0, ent->knockback_timer - delta_t);
  ent->weapon_cooldown_timer = max(0.0, ent->weapon_cooldown_timer - delta_t);
  ent->current_animation_timer += delta_t;
}

bool is_entity_invinsible(Entity *ent)
{
  return false;
}

void knockback_entity(Entity *ent, Vector2 attack_direction)
{
  if (ent->entity_type == PLAYER && ent->knockback_timer > 0)
  {
    return;
  }

  ent->knockback_timer = ENEMY_KNOCKBACK_TIME;
  ent->knockback_direction = attack_direction;

  switch (ent->entity_type)
  {
  case PLAYER:
    break;
  case SKULL:
    ent->attack_timer = SKULL_ATTACK_TIME + ENEMY_KNOCKBACK_TIME;
    break;
  case BAT:
    ent->attack_timer = BAT_ATTACK_TIME + ENEMY_KNOCKBACK_TIME;
    break;
  default:
    assert(false);
  }
}
const float PLAYER_I_FRAMES_TIME = 0.5f;
void damage_player(Entity *ent, Vector2 attack_direction, float damage_amount)
{
  if (is_entity_invinsible(ent))
  {
    return;
  }
  ent->invisible_timer = PLAYER_I_FRAMES_TIME;
  knockback_entity(ent, attack_direction);
  ent->health -= damage_amount;
}

const f32 TARGET_OFFSET_AMOUNT = 10;
void update_entity(Entity *ent, Game *game, double delta_t)
{
  if (!ent->active)
  {
    return;
  }

  if (ent->health <= 0)
  {
    ent->active = false;
    return;
  }

  ent->flip_x = ent->position.x > game->player.position.x;
  update_entity_timers(ent, (f32)delta_t);

  float sub_amount = ent->flip_x ? -TARGET_OFFSET_AMOUNT : TARGET_OFFSET_AMOUNT;

  if (ent->entity_type == SKULL)
  {
    sub_amount = 0;
  }

  Vector2 target = game->player.position;

  float distance_from_target = v2_length(v2_sub(ent->position, target));
  Vector2 target_center = v2_add(game->player.position, v2(16 / 2, 16 / 2));
  Vector2 center_pos = v2_add(ent->position, v2(16 / 2, 16 / 2));

  Vector2 target_offset = v2_sub(target, v2(sub_amount, 0));
  float x = (float)lerpf(ent->position.x, target_offset.x, delta_t * ent->speed);
  float y = (float)lerpf(ent->position.y, target_offset.y, delta_t * ent->speed);
  bool can_move_x = true;
  bool can_move_y = true;
  Vector2 potential_pos = v2(x, y);

  Vector2 move_direction = v2_normalize(v2_sub(potential_pos, ent->position));

  for (int i = 0; i < growing_array_get_valid_count(game->room_enemies); i++)
  {
    Entity *enemy = &game->room_enemies[i];

    if (!enemy->active || (enemy->position.x == ent->position.x && enemy->position.y == ent->position.y) ||
        enemy->knockback_timer > 0 || ent->speed > enemy->speed ||
        !game->player.active)
    {
      // lets assume if the position is the same, its the same enemy
      continue;
    }

    Vector2 enem_center = v2_add(enemy->position, v2(16 / 2, 16 / 2));
    if (circles_overlap(v2(x + 16 / 2, ent->position.y + 16 / 2), 5,
                        v2(enem_center.x, enem_center.y), 5))
    {
      float enemy_distance_to_target = v2_distance(enemy->position, target);
      // give presidence to closest enemy
      if (enemy_distance_to_target >= distance_from_target)
      {
        continue;
      }

      can_move_x = false;
    }

    if (circles_overlap(v2(ent->position.x + 16 / 2, y + 16 / 2), 5,
                        v2(enem_center.x, enem_center.y), 5))
    {
      float enemy_distance_to_target = v2_distance(enemy->position, target);
      // give presidence to closest enemy
      if (enemy_distance_to_target >= distance_from_target)
      {
        continue;
      }

      can_move_y = false;
    }
  }

  if (ent->knockback_timer > 0)
  {
    float t = 1.0 - (ent->knockback_timer / ENEMY_KNOCKBACK_TIME);
    ent->knockback_velocity.x = (float)lerpf(
        (double)ent->knockback_direction.x * ENEMY_KNOCKBACK_VELOCITY, 0, t);
    ent->knockback_velocity.y = (float)lerpf(
        (double)ent->knockback_direction.y * ENEMY_KNOCKBACK_VELOCITY, 0, t);
    ent->position.x += ent->knockback_velocity.x * (float)delta_t;
    ent->position.y += ent->knockback_velocity.y * (float)delta_t;
    can_move_x = false;
    can_move_y = false;
  }

  switch (ent->entity_type)
  {
  case SKULL:
    if (ents_overlap(ent, &game->player, SPRITE_PIXEL_SIZE))
    {
      damage_player(&game->player, move_direction, ent->strength);
    }
    break;
  case BAT:
    if (ent->attack_timer <= 0)
    {
      // spawn projectile
      ent->attack_timer = BAT_ATTACK_TIME;

      SpriteParticle proj = new_projectile(false);
      float sub = ent->flip_x ? -2 : 2;
      Vector2 pos = v2_sub(ent->position, v2(sub, 0));
      proj.position = v2_add(pos, v2(0, 16 / 2));
      proj.velocity =
          v2_sub(game->player.position, v2_mulf(v2_normalize(ent->position), 50));
      proj.rotation = -calc_rotation_to_target(game->player.position, pos);
      growing_array_add((void **)&game->projectiles, &proj);
    }
    else if (distance_from_target < get_random_float32_in_range(25, 35))
    {
      can_move_x = false;
      can_move_y = false;
    }
    break;
  default:
    break;
  }

  if (ent->current_animation_timer >= ent->idle_animation_play_time)
  {
    ent->current_animation_timer = 0.0;
    if (ent->current_animation_frame >= ent->idle_animation_count)
    {
      ent->current_animation_frame = 0;
    }
    else
    {
      ent->current_animation_frame += 1;
    }
  }

  if (can_move_x)
  {
    ent->position.x = x;
  }

  if (can_move_y)
  {
    ent->position.y = y;
  }
}

const float ANIMATE_DOWN_VALUE = 65;
const float ANIMATE_SPEED = 20;
void update_weapon_logic(Game *game, Vector2 player_velocity, double delta_t)
{
  Entity *player = &game->player;

  float rotation_z =
      -calc_rotation_to_target(world_frame.world_mouse_pos, player->position);
  float moveDistance = 15.0;

  float delta_x = moveDistance * cos(rotation_z);
  float delta_y = moveDistance * sin(rotation_z);
  Vector2 attack_position = v2_add(player->position, v2(delta_x, -delta_y));

  float attack_length = 10;

  if (player->equipped_weapon_index != 0 &&
      player->weapon_cooldown_timer <= 0 &&
      player->dodge_roll_timer <= 0 &&
      is_key_down(MOUSE_BUTTON_LEFT))
  {

    Weapon weapon = game->weapons_db[player->equipped_weapon_index];
    camera_shake(&game->camera, 0.75f);

    long bullets_per_shot = 1;

    if (weapon.min_bullets_per_shot != 0)
    {
      assert(weapon.min_bullets_per_shot < weapon.max_bullets_per_shot);
      bullets_per_shot = get_random_int_in_range(weapon.min_bullets_per_shot,
                                                 weapon.max_bullets_per_shot);
    }

    for (long i = 0; i < bullets_per_shot; i++)
    {
      Vector2 attack_direction = v2(cos(-rotation_z), sin(-rotation_z));
      float bullet_rotation = rotation_z;
      if (weapon.accuracy > 0.0)
      {
        float random_angle =
            get_random_float32_in_range(-weapon.accuracy, weapon.accuracy);
        float cos_angle = cos(random_angle);
        float sin_angle = sin(random_angle);
        bullet_rotation += random_angle;
        float new_x =
            attack_direction.x * cos_angle - attack_direction.y * sin_angle;
        float new_y =
            attack_direction.x * sin_angle + attack_direction.y * cos_angle;
        attack_direction = v2(cos(-bullet_rotation), sin(-bullet_rotation));
      }

      SpriteParticle projectile = new_projectile(true);
      projectile.position =
          v2_add(player->position, v2(delta_x + SPRITE_PIXEL_SIZE * 0.5f,
                                      -delta_y + SPRITE_PIXEL_SIZE * 0.5f));
      projectile.velocity = v2_mulf(attack_direction, weapon.velocity);
      projectile.sprite_cell_start_x = 0;
      projectile.sprite_cell_start_y = 1;
      projectile.current_frame = 0;
      projectile.time_per_frame = 0.015f;
      projectile.animation_frame_count = 2;
      projectile.rotation = bullet_rotation;
      projectile.damage = weapon.damage_per_bullet;
      projectile.distance_limit = weapon.distance_limit;

      growing_array_add((void **)&game->projectiles, &projectile);
    }

    game->player.weapon_cooldown_timer = weapon.fire_rate_seconds;
  }

  if (player->flip_x)
  {
    float angle_to_target = calc_rotation_to_target(
        v2(player->position.x + SPRITE_PIXEL_SIZE * 0.5f, player->position.y),
        world_frame.world_mouse_pos);
    player->weapon_angle = angle_to_target;
  }
  else
  {
    float angle_to_target =
        calc_rotation_to_target(world_frame.world_mouse_pos, player->position);
    player->weapon_angle = -angle_to_target;
  }
}

void draw_health_bar(Matrix4 xform, float max_health, float health)
{
}

void render_entity(Entity *entity)
{
  if (!entity->active)
  {
    return;
  }

  Vector2 sprite_size = get_image_size(sprites.enemies);
  Matrix4 xform = m4_scalar(1.0);
  xform = m4_translate(xform, v3(entity->position.x, entity->position.y, 0.0));
  Matrix4 xform_before_flip = xform;
  if (entity->flip_x)
  {
    xform = flip_sprite_x(xform);
  }

  Draw_Quad *quad =
      draw_image_xform(sprites.enemies, xform,
                       v2(SPRITE_PIXEL_SIZE, SPRITE_PIXEL_SIZE), COLOR_WHITE);
  quad->userdata[0].x = 1;
  quad->userdata[0].y = 0;

  if (entity->knockback_timer > 0)
  {
    quad->userdata[0].y = 1;
  }

  // @TODO: Maybe we should just store this as a v2?
  if (entity->animation == IDLE)
  {
    quad->uv = get_uv_coords(
        sprite_size,
        v2(entity->current_animation_frame + entity->idle_animation_frame_start_x,
           entity->idle_animation_frame_start_y),
        SPRITE_PIXEL_SIZE);
  }
  else
  {
    assert(false);
  }

  draw_health_bar(xform_before_flip, entity->max_health, entity->health);
}

void update_player_animation(Entity *entity, double delta_t)
{
  // Update the timer
  entity->current_animation_timer += delta_t;

  switch (entity->animation)
  {
  case WALK:
    if (entity->current_animation_timer >= entity->walk_animation_play_time)
    {
      entity->current_animation_timer = 0.0;
      if (entity->current_animation_frame >= entity->walk_animation_count)
      {
        entity->current_animation_frame = 0;
      }
      else
      {
        entity->current_animation_frame += 1;
      }
    }
    break;

  case ROLLING:
    if (entity->current_animation_timer >=
        entity->rolling_animation_play_time)
    {
      entity->current_animation_timer = 0.0;
      if (entity->current_animation_frame >= entity->rolling_animation_count)
      {
        entity->current_animation_frame = 0;
      }
      else
      {
        entity->current_animation_frame += 1;
      }
    }
    break;

  default:
    entity->current_animation_timer = 0.0;
    entity->current_animation_frame = 0;
    break;
  }
}

Matrix4 render_player(Entity *entity, Gfx_Image *player_sprite)
{
  Vector2 sprite_size = get_image_size(player_sprite);
  Matrix4 player_xform = m4_scalar(1.0);

  player_xform =
      m4_translate(player_xform, v3(entity->position.x, entity->position.y, 0.0));

  Matrix4 weapon_xform = player_xform;

  if (entity->flip_x)
  {
    player_xform = flip_sprite_x(player_xform);
  }
  Draw_Quad *quad =
      draw_image_xform(player_sprite, player_xform,
                       v2(SPRITE_PIXEL_SIZE, SPRITE_PIXEL_SIZE), COLOR_WHITE);

  switch (entity->animation)
  {
  case WALK:
    quad->uv = get_uv_coords(
        sprite_size,
        v2(entity->current_animation_frame + entity->walk_animation_frame_start,
           0),
        SPRITE_PIXEL_SIZE);
    break;
  case ROLLING:
    quad->uv = get_uv_coords(sprite_size,
                             v2(entity->current_animation_frame +
                                    entity->rolling_animation_frame_start_x,
                                entity->rolling_animation_frame_start_y),
                             SPRITE_PIXEL_SIZE);
    break;
  default:
    quad->uv = get_uv_coords(sprite_size, v2(0, 0), SPRITE_PIXEL_SIZE);
    break;
  }

  return weapon_xform;
}

void render_weapons(Entity *player, Matrix4 player_xform,
                    Gfx_Image *weapons_sprite, double delta_t)
{

  Vector2 sprite_size = get_image_size(weapons_sprite);
  if (player->equipped_weapon_index != 0)
  {
    Matrix4 xform = player_xform;

    // Center player xform to center of body
    xform = m4_translate(
        xform, v3(SPRITE_PIXEL_SIZE * 0.5f, SPRITE_PIXEL_SIZE * 0.5f, 0));
    // draw_circle_xform(xform, v2(1, 1), {{ 1, 0, 0, 1 }});
    float x_scale = 1.0;
    float y_scale = 1.0;

    bool aiming_above_player =
        world_frame.world_mouse_pos.y >
        v2_add(player->position, v2(SPRITE_PIXEL_SIZE * 0.5f, SPRITE_PIXEL_SIZE * 0.5f))
            .y;

    if (player->flip_x)
    {
      x_scale = -1.0;
    }

    float angle = player->weapon_angle + player->current_weapon_angle_offset;

    xform = m4_scale(xform, v3(x_scale, y_scale, 1));

    xform = m4_rotate_z(xform, angle);
    xform = m4_translate(xform, v3(0, -WEAPON_SPRITE_SIZE * 0.5f, 0));
    xform = m4_translate(xform, v3(-WEAPON_SPRITE_SIZE * 0.20, 0, 0));

    Vector2 center_pos = v2_add(player->position,
                                v2(SPRITE_PIXEL_SIZE * 0.5f, SPRITE_PIXEL_SIZE * 0.5f));

    if (aiming_above_player)
    {
      push_z_layer(0);
    }

    Draw_Quad *quad = draw_image_xform(
        weapons_sprite, xform, v2(WEAPON_SPRITE_SIZE, WEAPON_SPRITE_SIZE),
        COLOR_WHITE);
    // draw_circle_xform(xform, v2(1, 1), {{ 1, 0, 0, 1 }});
    quad->uv = get_uv_coords(sprite_size, v2(player->equipped_weapon_index, 0),
                             WEAPON_SPRITE_SIZE);
    if (aiming_above_player)
    {
      pop_z_layer();
    }
  }
}
