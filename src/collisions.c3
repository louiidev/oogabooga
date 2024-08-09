module collisions;
import engine;
import std::io;


def Vector2 = engine::Vector2;


fn bool circles_overlap(engine::Vector2 center1, float radius1, engine::Vector2 center2, float radius2) {
    // Calculate the distance between the centers of the two circles
    float distance = center1.distance(center2);
    // Check if the distance is less than or equal to the sum of the radii
    if (distance <= (radius1 + radius2)) {
        return true;
    }

    return false;
}