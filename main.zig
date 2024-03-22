// This is simple demo in which a cube rolls on grid, controlled by arrow keys.
//
// Created by 10aded Mar 2024.
//
// This project was compiled using the Zig compiler (version 0.11.0)
// and built with the command:
//
//     zig build -Doptimize=ReleaseFast
//
// run in the top directory of the project.
//
// The entire source code of this project is available on GitHub at:
//
//   https://github.com/10aded/Rolling-Cube-Demo
//
// and was developed (almost) entirely on the Twitch channel 10aded. Copies of the
// stream are available on YouTube at the @10aded channel.
//
// This project includes a copy of raylib, specifically v5.0 (commit number ae50bfa).
//
// Raylib is created by github user Ray (@github handle raysan5) and available at:
//
//    https://github.com/raysan5a
//
// See the pages above for full license details.

const std    = @import("std");
const rl     = @cImport(@cInclude("raylib.h"));

const sin    = std.math.sin;
const cos    = std.math.cos;
const pi     = std.math.pi;

const Vec3    = @Vector(3, f32);
const Vec3Int = @Vector(3, i32);

const mat33i8  = [3] @Vector(3, i8);
const mat33f32 = [3] @Vector(3, f32);

const Color = [4] u8;

const Triangle = struct{
    p1 : Vec3,
    p2 : Vec3,
    p3 : Vec3,
    color : Color,
};

const ANIMATION_TYPE = enum(u8) {
    UP,
    DOWN,
    LEFT,
    RIGHT,
};

// Constants.
// Window
const WINDOW_TITLE = "Rolling cube demo";
const initial_screen_width  = 1080;
const initial_screen_height = 1080 / 4 * 3;

// Camera
const initial_camera_position = Vec3{6,6,6};

// Geometry
const ORIGIN = Vec3{0,0,0};
const UNITX  = Vec3{1,0,0};
const UNITY  = Vec3{0,1,0};
const UNITZ  = Vec3{0,0,1};

// Animation.
const ANIMATION_TIME = 0.2;

// Colors.
const BLACK   = Color{0x00, 0x00, 0x00, 0xFF};
const WHITE   = Color{0xFF, 0xFF, 0xFF, 255};
const YELLOW  = Color{0xf5, 0xcf, 0x13, 255};
const DEBUG   = Color{0xFF, 0x00, 0xFF, 0xFF};

// Matrices
var main_cube_rot = id;

const id = mat33i8{
    .{1, 0, 0},
    .{0, 1, 0},
    .{0, 0, 1},
};

const idf32 = mat33i8_to_mat33f32(id);

const rotx90 = mat33i8{
    .{1, 0,  0},
    .{0, 0, -1},
    .{0, 1,  0},
};

const rotx180 = matmulT(i8,rotx90, rotx90);
const rotx270 = matmulT(i8,matmulT(i8, rotx90, rotx90), rotx90);

const roty90 = mat33i8{
    .{0, 0, -1},
    .{0, 1,  0},
    .{1, 0,  0},
};

const roty180 = matmulT(i8,roty90, roty90);
const roty270 = matmulT(i8,matmulT(i8, roty90, roty90), roty90);

const rotz90 = mat33i8 {
    .{0, -1, 0},
    .{1,  0, 0},
    .{0,  0, 1},
};

const rotz180 = matmulT(i8,rotz90, rotz90);
const rotz270 = matmulT(i8,matmulT(i8, rotz90, rotz90), rotz90);

// Globals
// Game
var cube_pos = Vec3Int{0,0,0};
var cube_posf32 : Vec3 = undefined;

// Animation
var animation_type = ANIMATION_TYPE.UP;
var animation_matrix : mat33f32 = undefined;
var stopwatch : std.time.Timer = undefined;

// Keyboard
var left_key_down             : bool = false;
var left_key_down_last_frame  : bool = false;
var right_key_down            : bool = false;
var right_key_down_last_frame : bool = false;
var up_key_down               : bool = false;
var up_key_down_last_frame    : bool = false;
var down_key_down             : bool = false;
var down_key_down_last_frame  : bool = false;

// Camera
var camera : rl.Camera3D = undefined;

// Generate matrices that rotate about a given axis.
// x-axis rotation.
fn matxrottheta(t : f32) mat33f32 {
    return mat33f32{
        .{1, 0, 0},
        .{0, cos(t), -sin(t)},
        .{0, sin(t),  cos(t)},
    };
}
// Note:
// y-axis rotation is not needed in this demo, since the y-axis
// points "up".

// z-axis rotation.
fn matzrottheta(t : f32) mat33f32 {
    return mat33f32{
        .{cos(t), -sin(t), 0},
        .{sin(t),  cos(t), 0},
        .{     0,       0, 1},
    };
}

// It doesn't appear that matrix multiplication is in the Zig standard
// libary, so here are some versions of the common linear algebra functions.

// Matrix multiplication, used in our case with T = i8, f32.
fn matmulT(comptime T : type, mat1 : [3] @Vector(3, T), mat2 : [3] @Vector(3, T)) [3] @Vector(3, T) {
    var ret : [3] @Vector(3, T) = undefined;
    for (0..3) |i| {
        for (0..3) |j| {
            var sum : T = 0;
            for (0..3) |k| {
                sum += mat1[i][k] * mat2[k][j];
            }
            ret[i][j] = sum;
        }
    }
    return ret;
}

// Multiplying a vector by a matrix.
fn matvecmul(mat : mat33f32, vec : Vec3) Vec3 {
    var ret : Vec3 = undefined;
    for (0..3) |i| {
        const dot = mat[i] * vec;
        ret[i] = @reduce(.Add, dot);
    }
    return ret;
}

// Scaling a matrix.
fn matsclmul(scalar : f32, mat : mat33f32) mat33f32 {
    var scv : Vec3 = @splat(scalar);
    var ret :  mat33f32 = undefined;
    for (0..3) |i| {
        ret[i] = mat[i] * scv;
    }
    return ret;
}

// Converting a i8 matrix to a f32 matrix.
fn mat33i8_to_mat33f32(mat : mat33i8) mat33f32 {
    var ret : mat33f32 = undefined;
    for (0..3) |i| {
        // Note: The current lines fails with v.0.11.0 of the compiler,
        // bit this has been fixed in a dev version of v.0.12.0.
        // ret[i] = @floatFromInt(mat[i]);
        for (0..3) |j| {
            ret[i][j] = @floatFromInt(mat[i][j]);
        }
    }
    return ret;
}

// Applying a matrix to a triangle.
fn mattrimul(mat: mat33f32, tri : Triangle) Triangle {
    const p1 = matvecmul(mat, tri.p1);
    const p2 = matvecmul(mat, tri.p2);
    const p3 = matvecmul(mat, tri.p3);
    return Triangle{.p1 = p1, .p2 = p2, .p3 = p3, .color = tri.color};
}

pub fn main() anyerror!void {
    // Attempt to make GPU not burn to 100%, maybe doesn't work?
    rl.SetConfigFlags(rl.FLAG_VSYNC_HINT);

    // Start the timer (used in animations).
    stopwatch = try std.time.Timer.start();

    // Define the camera to look into our 3d world
    camera.position = @bitCast(initial_camera_position);
    camera.target   = @bitCast(ORIGIN);
    camera.up       = @bitCast(UNITY);
    camera.fovy     = 45.0;                                // Camera field-of-view Y
    camera.projection = rl.CAMERA_PERSPECTIVE;             // Camera projection type
    
    // Spawn and setup raylib window.    
    rl.InitWindow(initial_screen_width, initial_screen_height, WINDOW_TITLE);
    defer rl.CloseWindow();

    rl.SetWindowState(rl.FLAG_WINDOW_RESIZABLE);
    rl.SetTargetFPS(144);

    while ( ! rl.WindowShouldClose() ) { // Listen for close button or ESC key.
        process_input_update_state();
        compute_and_apply_animations();
        render();
    }
}

fn process_input_update_state() void {
    // Check to see how pressed keys are.
    left_key_down_last_frame  = left_key_down;
    left_key_down             = rl.IsKeyDown(rl.KEY_LEFT);

    right_key_down_last_frame = right_key_down;
    right_key_down            = rl.IsKeyDown(rl.KEY_RIGHT);

    up_key_down_last_frame    = up_key_down;
    up_key_down               = rl.IsKeyDown(rl.KEY_UP);    

    down_key_down_last_frame  = down_key_down;
    down_key_down             = rl.IsKeyDown(rl.KEY_DOWN);    

    // When keys are pressed, rotate the cube, and update
    // its position.
    if (left_key_down and ! left_key_down_last_frame) {
        main_cube_rot = matmulT(i8, rotx90, main_cube_rot);
        cube_pos += Vec3Int{0,0,1};
        animation_type = .LEFT;
        _ = stopwatch.lap();
    }

    if (right_key_down and ! right_key_down_last_frame) {
        main_cube_rot = matmulT(i8, rotx270, main_cube_rot);
        animation_type = .RIGHT;
        cube_pos -= Vec3Int{0,0,1};
        _ = stopwatch.lap();
    }

    if (up_key_down and ! up_key_down_last_frame) {
        main_cube_rot = matmulT(i8, rotz90, main_cube_rot);
        animation_type = .UP;
        cube_pos -= Vec3Int{1,0,0};
        _ = stopwatch.lap();
    }

    if (down_key_down and ! down_key_down_last_frame) {
        main_cube_rot = matmulT(i8, rotz270, main_cube_rot);
        animation_type = .DOWN;        
        cube_pos += Vec3Int{1,0,0};
        _ = stopwatch.lap();
    }
}

fn compute_and_apply_animations() void {
    // Calculate, as a f32, the number of seconds passed since a arrow key was last pressed.
    // Clamp this time at ANIMATION_TIME.
    const elapsed_time_nano = stopwatch.read();
    const elapsed_time_secs_f64 = @as(f64, @floatFromInt(elapsed_time_nano)) / @as(f64, std.time.ns_per_s);
    const elapsed_time_secs = @as(f32, @floatCast(elapsed_time_secs_f64));
    const clamped_time = std.math.clamp(elapsed_time_secs, 0, ANIMATION_TIME);

    // Calculate the keyframe fraction.
    // I.e. 0 at start of an animation, 1 at the end.
    const animation_fraction = clamped_time / ANIMATION_TIME;

    // Can't cast @Vector(3, i8) to @Vector(3, f32) with @floatFromInt in Zig v.0.11.0,
    // this has been fixed in v.0.12.dev though.
    cube_posf32 = Vec3{@floatFromInt(cube_pos[0]),
                       @floatFromInt(cube_pos[1]),
                       @floatFromInt(cube_pos[2])};

    // Add in 0.5 offset, so that the cube sits on the squares of the grid.
    cube_posf32 += Vec3{0.5, 0.5, 0.5};

    // Depending on the animation_fraction, offset the position of the cube as follows:
    // The center of the cube, during rotation, moves on a circle
    // of radius R = sqrt(2)/2, from angle pi/4 to 3pi/4.
    
    const R = 0.5 * std.math.sqrt2;
    const theta1 = (1 - animation_fraction) * 0.5 * pi;
    const theta2 = theta1 + 0.25 * pi;
    // At t = 0, theta1 = 1/2 pi,
    // at t = 1, theta1 = 0   pi.
    // At t = 0, theta2 = 3/4 pi,
    // at t = 1, theta2 = 1/4 pi.

    // Calculate the center of the cube offset.
    const animation_offset = switch (animation_type) {
        .UP    => Vec3{-R * cos(theta2), R * sin(theta2), 0}  - Vec3{-R * cos(0.25 * pi), R * sin(0.25 * pi), 0},
        .DOWN  => Vec3{ R * cos(theta2), R * sin(theta2), 0}  - Vec3{ R * cos(0.25 * pi), R * sin(0.25 * pi), 0},
        .LEFT  => Vec3{0, R * sin(theta2), R * cos(theta2)}  - Vec3{0, R * sin(0.25 * pi),  R * cos(0.25 * pi)},
        .RIGHT => Vec3{0, R * sin(theta2), -R * cos(theta2)} - Vec3{0, R * sin(0.25 * pi), -R * cos(0.25 * pi)},
    };
    
    cube_posf32 += animation_offset;
    
    // Calculate cube animation rotation.
    animation_matrix = switch(animation_type) {
        .UP    => matzrottheta(-theta1),
        .DOWN  => matzrottheta(theta1),
        .LEFT  => matxrottheta(-theta1),
        .RIGHT => matxrottheta(theta1),
    };
}

fn render() void {
    rl.BeginDrawing();

    rl.ClearBackground(@bitCast(BLACK));

    rl.BeginMode3D(camera);

    rl.DrawGrid(10, 1);

    // Calculate the overall cube rotation, both from its final position
    // and the animation rotation.
    const final_cube_rotation = mat33i8_to_mat33f32(main_cube_rot);
    const cube_rotation = matmulT(f32, animation_matrix, final_cube_rotation);

    // Render the cube!
    render_cube(YELLOW, cube_posf32, cube_rotation);
    
    rl.EndMode3D();

    defer rl.EndDrawing();
}

// The procdure which computes a bunch of triangles, which raylib
// then draws.
fn render_cube(color : Color, pos : Vec3 , rot : mat33f32) void {
    // Scale the rotation by 1/2.
    const rot2 = matsclmul(0.5, rot);
    
    // Construct triangles for the top of the cube, (and then rotate these
    // around to get other faces).
    const edge_color = WHITE;
    const eps = 0.05; // Epsilon

    // Points for the face triangles.
    const f00 = Vec3{ -1 + eps, -1 + eps,  1};
    const f01 = Vec3{ -1 + eps,  1 - eps,  1};
    const f10 = Vec3{  1 - eps, -1 + eps,  1};
    const f11 = Vec3{  1 - eps,  1 - eps,  1};

    // Points for the edge triangles.
    const e00 = Vec3{ -1, -1, 1};
    const e10 = Vec3{  1, -1, 1};
    
    // Face triangles.
    const triangleA = Triangle{.p1 = f00, .p2 = f10, .p3 = f11, .color = color};
    const triangleB = Triangle{.p1 = f00, .p2 = f01, .p3 = f11, .color = color};
    // Edge triangles.
    const triangleC = Triangle{.p1 = e00, .p2 = f00, .p3 = e10, .color = edge_color};
    const triangleD = Triangle{.p1 = f00, .p2 = e10, .p3 = f10, .color = edge_color};

    // Top face edges.
    const edge_rot_mats = [4] mat33f32 {
        mat33i8_to_mat33f32(id),
        mat33i8_to_mat33f32(rotz90),
        mat33i8_to_mat33f32(rotz180),
        mat33i8_to_mat33f32(rotz270),
    };
    
    var top_face_edge_triangles : [8] Triangle = undefined;
    for (0..4) |i| {
        top_face_edge_triangles[2*i + 0] = mattrimul(edge_rot_mats[i], triangleC);
        top_face_edge_triangles[2*i + 1] = mattrimul(edge_rot_mats[i], triangleD);
    }

    const face_rot_mats = [6] mat33f32{
        mat33i8_to_mat33f32(id),
        mat33i8_to_mat33f32(rotx90),
        mat33i8_to_mat33f32(rotx180),
        mat33i8_to_mat33f32(rotx270),
        mat33i8_to_mat33f32(roty90),
        mat33i8_to_mat33f32(roty270),
    };

    const top_face_triangles = [2] Triangle{triangleA, triangleB} ++ top_face_edge_triangles;
    const tftn = top_face_triangles.len;
    // Rotate the triangles in the top face around to the other positions.
    // Set cube colors too.
    var cube_triangles : [6 * tftn] Triangle = undefined;
    for (0..6) |i| {
        for (top_face_triangles, 0..) |tri, j| {
            cube_triangles[tftn * i + j] = mattrimul(face_rot_mats[i], tri);
        }
    }

    // Rotate the triangles by rot, and then offset their position.
    for (cube_triangles, 0..) |tri, i| {
        var ntri = mattrimul(rot2, tri);
        ntri.p1 += pos;
        ntri.p2 += pos;
        ntri.p3 += pos;
        cube_triangles[i] = ntri;
    }
    
    // Draw face triangles.
    for (cube_triangles) |tri| {
        draw_triangle(tri);
    }
}

fn draw_triangle(triangle : Triangle) void {
    const p1 : rl.Vector3 = @bitCast(triangle.p1);
    const p2 : rl.Vector3 = @bitCast(triangle.p2);
    const p3 : rl.Vector3 = @bitCast(triangle.p3);
    rl.DrawTriangle3D(p1, p2, p3, @bitCast(triangle.color));
    rl.DrawTriangle3D(p2, p1, p3, @bitCast(triangle.color));
}
