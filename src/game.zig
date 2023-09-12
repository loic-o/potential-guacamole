const std = @import("std");
const zmath = @import("zmath");

const rsc = @import("rscmgr.zig");
const sp = @import("sprite.zig");

pub const GameState = enum {
    game_active,
    game_menu,
    game_win,
};

pub fn new(width: u32, height: u32) Game {
    return Game{
        .state = GameState.game_active,
        .keys = [_]bool{false} ** 1024,
        .width = width,
        .height = height,
        .renderer = undefined,
    };
}

pub const Game = struct {
    state: GameState = GameState.game_active,
    keys: [1024]bool,
    width: u32,
    height: u32,
    renderer: sp.Renderer,

    pub fn init(self: *Game) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        rsc.init(gpa.allocator());

        _ = try rsc.loadShader("shaders/sprite.vert", "shaders/sprite.frag", null, "sprite");
        var shader = rsc.getShader("sprite").?;

        var projection = zmath.orthographicOffCenterRhGl(
            0.0, // left
            @floatFromInt(self.width), // right
            0.0, // top
            @floatFromInt(self.height), // bottom
            -1.0,
            1.0, // near, far
        );
        shader.setInteger("image", 0, true);
        shader.setMatrix4("projection", projection, false);

        self.renderer = sp.new(shader);
        self.renderer.init();

        _ = try rsc.loadTexture("textures/awesomeface.png", "face");
    }

    pub fn deinit(self: *Game) void {
        rsc.deinit();
        self.renderer.deinit();
    }

    pub fn processInput(self: *Game, dt: f64) void {
        _ = self;
        _ = dt;
    }

    pub fn update(self: *Game, dt: f64) void {
        _ = self;
        _ = dt;
    }

    pub fn render(self: *Game) void {
        self.renderer.drawSprite(
            rsc.getTexture("face").?,
            zmath.f32x4(200.0, 200.0, 0.0, 0.0),
            zmath.f32x4(300.0, 400.0, 0.0, 0.0),
            45.0,
            zmath.f32x4(0.0, 1.0, 0.0, 1.0),
        );
    }
};
