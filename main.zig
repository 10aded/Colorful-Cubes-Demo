// This is a puzzle game about the geometry of cubes.
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
// * Start moving / animating the cube.
// * Think about data structures so that drawing triangles
//   just writes info to some buffer, which at a later stage
//   will be sent off to the GPU.
// * Create our own custom camera class.
// * Create our own grid drawing procedure.
// * Make tests for matrix multiplication.

const std    = @import("std");
const rl     = @cImport(@cInclude("raylib.h"));

const mat33i8  = [3][3] i8;
const mat33f32 = [3][3] f32;
const Vec3  = @Vector(3, f32);
const Color = [4] u8;
    
// Globals
const WINDOW_TITLE = "Colorful Cubes Demo";

// Camera
var camera : rl.Camera3D = undefined;


// Keyboard
var left_key_down            : bool = false;
var left_key_down_last_frame : bool = false;


// Constants
// Colors
const BLACK = Color{0x00, 0x00, 0x00, 0xFF};

// Matrices
var main_cube_rot = id;

const id = mat33i8{
    .{1, 0, 0},
    .{0, 1, 0},
    .{0, 0, 1},
};

const rotx90 = mat33i8{
    .{1, 0,  0},
    .{0, 0, -1},
    .{0, 1,  0},
};

const roty90 = mat33i8{
    .{0, 0, -1},
    .{0, 1, 0},
    .{1, 0,  1},
};

const rotz90 = mat33i8 {
    .{0, -1, 0},
    .{1,  0, 0},
    .{0,  0, 1},
};

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

fn matvecmul(mat : mat33f32, vec : Vec3) Vec3 {
    var ret : Vec3 = undefined;
    for (0..3) |i| {
        ret[i] = mat[i][0] * vec[0] + mat[i][1] * vec[1] + mat[i][2] * vec[2];
    }
    return ret;
}

fn matsclmul(scalar : f32, mat : mat33f32) mat33f32 {
    var ret = mat;
    for (0..3) |i| {
        for (0..3) |j| {
            ret[i][j] *= scalar;
        }
    }
    return ret;
}

fn mat33i8_to_mat33f32(mat : mat33i8) mat33f32 {
    var ret : mat33f32 = undefined;
    for (0..3) |i| {
        for (0..3) |j| {
            ret[i][j] = @floatFromInt(mat[i][j]);
        }
    }
    return ret;
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

pub fn main() void {

    //@debug
    const vec1 = Vec3{1,2,3};
    const vec2 = Vec3{0,4,1};
    const test1 = vec1 * vec2 == Vec3{0, 8, 3};
    std.debug.print("{any}\n", .{test1});
    
    // Attempt to make GPU not burn to 100%.
    rl.SetConfigFlags(rl.FLAG_VSYNC_HINT);

    const camera_position = Vec3{10,10,10};
        
    // Define the camera to look into our 3d world
    camera.position = vec3_to_rl(camera_position);
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
        render();
    }
}

fn process_input_update_state() void {
    // @debug
    // left  arrow: rotx90
    // right arrow: rotx270
    // up    arrow: rotz90
    // down  arrow: rotz270

    // 
    left_key_down_last_frame = left_key_down;
    left_key_down = rl.IsKeyDown(rl.KEY_LEFT);

    // TODO...
    // KEY_RIGHT           = 262,      // Key: Cursor right
    // KEY_LEFT            = 263,      // Key: Cursor left
    // KEY_DOWN            = 264,      // Key: Cursor down
    // KEY_UP              = 265,      // Key: Cursor up

    if (left_key_down and ! left_key_down_last_frame) {
        main_cube_rot = matmul(main_cube_rot, rotx90);
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

    const pos1 = Vec3{2,0,2};
    
    const cube_rotation = mat33i8_to_mat33f32(main_cube_rot);
    render_cube(cube1, pos1, cube_rotation);

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
    LIGHTGREEN,
    DARKGREEN,
    LIGHTBLUE,
    GRAYBLUE,
    BROWN,
    YELLOW2,
};


fn render_cube( cube : Cube, pos : Vec3 , rot : mat33f32) void {
    // Compute the 8 nodes of the cube.
    // pXYZ = Vec{X,Y,Z};
    const c000 = Vec3{-1, -1, -1};
    const c001 = Vec3{-1, -1,  1};
    const c010 = Vec3{-1,  1, -1};
    const c011 = Vec3{-1,  1,  1};
    const c100 = Vec3{ 1, -1, -1};
    const c101 = Vec3{ 1, -1,  1};
    const c110 = Vec3{ 1,  1, -1};
    const c111 = Vec3{ 1,  1,  1};

    const rot2 = matsclmul(0.5, rot);
    // Rotate the cube nodes by rot;
    const p000 =  matvecmul(rot2, c000) + pos;
    const p001 =  matvecmul(rot2, c001) + pos;
    const p010 =  matvecmul(rot2, c010) + pos;
    const p011 =  matvecmul(rot2, c011) + pos;
    const p100 =  matvecmul(rot2, c100) + pos;
    const p101 =  matvecmul(rot2, c101) + pos;
    const p110 =  matvecmul(rot2, c110) + pos;
    const p111 =  matvecmul(rot2, c111) + pos;
    
    // Compute 12 triangles (including their colors) which
    // when drawn, will draw the cube.

    const c1ta = Triangle{.p1 = p001, .p2 = p011, .p3 = p111, .color = cube[0]};
    const c1tb = Triangle{.p1 = p001, .p2 = p101, .p3 = p111, .color = cube[0]};
    const c2ta = Triangle{.p1 = p010, .p2 = p011, .p3 = p111, .color = cube[1]};
    const c2tb = Triangle{.p1 = p010, .p2 = p110, .p3 = p111, .color = cube[1]};
    const c3ta = Triangle{.p1 = p100, .p2 = p101, .p3 = p111, .color = cube[2]};
    const c3tb = Triangle{.p1 = p100, .p2 = p110, .p3 = p111, .color = cube[2]};
    const c4ta = Triangle{.p1 = p000, .p2 = p001, .p3 = p101, .color = cube[3]};
    const c4tb = Triangle{.p1 = p000, .p2 = p100, .p3 = p101, .color = cube[3]};
    const c5ta = Triangle{.p1 = p000, .p2 = p001, .p3 = p011, .color = cube[4]};
    const c5tb = Triangle{.p1 = p000, .p2 = p010, .p3 = p011, .color = cube[4]};
    const c6ta = Triangle{.p1 = p000, .p2 = p010, .p3 = p110, .color = cube[5]};
    const c6tb = Triangle{.p1 = p000, .p2 = p100, .p3 = p110, .color = cube[5]};

    const triangles = [12] Triangle{
        c1ta, c1tb,
        c2ta, c2tb,
        c3ta, c3tb,
        c4ta, c4tb,
        c5ta, c5tb,
        c6ta, c6tb,
    };

    // Draw triangles.
    for (triangles) |triangle| {
        draw_triangle(triangle);
    }
}

const Triangle = struct{
    p1 : Vec3,
    p2 : Vec3,
    p3 : Vec3,
    color : Color,
};

fn draw_triangle(triangle : Triangle) void {
    const p1 = vec3_to_rl(triangle.p1);
    const p2 = vec3_to_rl(triangle.p2);
    const p3 = vec3_to_rl(triangle.p3);
    rl.DrawTriangle3D(p1, p2, p3, rlc(triangle.color));
    rl.DrawTriangle3D(p2, p1, p3, rlc(triangle.color));
}


    // var mat = rotx90;
    // var i : usize = 0;
    // while (i <= 4) : (i += 1) {
    //     std.debug.print("{any}\n", .{mat});
    //     mat = matmul(mat,rotx90);
    // }
