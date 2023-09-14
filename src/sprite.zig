const std = @import("std");
const gl = @import("zopengl");
const zmath = @import("zmath");
const Shader = @import("Shader.zig");
const Texture = @import("Texture.zig");

pub fn new(shader: Shader) Renderer {
    return Renderer{
        .shader = shader,
        .vao = undefined,
    };
}

pub const Renderer = struct {
    shader: Shader,
    vao: u32,

    pub fn init(self: *Renderer) void {
        const verts = [_]f32{
            0.0, 1.0, 0.0, 1.0,
            1.0, 0.0, 1.0, 0.0,
            0.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 1.0,
            1.0, 1.0, 1.0, 1.0,
            1.0, 0.0, 1.0, 0.0,
        };
        var vbo: u32 = undefined;
        var vao: u32 = undefined;
        gl.genVertexArrays(1, &vao);
        gl.genBuffers(1, &vbo);

        self.vao = vao;
        gl.bindVertexArray(self.vao);

        gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
        gl.bufferData(gl.ARRAY_BUFFER, verts.len * @sizeOf(f32), &verts, gl.STATIC_DRAW);

        gl.vertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), null);
        gl.enableVertexAttribArray(0);

        gl.bindBuffer(gl.ARRAY_BUFFER, 0);
        gl.bindVertexArray(0);
    }

    pub fn deinit(self: *Renderer) void {
        gl.deleteVertexArrays(1, &self.vao);
        self.vao = undefined;
        std.log.debug("deinit'd the renderer", .{});
    }

    pub fn drawSprite(self: Renderer, texture: Texture, position: zmath.Vec, size: zmath.Vec, rotate: f32, color: zmath.Vec) void {
        var model = zmath.translation(position[0], position[1], 0.0);

        model = zmath.mul(zmath.translation(0.5 * size[0], 0.5 * size[1], 0.0), model);
        const rads = std.math.degreesToRadians(f32, rotate);
        model = zmath.mul(zmath.rotationZ(rads), model);
        model = zmath.mul(zmath.translation(-size[0] * 0.5, -size[1] * 0.5, 0.0), model);

        model = zmath.mul(zmath.scaling(size[0], size[1], 1.0), model);

        self.shader.use();
        self.shader.setMatrix4("model", model, false);
        self.shader.setVec3("spriteColor", color, false);

        gl.activeTexture(gl.TEXTURE0);
        texture.bind();

        gl.bindVertexArray(self.vao);
        gl.drawArrays(gl.TRIANGLES, 0, 6);
        gl.bindVertexArray(0);
    }
};
