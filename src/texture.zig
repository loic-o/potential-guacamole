const std = @import("std");
const gl = @import("zopengl");

pub fn new() Texture {
    var id: u32 = undefined;
    gl.GenTextures(1, &id);

    return Texture{
        .id = id,
        .width = 0,
        .height = 0,
        .format = gl.RGB,
        .internal_format = gl.RGBA,
        .wrap_s = gl.REPEAT,
        .wrap_t = gl.REPEAT,
        .min_filter = gl.LINEAR,
        .mag_filter = gl.LINEAR,
    };
}

pub const Texture = struct {
    id: u32 = undefined,
    width: u32 = undefined,
    height: u32 = undefined,
    format: gl.TextureFormat = undefined,
    internal_format: gl.TextureInternalFormat = undefined,
    wrap_s: gl.TextureWrap = undefined,
    wrap_t: gl.TextureWrap = undefined,
    filter_min: gl.TextureFilter = undefined,
    filter_mag: gl.TextureFilter = undefined,

    pub fn bind(self: Texture) void {
        gl.BindTexture(gl.TEXTURE_2D, self.id);
    }

    pub fn generate(self: *Texture, width: u32, height: u32, data: []const u8) void {
        self.width = width;
        self.height = height;

        gl.bindTexture(gl.TEXTURE_2D, self.id);
        gl.texImage2D(gl.TEXTURE_2D, 0, self.internal_format, width, height, 0, self.format, gl.UNSIGNED_BYTE, @ptrCast(data));
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, self.wrap_s);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, self.wrap_t);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, self.filter_min);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, self.filter_mag);

        gl.bindTexture(gl.TEXTURE_2D, 0);
    }
};
