const std = @import("std");
const gl = @import("zopengl");

const Shader = @import("Shader.zig");
const Texture = @import("Texture.zig");

pub const PostProcessor = @This();
const Self = PostProcessor;

pub fn init(shader: Shader, width: u32, height: u32) !Self {
    var self = Self{
        .post_processing_shader = shader,
        .width = width,
        .height = height,
    };

    gl.genFramebuffers(1, &self.msfbo);
    gl.genFramebuffers(1, &self.fbo);
    gl.genRenderbuffers(1, &self.rbo);

    gl.bindFramebuffer(gl.FRAMEBUFFER, self.msfbo);
    gl.bindRenderbuffer(gl.RENDERBUFFER, self.rbo);
    gl.renderbufferStorageMultisample(gl.RENDERBUFFER, 4, gl.RGB, @intCast(width), @intCast(height));
    gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.RENDERBUFFER, self.rbo);

    if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) {
        std.log.err("ERROR::POSTPROCESSOR: Failed to initialize MSFBO", .{});
        return error.FramebufferIncompleteMS;
    }

    gl.bindFramebuffer(gl.FRAMEBUFFER, self.fbo);
    self.texture = Texture.generate(gl.RGB, @intCast(width), @intCast(height), gl.RGB, gl.REPEAT, gl.REPEAT, gl.LINEAR, gl.LINEAR, null);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, self.texture.id, 0);

    if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) {
        std.log.err("ERROR::POSTPROCESSOR: Failed to initialize MSFBO", .{});
        return error.FramebufferIncomplete;
    }

    gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

    self.initRenderData();
    self.post_processing_shader.setInteger("scene", 0, true);
    const offset: f32 = 1.0 / 300.0;
    const offsets = [18]f32{
        -offset, offset,
        0.0,     offset,
        offset,  offset,
        -offset, 0.0,
        0.0,     0.0,
        offset,  0.0,
        -offset, -offset,
        0.0,     -offset,
        offset,  -offset,
    };
    gl.uniform2fv(gl.getUniformLocation(self.post_processing_shader.id.?, "offsets"), 9, @ptrCast(&offsets));

    const edge_kernel = [9]i32{
        -1, -1, -1,
        -1, 8,  -1,
        -1, -1, -1,
    };
    gl.uniform1iv(gl.getUniformLocation(self.post_processing_shader.id.?, "edge_kernel"), 9, @ptrCast(&edge_kernel));

    const blur_kernel = [9]f32{
        1.0 / 16.0, 2.0 / 16.0, 1.0 / 16.0,
        2.0 / 16.0, 2.0 / 16.0, 2.0 / 16.0,
        1.0 / 16.0, 2.0 / 16.0, 1.0 / 16.0,
    };
    gl.uniform1fv(gl.getUniformLocation(self.post_processing_shader.id.?, "blur_kernel"), 9, @ptrCast(&blur_kernel));

    return self;
}

post_processing_shader: Shader,
texture: Texture = undefined,
width: u32,
height: u32,
confuse: bool = false,
chaos: bool = false,
shake: bool = false,

msfbo: u32 = undefined,
fbo: u32 = undefined,
rbo: u32 = undefined,
vao: u32 = undefined,

pub fn deinit(self: *Self) void {
    gl.deleteRenderbuffers(1, &self.rbo);
    gl.deleteFramebuffers(1, &self.msfbo);
    gl.deleteFramebuffers(1, &self.fbo);
    gl.deleteVertexArrayBuffers(1, &self.vao);
}

pub fn beginRender(self: *Self) void {
    gl.bindFramebuffer(gl.FRAMEBUFFER, self.msfbo);
    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);
}

pub fn render(self: *Self, time: f32) void {
    // set the uniforms/options
    self.post_processing_shader.use();
    self.post_processing_shader.setFloat("time", time, false);
    self.post_processing_shader.setInteger("confuse", @intFromBool(self.confuse), false);
    self.post_processing_shader.setInteger("chaos", @intFromBool(self.chaos), false);
    self.post_processing_shader.setInteger("shake", @intFromBool(self.shake), false);

    gl.activeTexture(gl.TEXTURE0);
    self.texture.bind();
    gl.bindVertexArray(self.vao);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
    gl.bindVertexArray(0);
}

pub fn endRender(self: *Self) void {
    gl.bindFramebuffer(gl.READ_FRAMEBUFFER, self.msfbo);
    gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, self.fbo);
    gl.blitFramebuffer(0, 0, @intCast(self.width), @intCast(self.height), 0, 0, @intCast(self.width), @intCast(self.height), gl.COLOR_BUFFER_BIT, gl.NEAREST);
    gl.bindFramebuffer(gl.FRAMEBUFFER, 0);
}

fn initRenderData(self: *Self) void {
    var vbo: u32 = undefined;
    const vertices = [_]f32{
        // pos        // tex
        -1.0, -1.0, 0.0, 0.0,
        1.0,  1.0,  1.0, 1.0,
        -1.0, 1.0,  0.0, 1.0,

        -1.0, -1.0, 0.0, 0.0,
        1.0,  -1.0, 1.0, 0.0,
        1.0,  1.0,  1.0, 1.0,
    };
    gl.genVertexArrays(1, &self.vao);
    gl.genBuffers(1, &vbo);

    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, gl.STATIC_DRAW);

    gl.bindVertexArray(self.vao);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), null);
    gl.bindBuffer(gl.ARRAY_BUFFER, 0);
    gl.bindVertexArray(0);
}
