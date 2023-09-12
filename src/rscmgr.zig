const std = @import("std");
const gl = @import("zopengl");
const stbi = @import("zstbi");
const sh = @import("shader.zig");
const tx = @import("texture.zig");

const ShaderMapType = std.StringHashMap(sh.Shader);
const TextureMapType = std.StringHashMap(tx.Texture);

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
    shaders = ShaderMapType.init(allocator);
    textures = TextureMapType.init(allocator);
    stbi.init(allocator);
    // stbi.setFlipVerticallyOnLoad(true);
}

pub fn deinit() void {
    for (textures.iterator()) |t| {
        t.value.deinit();
    }
    textures.deinit();

    for (shaders.iterator()) |s| {
        s.value.deinit();
    }
    shaders.deinit();
}

var allocator: std.mem.Allocator = undefined;
var shaders: ShaderMapType = undefined;
var textures: TextureMapType = undefined;

pub fn loadShader(vertex_path: []const u8, fragment_path: []const u8, geometry_path: ?[]const u8, name: []const u8) !sh.Shader {
    const shader = try loadShaderFromFile(vertex_path, fragment_path, geometry_path);
    try shaders.put(name, shader);
    return shaders.get(name).?;
}

pub fn loadTexture(image_path: []const u8, name: []const u8) !tx.Texture {
    const texture = try loadTextureFromFile(image_path);
    try textures.put(name, texture);
    return textures.get(name).?;
}

pub fn getShader(name: []const u8) ?sh.Shader {
    return shaders.get(name);
}

pub fn getTexture(name: []const u8) ?tx.Texture {
    return textures.get(name);
}

pub fn clear() void {
    for (textures.iterator()) |t| {
        t.value.deinit();
    }
    textures.clearRetainingCapacity();

    for (shaders.iterator()) |s| {
        s.value.deinit();
    }
    shaders.clearRetainingCapacity();
}

fn loadShaderFromFile(vertex_path: []const u8, fragment_path: []const u8, geometry_path: ?[]const u8) !sh.Shader {
    const vshader_file = try std.fs.cwd().openFile(vertex_path, .{ .mode = .read_only });
    defer vshader_file.close();
    var vertex_code = try allocator.alloc(u8, try vshader_file.getEndPos());
    _ = try vshader_file.read(vertex_code);
    defer allocator.free(vertex_code);

    const fshader_file = try std.fs.cwd().openFile(fragment_path, .{ .mode = .read_only });
    defer fshader_file.close();
    var fragment_code = try allocator.alloc(u8, try fshader_file.getEndPos());
    _ = try fshader_file.read(fragment_code);
    defer allocator.free(fragment_code);

    var geometry_code: ?[]const u8 = null;
    if (geometry_path) |path| {
        const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
        defer file.close();
        var code = try allocator.alloc(u8, try file.getEndPos());
        _ = try file.read(code);
        geometry_code = code;
    }
    // defer allocator.free(geometry_code.?);

    var shader = sh.new();
    try shader.compile(vertex_code, fragment_code, geometry_code);
    return shader;
}

fn loadTextureFromFile(image_path: []const u8) !tx.Texture {
    var texture = tx.new();
    errdefer texture.deinit();

    var image = try stbi.Image.loadFromFile(@ptrCast(image_path), 0);
    defer image.deinit();

    switch (image.num_components) {
        1 => {
            texture.internal_format = gl.RED;
            texture.format = gl.RED;
        },
        3 => {
            texture.internal_format = gl.RGB;
            texture.format = gl.RGB;
        },
        4 => {
            texture.internal_format = gl.RGBA;
            texture.format = gl.RGBA;
        },
        else => unreachable,
    }
    texture.generate(image.width, image.height, image.data);
    return texture;
}
