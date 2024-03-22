// This is simple demo in which a cube rolls on grid, controlled by arrow keys.
//
// Created by 10aded Mar 2024 --- ???
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
//   https://github.com/10aded/   ???
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

// TODO:
// * Make the translation animation for the cube go along an arc; adjust animation_direction.

const std    = @import("std");
const rl     = @cImport(@cInclude("raylib.h"));

const sin    = std.math.sin;
const cos    = std.math.cos;
const pi     = std.math.pi;

const mat33i8  = [3] @Vector(3, i8);
const mat33f32 = [3] @Vector(3, f32);
const Vec3    = @Vector(3, f32);
const Vec3Int = @Vector(3, i32);
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

// Globals
const WINDOW_TITLE = "Colorful Cubes Demo";

// Camera
var camera : rl.Camera3D = undefined;

// Game
var cube_pos = Vec3Int{1,0,1};
var cube_posf32 : Vec3 = undefined;

// Animation
var   animation_type      = ANIMATION_TYPE.UP;
const ANIMATION_TIME      = 0.2;
var   animation_matrix : mat33f32 = undefined;

// Keyboard
var left_key_down             : bool = false;
var left_key_down_last_frame  : bool = false;
var right_key_down            : bool = false;
var right_key_down_last_frame : bool = false;
var up_key_down               : bool = false;
var up_key_down_last_frame    : bool = false;
var down_key_down             : bool = false;
var down_key_down_last_frame  : bool = false;

// Constants
// Colors
const BLACK = Color{0x00, 0x00, 0x00, 0xFF};
const RED   = Color{0xFF, 0x00, 0x00, 0xFF};
const GREEN = Color{0x00, 0xFF, 0x00, 0xFF};
const BLUE  = Color{0x00, 0x00, 0xFF, 0xFF};

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

const rotx180 = matmul(rotx90, rotx90);
const rotx270 = matmul(matmul(rotx90, rotx90), rotx90);

const roty90 = mat33i8{
    .{0, 0, -1},
    .{0, 1,  0},
    .{1, 0,  0},
};

const roty180 = matmul(roty90, roty90);
const roty270 = matmul(matmul(roty90, roty90), roty90);

const rotz90 = mat33i8 {
    .{0, -1, 0},
    .{1,  0, 0},
    .{0,  0, 1},
};

const rotz180 = matmul(rotz90, rotz90);
const rotz270 = matmul(matmul(rotz90, rotz90), rotz90);

fn matxrottheta(t : f32) mat33f32 {
    return mat33f32{
        .{1, 0, 0},
        .{0, cos(t), -sin(t)},
        .{0, sin(t),  cos(t)},
    };
}

fn matzrottheta(t : f32) mat33f32 {
    return mat33f32{
        .{cos(t), -sin(t), 0},
        .{sin(t),  cos(t), 0},
        .{     0,       0, 1},
    };
}


fn matmul(mat1 : mat33i8, mat2 : mat33i8) mat33i8 {
    var ret : mat33i8 = undefined;
    for (0..3) |i| {
        for (0..3) |j| {
            var sum : i8 = 0;
            for (0..3) |k| {
                sum += mat1[i][k] * mat2[k][j];
            }
            ret[i][j] = sum;
        }
    }
    return ret;
}

fn matmulf32(mat1 : mat33f32, mat2 : mat33f32) mat33f32 {
    var ret : mat33f32 = undefined;
    for (0..3) |i| {
        for (0..3) |j| {
            var sum : f32 = 0;
            for (0..3) |k| {
                sum += mat1[i][k] * mat2[k][j];
            }
            ret[i][j] = sum;
        }
    }
    return ret;
}

fn matvecmul(mat : mat33f32, vec : Vec3) Vec3 {
    var ret : Vec3 = undefined;
    for (0..3) |i| {
        const dot = mat[i] * vec;
        ret[i] = @reduce(.Add, dot);
    }
    return ret;
}

fn matsclmul(scalar : f32, mat : mat33f32) mat33f32 {
    var scv : Vec3 = @splat(scalar);
    var ret :  mat33f32 = undefined;
    for (0..3) |i| {
        ret[i] = mat[i] * scv;
    }
    return ret;
}

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

fn mattrimul(mat: mat33f32, tri : Triangle) Triangle {
    const p1 = matvecmul(mat, tri.p1);
    const p2 = matvecmul(mat, tri.p2);
    const p3 = matvecmul(mat, tri.p3);
    return Triangle{.p1 = p1, .p2 = p2, .p3 = p3, .color = tri.color};
}

// TODO: Adjust these colors.
const LIGHTGREEN = Color{0x47, 0x77, 0x54, 255};
const DARKGREEN  = Color{0x21, 0x3b, 0x25, 255};
const LIGHTBLUE  = Color{0xc0, 0xd1, 0xcc, 255};
const GRAYBLUE   = Color{0x65, 0x73, 0x8c, 255};
const BROWN      = Color{0x77, 0x5c, 0x4f, 255};
const YELLOW2    = Color{0xf5, 0xcf, 0x13, 255};

const MAGENTA = Color{0xFF, 0x00, 0xFF, 0xFF};
const DEBUG = MAGENTA;

const BLACK2     = Color{0x17, 0x0e, 0x19, 255};
const WHITE      = Color{0xFF, 0xFF, 0xFF, 255};

// Window
const initial_screen_width  = 1080;
const initial_screen_height = 1080 / 4 * 3;

// Geometry
const ORIGIN = Vec3{0,0,0};
const UNITX  = Vec3{1,0,0};
const UNITY  = Vec3{0,1,0};
const UNITZ  = Vec3{0,0,1};

//@debug
const test_p1 = Vec3{0, 0, 0};
const test_p2 = Vec3{1, 0, 0};
const test_p3 = Vec3{1, 1, 0};
const test_triangle = [3]Vec3{test_p1, test_p2, test_p3};

var stopwatch : std.time.Timer = undefined;

pub fn main() anyerror!void {
    // Attempt to make GPU not burn to 100%.
    rl.SetConfigFlags(rl.FLAG_VSYNC_HINT);

    const initial_camera_position = Vec3{6,6,6};

    // Start the timer (used in animations).
    stopwatch = try std.time.Timer.start();

    // Define the camera to look into our 3d world
    camera.position = vec3_to_rl(initial_camera_position);
    camera.target = vec3_to_rl(ORIGIN);
    camera.up = vec3_to_rl(UNITY);
    camera.fovy = 45.0;                                // Camera field-of-view Y
    camera.projection = rl.CAMERA_PERSPECTIVE;             // Camera projection type
    
    // Spawn and setup raylib window.    
    rl.InitWindow(initial_screen_width, initial_screen_height, WINDOW_TITLE);
    defer rl.CloseWindow();

    rl.SetWindowState(rl.FLAG_WINDOW_RESIZABLE);
    rl.SetTargetFPS(144);

    while ( ! rl.WindowShouldClose() ) { // Listen for close button or ESC key.

        process_input_update_state();


        const elapsed_time_nano = stopwatch.read();
        const elapsed_time_secs_f64 = @as(f64, @floatFromInt(elapsed_time_nano)) / @as(f64, std.time.ns_per_s);
        const elapsed_time_secs = @as(f32, @floatCast(elapsed_time_secs_f64));
        
        const clamped_time = std.math.clamp(elapsed_time_secs, 0, ANIMATION_TIME);
        // fraction is 0 at start of animation, 1 at end.
        const animation_fraction = clamped_time / ANIMATION_TIME;

        // @floatFromInt doesn't work on vectors in Zig v.0.11.0, this has been fixed in v.0.12.dev
        cube_posf32 = Vec3{@floatFromInt(cube_pos[0]), @floatFromInt(cube_pos[1]), @floatFromInt(cube_pos[2])};

        // TODO... Put this code somewhere sensible.
        // Depending on the animation_fraction, offset the position of the cube.
        // Set the translation animation direction.

        // The center of the cube, during rotation, moves on a circle
        // of radius R = sqrt(2)/2, from angle pi/4 to 3pi/4.
        const R = 0.5 * std.math.sqrt2;
        const theta1 = (1 - animation_fraction) * 0.5 * pi;
        // At t = 0, theta2 = 3/4pi,
        // at t = 1, theta2 = 1/4pi.
        const theta2 = theta1 + 0.25 * pi;
        const animation_offset = switch (animation_type) {
            .UP    => Vec3{-R * cos(theta2), R * sin(theta2), 0}  - Vec3{-R * cos(0.25 * pi), R * sin(0.25 * pi), 0},
            .DOWN  => Vec3{ R * cos(theta2), R * sin(theta2), 0}  - Vec3{ R * cos(0.25 * pi), R * sin(0.25 * pi), 0},
            .LEFT  => Vec3{0, R * sin(theta2), R * cos(theta2)}  - Vec3{0, R * sin(0.25 * pi),  R * cos(0.25 * pi)},
            .RIGHT => Vec3{0, R * sin(theta2), -R * cos(theta2)} - Vec3{0, R * sin(0.25 * pi), -R * cos(0.25 * pi)},
        };

        // Calculate cube animation rotation.

//        std.debug.print("theta: {}\n", .{theta}); // @debug
        
        // Set the rotation animation matrix.
        animation_matrix = switch(animation_type) {
            .UP    => matzrottheta(-theta1),
            .DOWN  => matzrottheta(theta1),
            .LEFT  => matxrottheta(-theta1),
            .RIGHT => matxrottheta(theta1),
        };

        cube_posf32 += animation_offset;
        
        render();
    }
}

fn process_input_update_state() void {
    // @debug
    // left  arrow: rotx90
    // right arrow: rotx270
    // up    arrow: rotz90
    // down  arrow: rotz270

    // Check to see how pressed keys are.
    left_key_down_last_frame = left_key_down;
    left_key_down = rl.IsKeyDown(rl.KEY_LEFT);
    right_key_down_last_frame = right_key_down;
    right_key_down = rl.IsKeyDown(rl.KEY_RIGHT);
    up_key_down_last_frame = up_key_down;
    up_key_down = rl.IsKeyDown(rl.KEY_UP);    
    down_key_down_last_frame = down_key_down;
    down_key_down = rl.IsKeyDown(rl.KEY_DOWN);    

    // When keys are pressed, rotate the cube, and update
    // its position.
    if (left_key_down and ! left_key_down_last_frame) {
        main_cube_rot = matmul(rotx90, main_cube_rot);
        cube_pos += Vec3Int{0,0,1};
        animation_type = .LEFT;
        _ = stopwatch.lap();
    }

    if (right_key_down and ! right_key_down_last_frame) {
        main_cube_rot = matmul(rotx270, main_cube_rot);
        animation_type = .RIGHT;
        cube_pos -= Vec3Int{0,0,1};
        _ = stopwatch.lap();
    }

    if (up_key_down and ! up_key_down_last_frame) {
        main_cube_rot = matmul(rotz90, main_cube_rot);
        animation_type = .UP;
        cube_pos -= Vec3Int{1,0,0};
        _ = stopwatch.lap();
    }

    if (down_key_down and ! down_key_down_last_frame) {
        main_cube_rot = matmul(rotz270, main_cube_rot);
        animation_type = .DOWN;        
        cube_pos += Vec3Int{1,0,0};
        _ = stopwatch.lap();
    }

    // @debug
//    std.debug.print("{any}\n", .{main_cube_rot});
}


fn render() void {
    rl.BeginDrawing();

    rl.ClearBackground(rlc(BLACK));

    rl.BeginMode3D(camera);

    // Draw a grid.
    rl.DrawGrid(10, 1);


    const final_cube_rotation = mat33i8_to_mat33f32(main_cube_rot);
    const cube_rotation = matmulf32(animation_matrix, final_cube_rotation);

    render_cube(cube1, cube_posf32, cube_rotation);

    // @debug
    render_cube(red_cube, UNITX, mat33i8_to_mat33f32(id));
    render_cube(green_cube, UNITY, mat33i8_to_mat33f32(id));
    render_cube(blue_cube, UNITZ, mat33i8_to_mat33f32(id));
    
    rl.EndMode3D();

    defer rl.EndDrawing();
}

// Convert our color data type to raylib's color data type.
fn rlc(color : Color) rl.Color {
    return rl.Color{.r = color[0], .g = color[1], .b = color[2], .a = color[3]};
}

// Convert our Vector3 data type to raylib's vector data type.
fn vec3_to_rl(vec : Vec3) rl.Vector3 {
    const dumb_rl_tl_vec3 = rl.Vector3{
        .x = vec[0],
        .y = vec[1],
        .z = vec[2],
    };
    return dumb_rl_tl_vec3;
}

// In the procedure below,
//
//    C2
//  C5C1C3C6
//    C4
//
// C1 represents the top face of the cube, C2 is pointing "north"
const Cube = [6] Color;

const cube1 = Cube{
    YELLOW2,
    YELLOW2,
    YELLOW2,
    YELLOW2,
    YELLOW2,
    YELLOW2,
};


const red_cube = Cube{
    RED,
    RED,
    RED,
    RED,
    RED,
    RED,
};

const green_cube = Cube{
    GREEN,
    GREEN,
    GREEN,
    GREEN,
    GREEN,
    GREEN,
};

const blue_cube = Cube{
    BLUE,
    BLUE,
    BLUE,
    BLUE,
    BLUE,
    BLUE,
};

fn render_cube(cube: Cube, pos : Vec3 , rot : mat33f32) void {
    // Construct triangles for the top of the cube, (and then rotate these
    // around to get other faces).
    const edge_color = WHITE;
    const eps = 0.05; // Epsilon

    // Points.
    const f00 = Vec3{ -1 + eps, -1 + eps,  1};
    const f01 = Vec3{ -1 + eps,  1 - eps,  1};
    const f10 = Vec3{  1 - eps, -1 + eps,  1};
    const f11 = Vec3{  1 - eps,  1 - eps,  1};
    const e00 = Vec3{ -1, -1, 1};
    const e10 = Vec3{  1, -1, 1};
    
    // Face triangles.
    const triangleA = Triangle{.p1 = f00, .p2 = f10, .p3 = f11, .color = DEBUG};
    const triangleB = Triangle{.p1 = f00, .p2 = f01, .p3 = f11, .color = DEBUG};
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
        // Set colors.
        cube_triangles[tftn * i + 0].color = cube[i];
        cube_triangles[tftn * i + 1].color = cube[i];
    }
    
    const rot2 = matsclmul(0.5, rot);

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
    const p1 = vec3_to_rl(triangle.p1);
    const p2 = vec3_to_rl(triangle.p2);
    const p3 = vec3_to_rl(triangle.p3);
    rl.DrawTriangle3D(p1, p2, p3, rlc(triangle.color));
    rl.DrawTriangle3D(p2, p1, p3, rlc(triangle.color));
}
