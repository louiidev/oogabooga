module game;

import std::io;
import engine;
import utils;
import entity;
import std::math;
import std::collections;
import particles;
import weapons;

def Vector2 = engine::Vector2;
def Matrix4 = engine::Matrix4;

const Vector2 ROOM_SIZE = {{ 272, 156 }} ;
const float CAMERA_SPEED = 10;
const float CAMERA_SHAKE_DECAY = 0.8f;
const float SHAKE_POWER = 2f;

macro @create_bat() {
	Entity ent;
	ent.active = true;
	ent.attack_timer = 3f;
	ent.current_animation_frame = 0;
	ent.idle_animation_frame_start_x = 0;
    ent.idle_animation_count = 4;
    ent.idle_animation_play_time = 0.1f;
	ent.speed = 1.3f;
    ent.entity_type = EntType.BAT;
	ent.sprite_cell_count_x = 4;
	ent.sprite_cell_count_y = 4;
	ent.max_health = 20;
	ent.health = 20;
	ent.position = {{ 
		engine::get_random_float32_in_range(-ROOM_SIZE.x * 0.5f, ROOM_SIZE.x * 0.5f),
		engine::get_random_float32_in_range(-ROOM_SIZE.y * 0.5f, ROOM_SIZE.y * 0.5f)
	}};

	return ent;
}

macro @create_skull() {
	Entity ent;
	ent.active = true;
	ent.attack_timer = 3f;
	ent.current_animation_frame = 0;
	ent.idle_animation_frame_start_x = 0;
	ent.idle_animation_frame_start_y = 1;
    ent.idle_animation_count = 0;
    ent.idle_animation_play_time = 0.1f;
	ent.speed = 1.3f;
    ent.entity_type = EntType.SKULL;
	ent.max_health = 20;
	ent.health = 20;
	ent.position = {{ 
		engine::get_random_float32_in_range(-ROOM_SIZE.x * 0.5f, ROOM_SIZE.x * 0.5f),
		engine::get_random_float32_in_range(-ROOM_SIZE.y * 0.5f, ROOM_SIZE.y * 0.5f)
	}};

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

struct Game {
	List(<entity::Entity>) room_enemies;
    Entity player_entity;
    engine::GfxFont *font;
	List(<particles::Particle>) particles;
	List(<particles::Particle>) projectiles;
	Camera camera;
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

	ulong b = 0x0f101dff;
	engine::window.clear_color = engine::hex_to_rgba(b);
	// Vector4 vec4 = {0.1f, 0.1f, 0.1f, 1};
	engine::window.scaled_width = 1280;
	engine::window.width = 1280;
    engine::window.scaled_height = 800;
    engine::window.height = 800;
    engine::window.x = 100;
    engine::window.y = 100;
	engine::window.title = @str("Hello from c3");
	engine::seed_for_random = engine::os_get_current_cycle_count();
	Game game = {};
	
	sprites.weapons = engine::load_image_from_disk(@str("./assets/weapons.png"), engine::get_heap_allocator());
    sprites.player = engine::load_image_from_disk(@str("./assets/player.png"), engine::get_heap_allocator());
    sprites.walls = engine::load_image_from_disk(@str("./assets/walls.png"), engine::get_heap_allocator());
    sprites.particles = engine::load_image_from_disk(@str("./assets/particles.png"), engine::get_heap_allocator());
    sprites.enemies = engine::load_image_from_disk(@str("./assets/enemies.png"), engine::get_heap_allocator());
    sprites.projectiles = engine::load_image_from_disk(@str("./assets/projectiles.png"), engine::get_heap_allocator());
    sprites.cursor = engine::load_image_from_disk(@str("./assets/cursor.png"), engine::get_heap_allocator());


	// engine::os_show_mouse_pointer(false);

	game.player_entity.speed = 100;
	game.player_entity.equipped_weapon = weapons::Weapons.GUN;
	game.player_entity.walk_animation_count = 6;
	game.player_entity.walk_animation_frame_start = 1;
	game.player_entity.walk_animation_play_time = 0.08f;
	game.player_entity.hitbox_size = {{ 8, 8 }};
	game.player_entity.hitbox_offset = {{ 4, 4 }};
	game.player_entity.strength = 2;

	game.room_enemies.push(@create_skull());
	game.room_enemies.push(@create_skull());

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
		game.camera.update(game.player_entity.position, delta_t);
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


		
		float room_left_x = -(ROOM_SIZE.x / 2.0);
		float room_left_y = -(ROOM_SIZE.y / 2.0);

		float room_right_x = (ROOM_SIZE.x / 2.0) - 16;
		float room_right_y = (ROOM_SIZE.y / 2.0) - 6;

		player_input = engine::v2_normalize(player_input);
		

		game.player_entity.flip_x = world_frame.world_mouse_pos.x < game.player_entity.position.x + SPRITE_PIXEL_SIZE * 0.5f;
		Vector2 player_velocity = engine::v2_mulf(player_input, game.player_entity.speed * (float)delta_t);
		Vector2 potential_pos = game.player_entity.position.add(player_velocity);
		potential_pos.x = math::clamp(potential_pos.x, room_left_x, room_right_x);
		potential_pos.y = math::clamp(potential_pos.y, room_left_y, room_right_y);


		if ((game.player_entity.knockback_velocity.x != 0 || game.player_entity.knockback_velocity.y != 0) && game.player_entity.knockback_timer > 0) {
			game.player_entity.knockback_timer-= (float)delta_t;
			float t = game.player_entity.knockback_timer / entity::ENEMY_KNOCKBACK_TIME;
			game.player_entity.knockback_velocity.x = (float)engine::lerpf(game.player_entity.knockback_velocity.x, 0, 1.0 - t);
			game.player_entity.knockback_velocity.y = (float)engine::lerpf(game.player_entity.knockback_velocity.y, 0, 1.0 - t);
			game.player_entity.position.x += game.player_entity.knockback_velocity.x * (float)delta_t;
			game.player_entity.position.y += game.player_entity.knockback_velocity.y * (float)delta_t;
		} else {
			game.player_entity.position = potential_pos;
		}



		

		if (player_input.x != 0 || player_input.y != 0) {
			game.player_entity.animation = EntAnimation.WALK;
		} else {
			game.player_entity.animation = EntAnimation.IDLE;
		}

		entity::update_player_animation(&game.player_entity, delta_t);

		entity::update_weapon_logic(&game, player_velocity, delta_t);


		foreach (&enemy : game.room_enemies)
    	{	   
			entity::update_entity(enemy, &game, delta_t);
		}

		game.room_enemies.remove_if(fn (p) => !p.active);
		


		Matrix4 walls_xform = engine::m4_scalar(1.0f);
		Vector2 walls_size = utils::get_image_size(sprites.walls);
		walls_xform = engine::m4_translate(walls_xform, @v3(-walls_size.x * 0.5f, -walls_size.y * 0.5f, 0.0f));
		engine::draw_image_xform(sprites.walls, walls_xform, walls_size, engine::COLOR_WHITE);

		Matrix4 player_xform = entity::render_player(&game.player_entity, sprites.player);
		entity::render_weapons(&game.player_entity, player_xform, sprites.weapons, delta_t);

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


		Vector2 cursor_position = world_frame.world_mouse_pos.add({{ -16 * 0.5f, -16 * 0.5f }});
		engine::draw_image(sprites.cursor, cursor_position, {{ 16, 16 }}, engine::COLOR_WHITE);


		engine::os_update();
        engine::gfx_update();
	}
	return 0;
}
