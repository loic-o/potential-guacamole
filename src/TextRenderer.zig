const std = @import("std");

const gl = @import("zopengl");
const zmath = @import("zmath");
const ft = @import("freetype");

const ResourceManager = @import("ResourceManager.zig");
const Shader = @import("Shader.zig");

pub const TextRenderer = @This();
const Self = TextRenderer;

pub const Character = struct {
    texture_id: u32 = undefined,
    size: zmath.Vec = undefined,
    bearing: zmath.Vec = undefined,
    advance: u32 = undefined,
};

characters: std.AutoHashMap(u8, Self.Character) = undefined,
text_shader: Shader = undefined,
vao: u32 = undefined,
vbo: u32 = undefined,

pub fn init(allocator: std.mem.Allocator, resource_manager: *ResourceManager, width: u32, height: u32) !Self {
    var self = Self{};
    self.characters = std.AutoHashMap(u8, Self.Character).init(allocator);
    self.text_shader = try resource_manager.loadShader("shaders/text_2d.vert", "shaders/text_2d.frag", null, "text");

    // load and configure the shader
    const projection = zmath.orthographicOffCenterRhGl(
        0.0,
        @as(f32, @floatFromInt(width)),
        0.0,
        @as(f32, @floatFromInt(height)),
        -1.0,
        1.0,
    );
    self.text_shader.setMatrix4("projection", projection, true);
    self.text_shader.setInteger("text", 0, false);

    // configure the VAO/VBO for texture quads
    gl.genVertexArrays(1, &self.vao);
    gl.genBuffers(1, &self.vbo);
    gl.bindVertexArray(self.vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);
    gl.bufferData(gl.ARRAY_BUFFER, 6 * 4 * @sizeOf(f32), null, gl.DYNAMIC_DRAW);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), null);
    gl.bindBuffer(gl.ARRAY_BUFFER, 0);
    gl.bindVertexArray(0);

    return self;
}

pub fn deinit(self: *Self) void {
    self.characters.deinit();
}

pub fn load(self: *Self, font_file_path: []const u8, font_size: u32) !void {
    const library = try ft.Library.init();
    defer library.deinit();
    const face = try library.createFace(@ptrCast(font_file_path), 0);
    defer face.deinit();
    try face.setPixelSizes(0, font_size);
    // disable byte-alignment restriction
    gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
    // pre-load/compile chars for the first 128 ASCII characters
    for (0..128) |i| {
        const ch: u8 = @intCast(i);
        try face.loadChar(ch, .{ .render = true });
        var tex: u32 = undefined;
        gl.genTextures(1, &tex);
        gl.bindTexture(gl.TEXTURE_2D, tex);
        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RED,
            @intCast(face.glyph().bitmap().width()),
            @intCast(face.glyph().bitmap().rows()),
            0,
            gl.RED,
            gl.UNSIGNED_BYTE,
            @ptrCast(face.glyph().bitmap().buffer()),
        );
        // set texture options
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

        // store char values for later use...
        const char = Character{
            .texture_id = tex,
            .size = zmath.f32x4(@floatFromInt(face.glyph().bitmap().width()), @floatFromInt(face.glyph().bitmap().rows()), 0, 0),
            .bearing = zmath.f32x4(@floatFromInt(face.glyph().bitmapLeft()), @floatFromInt(face.glyph().bitmapTop()), 0, 0),
            .advance = @intCast(face.glyph().advance().x),
        };
        try self.characters.put(ch, char);
    }
}

pub fn renderText(self: Self, text: []const u8, x: f32, y: f32, scale: f32, color: zmath.Vec) !void {
    var curr_x = x;
    self.text_shader.use();
    self.text_shader.setVec3("textColor", color, false);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindVertexArray(self.vao);

    for (text) |c| {
        const ch = self.characters.get(c).?;

        const xpos = curr_x + ch.bearing[0] * scale;
        const ypos = y + (self.characters.get('H').?.bearing[1] - ch.bearing[1]) * scale;

        const w = ch.size[0] * scale;
        const h = ch.size[1] * scale;
        // update the vbo
        const vertices = [24]f32{
            xpos,     ypos + h, 0.0, 1.0,
            xpos + w, ypos,     1.0, 0.0,
            xpos,     ypos,     0.0, 0.0,

            xpos,     ypos + h, 0.0, 1.0,
            xpos + w, ypos + h, 1.0, 1.0,
            xpos + w, ypos,     1.0, 0.0,
        };
        // render glyph texture over quad
        gl.bindTexture(gl.TEXTURE_2D, ch.texture_id);
        // update contents of VBO memory
        gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);
        gl.bufferSubData(gl.ARRAY_BUFFER, 0, @sizeOf(f32) * 6 * 4, &vertices);
        gl.bindBuffer(gl.ARRAY_BUFFER, 0);
        // render quad
        gl.drawArrays(gl.TRIANGLES, 0, 6);
        // advance cursors for next glyph
        curr_x += @as(f32, @floatFromInt(ch.advance >> 6)) * scale;
    }
    gl.bindVertexArray(0);
    gl.bindTexture(gl.TEXTURE_2D, 0);
}
