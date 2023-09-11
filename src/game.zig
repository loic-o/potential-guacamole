const std = @import("std");

pub const GameState = enum {
    game_active,
    game_menu,
    game_win,
};

pub fn new(width: u32, height: u32) Game {
    return Game{
        .state = GameState.game_active,
        .keys = [_]bool{false} ** 1024,
        .width = width,
        .height = height,
    };
}

pub const Game = struct {
    state: GameState = GameState.game_active,
    keys: [1024]bool,
    width: u32,
    height: u32,

    pub fn destroy(this: *Game) void {
        _ = this;
        @panic("Not implemented");
    }

    pub fn init(this: *Game) void {
        _ = this;
    }

    pub fn processInput(this: *Game, dt: f32) void {
        _ = this;
        _ = dt;
        @panic("Not implemented");
    }

    pub fn update(this: *Game, dt: f32) void {
        _ = this;
        _ = dt;
        @panic("Not implemented");
    }

    pub fn render(this: *Game) void {
        _ = this;
        @panic("Not implemented");
    }
};
