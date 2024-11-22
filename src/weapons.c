



void init_weapons_db(Game *game) {

  game->weapons_db[0] = (Weapon){0}; // empty value;
  game->weapons_db[1] = (Weapon){.name = STR("Pistol"),
                         .velocity = 300,
                         .fire_rate_seconds = 0.3f,
                         .damage_per_bullet = 7,
                         .accuracy = 0.15f,
                         .distance_limit = 300};
  game->weapons_db[2] = (Weapon){.name = STR("Shotgun"),
                         .velocity = 300,
                         .fire_rate_seconds = 0.5f,
                         .min_bullets_per_shot = 3,
                         .max_bullets_per_shot = 7,
                         .damage_per_bullet = 5,
                         .accuracy = 0.4f,
                         .distance_limit = 100};
  game->weapons_db[3] = (Weapon){.name = STR("Uzi"),
                         .velocity = 450,
                         .fire_rate_seconds = 0.15f,
                         .min_bullets_per_shot = 1,
                         .max_bullets_per_shot = 3,
                         .damage_per_bullet = 3.5f,
                         .accuracy = 0.25f,
                         .distance_limit = 200};
}
