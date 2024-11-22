
typedef enum { IDLE, WALK, ATTACK, ROLLING } EntAnimation;

typedef enum { PLAYER, BAT, SKULL, MAX_ENT_TYPE } EntType;

typedef struct Entity {
  bool active;
  bool flip_x;
  float health;
  float max_health;
  float speed;
  float weapon_angle;
  float current_weapon_angle_offset;
  bool flip_weapon;
  /* Player specific data, we will just set to -1 for enemy ents*/
  Vector2 position;

  int strength;

  int sprite_cell_count_x;
  int sprite_cell_count_y;

  int equipped_weapon_index;
  int offhand_weapon_index;
  float current_animation_timer;
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

  float attack_timer;
  float knockback_timer;
  Vector2 knockback_velocity;
  Vector2 knockback_direction;

  EntType entity_type;
  EntAnimation animation;

  // when player gets hurt, we give them i frames
  // or when they roll
  float invisible_timer;

  float dodge_roll_cooldown_timer;
  float dodge_roll_timer;
  float weapon_cooldown_timer;
  Vector2 dodge_velocity;
  Vector2 dodge_direction;
} Entity;

typedef struct {
  Vector2 world_mouse_pos;
} WorldFrame;




typedef enum { RING, MAX_RELIC } RelicType;

typedef enum {
  NIL,
  RELIC,
  GOLD,
  WEAPON,
  HEALTH_POTION,
  STAT_UPGRADE,
  RANDOM
} RewardType;

// percentage upgrade
typedef union {
  float health;
  float speed;
  float fire_rate;
  float dash_cooldown;
} StatUpgrade;

typedef union {
  s32 weapon_db_index;
  StatUpgrade stat_upgrade;
  s32 gold_amount;
  RelicType relic_type;
  s32 health_amount;
} PickupData;

typedef struct {
  RewardType type;
  PickupData data;
} Pickup;

typedef struct {
  Vector2 position;
  RewardType reward_item;
} Door;

typedef enum {
  MAIN_MENU,
  GAME_PLAY,
} GameState;

typedef struct {
  Vector2 position;
  float shake_amount;
} Camera;

typedef struct {

  // int bullets;
  float fire_rate_seconds;
  // 0.0 accurate -> 1.0 not very accurate
  float accuracy;
  string name;
  float damage_per_bullet;
  int min_bullets_per_shot;
  int max_bullets_per_shot;
  float velocity;
  float distance_limit;
} Weapon;


typedef struct SpriteParticle {
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

    bool player_projectile;
    float distance_limit;
    float current_distance;
    float damage;
} SpriteParticle;


#define WEAPONS_COUNT 4

typedef struct Game {
  Entity *room_enemies;
  Entity player;
  Gfx_Font *font;
  SpriteParticle *particles;   // list
  SpriteParticle *projectiles; // list
  Vector4 *walls;              // list
  Door doors[3];
  Weapon weapons_db[WEAPONS_COUNT];
  Camera camera;
  bool doors_locked;
  bool show_reward;
  Pickup current_room_reward;
  GameState current_state;
} Game;

typedef struct {
  Gfx_Image *player;
  Gfx_Image *weapons;
  Gfx_Image *walls;
  Gfx_Image *particles;
  Gfx_Image *enemies;
  Gfx_Image *projectiles;
  Gfx_Image *cursor;
  Gfx_Image *health_bar;
  Gfx_Image *door;
  Gfx_Image *rewards;
} Sprites;

Sprites sprites = {0};
