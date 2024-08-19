module weapons;

import engine;
import game;



const int WEAPONS_COUNT = 4;

struct Weapon {
    // int bullets;
    float fire_rate_seconds;
    // 0.0 accurate -> 1.0f not very accurate
	float accuracy;
    CString name;
    float damage_per_bullet;
    int min_bullets_per_shot;
    int max_bullets_per_shot;
    float velocity;
    float distance_limit;
}


// lets remove this???
enum Weapons {
	NIL,
    PISTOL,
    SHOTGUN,
    UZI,
}

fn void init_weapons_db(Game *game) {

    game.weapons_db[0] = {}; // empty value;
    game.weapons_db[1] = { .name = @str("Pistol"), .velocity = 300, .fire_rate_seconds = 0.3f, .damage_per_bullet = 7f, .accuracy = 0.15f, .distance_limit = 300 };
    game.weapons_db[2] = { .name = @str("Shotgun"), .velocity = 300, .fire_rate_seconds = 0.5f, .min_bullets_per_shot = 3, .max_bullets_per_shot = 7, .damage_per_bullet = 5f, .accuracy = 0.4f, .distance_limit = 100 };
    game.weapons_db[3] = { .name = @str("Uzi"), .velocity = 450, .fire_rate_seconds = 0.15f, .min_bullets_per_shot = 1, .max_bullets_per_shot = 3, .damage_per_bullet = 3.5f, .accuracy = 0.25f, .distance_limit = 200  };
}