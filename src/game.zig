const std = @import("std");
const glfw = @import("zglfw");
const zmath = @import("zmath");

const tx = @import("texture.zig");
const rsc = @import("rscmgr.zig");
const sp = @import("sprite.zig");
const lvl = @import("level.zig");

const default_player_size = zmath.f32x4(100.0, 20.0, 0.0, 0.0);
const default_player_velocity: f32 = 500.0;
const initial_ball_velocity = zmath.f32x4(100.0, -350.0, 0.0, 0.0);
// const initial_ball_velocity = zmath.f32x4(25.0, -82.0, 0.0, 0.0);
const default_ball_radius: f32 = 12.5;

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
    ball: Ball = undefined,

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

        const ball_pos = self.player.position + [_]f32{ default_player_size[0] / 2.0 - default_ball_radius, -default_ball_radius * 2.0, 0.0, 0.0 };
        self.ball = Ball{
            .position = ball_pos,
            .sprite = rsc.getTexture("face"),
            .velocity = initial_ball_velocity,
        };
    }

    pub fn deinit(self: *Game) void {
        rsc.deinit();
        self.renderer.deinit();
    }

    pub fn processInput(self: *Game, dt: f64) void {
        if (self.state == .game_active) {
            const vel: f32 = self.player.velocity[0] * @as(f32, @floatCast(dt));
            if (self.keys[@intFromEnum(glfw.Key.a)]) {
                if (self.player.position[0] >= 0.0) {
                    self.player.position[0] -= @floatCast(vel);
                    if (self.ball.stuck) {
                        self.ball.position[0] -= vel;
                    }
                }
            }
            if (self.keys[@intFromEnum(glfw.Key.d)]) {
                if (self.player.position[0] <= @as(f32, @floatFromInt(self.width)) - self.player.size[0]) {
                    self.player.position[0] += @floatCast(vel);
                    if (self.ball.stuck) {
                        self.ball.position[0] += vel;
                    }
                }
            }
            if (self.keys[@intFromEnum(glfw.Key.space)]) {
                self.ball.stuck = false;
            }
        }
    }

    pub fn update(self: *Game, dt: f64) void {
        _ = self.ball.move(dt, self.width);
        self.doCollisions();
    }

    fn doCollisions(self: *Game) void {
        for (self.levels[self.current_level].bricks.items) |*br| {
            if (!br.destroyed) {
                // if (checkCollision(self.ball.position, self.ball.size, br.position, br.size)) {
                if (checkBallCollision(self.ball.position, self.ball.radius, br.position, br.size)) {
                    if (br.is_solid) {
                        br.destroyed = true;
                    }
                }
            }
        }
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
            self.ball.draw(self.renderer);
        }
    }
};

pub const Player = struct {
    position: zmath.Vec = zmath.f32x4(0.0, 0.0, 0.0, 1.0),
    size: zmath.Vec = default_player_size,
    color: zmath.Vec = zmath.f32x4s(1.0),
    velocity: zmath.Vec = zmath.f32x4(default_player_velocity, 0.0, 0.0, 0.0),
    is_solid: bool = false,
    destroyed: bool = false,
    sprite: ?tx.Texture,

    pub fn draw(self: @This(), renderer: sp.Renderer) void {
        renderer.drawSprite(self.sprite.?, self.position, self.size, 0.0, self.color);
    }
};

pub const Ball = struct {
    position: zmath.Vec = zmath.f32x4(0.0, 0.0, 0.0, 1.0),
    size: zmath.Vec = zmath.f32x4(default_ball_radius * 2.0, default_ball_radius * 2.0, 0.0, 0.0),
    color: zmath.Vec = zmath.f32x4s(1.0),
    velocity: zmath.Vec = zmath.f32x4(0.0, 0.0, 0.0, 0.0),
    sprite: ?tx.Texture,
    radius: f32 = 12.5,
    stuck: bool = true,

    pub fn move(self: *@This(), dt: f64, window_width: u32) zmath.Vec {
        const ww = @as(f32, @floatFromInt(window_width));
        const t = @as(f32, @floatCast(dt));
        if (self.stuck) {
            self.position += (self.velocity * [_]f32{ t, t, 1.0, 1.0 });
            if (self.position[0] <= 0.0) {
                self.velocity[0] = -self.velocity[0];
                self.position[0] = 0.0;
            } else if (self.position[0] + self.size[0] >= ww) {
                self.velocity[0] = -self.velocity[0];
                self.position[0] = ww - self.size[0];
            }
            if (self.position[1] <= 0.0) {
                self.velocity[1] = -self.velocity[1];
                self.position[1] = 0.0;
            }
        }
        return self.position;
    }

    pub fn reset(self: *@This(), position: zmath.Vec, velocity: zmath.Vec) void {
        self.position = position;
        self.velocity = velocity;
    }

    pub fn draw(self: @This(), renderer: sp.Renderer) void {
        renderer.drawSprite(self.sprite.?, self.position, self.size, 0.0, self.color);
    }
};

fn checkBallCollision(ball_pos: zmath.Vec, ball_radius: f32, box_position: zmath.Vec, box_size: zmath.Vec) bool {
    const center = ball_pos + [_]f32{ ball_radius, ball_radius, 0.0, 0.0 };
    const aabb_half_ext = box_size * [_]f32{ 0.5, 0.5, 0.0, 0.0 };
    const aabb_center = box_position + aabb_half_ext;
    var diff = center - aabb_center;
    const clamped = zmath.clamp(diff, -aabb_half_ext, aabb_half_ext);
    const closest = aabb_center + clamped;
    diff = closest - center;
    return zmath.length2(diff)[0] < ball_radius;
}

fn checkCollision(pos1: zmath.Vec, sz1: zmath.Vec, pos2: zmath.Vec, sz2: zmath.Vec) bool {
    const coll_x = (pos1[0] + sz1[0] >= pos2[0]) and (pos2[0] + sz2[0] >= pos1[0]);
    const coll_y = (pos1[1] + sz1[1] >= pos2[1]) and (pos2[1] + sz2[1] >= pos1[1]);
    return coll_x and coll_y;
}
