const std = @import("std");
const gl = @import("zopengl");

pub fn new() Texture {
    var id: u32 = undefined;
    gl.genTextures(1, &id);

    return Texture{
        .id = id,
        .width = 0,
        .height = 0,
        .format = gl.RGB,
        .internal_format = gl.RGBA,
        .wrap_s = gl.REPEAT,
        .wrap_t = gl.REPEAT,
        .filter_min = gl.LINEAR,
        .filter_mag = gl.LINEAR,
    };
}

pub const Texture = struct {
    id: u32 = undefined,
    width: u32 = undefined,
    height: u32 = undefined,
    format: u32 = undefined,
    internal_format: u32 = undefined,
    wrap_s: u32 = undefined,
    wrap_t: u32 = undefined,
    filter_min: u32 = undefined,
    filter_mag: u32 = undefined,

    pub fn deinit(self: *Texture) void {
        gl.deleteTextures(1, self.id);
        self.id = undefined;
    }

    pub fn bind(self: Texture) void {
        gl.bindTexture(gl.TEXTURE_2D, self.id);
    }

    pub fn generate(self: *Texture, width: u32, height: u32, data: []const u8) void {
        self.width = width;
        self.height = height;

        gl.bindTexture(gl.TEXTURE_2D, self.id);
        gl.texImage2D(gl.TEXTURE_2D, 0, self.internal_format, @intCast(width), @intCast(height), 0, self.format, gl.UNSIGNED_BYTE, @ptrCast(data));
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, @intCast(self.wrap_s));
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, @intCast(self.wrap_t));
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, @intCast(self.filter_min));
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, @intCast(self.filter_mag));

        gl.bindTexture(gl.TEXTURE_2D, 0);
    }
};
