const std = @import("std");
const zmath = @import("zmath");
const sp = @import("sprite.zig");
const tx = @import("texture.zig");
const rsc = @import("rscmgr.zig");

pub const Brick = struct {
    position: zmath.Vec = zmath.f32x4(0.0, 0.0, 0.0, 1.0),
    size: zmath.Vec = zmath.f32x4(1.0, 1.0, 1.0, 0.0),
    color: zmath.Vec = zmath.f32x4s(1.0),
    is_solid: bool = false,
    destroyed: bool = false,
    sprite: ?tx.Texture,

    pub fn draw(self: @This(), renderer: sp.Renderer) void {
        renderer.drawSprite(self.sprite.?, self.position, self.size, 0.0, self.color);
    }
};

pub fn loadLevel(allocator: std.mem.Allocator, file_path: []const u8, level_width: u32, level_height: u32) !Level {
    const level_file = try std.fs.cwd().openFile(file_path, .{ .mode = .read_only });
    defer level_file.close();
    var level_text = try allocator.alloc(u8, try level_file.getEndPos());
    _ = try level_file.read(level_text);
    defer allocator.free(level_text);

    var arena = std.heap.ArenaAllocator.init(allocator);
    var arena_alloc = arena.allocator();
    defer arena.deinit();

    var tile_data = std.ArrayList(std.ArrayList(u8)).init(arena_alloc);

    var line_iter = std.mem.tokenizeSequence(u8, level_text, "\n");
    while (line_iter.next()) |line| {
        var br_iter = std.mem.tokenizeSequence(u8, line, " ");
        var row = std.ArrayList(u8).init(arena_alloc);
        while (br_iter.next()) |br| {
            std.debug.assert(br.len == 1);
            std.debug.assert(br[0] >= '0');
            std.debug.assert(br[0] <= '9');
            try row.append(br[0] - '0');
        }
        try tile_data.append(row);
    }

    var level = Level{
        .bricks = std.ArrayList(Brick).init(allocator),
    };
    try initBricks(&level.bricks, tile_data, level_width, level_height);

    return level;
}

fn initBricks(bricks: *std.ArrayList(Brick), tile_data: std.ArrayList(std.ArrayList(u8)), level_width: u32, level_height: u32) !void {
    const height = tile_data.items.len;
    const width = tile_data.items[0].items.len;
    const unit_width = @as(f32, @floatFromInt(level_width)) / @as(f32, @floatFromInt(width));
    const unit_height = @as(f32, @floatFromInt(level_height)) / @as(f32, @floatFromInt(height));

    const solid_texture = rsc.getTexture("block_solid").?;
    const block_texture = rsc.getTexture("block").?;

    for (tile_data.items, 0..) |row, y| {
        for (row.items, 0..) |br, x| {
            const pos = zmath.f32x4(unit_width * @as(f32, @floatFromInt(x)), unit_height * @as(f32, @floatFromInt(y)), 0.0, 1.0);
            const sz = zmath.f32x4(unit_width, unit_height, 0.0, 0.0);
            if (br == 1) {
                const brick = Brick{
                    .position = pos,
                    .size = sz,
                    .is_solid = true,
                    .sprite = solid_texture,
                };
                try bricks.append(brick);
            } else if (br > 1) {
                const clr = switch (br) {
                    2 => zmath.f32x4(0.2, 0.6, 1.0, 1.0),
                    3 => zmath.f32x4(0.0, 0.7, 0.0, 1.0),
                    4 => zmath.f32x4(0.8, 0.8, 0.4, 1.0),
                    5 => zmath.f32x4(1.0, 0.5, 0.0, 1.0),
                    else => unreachable,
                };
                const brick = Brick{
                    .position = pos,
                    .size = sz,
                    .color = clr,
                    .is_solid = true,
                    .sprite = block_texture,
                };
                try bricks.append(brick);
            }
        }
    }
}

pub const Level = struct {
    bricks: std.ArrayList(Brick),

    pub fn draw(self: @This(), renderer: sp.Renderer) void {
        for (self.bricks.items) |brick| {
            if (!brick.destroyed) {
                brick.draw(renderer);
            }
        }
    }

    pub fn isCompleted(self: @This()) bool {
        _ = self;
        return false;
    }
};
