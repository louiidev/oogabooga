module game;

import std::io;
import engine;
import utils;
import entity;
import std::math;
import std::collections;
import particles;
import weapons;
import collisions;

def Vector2 = engine::Vector2;
def Vector3 = engine::Vector3;
def Matrix4 = engine::Matrix4;
def m4_scale = engine::m4_scale;

const Vector2 ROOM_SIZE = {{ 464, 246 }} ;
const Vector3 DOOR_ONE_POS = {{ 178, 258, 0 }};
const Vector3 DOOR_TWO_POS = {{ 226, 258, 0 }};
const Vector3 DOOR_THREE_POS = {{ 274, 258, 0 }};
const Vector2 SPAWN_POS = {{ 0, -120 }};
const float CAMERA_SPEED = 10;
const float CAMERA_SHAKE_DECAY = 0.8f;
const float SHAKE_POWER = 2f;

const float DODGE_VELOCITY = 350;
const float DODGE_TIME = 0.5f;
const float PLAYER_KNOCKBACK_VELOCITY = 150;


enum RelicType {
	RING,
	MAX_RELIC,
}



enum RewardType {
	NIL,
	RELIC,
	GOLD,
	WEAPON,
	HEALTH_POTION,
	STAT_UPGRADE,
	RANDOM,
}

// percentage upgrade
union StatUpgrade {
	float health;
	float speed;
	float fire_rate;
	float dash_cooldown;
}

union PickupData {
		int weapon_db_index;
		StatUpgrade stat_upgrade;
		int gold_amount;
		RelicType relic_type;
		int health_amount;
	}

struct Pickup {
	RewardType type;
	PickupData data; 
}


struct Game {
	List(<entity::Entity>) room_enemies;
    Entity player;
    engine::Gfx_Font *font;
	List(<particles::SpriteParticle>) particles;
	List(<particles::SpriteParticle>) projectiles;
	List(<collisions::Rect>) walls;
	Door[3] doors;
	Weapon[weapons::WEAPONS_COUNT] weapons_db;
	Camera camera;
	bool doors_locked;
	bool show_reward;
	Pickup current_room_reward;
}


struct Door {
	Vector2 position;
	RewardType reward_item;
}

fn RewardType get_random_door_reward_type() {
	return (RewardType)engine::get_random_int_in_range(1, (long)RewardType.RANDOM);
}

fn RewardType get_random_pickup_reward_type() {
	return (RewardType)engine::get_random_int_in_range(1, (long)RewardType.RANDOM - 1);
}

fn Pickup get_pickup_from_reward(RewardType type) {
	Pickup pickup;
	pickup.type = type;
	switch(type) {
		case RELIC:
			pickup.data = PickupData { .relic_type = RING };
		case GOLD:
			pickup.data = PickupData { .gold_amount = (int)engine::get_random_int_in_range(5, 15) };
		case WEAPON:
			pickup.data = PickupData { .weapon_db_index = (int)engine::get_random_int_in_range(1, weapons::WEAPONS_COUNT) };
		case HEALTH_POTION:
			pickup.data = PickupData { .health_amount = 1 };
		case STAT_UPGRADE:
			pickup.data = PickupData { .stat_upgrade = StatUpgrade { .health = 1 } };
		default:
			unreachable();
	}


	return pickup;
}

macro @create_bat() {
	Entity ent;
	ent.new();
	ent.attack_timer = 3f;
	ent.current_animation_frame = 0;
	ent.idle_animation_frame_start_x = 0;
    ent.idle_animation_count = 4;
    ent.idle_animation_play_time = 0.1f;
	ent.speed = 1.3f;
    ent.entity_type = EntType.BAT;
	ent.sprite_cell_count_x = 4;
	ent.sprite_cell_count_y = 4;
	ent.max_health = 2;
	ent.health = 2;
	ent.position = @v2( 
		engine::get_random_float32_in_range(-ROOM_SIZE.x * 0.5f, ROOM_SIZE.x * 0.5f),
		engine::get_random_float32_in_range(100, ROOM_SIZE.y * 0.5f)
	);

	return ent;
}

macro @create_skull() {
	Entity ent;
	ent.new();
	ent.attack_timer = 3f;
	ent.current_animation_frame = 0;
	ent.idle_animation_frame_start_x = 0;
	ent.idle_animation_frame_start_y = 1;
    ent.idle_animation_count = 0;
    ent.idle_animation_play_time = 0.1f;
	ent.speed = 0.3f;
    ent.entity_type = EntType.SKULL;
	ent.max_health = 2;
	ent.strength = 2;
	ent.health = 2;
	ent.position = @v2( 
		engine::get_random_float32_in_range(-ROOM_SIZE.x * 0.5f, ROOM_SIZE.x * 0.5f),
		engine::get_random_float32_in_range(0, ROOM_SIZE.y * 0.5f)
	);

	return ent;
}


def is_key_down = engine::is_key_down;
def is_key_just_released = engine::is_key_just_released;
def InputKeyCode = engine::InputKeyCode;

def Entity = entity::Entity;


struct Camera {
	Vector2 position;
	float shake_amount;
}


fn void Camera.update(Camera* self, Vector2 target, double delta_t) {
	utils::animate_v2_to_target(&self.position, target, delta_t, CAMERA_SPEED);
	self.shake_amount = $$max(self.shake_amount - CAMERA_SHAKE_DECAY * (float)delta_t, 0f);
	float amount = $$pow(self.shake_amount, SHAKE_POWER);
    // rotation = max_roll * amount * rand_range(-1, 1)
    self.position.x+= amount * engine::get_random_float32_in_range(-1, 1);
    self.position.y+= amount * engine::get_random_float32_in_range(-1, 1);
}

fn void Camera.shake(Camera* self, float amount) {
	if (amount > self.shake_amount) {
		self.shake_amount = amount;
	}
}


struct WorldFrame {
	Vector2 world_mouse_pos;
}

def GfxImage = engine::GfxImage;
struct Sprites {
	GfxImage *player;
	GfxImage *weapons;
	GfxImage *walls;
	GfxImage *particles;
	GfxImage *enemies;
	GfxImage *projectiles;
	GfxImage *cursor;
	GfxImage *health_bar;
	GfxImage *door;
	GfxImage *rewards;
}

struct Cbuffer {
	Vector2 mouse_pos_screen; // We use this to make a light around the mouse cursor
	Vector2 window_size;
}

WorldFrame world_frame = {};

Sprites sprites = {};

bool draw_hitboxes = false;


fn int main(String[] args)
{

	engine::oogabooga_init(5 * 1024 * 1024);
	
	CString source;
	bool ok = engine::os_read_entire_file_s(@str("./shaders/shader.hlsl"), &source, engine::get_heap_allocator());
	assert(ok, "Could not read ./shaders/shader.hlsl");

	engine::shader_recompile_with_extension(source, Cbuffer.sizeof);
	engine::dealloc_string(engine::get_heap_allocator(), source);

	ulong b = 0x222034ff;
	engine::window.clear_color = engine::hex_to_rgba(b);
	// Vector4 vec4 = {0.1f, 0.1f, 0.1f, 1};
	engine::window.scaled_width = 1280;
	engine::window.width = 1280;
    engine::window.scaled_height = 800;
    engine::window.height = 800;
    engine::window.x = 100;
    engine::window.y = 100;
	engine::window.title = @str("bullet hell roguelite");
	engine::seed_for_random = engine::os_get_current_cycle_count();
	Game game = { .doors_locked = true };

	
	sprites.weapons = engine::load_image_from_disk(@str("./assets/weapons.png"), engine::get_heap_allocator());
    sprites.player = engine::load_image_from_disk(@str("./assets/player.png"), engine::get_heap_allocator());
    sprites.walls = engine::load_image_from_disk(@str("./assets/walls.png"), engine::get_heap_allocator());
    sprites.particles = engine::load_image_from_disk(@str("./assets/particles.png"), engine::get_heap_allocator());
    sprites.enemies = engine::load_image_from_disk(@str("./assets/enemies.png"), engine::get_heap_allocator());
    sprites.projectiles = engine::load_image_from_disk(@str("./assets/projectiles.png"), engine::get_heap_allocator());
    sprites.cursor = engine::load_image_from_disk(@str("./assets/cursor.png"), engine::get_heap_allocator());
    sprites.health_bar = engine::load_image_from_disk(@str("./assets/healthbar.png"), engine::get_heap_allocator());
    sprites.door = engine::load_image_from_disk(@str("./assets/door.png"), engine::get_heap_allocator());
    sprites.rewards = engine::load_image_from_disk(@str("./assets/rewards.png"), engine::get_heap_allocator());

	game.font = engine::load_font_from_disk(@str("./assets/m6x11.ttf"), engine::get_heap_allocator());

	// engine::os_show_mouse_pointer(false);
	game.player.new();
	game.player.position = SPAWN_POS;
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

	game.current_room_reward = get_pickup_from_reward(RewardType.WEAPON);

	weapons::init_weapons_db(&game);

	// left
	game.walls.push({ -240, -270 / 2, 12, 270 });
	// right
	game.walls.push({ 240 - 12, -270 / 2, 12, 270 });
	// bottom
	game.walls.push({ -240, -270 / 2, 480, 12 });
	// top
	int y_pos = 270 / 2 - 12;
	game.walls.push({ -240, y_pos, (int)DOOR_ONE_POS.x, 12 });
	int start_x_one = -240 + (int)DOOR_ONE_POS.x + 12;
	int start_x_two = -240 + (int)DOOR_TWO_POS.x + 12;
	int start_x_three = -240 + (int)DOOR_THREE_POS.x + 12;
	game.walls.push({ start_x_one, y_pos, (int)DOOR_TWO_POS.x - (int)DOOR_ONE_POS.x - 12, 12 });
	game.walls.push({ start_x_two, y_pos, (int)DOOR_THREE_POS.x - (int)DOOR_TWO_POS.x - 12, 12 });
	game.walls.push({ start_x_three, y_pos, 480 - (int)DOOR_THREE_POS.x + 12, 12 });

	// add doors
	game.doors[0] = (Door { .position = @v2(start_x_one - 12, y_pos), .reward_item = RewardType.NIL });
	game.doors[1] = (Door { .position = @v2(start_x_two - 12, y_pos), .reward_item = RewardType.NIL });
	game.doors[2] = (Door { .position = @v2(start_x_three - 12, y_pos), .reward_item = RewardType.NIL });
	

	generate_room(&game);

	double last_time = engine::os_get_current_time_in_seconds();

	int target_render_width = 320;
	float zoom = (float)engine::window.width / (float)target_render_width;
	float scaled_render_height = (float)engine::window.height / zoom;

	float half_width = target_render_width * 0.5f;
	float half_height = scaled_render_height * 0.5f;

	float fps_limit = 144;
    float min_frametime = 1.0 / fps_limit;


	Cbuffer cbuffer;

	

 	while (!engine::window.should_close)
    {
		double now = engine::os_get_current_time_in_seconds();
        double delta_t = now - last_time;
		

		if (delta_t < min_frametime)
        {
            engine::os_high_precision_sleep((min_frametime - delta_t) * 1000.0);
            now = engine::os_get_current_time_in_seconds();
            delta_t = now - last_time;
        }

		last_time = now;

		engine::reset_temporary_storage();
		engine::draw_frame.cbuffer = &cbuffer;
		if (game.player.active) {
			game.camera.update(game.player.position, delta_t);
		}
		engine::draw_frame.enable_z_sorting = true;
		engine::draw_frame.projection = engine::m4_make_orthographic_projection(-half_width, half_width, -half_height, half_height, -1, 10);
		engine::draw_frame.view = engine::m4_make_scale(@v3(1, 1, 1));
		engine::draw_frame.view = engine::m4_mul(engine::draw_frame.view, engine::m4_make_translation(@v3(game.camera.position.x, game.camera.position.y, 0)));


		world_frame.world_mouse_pos = utils::screen_to_world();
			
		Vector2 player_input = @v2(0, 0);
		if (is_key_down(InputKeyCode.KEY_ARROW_UP.value) || is_key_down((int)'W'))
		{
			player_input.y += 1;

		}

		if (is_key_down(InputKeyCode.KEY_ARROW_DOWN.value) || is_key_down((int)'S'))
		{
			player_input.y -= 1;

		}

		if (is_key_down(InputKeyCode.KEY_ARROW_RIGHT.value) || is_key_down((int)'D'))
		{
			player_input.x += 1;

		}

		if (is_key_down(InputKeyCode.KEY_ARROW_LEFT.value) || is_key_down((int)'A'))
		{
			player_input.x -= 1;
		}

		player_input = engine::v2_normalize(player_input);
		float dodge_timer = 0.5f;
		if (engine::is_key_just_pressed(InputKeyCode.KEY_SPACEBAR.value) && game.player.dodge_roll_cooldown_timer == 0) {
			Vector2 dash_direction = player_input;
			if (player_input.x == 0.0 && player_input.y == 0.0) {
				dash_direction = game.player.flip_x ? Vector2 {{ 1, 0 }} : Vector2 {{ -1, 0 }};
			}

			game.player.dodge_direction = dash_direction;
			game.player.dodge_roll_cooldown_timer = dodge_timer + 0.24f;
    		game.player.dodge_roll_timer = dodge_timer;
		}

		
		float room_left_x = -(ROOM_SIZE.x / 2.0);
		float room_left_y = -(ROOM_SIZE.y / 2.0);

		float room_right_x = (ROOM_SIZE.x / 2.0) - 16;
		float room_right_y = (ROOM_SIZE.y / 2.0) - 6;

		if (game.doors_locked && game.room_enemies.len() == 0) {
			game.doors_locked = false;
			game.show_reward = true;
			foreach (&door : game.doors) {
				door.reward_item = get_random_door_reward_type();
			}
		}
		
		if (game.player.health <= 0) {
			game.player.active = false;
		}

		game.player.flip_x = world_frame.world_mouse_pos.x < game.player.position.x + SPRITE_PIXEL_SIZE * 0.5f;
		Vector2 player_velocity = engine::v2_mulf(player_input, game.player.speed * (float)delta_t);
		Vector2 center_pos = game.player.position.add(@v2(SPRITE_PIXEL_SIZE * 0.5f, SPRITE_PIXEL_SIZE * 0.5f));
		Vector2 potential_center_pos_x = center_pos.add(@v2(player_velocity.x, 0));
		Vector2 potential_center_pos_y = center_pos.add(@v2(0, player_velocity.y));
		Vector2 potential_pos_x = game.player.position.add(@v2(player_velocity.x, 0));
		Vector2 potential_pos_y = game.player.position.add(@v2(0, player_velocity.y));


		bool can_move_x = true;
		bool can_move_y = true;

		// timers
    	game.player.update_timers((float)delta_t);


		if (game.player.dodge_roll_timer > 0) {
			float t = 1.0f - (game.player.dodge_roll_timer / dodge_timer);
			game.player.dodge_velocity.x = (float)engine::lerpf((double)game.player.dodge_direction.x * DODGE_VELOCITY, 0, t);
			game.player.dodge_velocity.y = (float)engine::lerpf((double)game.player.dodge_direction.y * DODGE_VELOCITY, 0, t);
			potential_pos_x.x = game.player.position.x + game.player.dodge_velocity.x * (float)delta_t;
			potential_pos_y.y = game.player.position.y + game.player.dodge_velocity.y * (float)delta_t;

		}

		if (game.player.knockback_timer > 0) {
			float t = game.player.knockback_timer / entity::ENEMY_KNOCKBACK_TIME;
			game.player.knockback_velocity.x = (float)engine::lerpf((double)game.player.knockback_direction.x * PLAYER_KNOCKBACK_VELOCITY, 0, 1.0 - t);
			game.player.knockback_velocity.y = (float)engine::lerpf((double)game.player.knockback_direction.y * PLAYER_KNOCKBACK_VELOCITY, 0, 1.0 - t);
			potential_pos_x.x = game.player.position.x + game.player.knockback_velocity.x * (float)delta_t;
			potential_pos_y.y = game.player.position.y + game.player.knockback_velocity.y * (float)delta_t;
		}



		if (game.doors_locked) {
			foreach(door : game.doors) {
				if (collisions::rect_circle_collision({ (int)door.position.x, (int)door.position.y, 12, 12 }, potential_center_pos_x, game.player.collision_radius)) {
					can_move_x = false;
				}
				
				if (collisions::rect_circle_collision({ (int)door.position.x, (int)door.position.y, 12, 12 }, potential_center_pos_y, game.player.collision_radius)) {
					can_move_y = false;
				}

				if (!can_move_x && !can_move_y) {
					break;
				}
			}
		} else {
			foreach(door : game.doors) {
				if (collisions::rect_circle_collision({ (int)door.position.x, (int)door.position.y, 12, 12 }, center_pos, game.player.collision_radius)) {
					generate_room(&game);
					can_move_x = false;
					can_move_y = false;
					break;
				}
				
				
			}
		}


		foreach(wall : game.walls) {
			if (collisions::rect_circle_collision(wall, potential_center_pos_x, game.player.collision_radius)) {
				can_move_x = false;
			}
			
			if (collisions::rect_circle_collision(wall, potential_center_pos_y, game.player.collision_radius)) {
				can_move_y = false;
			}

			if (!can_move_x && !can_move_y) {
				break;
			}
		}

		Vector2 previous_pos = game.player.position;

		if (game.player.active) {
			if (can_move_x) {
				game.player.position.x = potential_pos_x.x;
			}

			if (can_move_y) {
				game.player.position.y = potential_pos_y.y;
			}
		}


		if (game.show_reward) {
			Vector2 image_size = utils::get_image_size(sprites.rewards);
			Matrix4 xform = engine::m4_scalar(1.0f);
			xform = engine::m4_translate(xform, @v3(-SPRITE_PIXEL_SIZE, -SPRITE_PIXEL_SIZE * 0.5f, 0.0f));
			xform = engine::m4_translate(xform, @v3(0.0f, SPRITE_PIXEL_SIZE * 5, 0.0f));
			{
					engine::DrawQuad *quad = engine::draw_image_xform(sprites.rewards, xform, @v2(SPRITE_PIXEL_SIZE, SPRITE_PIXEL_SIZE), engine::COLOR_WHITE);
					quad.uv = utils::get_uv_coords(image_size, @v2(0, 0), SPRITE_PIXEL_SIZE);
			}
		
			xform = engine::m4_translate(xform, @v3(0.0f, SPRITE_PIXEL_SIZE * 0.25f, 0.0f));

			switch(game.current_room_reward.type) {
				case WEAPON:
					Vector2 weapon_image_size = utils::get_image_size(sprites.weapons);
					engine::DrawQuad *quad = engine::draw_image_xform(sprites.weapons, xform, @v2(WEAPON_SPRITE_SIZE, WEAPON_SPRITE_SIZE), engine::COLOR_WHITE);
					quad.uv = utils::get_uv_coords(weapon_image_size, @v2((int)game.current_room_reward.data.weapon_db_index, 0), WEAPON_SPRITE_SIZE);
				default:
					engine::DrawQuad *quad = engine::draw_image_xform(sprites.rewards, xform, @v2(SPRITE_PIXEL_SIZE, SPRITE_PIXEL_SIZE), engine::COLOR_WHITE);
					quad.uv = utils::get_uv_coords(image_size, @v2((int)game.current_room_reward.type, 0), SPRITE_PIXEL_SIZE);
			}

			Vector2 reward_position = xform.position();
			Vector2 center_position = game.player.position.add(@v2(SPRITE_PIXEL_SIZE * 0.5f, SPRITE_PIXEL_SIZE * 0.5f));
			if (collisions::rect_circle_collision({ (int)reward_position.x, (int)reward_position.y, SPRITE_PIXEL_SIZE, SPRITE_PIXEL_SIZE},center_position, game.player.collision_radius)) {


				if (engine::is_key_down((int)'E')) {
					game.show_reward = false;


					switch(game.current_room_reward.type) {
						case WEAPON:
							if (game.player.offhand_weapon_index != 0) {
								// drop current weapon
							}
							game.player.offhand_weapon_index = game.player.equipped_weapon_index;
							game.player.equipped_weapon_index = game.current_room_reward.data.weapon_db_index;
							
						default:
							
					}

				}


			


			}
		}
		

		
		if (game.player.dodge_roll_timer > 0) {
			game.player.animation = EntAnimation.ROLLING;
		} else if (player_input.x != 0 || player_input.y != 0) {
			game.player.animation = EntAnimation.WALK;
		} else {
			game.player.animation = EntAnimation.IDLE;
		}
		engine::push_z_layer(10);
		entity::update_player_animation(&game.player, delta_t);
		entity::update_weapon_logic(&game, player_velocity, delta_t);


		foreach (&enemy : game.room_enemies)
    	{	   
			entity::update_entity(enemy, &game, delta_t);
		}

		game.room_enemies.remove_if(fn (p) => !p.active);


		Matrix4 walls_xform = engine::m4_scalar(1.0f);
		Vector2 walls_size = utils::get_image_size(sprites.walls);
		walls_xform = engine::m4_translate(walls_xform, @v3(-walls_size.x * 0.5f, -walls_size.y * 0.5f, 0.0f));
		engine::push_z_layer(-1);
		engine::draw_image_xform(sprites.walls, walls_xform, walls_size, engine::COLOR_WHITE);
		
		Vector2 door_size = utils::get_image_size(sprites.door);
		foreach(door : game.doors) {
			Matrix4 door_xform = engine::m4_translate(engine::m4_scalar(1.0f), @v3((int)door.position.x, (int)door.position.y, 0));
			if (game.doors_locked) {
				engine::draw_image_xform(sprites.door, door_xform, door_size, engine::COLOR_WHITE);
			} else if (door.reward_item != NIL) {
				door_xform = engine::m4_translate(door_xform, @v3(-2.5f, SPRITE_PIXEL_SIZE, 0));
				Vector2 image_size = utils::get_image_size(sprites.rewards);
				engine::DrawQuad *quad = engine::draw_image_xform(sprites.rewards, door_xform, @v2(SPRITE_PIXEL_SIZE, SPRITE_PIXEL_SIZE), engine::COLOR_WHITE);
				quad.uv = utils::get_uv_coords(image_size, @v2((int)door.reward_item, 0), SPRITE_PIXEL_SIZE);
			}
		}
	

		engine::pop_z_layer();
		if (game.player.active) {
			Matrix4 player_xform = entity::render_player(&game.player, sprites.player);
			entity::render_weapons(&game.player, player_xform, sprites.weapons, delta_t);
		}
		

		foreach (enemies : game.room_enemies)
    	{	   
			entity::render_entity(enemies);
		}
		

		particles::update_and_draw_projectiles(sprites.projectiles, &game, delta_t);
		particles::update_and_draw_particles(sprites.particles, &game.particles, delta_t);


		if (is_key_just_released((int)'E'))
		{
			draw_hitboxes = !draw_hitboxes;
			// io::printn("FPS: %.2f", 1.0 / delta_t);
			// io::printn("ms: %.2f", delta_t * 1000.0);
		}



		// foreach(wall : game.walls) {
		// 	engine::draw_rect(@v2(wall.x, wall.y), @v2(wall.z, wall.w), @v4(1, 0, 0, 1));
		// }

		// foreach(wall : game.doors) {
		// 	engine::draw_rect(@v2(wall.x, wall.y), @v2(wall.w, wall.z), @v4(0, 0, 1, 1));
		// }


		Vector2 cursor_position = world_frame.world_mouse_pos.add({{ -16 * 0.5f, -16 * 0.5f }});
		engine::draw_image(sprites.cursor, cursor_position, {{ 16, 16 }}, engine::COLOR_WHITE);


		// UI rendering
		engine::draw_frame.projection = engine::m4_make_orthographic_projection(window.pixel_width * -0.5f, window.pixel_width * 0.5f, window.pixel_height * -0.5f, window.pixel_height * 0.5f, -1, 10);
		engine::draw_frame.view = engine::m4_make_scale(@v3(1, 1, 1));
		float ui_scalar = 5.0f;
		{

			Vector2 sprite_size = utils::get_image_size(sprites.health_bar);
			// HEALTH BAR
			Matrix4 xform = @m4_identity();
			Vector2 start_pos = {{ (window.pixel_width * -0.5f) + 15, (window.pixel_height * 0.5f) - sprite_size.y * ui_scalar - 15 }};
			xform = xform.translate(start_pos);
			Matrix4 sprite_xform = m4_scale(xform, {{ ui_scalar, ui_scalar, 1 }});
			// Calculate red section 
			Matrix4 bar_xform = sprite_xform.translate(@v2(3, 3));
			Vector2 bar_max_size = utils::get_image_size(sprites.health_bar).add(@v2(-6, -6));
			Vector2 bar_size_after_health_percentage = engine::v2_mul(bar_max_size, @v2((float)game.player.health / (float)game.player.max_health, 1));
			// Draw bar
			engine::draw_rect_xform(bar_xform, bar_size_after_health_percentage, @v4(1, 0, 0, 1));
			engine::draw_image_xform(sprites.health_bar, sprite_xform, sprite_size, engine::COLOR_WHITE);
			
			// Draw Text
			CString text = @str("Health %i/%i");
			CString formatted = engine::sprints(engine::get_temporary_allocator(), text, game.player.health, game.player.max_health);
			int font_height = 24;
			engine::Gfx_Text_Metrics metrics = engine::measure_text(game.font, formatted, font_height, @v2(1, 1));
			Vector2 justified = start_pos;
			justified = engine::v2_add(justified, @v2(sprite_size.x * ui_scalar * 0.5f - metrics.visual_size.x * 0.5f, sprite_size.y * ui_scalar * 0.5f - metrics.visual_size.y * 0.5f));
			engine::draw_text(game.font, formatted, font_height, justified, @v2(1, 1), engine::COLOR_WHITE);

		}

		engine::os_update();
        engine::gfx_update();
	}
	return 0;
}



fn void generate_room(Game *game) {
	game.show_reward = false;
	game.doors_locked = true;
	game.player.position = SPAWN_POS;

	long number_of_enemies = engine::get_random_int_in_range(1, 2);
	for(int i = 0; i < number_of_enemies; i++) {
		long enemy_type = engine::get_random_int_in_range(1, (long)EntType.MAX_ENT_TYPE - 1);
		EntType type = (EntType)enemy_type;
		switch (type) {
			case BAT:
				game.room_enemies.push(@create_bat());
			case SKULL:
				game.room_enemies.push(@create_skull());
			default:
				unreachable();
		}
	}
}