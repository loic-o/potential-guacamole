const std = @import("std");
const gl = @import("zopengl");

pub const Texture = @This();

id: u32,

pub fn generate(
    internal_format: u32,
    width: u32,
    height: u32,
    format: u32,
    wrap_s: u32,
    wrap_t: u32,
    filter_min: u32,
    filter_mag: u32,
    data: ?[]const u8,
) Texture {
    var id: u32 = undefined;
    gl.genTextures(1, &id);
    gl.bindTexture(gl.TEXTURE_2D, id);
    gl.texImage2D(gl.TEXTURE_2D, 0, internal_format, @intCast(width), @intCast(height), 0, format, gl.UNSIGNED_BYTE, @ptrCast(data));
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, @intCast(wrap_s));
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, @intCast(wrap_t));
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, @intCast(filter_min));
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, @intCast(filter_mag));

    gl.bindTexture(gl.TEXTURE_2D, 0);

    return Texture{ .id = id };
}

pub fn bind(self: Texture) void {
    gl.bindTexture(gl.TEXTURE_2D, self.id);
}

pub fn deinit(self: *Texture) void {
    gl.deleteTextures(1, &[_]u32{self.id});
    self.id = undefined;
}
