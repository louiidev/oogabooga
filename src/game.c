
#include "./utils.c"
#include "./collisions.c"
#include "./entity.c"
#include "./particles.c"

#include "./weapons.c"

#define ROOM_SIZE_X 464
#define ROOM_SIZE_Y 246
#define DOOR_ONE_POS_X 178
#define DOOR_ONE_POS_Y 258
#define DOOR_TWO_POS_X 226
#define DOOR_TWO_POS_Y 258
#define DOOR_THREE_POS_X 274
#define DOOR_THREE_POS_Y 258
#define SPAWN_POS_X 0
#define SPAWN_POS_Y -120
#define CAMERA_SPEED 10.0
#define CAMERA_SHAKE_DECAY 0.8f
#define SHAKE_POWER 2.0
#define DODGE_VELOCITY 350.0
#define DODGE_TIME 0.5f
#define PLAYER_KNOCKBACK_VELOCITY 150.0

RewardType get_random_door_reward_type()
{
  return get_random_int_in_range(1, (s64)RANDOM);
}

RewardType get_random_pickup_reward_type()
{
  return get_random_int_in_range(1, (s64)RANDOM - 1);
}

Pickup get_pickup_from_reward(RewardType type)
{
  Pickup pickup;
  pickup.type = type;
  switch (type)
  {
  case RELIC:
    pickup.data = (PickupData){.relic_type = RING};
    break;
  case GOLD:
    pickup.data =
        (PickupData){.gold_amount = (s32)get_random_int_in_range(5, 15)};
    break;
  case WEAPON:
    pickup.data = (PickupData){
        .weapon_db_index = (s32)get_random_int_in_range(1, WEAPONS_COUNT)};
    break;
  case HEALTH_POTION:
    pickup.data = (PickupData){.health_amount = 1};
    break;
  case STAT_UPGRADE:
    pickup.data = (PickupData){.stat_upgrade = (StatUpgrade){.health = 1}};
    break;
  default:
    assert(false);
  }

  return pickup;
}

Entity create_bat()
{
  Entity ent = new_entity();
  ent.attack_timer = 3;
  ent.current_animation_frame = 0;
  ent.idle_animation_frame_start_x = 0;
  ent.idle_animation_count = 4;
  ent.idle_animation_play_time = 0.1;
  ent.speed = 1.3;
  ent.entity_type = BAT;
  ent.sprite_cell_count_x = 4;
  ent.sprite_cell_count_y = 4;
  ent.max_health = 10;
  ent.health = 10;
  ent.position =
      v2(get_random_float32_in_range(-ROOM_SIZE_X * 0.5f, ROOM_SIZE_X * 0.5f),
         get_random_float32_in_range(100, ROOM_SIZE_Y * 0.5f));

  return ent;
}

Entity create_skull()
{
  Entity ent = new_entity();
  ent.attack_timer = 3;
  ent.current_animation_frame = 0;
  ent.idle_animation_frame_start_x = 0;
  ent.idle_animation_frame_start_y = 1;
  ent.idle_animation_count = 0;
  ent.idle_animation_play_time = 0.1;
  ent.speed = 0.3;
  ent.entity_type = SKULL;
  ent.max_health = 20;
  ent.strength = 2;
  ent.health = 20;
  ent.position =
      v2(get_random_float32_in_range(-ROOM_SIZE_X * 0.5f, ROOM_SIZE_X * 0.5f),
         get_random_float32_in_range(0, ROOM_SIZE_Y * 0.5f));

  return ent;
}

void camera_update(Camera *self, Vector2 target, double delta_t)
{
  animate_v2_to_target(&self->position, target, delta_t, CAMERA_SPEED);
  self->shake_amount =
      max(self->shake_amount - CAMERA_SHAKE_DECAY * (float)delta_t, 0);
  float amount = pow(self->shake_amount, SHAKE_POWER);
  // rotation = max_roll * amount * rand_range(-1, 1)
  self->position.x += amount * get_random_float32_in_range(-1, 1);
  self->position.y += amount * get_random_float32_in_range(-1, 1);
}

void generate_room(Game *game)
{
  game->show_reward = false;
  game->doors_locked = true;
  game->player.position = v2(SPAWN_POS_X, SPAWN_POS_Y);
  game->current_room_reward = get_pickup_from_reward(WEAPON);
  s64 number_of_enemies = get_random_int_in_range(15, 50);
  for (s32 i = 0; i < number_of_enemies; i++)
  {
    s64 enemy_type = get_random_int_in_range(1, (s64)MAX_ENT_TYPE - 1);
    EntType type = (EntType)enemy_type;
    switch (type)
    {
    case BAT:
      Entity bat = create_bat();
      growing_array_add((void **)&game->room_enemies, &bat);
      break;
    case SKULL:
      Entity skull = create_skull();
      growing_array_add((void **)&game->room_enemies, &skull);
      break;
    default:
      assert(false);
    }
  }
}

typedef struct
{
  Vector2
      mouse_pos_screen; // We use this to make a light around the mouse cursor
  Vector2 window_size;
} Cbuffer;

bool draw_hitboxes = false;

s32 entry(s32 argc, char **argv)
{
  string source;
  bool ok = os_read_entire_file_s(STR("./shaders/shader.hlsl"), &source,
                                  get_heap_allocator());
  assert(ok, "Could not read ./shaders/shader.hlsl");

  shader_recompile_with_extension(source, sizeof(Cbuffer));
  dealloc_string(get_heap_allocator(), source);

  u64 b = 0x222034ff;
  window.clear_color = hex_to_rgba(b);
  // Vector4 vec4 = {0.1, 0.1, 0.1, 1};
  window.scaled_width = 1280;
  window.width = 1280;
  window.scaled_height = 800;
  window.height = 800;
  window.x = 100;
  window.y = 100;
  window.title = STR("bullet hell roguelite");
  seed_for_random = rdtsc();
  Game game = {0};
  game.doors_locked = true;

  sprites.weapons =
      load_image_from_disk(STR("./assets/weapons.png"), get_heap_allocator());
  sprites.player =
      load_image_from_disk(STR("./assets/player.png"), get_heap_allocator());
  sprites.walls =
      load_image_from_disk(STR("./assets/walls.png"), get_heap_allocator());
  sprites.particles =
      load_image_from_disk(STR("./assets/particles.png"), get_heap_allocator());
  sprites.enemies =
      load_image_from_disk(STR("./assets/enemies.png"), get_heap_allocator());
  sprites.projectiles = load_image_from_disk(STR("./assets/projectiles.png"),
                                             get_heap_allocator());
  sprites.cursor =
      load_image_from_disk(STR("./assets/cursor.png"), get_heap_allocator());
  sprites.health_bar =
      load_image_from_disk(STR("./assets/healthbar.png"), get_heap_allocator());
  sprites.door =
      load_image_from_disk(STR("./assets/door.png"), get_heap_allocator());
  sprites.rewards =
      load_image_from_disk(STR("./assets/rewards.png"), get_heap_allocator());

  game.font =
      load_font_from_disk(STR("./assets/m6x11.ttf"), get_heap_allocator());

  // os_show_mouse_pos32er(false);
  game.player = new_entity();
  game.player.position = v2(SPAWN_POS_X, SPAWN_POS_Y);
  game.player.speed = 100;
  game.player.equipped_weapon_index = 1;
  game.player.walk_animation_count = 6;
  game.player.walk_animation_frame_start = 1;
  game.player.walk_animation_play_time = 0.08f;

  game.player.rolling_animation_count = 3;
  game.player.rolling_animation_frame_start_x = 0;
  game.player.rolling_animation_frame_start_y = 1;
  game.player.rolling_animation_play_time = 0.05f;

  game.player.strength = 1;
  game.player.health = 10;
  game.player.max_health = 10;

  game.current_room_reward = get_pickup_from_reward(WEAPON);

  growing_array_init((void **)&game.room_enemies, sizeof(Entity),
                     get_heap_allocator());
  growing_array_init((void **)&game.projectiles, sizeof(SpriteParticle),
                     get_heap_allocator());
  growing_array_init((void **)&game.particles, sizeof(SpriteParticle),
                     get_heap_allocator());
  growing_array_init((void **)&game.walls, sizeof(Vector4),
                     get_heap_allocator());

  init_weapons_db(&game);

  Vector4 left_wall = v4(-240, -270 / 2, 12, 270);
  Vector4 right_wall = v4(240 - 12, -270 / 2, 12, 270);
  Vector4 bottom_wall = v4(-240, -270 / 2, 480, 12);

  growing_array_add((void **)&game.walls, &left_wall);
  growing_array_add((void **)&game.walls, &right_wall);
  growing_array_add((void **)&game.walls, &bottom_wall);

  // top

  s32 y_pos = 270 / 2 - 12;
  Vector4 t_1 = v4(-240, y_pos, (s32)DOOR_ONE_POS_X, 12);

  growing_array_add((void **)&game.walls, &t_1);

  s32 start_x_one = -240 + (s32)DOOR_ONE_POS_X + 12;
  s32 start_x_two = -240 + (s32)DOOR_TWO_POS_X + 12;
  s32 start_x_three = -240 + (s32)DOOR_THREE_POS_X + 12;
  Vector4 t_2 = v4(start_x_one, y_pos,
                   (s32)DOOR_TWO_POS_X - (s32)DOOR_ONE_POS_X - 12, 12);
  growing_array_add((void **)&game.walls, &t_2);
  Vector4 t_3 = v4(start_x_two, y_pos,
                   (s32)DOOR_THREE_POS_X - (s32)DOOR_TWO_POS_X - 12, 12);

  growing_array_add((void **)&game.walls, &t_3);
  Vector4 t_4 = v4(start_x_three, y_pos, 480 - (s32)DOOR_THREE_POS_X + 12, 12);
  growing_array_add((void **)&game.walls, &t_4);

  // add doors
  game.doors[0] =
      (Door){.position = v2(start_x_one - 12, y_pos), .reward_item = NIL};
  game.doors[1] =
      (Door){.position = v2(start_x_two - 12, y_pos), .reward_item = NIL};
  game.doors[2] =
      (Door){.position = v2(start_x_three - 12, y_pos), .reward_item = NIL};

  generate_room(&game);

  double last_time = os_get_current_time_in_seconds();

  s32 target_render_width = 320;
  float zoom = (float)window.width / (float)target_render_width;
  float scaled_render_height = (float)window.height / zoom;

  float half_width = target_render_width * 0.5f;
  float half_height = scaled_render_height * 0.5f;

  float fps_limit = 144;
  float min_frametime = 1.0 / fps_limit;

  Cbuffer cbuffer;

  bool paused = false;
  while (!window.should_close)
  {
    double now = os_get_current_time_in_seconds();
    double delta_t = now - last_time;

    if (delta_t < min_frametime)
    {
      os_high_precision_sleep((min_frametime - delta_t) * 1000.0);
      now = os_get_current_time_in_seconds();
      delta_t = now - last_time;
    }

    if (is_key_just_released((s32)'P'))
    {
      paused = !paused;
    }

    if (paused)
    {
      delta_t = 0.0;
    }

    last_time = now;

    reset_temporary_storage();
    draw_frame.cbuffer = &cbuffer;

    if (game.current_state == MAIN_MENU)
    {
      draw_frame.projection = m4_make_orthographic_projection(
          window.pixel_width * -0.5f, window.pixel_width * 0.5f,
          window.pixel_height * -0.5f, window.pixel_height * 0.5f, -1, 10);
      draw_frame.view = m4_make_scale(v3(1, 1, 1));
      world_frame.world_mouse_pos = screen_to_world();

      Matrix4 xform = m4_scalar(1.0);
      float width = 150.0;
      float height = 250.0;

      xform = m4_translate(xform, v3(width * 0.5f, height * 0.5f, 0.0));
      draw_rect_xform(xform, v2(width, height), v4(0.1, 0.1, 0.1, 1.0));

      // Draw Text
      string start_text = STR("Start Game");
      string load_text = STR("Load Game");
      string options_text = STR("Options");
      string exit_text = STR("Exit");
      s32 font_height = 24;
      float text_padding = 5;
      float all_text_height = (font_height + text_padding) * 4;
      float top_bottom_padding = height * 0.5f - all_text_height;
      xform = m4_translate(xform, v3(top_bottom_padding, 0.0, 0.0));
      assert(top_bottom_padding > 0, "Text calculation off");
      {
        xform = m4_translate(xform, v3(0.0, font_height + text_padding, 0.0));
        Gfx_Text_Metrics metrics =
            measure_text(game.font, start_text, font_height, v2(1, 1));
        Vector2 justified =
            v2(metrics.visual_size.x * 0.5f, metrics.visual_size.y * 0.5f);
        Matrix4 text_xform =
            m4_translate(xform, v3(justified.x, justified.y, 0.0));
        draw_text_xform(game.font, start_text, font_height, text_xform,
                        v2(1, 1), COLOR_WHITE);

        Vector2 position = get_matrix_position(xform);
        Vector4 rect = v4((s32)position.x, (s32)position.y, metrics.visual_size.x,
                          metrics.visual_size.y);

        if (point_inside_rect(rect, position))
        {
          game.current_state = GAME_PLAY;
        }
      }

      {
        xform = m4_translate(xform, v3(0.0, font_height + text_padding, 0.0));
        Gfx_Text_Metrics metrics =
            measure_text(game.font, load_text, font_height, v2(1, 1));
        Vector2 justified =
            v2(metrics.visual_size.x * 0.5f, metrics.visual_size.y * 0.5f);
        Matrix4 text_xform =
            m4_translate(xform, v3(width * 0.5f, height * 0.5f, 0.0));
        draw_text_xform(game.font, load_text, font_height, text_xform, v2(1, 1),
                        COLOR_WHITE);
      }

      {
        xform = m4_translate(xform, v3(0.0, font_height + text_padding, 0.0));

        Gfx_Text_Metrics metrics =
            measure_text(game.font, options_text, font_height, v2(1, 1));
        Vector2 justified =
            v2(metrics.visual_size.x * 0.5f, metrics.visual_size.y * 0.5f);
        Matrix4 text_xform =
            m4_translate(xform, v3(width * 0.5f, height * 0.5f, 0.0));
        draw_text_xform(game.font, options_text, font_height, text_xform,
                        v2(1, 1), COLOR_WHITE);
      }

      {
        xform = m4_translate(xform, v3(0.0, font_height + text_padding, 0.0));

        Gfx_Text_Metrics metrics =
            measure_text(game.font, exit_text, font_height, v2(1, 1));
        Vector2 justified =
            v2(metrics.visual_size.x * 0.5f, metrics.visual_size.y * 0.5f);
        Matrix4 text_xform =
            m4_translate(xform, v3(width * 0.5f, height * 0.5f, 0.0));
        draw_text_xform(game.font, exit_text, font_height, text_xform, v2(1, 1),
                        COLOR_WHITE);

        Vector2 position = get_matrix_position(xform);
        ;
        Vector4 rect = {(s32)position.x, (s32)position.y, metrics.visual_size.x,
                        metrics.visual_size.y};

        if (point_inside_rect(rect, position))
        {
          return 0;
        }
      }

      continue;
    }

    if (game.player.active)
    {
      camera_update(&game.camera, game.player.position, delta_t);
    }

    draw_frame.enable_z_sorting = true;
    draw_frame.projection = m4_make_orthographic_projection(
        -half_width, half_width, -half_height, half_height, -1, 10);
    draw_frame.view = m4_make_scale(v3(1, 1, 1));
    draw_frame.view = m4_mul(
        draw_frame.view, m4_make_translation(v3(game.camera.position.x,
                                                game.camera.position.y, 0)));

    world_frame.world_mouse_pos = screen_to_world();

    Vector2 player_input = v2(0, 0);
    if (is_key_down(KEY_ARROW_UP) || is_key_down((s32)'W'))
    {
      player_input.y += 1;
    }

    if (is_key_down(KEY_ARROW_DOWN) ||
        is_key_down((s32)'S'))
    {
      player_input.y -= 1;
    }

    if (is_key_down(KEY_ARROW_RIGHT) ||
        is_key_down((s32)'D'))
    {
      player_input.x += 1;
    }

    if (is_key_down(KEY_ARROW_LEFT) ||
        is_key_down((s32)'A'))
    {
      player_input.x -= 1;
    }

    for (u64 i = 0; i < input_frame.number_of_events; i++)
    {
      Input_Event e = input_frame.events[i];

      switch (e.kind)
      {
      case INPUT_EVENT_SCROLL:
        if (e.yscroll != 0.0)
        {
          // Swap weapons
          s32 offhand = game.player.offhand_weapon_index;
          game.player.offhand_weapon_index = game.player.equipped_weapon_index;
          game.player.equipped_weapon_index = offhand;
        }
        break;
      default:
        break;
      }
    }

    player_input = v2_normalize(player_input);
    float dodge_timer = 0.5f;
    if (is_key_just_pressed(KEY_SPACEBAR) &&
        game.player.dodge_roll_cooldown_timer == 0)
    {
      Vector2 dash_direction = player_input;
      if (player_input.x == 0.0 && player_input.y == 0.0)
      {
        dash_direction = game.player.flip_x ? v2(1, 0) : v2(-1, 0);
      }

      game.player.dodge_direction = dash_direction;
      game.player.dodge_roll_cooldown_timer = dodge_timer + 0.24f;
      game.player.dodge_roll_timer = dodge_timer;
    }

    float room_left_x = -(ROOM_SIZE_X / 2.0);
    float room_left_y = -(ROOM_SIZE_Y / 2.0);

    float room_right_x = (ROOM_SIZE_X / 2.0) - SPRITE_PIXEL_SIZE;
    float room_right_y = (ROOM_SIZE_Y / 2.0) - 6;

    if (game.doors_locked && growing_array_get_valid_count(game.room_enemies) == 0)
    {
      game.doors_locked = false;
      game.show_reward = true;

      for (int i = 0; i < growing_array_get_valid_count(game.doors); i++)
      {
        {
          Door *door = &game.doors[i];
          door->reward_item = get_random_door_reward_type();
        }
      }

      if (game.player.health <= 0)
      {
        game.player.active = false;
      }

      game.player.flip_x = world_frame.world_mouse_pos.x <
                           game.player.position.x + SPRITE_PIXEL_SIZE * 0.5f;
      Vector2 player_velocity =
          v2_mulf(player_input, game.player.speed * (float)delta_t);
      Vector2 center_pos =
          v2_add(game.player.position,
                 v2(SPRITE_PIXEL_SIZE * 0.5f, SPRITE_PIXEL_SIZE * 0.5f));
      Vector2 potential_center_pos_x =
          v2_add(center_pos, v2(player_velocity.x, 0));
      Vector2 potential_center_pos_y =
          v2_add(center_pos, v2(0, player_velocity.y));
      Vector2 potential_pos_x =
          v2_add(game.player.position, v2(player_velocity.x, 0));
      Vector2 potential_pos_y =
          v2_add(game.player.position, v2(0, player_velocity.y));

      bool can_move_x = true;
      bool can_move_y = true;

      // timers
      update_entity_timers(&game.player, (float)delta_t);

      if (game.player.dodge_roll_timer > 0)
      {
        float t = 1.0 - (game.player.dodge_roll_timer / dodge_timer);
        game.player.dodge_velocity.x = (float)lerpf(
            (double)game.player.dodge_direction.x * DODGE_VELOCITY, 0, t);
        game.player.dodge_velocity.y = (float)lerpf(
            (double)game.player.dodge_direction.y * DODGE_VELOCITY, 0, t);
        potential_pos_x.x = game.player.position.x +
                            game.player.dodge_velocity.x * (float)delta_t;
        potential_pos_y.y = game.player.position.y +
                            game.player.dodge_velocity.y * (float)delta_t;
      }

      if (game.player.knockback_timer > 0)
      {
        float t = game.player.knockback_timer / ENEMY_KNOCKBACK_TIME;
        game.player.knockback_velocity.x =
            (float)lerpf((double)game.player.knockback_direction.x *
                             PLAYER_KNOCKBACK_VELOCITY,
                         0, 1.0 - t);
        game.player.knockback_velocity.y =
            (float)lerpf((double)game.player.knockback_direction.y *
                             PLAYER_KNOCKBACK_VELOCITY,
                         0, 1.0 - t);
        potential_pos_x.x = game.player.position.x +
                            game.player.knockback_velocity.x * (float)delta_t;
        potential_pos_y.y = game.player.position.y +
                            game.player.knockback_velocity.y * (float)delta_t;
      }

      if (game.doors_locked)
      {
        for (int i = 0; i < growing_array_get_valid_count(game.doors); i++)
        {
          Door door = game.doors[i];
          if (rect_circle_collision(
                  v4((s32)door.position.x, (s32)door.position.y, 12, 12),
                  potential_center_pos_x, game.player.collision_radius))
          {
            can_move_x = false;
          }

          if (rect_circle_collision(
                  v4((s32)door.position.x, (s32)door.position.y, 12, 12),
                  potential_center_pos_y, game.player.collision_radius))
          {
            can_move_y = false;
          }

          if (!can_move_x && !can_move_y)
          {
            break;
          }
        }
      }
      else
      {
        for (int i = 0; i < growing_array_get_valid_count(game.doors); i++)
        {
          Door door = game.doors[i];
          if (rect_circle_collision(
                  v4((s32)door.position.x, (s32)door.position.y, 12, 12),
                  center_pos, game.player.collision_radius))
          {
            generate_room(&game);
            can_move_x = false;
            can_move_y = false;
            break;
          }
        }
      }

      for (int i = 0; i < growing_array_get_valid_count(game.walls); i++)
      {
        Vector4 wall = game.walls[i];
        if (rect_circle_collision(wall, potential_center_pos_x,
                                  game.player.collision_radius))
        {
          can_move_x = false;
        }

        if (rect_circle_collision(wall, potential_center_pos_y,
                                  game.player.collision_radius))
        {
          can_move_y = false;
        }

        if (!can_move_x && !can_move_y)
        {
          break;
        }
      }

      Vector2 previous_pos = game.player.position;

      if (game.player.active)
      {
        if (can_move_x)
        {
          game.player.position.x = potential_pos_x.x;
        }

        if (can_move_y)
        {
          game.player.position.y = potential_pos_y.y;
        }
      }

      if (game.show_reward)
      {
        Vector2 image_size = get_image_size(sprites.rewards);
        Matrix4 xform = m4_scalar(1.0);
        xform = m4_translate(
            xform, v3(-SPRITE_PIXEL_SIZE, -SPRITE_PIXEL_SIZE * 0.5f, 0.0));
        xform = m4_translate(xform, v3(0.0, SPRITE_PIXEL_SIZE * 5, 0.0));
        {
          Draw_Quad *quad = draw_image_xform(
              sprites.rewards, xform, v2(SPRITE_PIXEL_SIZE, SPRITE_PIXEL_SIZE),
              COLOR_WHITE);
          quad->uv = get_uv_coords(image_size, v2(0, 0), SPRITE_PIXEL_SIZE);
        }

        xform = m4_translate(xform, v3(0.0, SPRITE_PIXEL_SIZE * 0.25f, 0.0));

        switch (game.current_room_reward.type)
        {
        case WEAPON:
        {
          Vector2 weapon_image_size = get_image_size(sprites.weapons);
          Draw_Quad *quad = draw_image_xform(
              sprites.weapons, xform,
              v2(WEAPON_SPRITE_SIZE, WEAPON_SPRITE_SIZE), COLOR_WHITE);
          quad->uv = get_uv_coords(
              weapon_image_size,
              v2((s32)game.current_room_reward.data.weapon_db_index, 0),
              WEAPON_SPRITE_SIZE);
          break;
        }
        default:
        {
          Draw_Quad *quad = draw_image_xform(
              sprites.rewards, xform, v2(SPRITE_PIXEL_SIZE, SPRITE_PIXEL_SIZE),
              COLOR_WHITE);
          quad->uv = get_uv_coords(image_size,
                                   v2((s32)game.current_room_reward.type, 0),
                                   SPRITE_PIXEL_SIZE);
          break;
        }
        }

        Vector2 reward_position = get_matrix_position(xform);
        ;
        Vector2 center_position =
            v2_add(game.player.position,
                   v2(SPRITE_PIXEL_SIZE * 0.5f, SPRITE_PIXEL_SIZE * 0.5f));
        if (rect_circle_collision(
                v4((s32)reward_position.x, (s32)reward_position.y,
                   SPRITE_PIXEL_SIZE, SPRITE_PIXEL_SIZE),
                center_position, game.player.collision_radius))
        {

          if (is_key_down((s32)'E'))
          {
            game.show_reward = false;

            switch (game.current_room_reward.type)
            {
            case WEAPON:
              if (game.player.offhand_weapon_index != 0)
              {
                // drop current weapon
              }
              else if (game.player.equipped_weapon_index != 0)
              {
                game.player.offhand_weapon_index =
                    game.player.equipped_weapon_index;
              }
              game.player.equipped_weapon_index =
                  game.current_room_reward.data.weapon_db_index;
              break;
            default:
            }
          }
        }
      }

      if (game.player.dodge_roll_timer > 0)
      {
        game.player.animation = ROLLING;
      }
      else if (player_input.x != 0 || player_input.y != 0)
      {
        game.player.animation = WALK;
      }
      else
      {
        game.player.animation = IDLE;
      }
      push_z_layer(10);
      update_player_animation(&game.player, delta_t);
      update_weapon_logic(&game, player_velocity, delta_t);

      for (int i = growing_array_get_valid_count(game.room_enemies); i >= 0;
           i--)
      {
        Entity *enemy = &game.room_enemies[i];

        update_entity(enemy, &game, delta_t);

        if (!enemy->active)
        {
          growing_array_ordered_remove_by_index((void **)game.room_enemies, i);
        }
      }

      Matrix4 walls_xform = m4_scalar(1.0);
      Vector2 walls_size = get_image_size(sprites.walls);
      walls_xform = m4_translate(
          walls_xform, v3(-walls_size.x * 0.5f, -walls_size.y * 0.5f, 0.0));
      push_z_layer(-1);
      draw_image_xform(sprites.walls, walls_xform, walls_size, COLOR_WHITE);

      Vector2 door_size = get_image_size(sprites.door);
      for (int i = 0; i < growing_array_get_valid_count(game.doors); i++)
      {

        Door door = game.doors[i];
        Matrix4 door_xform = m4_translate(
            m4_scalar(1.0), v3((s32)door.position.x, (s32)door.position.y, 0));
        if (game.doors_locked)
        {
          draw_image_xform(sprites.door, door_xform, door_size, COLOR_WHITE);
        }
        else if (door.reward_item != NIL)
        {
          door_xform =
              m4_translate(door_xform, v3(-2.5f, SPRITE_PIXEL_SIZE, 0));
          Vector2 image_size = get_image_size(sprites.rewards);
          Draw_Quad *quad = draw_image_xform(
              sprites.rewards, door_xform,
              v2(SPRITE_PIXEL_SIZE, SPRITE_PIXEL_SIZE), COLOR_WHITE);
          quad->uv = get_uv_coords(image_size, v2((s32)door.reward_item, 0),
                                   SPRITE_PIXEL_SIZE);
        }
      }

      pop_z_layer();
      if (game.player.active)
      {
        Matrix4 player_xform = render_player(&game.player, sprites.player);
        render_weapons(&game.player, player_xform, sprites.weapons, delta_t);
      }

      for (int i = 0; i < growing_array_get_valid_count(game.room_enemies);
           i++)
      {
        Entity enemy = game.room_enemies[i];
        render_entity(&enemy);
      }

      update_and_draw_projectiles(sprites.projectiles, &game, delta_t);
      update_and_draw_particles(sprites.particles, game.particles, delta_t);

      if (is_key_just_released((s32)'E'))
      {
        draw_hitboxes = !draw_hitboxes;
      }

      // foreach(wall : game.walls) {
      // 	draw_rect(v2(wall.x, wall.y), v2(wall.z, wall.w), v4(1, 0, 0,
      // 1));
      // }

      // foreach(wall : game.doors) {
      // 	draw_rect(v2(wall.x, wall.y), v2(wall.w, wall.z), v4(0, 0, 1,
      // 1));
      // }

      Vector2 cursor_position =
          v2_add(world_frame.world_mouse_pos,
                 v2(-SPRITE_PIXEL_SIZE * 0.5f, -SPRITE_PIXEL_SIZE * 0.5f));
      draw_image(sprites.cursor, cursor_position,
                 v2(SPRITE_PIXEL_SIZE, SPRITE_PIXEL_SIZE), COLOR_WHITE);

      // UI rendering
      draw_frame.projection = m4_make_orthographic_projection(
          window.pixel_width * -0.5f, window.pixel_width * 0.5f,
          window.pixel_height * -0.5f, window.pixel_height * 0.5f, -1, 10);
      draw_frame.view = m4_make_scale(v3(1, 1, 1));
      float ui_scalar = 5.0;
      {

        Vector2 sprite_size = get_image_size(sprites.health_bar);
        // HEALTH BAR
        Matrix4 xform = m4_make_scale(v3(1, 1, 1));
        Vector3 start_pos =
            v3(window.pixel_width * -0.5f + 15,
               (window.pixel_height * 0.5f) - sprite_size.y * ui_scalar - 15, 0);
        xform = m4_translate(xform, start_pos);
        Matrix4 sprite_xform = m4_scale(xform, v3(ui_scalar, ui_scalar, 1));
        // Calculate red section
        Matrix4 bar_xform = m4_translate(xform, v3(3, 3, 0));
        Vector2 bar_max_size =
            v2_add(get_image_size(sprites.health_bar), v2(-6, -6));
        Vector2 bar_size_after_health_percentage = v2_mul(
            bar_max_size,
            v2((float)game.player.health / (float)game.player.max_health, 1));
        // Draw bar
        draw_rect_xform(bar_xform, bar_size_after_health_percentage,
                        v4(1, 0, 0, 1));
        draw_image_xform(sprites.health_bar, sprite_xform, sprite_size,
                         COLOR_WHITE);

        // Draw Text
        string text = STR("Health %.1/%.1");
        string formatted = sprint(get_temporary_allocator(), text,
                                  game.player.health, game.player.max_health);
        s32 font_height = 24;
        Gfx_Text_Metrics metrics =
            measure_text(game.font, formatted, font_height, v2(1, 1));
        Vector2 justified = v2(start_pos.x, start_pos.y);
        justified = v2_add(justified, v2(sprite_size.x * ui_scalar * 0.5f -
                                             metrics.visual_size.x * 0.5f,
                                         sprite_size.y * ui_scalar * 0.5f -
                                             metrics.visual_size.y * 0.5f));
        draw_text(game.font, formatted, font_height, justified, v2(1, 1),
                  COLOR_WHITE);
      }

      os_update();
      gfx_update();
    }
    return 0;
  }
}