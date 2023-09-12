const std = @import("std");
const gl = @import("zopengl");
const zmath = @import("zmath");

pub fn new() Shader {
    var shader = Shader{};
    return shader;
}

pub const Shader = struct {
    id: ?u32 = null,

    pub fn use(self: Shader) void {
        gl.useProgram(self.id.?);
    }

    pub fn deinit(self: *Shader) void {
        if (self.id) {
            gl.deleteProgram(self.id.?);
        }
    }

    pub fn compile(self: *Shader, vertex_source: []const u8, fragment_source: []const u8, geometry_source: ?[]const u8) !void {
        var vertex_shader = gl.createShader(gl.VERTEX_SHADER);
        gl.shaderSource(vertex_shader, 1, &vertex_source.ptr, null);
        gl.compileShader(vertex_shader);
        try checkCompilerError(vertex_shader, ErrorType.vertex);

        var fragment_shader = gl.createShader(gl.FRAGMENT_SHADER);
        gl.shaderSource(fragment_shader, 1, &fragment_source.ptr, null);
        gl.compileShader(fragment_shader);
        try checkCompilerError(fragment_shader, ErrorType.fragment);

        var geom_shader: ?u32 = null;
        if (geometry_source) |source| {
            var id = gl.createShader(gl.GEOMETRY_SHADER);
            gl.shaderSource(id, 1, &source.ptr, null);
            gl.compileShader(id);
            geom_shader = id;
        }

        var program = gl.createProgram();
        gl.attachShader(program, vertex_shader);
        gl.attachShader(program, fragment_shader);
        if (geom_shader) |id| {
            gl.attachShader(program, id);
        }
        gl.linkProgram(program);
        try checkCompilerError(program, ErrorType.program);

        gl.deleteShader(vertex_shader);
        gl.deleteShader(fragment_shader);
        if (geom_shader) |id| {
            gl.deleteShader(id);
        }

        self.id = program;
    }

    pub fn setFloat(self: Shader, name: []const u8, value: f32, use_shader: bool) void {
        if (use_shader) {
            self.use();
        }
        gl.uniform1f(gl.getUniformLocation(self.id.?, @ptrCast(name)), value);
    }

    pub fn setInteger(self: Shader, name: []const u8, value: i32, use_shader: bool) void {
        if (use_shader) {
            self.use();
        }
        gl.uniform1i(gl.getUniformLocation(self.id.?, @ptrCast(name)), value);
    }

    pub fn setVector2f(self: Shader, name: []const u8, x: f32, y: f32, use_shader: bool) void {
        if (use_shader) {
            self.use();
        }
        gl.uniform2f(gl.getUniformLocation(self.id.?, @ptrCast(name)), x, y);
    }

    pub fn setVec3(self: Shader, name: []const u8, value: zmath.Vec, use_shader: bool) void {
        if (use_shader) {
            self.use();
        }
        gl.uniform3f(gl.getUniformLocation(self.id.?, @ptrCast(name)), value[0], value[1], value[2]);
    }

    pub fn setVector3f(self: Shader, name: []const u8, x: f32, y: f32, z: f32, use_shader: bool) void {
        if (use_shader) {
            self.use();
        }
        gl.uniform3f(gl.getUniformLocation(self.id.?, @ptrCast(name)), x, y, z);
    }

    pub fn setVec4(self: Shader, name: []const u8, value: zmath.Vec, use_shader: bool) void {
        if (use_shader) {
            self.use();
        }
        gl.uniform4f(gl.getUniformLocation(self.id.?, @ptrCast(name)), value[0], value[1], value[2], value[3]);
    }

    pub fn setVector4f(self: Shader, name: []const u8, x: f32, y: f32, z: f32, w: f32, use_shader: bool) void {
        if (use_shader) {
            self.use();
        }
        gl.uniform4f(gl.getUniformLocation(self.id.?, @ptrCast(name)), x, y, z, w);
    }

    pub fn setMatrix4(self: Shader, name: []const u8, mat: zmath.Mat, use_shader: bool) void {
        if (use_shader) {
            self.use();
        }
        gl.uniformMatrix4fv(gl.getUniformLocation(self.id.?, @ptrCast(name)), 1, gl.FALSE, &zmath.matToArr(mat));
    }
};

const ErrorType = enum {
    vertex,
    fragment,
    program,
};

fn checkCompilerError(shader: u32, errorType: ErrorType) !void {
    const BUFF_SIZE = 1024;
    var success: i32 = 0;
    var infoLog: [BUFF_SIZE]u8 = undefined;
    switch (errorType) {
        .program => {
            gl.getProgramiv(shader, gl.LINK_STATUS, &success);
            if (success == 0) {
                gl.getProgramInfoLog(shader, BUFF_SIZE, null, &infoLog);
                std.log.warn("ERROR::SHADER::PROGRAM::LINKING_FAILED\n{s}\n", .{infoLog});
                return error.Error;
            }
        },
        .vertex, .fragment => {
            gl.getShaderiv(shader, gl.COMPILE_STATUS, &success);
            if (success == 0) {
                gl.getShaderInfoLog(shader, BUFF_SIZE, null, &infoLog);
                std.log.warn("ERROR::SHADER::{}::COMPILATION_FAILED\n{s}\n", .{ errorType, infoLog });
                return error.Error;
            }
        },
    }
}
