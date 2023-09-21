This is the breakout-like game from the tutorials presented at [Learn OpenGL](https://learnopengl.com/In-Practice/2D-Game/Breakout),
translated to Zig.  By default I attempted to leave the structure of the code as much like the original C as possible,
but slowly, as I get more comfortable w/ Zig I will refactor the code to be more Zig-like.

I am using libraries from [zig-gamedev](https://github.com/michal-z/zig-gamedev) for many things, and this did require
a departure from the C code in a number of areas.

I am also using the freetype bindings from the [Mach-Freetype](https://github.com/hexops/mach-freetype) to do text
rendering.

