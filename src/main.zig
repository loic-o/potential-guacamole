const std = @import("std");
const glfw = @import("zglfw");
const gl = @import("zopengl");

const game = @import("game.zig");

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 600;

var breakout: game.Game = game.new(SCREEN_WIDTH, SCREEN_HEIGHT);

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    const gl_major = 3;
    const gl_minor = 3;
    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.opengl_forward_compat, true);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);

    const window = glfw.Window.create(SCREEN_WIDTH, SCREEN_HEIGHT, "Breakout !", null) catch |err| {
        std.log.err("Failed to create GLFW window:\n{}", .{err});
        std.process.exit(1);
    };
    defer window.destroy();
    glfw.makeContextCurrent(window);

    gl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor) catch |err| {
        std.log.err("Failed to initialize zopengl:\n{}", .{err});
        std.process.exit(1);
    };

    if (glfw.Window.setKeyCallback(window, keyCallback)) |_| {} else {
        // std.log.debug("setKeyCallback returned null", .{});
    }
    if (glfw.Window.setFramebufferSizeCallback(window, framebufferSizeCallback)) |_| {} else {
        // std.log.debug("setFramebufferSizeCallback returned null", .{});
    }

    gl.viewport(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    try breakout.init(allocator);

    var delta_time: f64 = 0.0; // time between current frame and last frame
    var last_frame: f64 = 0.0; // time of last frame

    while (!window.shouldClose()) {
        const current_frame = glfw.getTime();
        delta_time = current_frame - last_frame;
        last_frame = current_frame;
        glfw.pollEvents();

        breakout.processInput(delta_time);

        breakout.update(delta_time) catch |err| {
            std.log.err("update failed. {}", .{err});
            break;
        };

        gl.clearColor(0.0, 0.0, 0.0, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT);
        breakout.render();

        window.swapBuffers();
    }

    std.log.debug("exited game loop", .{});
    breakout.deinit();
    _ = gpa.deinit();
}

fn keyCallback(window: *glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
    _ = mods;
    _ = scancode;
    if (key == glfw.Key.escape and action == glfw.Action.press) {
        glfw.Window.setShouldClose(window, true);
    }
    var ikey: usize = @intCast(@intFromEnum(key));
    if (ikey >= 0 and ikey < 1024) {
        if (action == glfw.Action.press) {
            breakout.keys[ikey] = true;
        } else if (action == glfw.Action.release) {
            breakout.keys[ikey] = false;
        }
    }
}

fn framebufferSizeCallback(window: *glfw.Window, width: c_int, height: c_int) callconv(.C) void {
    _ = window;
    gl.viewport(0, 0, width, height);
}
