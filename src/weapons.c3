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
    game.weapons_db[1] = { .name = @str("Pistol"), .fire_rate_seconds = 0.3f, .min_bullets_per_shot = 1, .damage_per_bullet = 10f, .accuracy = 0.3f };
    game.weapons_db[2] = { .name = @str("Shotgun"), .fire_rate_seconds = 0.5f, .min_bullets_per_shot = 2, .max_bullets_per_shot = 3, .damage_per_bullet = 5f, };
    game.weapons_db[3] = { .name = @str("Uzi"), .fire_rate_seconds = 0.2f, .min_bullets_per_shot = 1, .max_bullets_per_shot = 2, .damage_per_bullet = 3.5f, };
}