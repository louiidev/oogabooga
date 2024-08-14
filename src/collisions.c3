module collisions;
import engine;
import std::io;
import entity;

// x, y is bottom left corner
def Rect = int[<4>];

def Vector2 = engine::Vector2;


fn bool ents_overlap(Entity *ent_a, Entity *ent_b, float ent_size) {
    Vector2 a_center_pos = ent_a.position.add(@v2(ent_size * 0.5f, ent_size * 0.5f)); 
    Vector2 b_center_pos = ent_b.position.add(@v2(ent_size * 0.5f, ent_size * 0.5f)); 
    return circles_overlap(a_center_pos, ent_a.collision_radius, b_center_pos, ent_b.collision_radius);
}


fn bool circles_overlap(engine::Vector2 center1, float radius1, engine::Vector2 center2, float radius2) {
    // Calculate the distance between the centers of the two circles
    float distance = center1.distance(center2);
    // Check if the distance is less than or equal to the sum of the radii
    if (distance <= (radius1 + radius2)) {
        return true;
    }

    return false;
}


// Rect min is the bottom left corner
fn bool rect_circle_collision(Rect rect, Vector2 circle_center, float radius) {
    float[<2>] rect_min = rect.xy;
    float[<2>] size = rect.zw;
    float dist_x = $$abs(circle_center.x - (rect_min.x + size.x / 2));
    float dist_y = $$abs(circle_center.y - (rect_min.y + size.y / 2));

    if (dist_x > (size.x / 2 + radius)) { return false; }
    if (dist_y > (size.y / 2 + radius)) { return false; }

    if (dist_x <= (size.x / 2)) { return true; }
    if (dist_y <= (size.y / 2)) { return true; }

    float dx = dist_x - size.x / 2;
    float dy = dist_y - size.y / 2;
    return (dx * dx + dy * dy <= (radius * radius));
}
