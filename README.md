# Rolling Cube Demo

This is just a simple demo in which a cube is rolled around a grid.

![Screenshot](rolling-cube.gif "An illustration of the demo, showing a yellow cube rolling on a grid.")

## Keyboard

Simply press the arrow keys to control the position of the cube. Note how the arrow key input is not blocked when animations are still playing!

## Build Instructions

This is a Zig project that natively calls raylib code (which is written in C). (More on dependencies below.)

Since the Zig compiler comes with its own build system and is also a C compiler, the project can be built and run with the command

`zig build run`

A release build can be created with the following command.

`zig build -Doptimize=ReleaseFast`

The project was built with the Zig 0.11.0 compiler on Windows 11, available from the [download page](https://ziglang.org/download/) on `ziglang.org`. Compilation of the game on other operating systems has not been tested.

## Dependencies

The project is written in Zig and uses the raylib library, [specifically v5.0](https://github.com/raysan5/raylib/releases/tag/5.0) (commit number ae50bfa). We included the necessary source files from raylib directly in our project (under the `Raylib5` directory), but deleted unnecessary parts of the library (like its numerous examples). We also combined the `build.zig` file1 there into the build file for the project, simplifying it for Zig compiler 0.11.0.

Raylib is created by Ramon Santamaria (GitHub handle [@raysan5](https://github.com/raysan5)) and is available on GitHub [here](https://github.com/raysan5/raylib). See the link above for Raylib's full license / copywrite details.

## Development

The entire development of this app (basically) was streamed on Twitch and recordings were uploaded to YouTube at:

https://www.twitch.tv/10aded

https://www.youtube.com/@10aded
