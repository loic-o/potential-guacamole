const std = @import("std");
const gl = @import("zopengl");
const stbi = @import("zstbi");
const Texture = @import("Texture.zig");
const Shader = @import("Shader.zig");

pub const ResourceManager = @This();
const Self = ResourceManager;

pub fn init(allocator: std.mem.Allocator) ResourceManager {
    stbi.init(allocator);
    return ResourceManager{
        .allocator = allocator,
        .shaders = std.StringHashMap(Shader).init(allocator),
        .textures = std.StringHashMap(Texture).init(allocator),
    };
}

allocator: std.mem.Allocator,

shaders: std.StringHashMap(Shader),
textures: std.StringHashMap(Texture),

pub fn deinit(self: *Self) void {
    self.clear();
    self.shaders.deinit();
    self.textures.deinit();
    self.shaders = undefined;
    self.textures = undefined;
}

pub fn loadShader(self: *Self, vertex_path: []const u8, fragment_path: []const u8, geometry_path: ?[]const u8, name: []const u8) !Shader {
    const sh = try loadShaderFromFile(self.allocator, vertex_path, fragment_path, geometry_path);
    try self.shaders.put(name, sh);
    return sh;
}

pub fn getShader(self: Self, name: []const u8) ?Shader {
    return self.shaders.get(name);
}

pub fn loadTexture(self: *Self, image_path: []const u8, name: []const u8) !Texture {
    const texture = try loadTextureFromFile(image_path);
    try self.textures.put(name, texture);
    return texture;
}

pub fn getTexture(self: Self, name: []const u8) ?Texture {
    return self.textures.get(name);
}

pub fn clear(self: *Self) void {
    {
        var iter = self.shaders.iterator();
        while (iter.next()) |i| {
            i.value_ptr.deinit();
        }
    }
    {
        var iter = self.textures.iterator();
        while (iter.next()) |i| {
            i.value_ptr.deinit();
        }
    }
    self.shaders.clearAndFree();
    self.textures.clearAndFree();
}

fn loadShaderFromFile(allocator: std.mem.Allocator, vertex_path: []const u8, fragment_path: []const u8, geometry_path: ?[]const u8) !Shader {
    const vshader_file = try std.fs.cwd().openFile(vertex_path, .{ .mode = .read_only });
    defer vshader_file.close();

    var vertex_code = try allocator.alloc(u8, try vshader_file.getEndPos());
    defer allocator.free(vertex_code);

    const fshader_file = try std.fs.cwd().openFile(fragment_path, .{ .mode = .read_only });
    defer fshader_file.close();

    var fragment_code = try allocator.alloc(u8, try fshader_file.getEndPos());
    defer allocator.free(fragment_code);

    _ = try vshader_file.read(vertex_code);
    _ = try fshader_file.read(fragment_code);

    var geometry_code: ?[]const u8 = null;
    if (geometry_path) |path| {
        const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
        defer file.close();
        var code = try allocator.alloc(u8, try file.getEndPos());
        _ = try file.read(code);
        geometry_code = code;
    }
    defer {
        if (geometry_code) |m| {
            allocator.free(m);
        }
    }
    return Shader.compile(vertex_code, fragment_code, geometry_code);
}

fn loadTextureFromFile(image_path: []const u8) !Texture {
    var image = try stbi.Image.loadFromFile(@ptrCast(image_path), 0);
    const Formats = std.meta.Tuple(&.{ u32, u32 });
    defer image.deinit();
    var formats: Formats = switch (image.num_components) {
        1 => .{ gl.RED, gl.RED },
        3 => .{ gl.RGB, gl.RGB },
        4 => .{ gl.RGBA, gl.RGBA },
        else => return error.InvalidFormat,
    };
    return Texture.generate(
        formats[0],
        image.width,
        image.height,
        formats[1],
        gl.REPEAT,
        gl.REPEAT,
        gl.LINEAR,
        gl.LINEAR,
        image.data,
    );
}
