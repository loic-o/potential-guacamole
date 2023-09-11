const std = @import("std");
const shader = @import("shader.zig");
const texture = @import("texture.zig");

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
    textures = texture.init(allocator);
    shaders = shader.init(allocator);
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
var shaders: std.StringHashMap(shader.Shader) = undefined;
var textures: std.StringHashMap(texture.Texture) = undefined;

fn loadShaderFromFile(vertex_path: []const u8, fragment_path: []const u8, geometry_path: []const u8) []u8 {
    _ = geometry_path;
    _ = fragment_path;
    _ = vertex_path;
    @panic("not implemented");
}

pub fn loadShader(vertex_path: []const u8, fragment_path: []const u8, geometry_path: []const u8, name: []const u8) shader.Shader {
    _ = name;
    _ = geometry_path;
    _ = fragment_path;
    _ = vertex_path;
    @panic("not implemented");
}

pub fn getShader(name: []const u8) ?shader.Shader {
    shaders.get(name);
}

fn loadTextureFromFile(image_path: []const u8, alpha: bool) []u8 {
    _ = alpha;
    _ = image_path;
    @panic("not implemented");
}

pub fn loadTexture(image_path: []const u8, alpha: bool, name: []const u8) texture.Texture {
    _ = name;
    _ = alpha;
    _ = image_path;
    @panic("not implemented");
}

pub fn getTexture(name: []const u8) ?texture.Texture {
    textures.get(name);
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
