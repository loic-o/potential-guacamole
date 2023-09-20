const std = @import("std");
const glfw = @import("zglfw");
const zmath = @import("zmath");
const zaudio = @import("zaudio");

const Texture = @import("Texture.zig");
const sp = @import("sprite.zig");
const lvl = @import("level.zig");
const ptcl = @import("particles.zig");
const ResourceManager = @import("ResourceManager.zig");
const PostProcessor = @import("PostProcessor.zig");
const Powerup = @import("Powerup.zig");

const default_player_size = zmath.f32x4(100.0, 20.0, 0.0, 0.0);
const default_player_velocity: f32 = 500.0;
const initial_ball_velocity = zmath.f32x4(100.0, -350.0, 0.0, 0.0);
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

const Sounds = struct {
    engine: *zaudio.Engine = undefined,
    bg_music: *zaudio.Sound = undefined,
    brick_collide: *zaudio.Sound = undefined,
    solid_collide: *zaudio.Sound = undefined,
    paddle_collide: *zaudio.Sound = undefined,
    powerup: *zaudio.Sound = undefined,

    pub fn init(allocator: std.mem.Allocator) !Sounds {
        zaudio.init(allocator);
        const engine = try zaudio.Engine.create(null);
        const self = Sounds{
            .engine = engine,
            .bg_music = try engine.createSoundFromFile("audio/breakout.mp3", .{ .flags = .{ .stream = true } }),
            .brick_collide = try engine.createSoundFromFile("audio/bleep.mp3", .{}),
            .solid_collide = try engine.createSoundFromFile("audio/solid.wav", .{}),
            .paddle_collide = try engine.createSoundFromFile("audio/bleep.wav", .{}),
            .powerup = try engine.createSoundFromFile("audio/powerup.wav", .{}),
        };
        self.bg_music.setLooping(true);
        self.bg_music.setVolume(0.5);
        try self.bg_music.start();
        return self;
    }

    pub fn deinit(self: *Sounds) !void {
        if (self.bg_music.isPlaying()) {
            try self.bg_music.stop();
        }
        self.bg_music.destroy();
        self.brick_collide.destroy();
        self.solid_collide.destroy();
        self.paddle_collide.destroy();
        self.powerup.destroy();

        self.engine.destroy();
        zaudio.deinit();
    }
};

pub const Game = struct {
    allocator: std.mem.Allocator = undefined,
    state: GameState = GameState.game_active,
    keys: [1024]bool,
    width: u32,
    height: u32,
    renderer: sp.Renderer = undefined,
    levels: [4]lvl.Level,
    current_level: u32 = 0,
    player: Player = undefined,
    ball: Ball = undefined,
    particles: ptcl.ParticleGenerator = undefined,
    resource_manager: ResourceManager = undefined,
    effects: PostProcessor = undefined,
    shake_time: f32 = 0.0,
    powerups: std.ArrayList(Powerup) = undefined,
    rng: std.rand.DefaultPrng = undefined,
    audio: Sounds = undefined,

    pub fn init(self: *Game, allocator: std.mem.Allocator) !void {
        self.allocator = allocator;
        self.resource_manager = ResourceManager.init(allocator);

        self.rng = std.rand.DefaultPrng.init(234234);

        const sprite_shader = try self.resource_manager.loadShader("shaders/sprite.vert", "shaders/sprite.frag", null, "sprite");
        const particle_shader = try self.resource_manager.loadShader("shaders/particle.vert", "shaders/particle.frag", null, "particle");
        const effect_shader = try self.resource_manager.loadShader("shaders/post_processing.vert", "shaders/post_processing.frag", null, "postprocessing");
        const projection = zmath.orthographicOffCenterRhGl(
            0.0, // left
            @floatFromInt(self.width), // right
            0.0, // top
            @floatFromInt(self.height), // bottom
            -1.0,
            1.0, // near, far
        );
        sprite_shader.setInteger("image", 0, true);
        sprite_shader.setMatrix4("projection", projection, false);
        particle_shader.setInteger("sprite", 0, true);
        particle_shader.setMatrix4("projection", projection, false);

        _ = try self.resource_manager.loadTexture("textures/background.jpg", "background");
        _ = try self.resource_manager.loadTexture("textures/awesomeface.png", "face");
        _ = try self.resource_manager.loadTexture("textures/block.png", "block");
        _ = try self.resource_manager.loadTexture("textures/block_solid.png", "block_solid");
        _ = try self.resource_manager.loadTexture("textures/paddle.png", "paddle");
        const ptexture = try self.resource_manager.loadTexture("textures/particle.png", "particle");
        _ = try self.resource_manager.loadTexture("textures/powerup_speed.png", "speed");
        _ = try self.resource_manager.loadTexture("textures/powerup_sticky.png", "sticky");
        _ = try self.resource_manager.loadTexture("textures/powerup_passthrough.png", "passThrough");
        _ = try self.resource_manager.loadTexture("textures/powerup_increase.png", "padSizeIncrease");
        _ = try self.resource_manager.loadTexture("textures/powerup_confuse.png", "confuse");
        _ = try self.resource_manager.loadTexture("textures/powerup_chaos.png", "chaos");

        self.renderer = sp.new(sprite_shader);
        self.renderer.init();
        self.particles = try ptcl.ParticleGenerator.init(self.allocator, 500, particle_shader, ptexture);
        self.effects = try PostProcessor.init(effect_shader, self.width, self.height);
        self.powerups = std.ArrayList(Powerup).init(allocator);
        self.audio = try Sounds.init(allocator);

        self.levels[0] = try lvl.loadLevel(allocator, self.resource_manager, "levels/one.lvl", self.width, self.height / 2);
        self.levels[1] = try lvl.loadLevel(allocator, self.resource_manager, "levels/two.lvl", self.width, self.height / 2);
        self.levels[2] = try lvl.loadLevel(allocator, self.resource_manager, "levels/three.lvl", self.width, self.height / 2);
        self.levels[3] = try lvl.loadLevel(allocator, self.resource_manager, "levels/four.lvl", self.width, self.height / 2);

        self.player = Player{
            .position = zmath.f32x4(
                @as(f32, @floatFromInt(self.width)) / 2.0 - (default_player_size[0] / 2.0),
                @as(f32, @floatFromInt(self.height)) - default_player_size[1],
                0.0,
                1.0,
            ),
            .sprite = self.resource_manager.getTexture("paddle"),
        };

        const ball_pos = self.player.position + [_]f32{ default_player_size[0] / 2.0 - default_ball_radius, -default_ball_radius * 2.0, 0.0, 0.0 };
        self.ball = Ball{
            .position = ball_pos,
            .sprite = self.resource_manager.getTexture("face"),
            .velocity = initial_ball_velocity,
        };

        std.log.debug("game initialization complete.", .{});
    }

    pub fn deinit(self: *Game) void {
        self.audio.deinit() catch |err| {
            std.log.err("failed to deinit sound: {}", .{err});
        };
        self.particles.deinit();
        for (&self.levels) |*level| {
            level.deinit();
        }
        for (self.powerups.items) |*pu| {
            pu.deinit();
        }
        self.powerups.deinit();
        self.renderer.deinit();
        self.resource_manager.deinit();
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

    pub fn update(self: *Game, dt: f64) !void {
        _ = self.ball.move(dt, self.width);
        try self.doCollisions();

        self.particles.update(dt, self.ball, 2, zmath.f32x4(self.ball.radius / 2, self.ball.radius / 2, 0, 0));

        self.updatePowerups(dt);

        if (self.shake_time > 0.0) {
            self.shake_time -= @as(f32, @floatCast(dt));
            if (self.shake_time <= 0.0) {
                self.effects.shake = false;
            }
        }

        if (self.ball.position[1] >= @as(f32, @floatFromInt(self.height))) {
            // not sure i want to do this....start over?
            self.resetLevel();
            self.resetPlayer();
        }
    }

    fn shouldSpawn(self: *Game, chance: u32) bool {
        var random: u32 = self.rng.random().uintLessThan(u32, 1 << 16);
        // std.log.debug("rng: {}", .{random});
        return ((random % chance) == 0);
    }

    fn spawnPowerups(self: *Game, block: lvl.Brick) !void {
        if (self.shouldSpawn(75)) {
            try self.powerups.append(Powerup.init(
                Powerup.PowerupType.speed, // type
                zmath.f32x4(0.5, 0.5, 1.0, 1.0), // color
                0.0, // duration
                block.position, // position
                self.resource_manager.getTexture("speed").?, // texture
            ));
        }
        if (self.shouldSpawn(75)) {
            try self.powerups.append(Powerup.init(
                Powerup.PowerupType.sticky, // type
                zmath.f32x4(1.0, 0.5, 1.0, 1.0), // color
                20.0, // duration
                block.position, // position
                self.resource_manager.getTexture("sticky").?, // texture
            ));
        }
        if (self.shouldSpawn(75)) {
            try self.powerups.append(Powerup.init(
                Powerup.PowerupType.passThrough, // type
                zmath.f32x4(0.5, 1.0, 0.5, 1.0), // color
                10.0, // duration
                block.position, // position
                self.resource_manager.getTexture("passThrough").?, // texture
            ));
        }
        if (self.shouldSpawn(75)) {
            try self.powerups.append(Powerup.init(
                Powerup.PowerupType.padSizeIncrease, // type
                zmath.f32x4(1.0, 0.6, 0.4, 1.0), // color
                0.0, // duration
                block.position, // position
                self.resource_manager.getTexture("padSizeIncrease").?, // texture
            ));
        }
        if (self.shouldSpawn(15)) {
            try self.powerups.append(Powerup.init(
                Powerup.PowerupType.confuse, // type
                zmath.f32x4(1.0, 0.3, 0.3, 1.0), // color
                15.0, // duration
                block.position, // position
                self.resource_manager.getTexture("confuse").?, // texture
            ));
        }
        if (self.shouldSpawn(15)) {
            try self.powerups.append(Powerup.init(
                Powerup.PowerupType.chaos, // type
                zmath.f32x4(0.9, 0.25, 0.25, 1.0), // color
                15.0, // duration
                block.position, // position
                self.resource_manager.getTexture("chaos").?, // texture
            ));
        }
    }

    fn activatePowerup(self: *Game, powerup: Powerup) void {
        switch (powerup.type) {
            .speed => self.ball.velocity *= zmath.f32x4(1.2, 1.2, 1, 1),
            .sticky => {
                self.ball.sticky = true;
                self.player.color = zmath.f32x4(1.0, 0.5, 1.0, 1.0);
            },
            .passThrough => {
                self.ball.passThrough = true;
                self.ball.color = zmath.f32x4(1.0, 0.5, 0.5, 1.0);
            },
            .padSizeIncrease => self.player.size[0] += 50.0,
            .confuse => {
                if (!self.effects.chaos) {
                    self.effects.confuse = true;
                }
            },
            .chaos => {
                if (!self.effects.confuse) {
                    self.effects.chaos = true;
                }
            },
        }
    }

    fn updatePowerups(self: *Game, delta_time: f64) void {
        const dt: f32 = @as(f32, @floatCast(delta_time));
        for (self.powerups.items) |*pu| {
            pu.position += (pu.velocity * zmath.f32x4(dt, dt, 1, 1));
            if (pu.activated) {
                pu.duration -= dt;
                if (pu.duration <= 0.0) {
                    // remove powerup from list (will later be removed)
                    pu.activated = false;
                    // deactivate effects
                    switch (pu.type) {
                        .sticky => {
                            if (!isOtherPowerupActive(self.powerups, .sticky)) {
                                // only reset if no other powerup of type sticky is active
                                self.ball.sticky = false;
                                self.player.color = zmath.f32x4s(1.0);
                            }
                        },
                        .passThrough => {
                            if (!isOtherPowerupActive(self.powerups, .passThrough)) {
                                // only reset if no other powerup of type passThrough is active
                                self.ball.passThrough = false;
                                self.player.color = zmath.f32x4s(1.0);
                            }
                        },
                        .confuse => {
                            if (!isOtherPowerupActive(self.powerups, .confuse)) {
                                // only reset if no other powerup of type confuse is active
                                self.effects.confuse = false;
                            }
                        },
                        .chaos => {
                            if (!isOtherPowerupActive(self.powerups, .chaos)) {
                                // only reset if no other powerup of type chaos is active
                                self.effects.chaos = false;
                            }
                        },
                        else => {},
                    }
                }
            }
        }
        // clear out destroyed powerups;
        var i: usize = 0;
        while (i < self.powerups.items.len) {
            if (self.powerups.items[i].destroyed and !self.powerups.items[i].activated) {
                _ = self.powerups.orderedRemove(i);
            } else {
                i += 1;
            }
        }
    }

    fn isOtherPowerupActive(list: std.ArrayList(Powerup), pu_type: Powerup.PowerupType) bool {
        for (list.items) |pu| {
            if (pu.activated and pu.type == pu_type) return true;
        }
        return false;
    }

    pub fn render(self: *Game) void {
        if (self.state == .game_active) {
            // begin rendering to the post processing framebuffer
            self.effects.beginRender();
            // render the frame
            self.renderer.drawSprite(
                self.resource_manager.getTexture("background").?,
                zmath.f32x4(0.0, 0.0, 0.0, 1.0),
                zmath.f32x4(@as(f32, @floatFromInt(self.width)), @as(f32, @floatFromInt(self.height)), 1.0, 0.0),
                0.0,
                zmath.f32x4s(1.0),
            );

            self.levels[self.current_level].draw(self.renderer);

            for (self.powerups.items) |pu| {
                if (!pu.destroyed) {
                    pu.draw(self.renderer);
                }
            }

            self.player.draw(self.renderer);
            self.particles.draw();

            self.ball.draw(self.renderer);
            // end rendering to the post processing framebuffer
            self.effects.endRender();
            // render the post processing quad
            self.effects.render(@floatCast(glfw.getTime()));
        }
    }

    fn resetLevel(self: *@This()) void {
        for (self.levels[self.current_level].bricks.items) |*br| {
            br.destroyed = false;
        }
    }

    fn resetPlayer(self: *@This()) void {
        self.player.position = zmath.f32x4(
            @as(f32, @floatFromInt(self.width)) / 2.0 - (default_player_size[0] / 2.0),
            @as(f32, @floatFromInt(self.height)) - default_player_size[1],
            0.0,
            1.0,
        );
        self.ball.stuck = true;
        const ball_pos = self.player.position + [_]f32{ default_player_size[0] / 2.0 - default_ball_radius, -default_ball_radius * 2.0, 0.0, 0.0 };
        self.ball.position = ball_pos;
    }

    fn doCollisions(self: *Game) !void {
        // check all the bricks...
        for (self.levels[self.current_level].bricks.items) |*br| {
            if (!br.destroyed) {
                const collision_result = checkBallCollision(self.ball.position, self.ball.radius, br.position, br.size);
                if (collision_result.collided) {
                    if (!br.is_solid) {
                        br.destroyed = true;
                        try self.spawnPowerups(br.*);
                        self.audio.brick_collide.start() catch {};
                    } else {
                        // solid blocks enable the shake effect
                        self.shake_time = 0.05;
                        self.effects.shake = true;
                        self.audio.solid_collide.start() catch {};
                    }
                    // resolve the collision
                    if (!(self.ball.passThrough and !br.is_solid)) {
                        switch (collision_result.direction.?) {
                            .left, .right => {
                                self.ball.velocity[0] = -self.ball.velocity[0]; // reverse horizontal Direction
                                // relocate
                                const penetration = self.ball.radius - @fabs(collision_result.difference.?[0]);
                                if (collision_result.direction.? == .left) {
                                    self.ball.position[0] += penetration;
                                } else {
                                    self.ball.position[0] -= penetration;
                                }
                            },
                            else => {
                                self.ball.velocity[1] = -self.ball.velocity[1]; // reverse vertical Direction
                                // relocate
                                const penetration = self.ball.radius - @fabs(collision_result.difference.?[1]);
                                if (collision_result.direction.? == .up) {
                                    self.ball.position[1] -= penetration;
                                } else {
                                    self.ball.position[1] += penetration;
                                }
                            },
                        }
                    }
                }
            }
        }
        // check for collisions with powerups
        for (self.powerups.items) |*pu| {
            if (!pu.destroyed) {
                if (pu.position[1] >= @as(f32, @floatFromInt(self.height))) {
                    pu.destroyed = true;
                }
                if (checkCollision(self.player.position, self.player.size, pu.position, pu.size)) {
                    // collided w/ player, activate it!
                    self.activatePowerup(pu.*);
                    pu.destroyed = true;
                    pu.activated = true;
                    self.audio.powerup.start() catch {};
                }
            }
        }
        // check the paddle
        const collision = checkBallCollision(self.ball.position, self.ball.radius, self.player.position, self.player.size);
        if (!self.ball.stuck and collision.collided) {
            // check where it hit the board, and change the velocity based on where it hit the board
            const center_board = self.player.position[0] + self.player.size[0] / 2.0;
            const distance = (self.ball.position[0] + self.ball.radius) - center_board;
            const percentage = distance / (self.player.size[0] / 2.0);
            // then move accordingly
            const strength = 2.0;
            const old_velocity = self.ball.velocity;
            self.ball.velocity[0] = initial_ball_velocity[0] * percentage * strength;
            // this is a prob if the ball makes it inside of the paddle and gets stuck
            // self.ball.velocity[1] = -self.ball.velocity[1];
            // so always just assume that it hit the top (so it wont bounce down and try again...
            self.ball.velocity[1] = -1.0 * @fabs(self.ball.velocity[1]);
            self.ball.velocity = zmath.normalize2(self.ball.velocity) * zmath.length2(old_velocity);
            // if the ball is sticky, mark it as stuck b/c it just landed on the paddle.
            self.ball.stuck = self.ball.sticky;

            self.audio.paddle_collide.start() catch {};
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
    sprite: ?Texture,

    pub fn draw(self: @This(), renderer: sp.Renderer) void {
        renderer.drawSprite(self.sprite.?, self.position, self.size, 0.0, self.color);
    }
};

pub const Ball = struct {
    position: zmath.Vec = zmath.f32x4(0.0, 0.0, 0.0, 1.0),
    size: zmath.Vec = zmath.f32x4(default_ball_radius * 2.0, default_ball_radius * 2.0, 0.0, 0.0),
    color: zmath.Vec = zmath.f32x4s(1.0),
    velocity: zmath.Vec = zmath.f32x4(0.0, 0.0, 0.0, 0.0),
    sprite: ?Texture,
    radius: f32 = 12.5,
    stuck: bool = true,
    sticky: bool = false,
    passThrough: bool = false,

    pub fn move(self: *@This(), dt: f64, window_width: u32) zmath.Vec {
        const ww = @as(f32, @floatFromInt(window_width));
        const t = @as(f32, @floatCast(dt));
        if (!self.stuck) {
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

const CollisionResult = struct {
    collided: bool,
    direction: ?Direction,
    difference: ?zmath.Vec,
};

/// NOTE: a tagged union here - for the return type - is probably appropriate
fn checkBallCollision(ball_pos: zmath.Vec, ball_radius: f32, box_position: zmath.Vec, box_size: zmath.Vec) CollisionResult {
    const center = ball_pos + [_]f32{ ball_radius, ball_radius, 0.0, 0.0 };
    const aabb_half_ext = box_size * [_]f32{ 0.5, 0.5, 0.0, 0.0 };
    const aabb_center = box_position + aabb_half_ext;
    var diff = center - aabb_center;
    const clamped = zmath.clamp(diff, -aabb_half_ext, aabb_half_ext);
    const closest = aabb_center + clamped;
    diff = closest - center;
    if (zmath.length2(diff)[0] < ball_radius) {
        return .{
            .collided = true,
            .direction = vectorDirection(diff),
            .difference = diff,
        };
    } else {
        return .{
            .collided = false,
            .direction = null,
            .difference = null,
        };
    }
}

fn checkCollision(pos1: zmath.Vec, sz1: zmath.Vec, pos2: zmath.Vec, sz2: zmath.Vec) bool {
    const coll_x = (pos1[0] + sz1[0] >= pos2[0]) and (pos2[0] + sz2[0] >= pos1[0]);
    const coll_y = (pos1[1] + sz1[1] >= pos2[1]) and (pos2[1] + sz2[1] >= pos1[1]);
    return coll_x and coll_y;
}

const Direction = enum {
    up,
    right,
    down,
    left,
};

fn vectorDirection(target: zmath.Vec) Direction {
    const compass = [_]zmath.Vec{
        zmath.f32x4(0.0, 1.0, 0.0, 0.0), // up
        zmath.f32x4(1.0, 0.0, 0.0, 0.0), // right
        zmath.f32x4(0.0, -1.0, 0.0, 0.0), // down
        zmath.f32x4(-1.0, 0.0, 0.0, 0.0), // left
    };
    var max: f32 = 0;
    var best_match: ?usize = null;
    for (compass, 0..) |comp, i| {
        const dot_prod = zmath.dot2(zmath.normalize2(target), comp);
        if (dot_prod[0] > max) {
            max = dot_prod[0];
            best_match = i;
        }
    }
    return @enumFromInt(best_match.?);
}
