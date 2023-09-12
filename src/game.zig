const std = @import("std");
const glfw = @import("zglfw");
const zmath = @import("zmath");

const tx = @import("texture.zig");
const rsc = @import("rscmgr.zig");
const sp = @import("sprite.zig");
const lvl = @import("level.zig");

pub const GameState = enum {
    game_active,
    game_menu,
    game_win,
};

pub fn new(width: u32, height: u32) Game {
    return Game{
        .keys = [_]bool{false} ** 1024,
        .width = width,
        .height = height,
        .levels = [_]lvl.Level{undefined} ** 4,
    };
}

pub const Game = struct {
    state: GameState = GameState.game_active,
    keys: [1024]bool,
    width: u32,
    height: u32,
    renderer: sp.Renderer = undefined,
    levels: [4]lvl.Level,
    current_level: u32 = 0,
    player: Player = undefined,

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

        _ = try rsc.loadTexture("textures/background.jpg", "background");
        _ = try rsc.loadTexture("textures/awesomeface.png", "face");
        _ = try rsc.loadTexture("textures/block_solid.png", "block_solid");
        _ = try rsc.loadTexture("textures/block.png", "block");
        _ = try rsc.loadTexture("textures/paddle.png", "paddle");

        self.levels[0] = try lvl.loadLevel(gpa.allocator(), "levels/one.lvl", self.width, self.height / 2);
        self.levels[1] = try lvl.loadLevel(gpa.allocator(), "levels/two.lvl", self.width, self.height / 2);
        self.levels[2] = try lvl.loadLevel(gpa.allocator(), "levels/three.lvl", self.width, self.height / 2);
        self.levels[3] = try lvl.loadLevel(gpa.allocator(), "levels/four.lvl", self.width, self.height / 2);

        self.player = Player{
            .position = zmath.f32x4(@as(f32, @floatFromInt(self.width)) / 2.0 - 50.0, @as(f32, @floatFromInt(self.height)) - 20.0, 0.0, 1.0),
            .sprite = rsc.getTexture("paddle"),
        };
    }

    pub fn deinit(self: *Game) void {
        rsc.deinit();
        self.renderer.deinit();
    }

    pub fn processInput(self: *Game, dt: f64) void {
        if (self.state == .game_active) {
            const vel = self.player.velocity[0] * dt;
            if (self.keys[@intFromEnum(glfw.Key.a)]) {
                if (self.player.position[0] >= 0.0) {
                    self.player.position[0] -= @floatCast(vel);
                }
            }
            if (self.keys[@intFromEnum(glfw.Key.d)]) {
                if (self.player.position[0] <= @as(f32, @floatFromInt(self.width)) - self.player.size[0]) {
                    self.player.position[0] += @floatCast(vel);
                }
            }
        }
    }

    pub fn update(self: *Game, dt: f64) void {
        _ = self;
        _ = dt;
    }

    pub fn render(self: *Game) void {
        if (self.state == .game_active) {
            self.renderer.drawSprite(
                rsc.getTexture("background").?,
                zmath.f32x4(0.0, 0.0, 0.0, 1.0),
                zmath.f32x4(@as(f32, @floatFromInt(self.width)), @as(f32, @floatFromInt(self.height)), 1.0, 0.0),
                0.0,
                zmath.f32x4s(1.0),
            );
            self.levels[self.current_level].draw(self.renderer);
            self.player.draw(self.renderer);
        }
    }
};

pub const Player = struct {
    position: zmath.Vec = zmath.f32x4(0.0, 0.0, 0.0, 1.0),
    size: zmath.Vec = zmath.f32x4(100.0, 20.0, 0.0, 0.0),
    color: zmath.Vec = zmath.f32x4s(1.0),
    velocity: zmath.Vec = zmath.f32x4(500.0, 0.0, 0.0, 0.0),
    is_solid: bool = false,
    destroyed: bool = false,
    sprite: ?tx.Texture,

    pub fn draw(self: @This(), renderer: sp.Renderer) void {
        renderer.drawSprite(self.sprite.?, self.position, self.size, 0.0, self.color);
    }
};
