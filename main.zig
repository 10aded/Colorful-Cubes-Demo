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
// * Think about data structures so that drawing triangles
//   just writes info to some buffer, which at a later stage
//   will be sent off to the GPU.

const std    = @import("std");
const rl     = @cImport(@cInclude("raylib.h"));

const Vec3  = @Vector(3, f32);
const Color = [4] u8;
    
// Globals
const WINDOW_TITLE = "Colorful Cubes Demo";

// Constants
// Colors
const BLACK = Color{0x0, 0x0, 0x0, 0xFF};


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
    // Attempt to make GPU not burn to 100%.
    rl.SetConfigFlags(rl.FLAG_VSYNC_HINT);

    //     typedef struct Camera3D {
    // Vector3 position;       // Camera position
    // Vector3 target;         // Camera target it looks-at
    // Vector3 up;             // Camera up vector (rotation over its axis)
    // float fovy;             // Camera field-of-view aperture in Y (degrees) in perspective, used as near plane width in orthographic
    // int projection;         // Camera projection: CAMERA_PERSPECTIVE or CAMERA_ORTHOGRAPHIC
    // } Camera3D;


    const camera_position = Vec3{10,10,10};
        
    // Define the camera to look into our 3d world
    var camera : rl.Camera3D = undefined;
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
        rl.BeginDrawing();

        rl.ClearBackground(rlc(BLACK));

        rl.BeginMode3D(camera);

        // Draw a grid.
        rl.DrawGrid(10, 1);
        
        const p1 = vec3_to_rl(test_triangle[0]);
        const p2 = vec3_to_rl(test_triangle[1]);
        const p3 = vec3_to_rl(test_triangle[2]);
        rl.DrawTriangle3D(p1, p2, p3, rlc(BLACK));
        
        rl.EndMode3D();
        
        defer rl.EndDrawing();
    }
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
