bool circles_overlap(Vector2 center1, float radius1, Vector2 center2, float radius2) {
    // Calculate the distance between the centers of the two circles
    float distance = v2_length(v2_sub(center1, center2));
    // Check if the distance is less than or equal to the sum of the radii
    if (distance <= (radius1 + radius2)) {
        return true;
    }

    return false;
}

bool ents_overlap(Entity *ent_a, Entity *ent_b, float ent_size) {
    Vector2 a_center_pos = v2_add(ent_a->position, v2(ent_size * 0.5f, ent_size * 0.5f));
    Vector2 b_center_pos = v2_add(ent_b->position, v2(ent_size * 0.5f, ent_size * 0.5f));
    return circles_overlap(a_center_pos, ent_a->collision_radius, b_center_pos, ent_b->collision_radius);
}





// rect min is the bottom left corner
bool rect_circle_collision(Vector4 rect, Vector2 circle_center, float radius) {
    Vector2 rect_min = rect.xy;
    Vector2 size = rect.zw;
    float dist_x = abs(circle_center.x - (rect_min.x + size.x / 2));
    float dist_y = abs(circle_center.y - (rect_min.y + size.y / 2));

    if (dist_x > (size.x / 2 + radius)) { return false; }
    if (dist_y > (size.y / 2 + radius)) { return false; }

    if (dist_x <= (size.x / 2)) { return true; }
    if (dist_y <= (size.y / 2)) { return true; }

    float dx = dist_x - size.x / 2;
    float dy = dist_y - size.y / 2;
    return (dx * dx + dy * dy <= (radius * radius));
}


bool point_inside_rect(Vector4 rect, Vector2 p) {
  return rect.x >= rect.x && rect.x <= rect.x && rect.y >= rect.y && rect.y <= rect.y;
}
