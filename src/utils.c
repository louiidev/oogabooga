

bool almost_equals(float a, float b, float epsilon) {
  return fabs((double)a - (double)b) <= (double)epsilon;
}

bool animate_f32_to_target(float *value, float target, float delta_t,
                           float rate) {
  *value += (target - *value) * (1 - pow(2.0f, -rate * delta_t));
  if (almost_equals(*value, target, 0.001f)) {
    *value = target;
    return true; // reached
  }
  return false;
}

void animate_v2_to_target(Vector2 *value, Vector2 target, double delta_t,
                          float rate) {
  animate_f32_to_target(&(value->x), target.x, (float)delta_t, rate);
  animate_f32_to_target(&(value->y), target.y, (float)delta_t, rate);
}

Vector2 get_image_size(Gfx_Image *image) {
  return v2(image->width, image->height);
}

Vector4 get_uv_coords(Vector2 image_size, Vector2 cell_index,
                      float sprite_pixel_size) {
  // Calculate the width and height of each cell in UV space
  float cell_width = sprite_pixel_size / image_size.x;
  float cell_height = sprite_pixel_size / image_size.y;

  Vector2 cell_count =
      v2(image_size.x / sprite_pixel_size, image_size.y / sprite_pixel_size);

  float u = (float)fmod(cell_index.x, cell_count.x) * cell_width;
  float v = 1.0f - ((float)fmod(cell_index.y, cell_count.y) + 1) * cell_height;

  return v4(u, v, u + cell_width, v + cell_height);
}

float calc_rotation_to_target(Vector2 a, Vector2 b) {
  float delta_x = a.x - b.x;
  float delta_y = a.y - b.y;
  float angle = atan2(delta_y, delta_x);
  return angle;
}


Vector2 screen_to_world() {
  float mouse_x = input_frame.mouse_x;
  float mouse_y = input_frame.mouse_y;
  Matrix4 proj = draw_frame.projection;
  Matrix4 view = draw_frame.view;

  // Normalize the mouse coordinates
  float ndc_x = (mouse_x / (window.width * 0.5f)) - 1.0f;
  float ndc_y = (mouse_y / (window.height * 0.5f)) - 1.0f;

  // Transform to world coordinates
  Vector4 world_pos = v4(ndc_x, ndc_y, 0, 1);
  world_pos = m4_transform(m4_inverse(proj), world_pos);
  world_pos = m4_transform(view, world_pos);
  // log("%f, %f", world_pos.x, world_pos.y);

  // Return as 2D vector
  return v2(world_pos.x, world_pos.y);
}

float rad_to_deg(float radians) { return radians * (180.0f / M_PI); }

float deg_to_rad(float deg) { return deg * (M_PI / 180.0f); }

Matrix4 flip_sprite_x(Matrix4 xform) {
  xform =
      m4_translate(xform, v3(SPRITE_PIXEL_SIZE / 2, SPRITE_PIXEL_SIZE / 2, 0));
  xform = m4_scale(xform, v3(-1, 1, 1));
  xform = m4_translate(xform,
                       v3(-SPRITE_PIXEL_SIZE / 2, -SPRITE_PIXEL_SIZE / 2, 0));

  return xform;
}

bool line_circle_collision(Vector2 p1, Vector2 p2, Vector2 circle_center,
                           float radius) {
  // Vector from p1 to p2
  Vector2 d = v2(p2.x - p1.x, p2.y - p1.y);

  // Vector from p1 to the circle center
  Vector2 f = v2(p1.x - circle_center.x, p1.y - circle_center.y);

  float a = d.x * d.x + d.y * d.y;
  float b = 2 * (f.x * d.x + f.y * d.y);
  float c = f.x * f.x + f.y * f.y - radius * radius;

  float discriminant = b * b - 4 * a * c;

  // If discriminant is negative, no real roots, the line does not intersect the
  // circle
  if (discriminant < 0) {
    return false;
  }

  discriminant = sqrt(discriminant);

  // Find the points of intersection, t1 and t2 are the parameter values
  float t1 = (-b - discriminant) / (2 * a);
  float t2 = (-b + discriminant) / (2 * a);

  // Check if the intersection points are within the segment
  if (t1 >= 0 && t1 <= 1) {
    return true;
  }
  if (t2 >= 0 && t2 <= 1) {
    return true;
  }

  return false;
}


Vector2 get_matrix_position(Matrix4 xform) {
    return v2(xform.m[0][3], xform.m[1][3]);
}


float v2_distance(Vector2 a, Vector2 b) {
    return v2_length(v2_sub(a, b));
}

#define DEFAULT_DISTANCE_LIMIT 300.0f
SpriteParticle new_projectile(bool player_projectile) {

    SpriteParticle p;
    p.active = true;
    p.distance_limit = DEFAULT_DISTANCE_LIMIT;
    p.player_projectile = player_projectile;
}
void camera_shake(Camera *self, float amount) {
  if (amount > self->shake_amount) {
    self->shake_amount = amount;
  }
}
