const std = @import("std");

const zmath = @import("zmath");
const gl = @import("zopengl");

const sp = @import("sprite.zig");
const Texture = @import("Texture.zig");

pub const Powerup = @This();
const Self = Powerup;

pub const PowerupType = enum {
    speed,
    sticky,
    passThrough,
    padSizeIncrease,
    confuse,
    chaos,
};

type: PowerupType,
duration: f32,
activated: bool = false,
destroyed: bool = false,
position: zmath.Vec,
size: zmath.Vec = zmath.f32x4(60.0, 20.0, 0.0, 0.0),
velocity: zmath.Vec = zmath.f32x4(0.0, 150.0, 0.0, 0.0),
color: zmath.Vec,
texture: Texture,

pub fn init(powerup_type: PowerupType, color: zmath.Vec, duration: f32, position: zmath.Vec, texture: Texture) Self {
    return Self{
        .type = powerup_type,
        .color = color,
        .duration = duration,
        .position = position,
        .texture = texture,
    };
}

pub fn deinit(self: *Self) void {
    _ = self;
}

pub fn draw(self: Self, renderer: sp.Renderer) void {
    renderer.drawSprite(self.texture, self.position, self.size, 0.0, self.color);
}
