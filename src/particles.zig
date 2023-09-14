const std = @import("std");

const gl = @import("zopengl");
const zmath = @import("zmath");

const Ball = @import("game.zig").Ball;
const Shader = @import("Shader.zig");
const Texture = @import("Texture.zig");

pub const Particle = struct {
    position: zmath.Vec = zmath.f32x4(0, 0, 0, 1),
    velocity: zmath.Vec = zmath.f32x4s(0),
    color: zmath.Vec = zmath.f32x4s(1),
    life: f32 = 0,
};

pub const ParticleGenerator = struct {
    const Self = @This();

    num_particles: u32 = 500,
    shader: Shader,
    sprite: Texture,
    particles: std.ArrayList(Particle),
    prng: std.rand.Random,
    vao: u32,
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: std.mem.Allocator, comptime max_particles: u32, shader: Shader, texture: Texture) !Self {
        var rnd = std.rand.DefaultPrng.init(0);
        var prng = rnd.random();

        const p_quad = [_]f32{
            0, 1, 0, 1,
            1, 0, 1, 0,
            0, 0, 0, 0,

            0, 1, 0, 1,
            1, 1, 1, 1,
            1, 0, 1, 0,
        };

        var vao: u32 = undefined;
        var vbo: u32 = undefined;

        gl.genVertexArrays(1, &vao);
        gl.genBuffers(1, &vbo);
        gl.bindVertexArray(vao);
        // fill mesh buffer
        gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
        gl.bufferData(gl.ARRAY_BUFFER, p_quad.len * @sizeOf(f32), &p_quad, gl.STATIC_DRAW);
        // set mesh attributes
        gl.enableVertexAttribArray(0);
        gl.vertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), null);
        gl.bindVertexArray(0);

        // create default particle instances
        var arena = std.heap.ArenaAllocator.init(allocator);
        var particles = try std.ArrayList(Particle).initCapacity(arena.allocator(), max_particles);
        for (0..max_particles) |_| {
            particles.appendAssumeCapacity(Particle{});
        }

        return Self{
            .num_particles = max_particles,
            .shader = shader,
            .sprite = texture,
            .particles = particles,
            .prng = prng,
            .vao = vao,
            .arena = arena,
        };
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
    }

    pub fn update(self: *Self, dt: f64, ball: Ball, new_particles: u32, offset: zmath.Vec) void {
        const dtf = @as(f32, @floatCast(dt));
        // add new particles
        for (0..new_particles) |_| {
            const unused_particle = self.firstUnusedParticle();
            self.respawnParticle(&self.particles.items[unused_particle], ball, offset);
        }
        // update all particles
        for (self.particles.items) |*p| {
            p.life -= dtf;
            if (p.life > 0.0) {
                // particle is alive, thus update
                p.position -= p.velocity * [_]f32{ dtf, dtf, 0, 0 };
                p.color[3] -= dtf * 2.5;
            }
        }
    }

    var last_used_particle: usize = 0;

    fn firstUnusedParticle(self: *Self) usize {
        // search from last used particle, this will usually return alomost instantly
        for (last_used_particle..self.num_particles) |i| {
            if (self.particles.items[i].life <= 0.0) {
                last_used_particle = i;
                return i;
            }
        }
        // otherwise do a linear search
        for (0..last_used_particle) |i| {
            if (self.particles.items[i].life <= 0.0) {
                last_used_particle = i;
                return i;
            }
        }
        // override first particle if all others are alive
        last_used_particle = 0;
        return 0;
    }

    fn respawnParticle(self: *Self, particle: *Particle, ball: Ball, offset: zmath.Vec) void {
        const random: f32 = self.prng.float(f32) * 10 - 5;
        const rColor = 0.5 + self.prng.float(f32);

        particle.position = ball.position + [_]f32{ random, random, 0, 0 } + offset;
        particle.color = zmath.f32x4(rColor, rColor, rColor, 1.0);
        particle.life = 1.0;
        particle.velocity = ball.velocity * zmath.f32x4s(0.1);
    }

    pub fn draw(self: Self) void {
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE);
        self.shader.use();
        for (self.particles.items) |particle| {
            if (particle.life > 0.0) {
                self.shader.setVector2f("offset", particle.position[0], particle.position[1], false);
                self.shader.setVec4("color", particle.color, false);
                self.sprite.bind();
                gl.bindVertexArray(self.vao);
                gl.drawArrays(gl.TRIANGLES, 0, 6);
                gl.bindVertexArray(0);
            }
        }
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    }
};
