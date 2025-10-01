const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const Zhtml = @import("./zhtml.zig");

const Internal = struct {
    // only used for internal debugging, do not use for other purposes
    // TODO: well actually I should just figure out how to create a Writer
    // from a fixed sized array
    allocator: Allocator,

    last_error: ?struct {
        value: anyerror,
        trace: []const u8,
    } = null,

    inline fn clearError(self: *@This()) void {
        if (builtin.mode == .Debug) {
            if (self.last_error) |existing_err| {
                self.allocator.free(existing_err.trace);
            }
            self.last_error = null;
        }
    }

    inline fn setError(self: *@This(), err: anytype) void {
        const Self = @This();

        const _setError = struct {
            inline fn _(internal: *Self, err2: anytype) !void {
                const trace = if (builtin.mode != .Debug) &.{} else blk: {
                    if (internal.last_error) |existing_err| {
                        internal.allocator.free(existing_err.trace);
                    }

                    var buf: std.io.Writer.Allocating = .init(internal.allocator);
                    const info = try std.debug.getSelfDebugInfo();
                    try std.debug.writeCurrentStackTrace(
                        &buf.writer,
                        info,
                        .detect(std.fs.File.stderr()),
                        @returnAddress(),
                    );

                    try buf.writer.flush();

                    const trace = try buf.toOwnedSlice();
                    break :blk trace;
                };

                internal.last_error = .{
                    .value = err2,
                    .trace = trace,
                };
            }
        }._;

        _setError(self, err) catch |inner_err| {
            @panic(@errorName(inner_err));
        };
    }

    fn getLastError(self: @This()) !void {
        if (self.last_error) |err| {
            return err.value;
        }
    }

    fn getLastErrorTrace(self: @This()) ?[]const u8 {
        if (self.last_error) |err| {
            return err.trace;
        }
    }

    fn printLastErrorTrace(self: @This()) ?[]const u8 {
        if (self.last_error) |err| {
            std.debug.print("{s}\n", .{err.trace});
        }
    }
};

_internal: *Internal,

unwrap: *Zhtml,

html: Elem,
head: Elem,
title: Elem,
body: Elem,
meta: VoidElem,

script: Elem,
style: Elem,
noscript: Elem,
link: VoidElem,

a: Elem,
base: VoidElem,

p: Elem,
div: Elem,
span: Elem,

details: Elem,
summary: Elem,

b: Elem,
i: Elem,
em: Elem,
strong: Elem,
small: Elem,
s: Elem,
pre: Elem,
code: Elem,

br: VoidElem,
hr: VoidElem,

blockQuote: Elem,

ol: Elem,
ul: Elem,
li: Elem,

form: Elem,
input: VoidElem,
textarea: Elem,
button: Elem,
label: Elem,
select: Elem,
option: Elem,

h1: Elem,
h2: Elem,
h3: Elem,
h4: Elem,
h5: Elem,
h6: Elem,
h7: Elem,

table: Elem,
thead: Elem,
tbody: Elem,
col: VoidElem,
tr: Elem,
td: Elem,

svg: Elem,
img: VoidElem,
area: VoidElem,

iframe: Elem,

video: Elem,
embed: VoidElem,
track: VoidElem,
source: VoidElem,

comment: CommentElem,

pub fn init(w: *std.Io.Writer, allocator: Allocator) !@This() {
    const zhtml = try allocator.create(Zhtml);
    zhtml.* = try .init(w, allocator);

    var self: @This() = undefined;

    self.unwrap = zhtml;

    self._internal = try allocator.create(Internal);
    self._internal.* = .{
        .allocator = allocator,
    };

    // Check if the elem fields in this file has a matching field in zhtml.zig
    inline for (std.meta.fields(@This())) |field| {
        switch (field.type) {
            Elem, VoidElem, CommentElem => _ = @field(zhtml, field.name),
            else => {},
        }
    }

    inline for (std.meta.fields(Zhtml)) |field| {
        switch (field.type) {
            // NOTE:
            // If there's a compile error saying:
            //   no field named 'XYZ' in struct 'zhtml-wrapped'
            // it means `XYZ: Elem` must be added above.
            Zhtml.CommentElem => @field(self, field.name) = .{
                .unwrap = Zhtml.CommentElem.init(self.unwrap),
                ._internal = self._internal,
            },
            Zhtml.VoidElem => @field(self, field.name) = .{
                .unwrap = Zhtml.VoidElem.init(field.name, self.unwrap),
                ._internal = self._internal,
            },
            Zhtml.Elem => @field(self, field.name) = .{
                .unwrap = Zhtml.Elem.init(field.name, self.unwrap),
                ._internal = self._internal,
            },

            else => {},
        }
    }
    return self;
}

pub fn deinit(self: @This(), allocator: Allocator) void {
    self.unwrap.deinit(allocator);
    allocator.destroy(self.unwrap);

    if (self._internal.last_error) |err|
        allocator.free(err.trace);
    allocator.destroy(self._internal);
}

inline fn setLastError(self: @This(), err: anytype) void {
    self._internal.setError(err);
}

pub inline fn clearError(self: @This()) void {
    self._internal.clearError();
}

pub inline fn getError(self: @This()) !void {
    return self._internal.getLastError();
}

pub inline fn getErrorTrace(self: @This()) ?[]const u8 {
    return self._internal.getLastErrorTrace();
}

pub inline fn attr(self: @This(), key: anytype, value: []const u8) void {
    self.getError() catch return;
    self.unwrap.attr(key, value) catch |err| {
        self.setLastError(err);
    };
}

pub inline fn attrs(self: @This(), args: anytype) void {
    self.getError() catch return;
    self.unwrap.attrs(args) catch |err| {
        self.setLastError(err);
    };
}

pub inline fn write(self: @This(), str: []const u8) void {
    self.getError() catch return;
    self.unwrap.write(str) catch |err| {
        self.setLastError(err);
    };
}

pub inline fn @"writeUnsafe!?"(self: @This(), str: []const u8) void {
    self.getError() catch return;
    self.unwrap.@"writeUnsafe!?"(str) catch |err| {
        self.setLastError(err);
    };
}

pub fn print(
    self: @This(),
    gpa: Allocator,
    comptime fmt: []const u8,
    args: anytype,
) Allocator.Error!void {
    self.getError() catch return;
    self.unwrap.print(gpa, fmt, args) catch |err| {
        switch (err) {
            Allocator.Error.OutOfMemory => |alloc_err| return alloc_err,
            Zhtml.WriterError.WriteFailed => self.setLastError(err),
        }
    };
}

pub fn @"printUnsafe!?"(
    self: @This(),
    gpa: Allocator,
    comptime fmt: []const u8,
    args: anytype,
) Allocator.Error!void {
    self.getError() catch return;
    self.unwrap.@"printUnsafe!?"(gpa, fmt, args) catch |err| {
        switch (err) {
            Allocator.Error.OutOfMemory => |alloc_err| return alloc_err,
            Zhtml.WriterError.WriteFailed => self.setLastError(err),
        }
    };
}

pub const Elem = struct {
    unwrap: Zhtml.Elem,
    _internal: *Internal,

    pub fn init(tag_name: []const u8, zhtml: ZhtmlWrapped) @This() {
        return .{
            .unwrap = .init(tag_name, zhtml.unwrap),
            ._internal = zhtml._internal,
        };
    }

    pub inline fn begin(self: @This()) void {
        invokeUnwrap(self, "begin", .{}) catch {};
    }

    pub inline fn end(self: @This()) void {
        invokeUnwrap(self, "end", .{}) catch {};
    }

    pub inline fn render(self: @This(), str: []const u8) void {
        invokeUnwrap(self, "render", .{str}) catch {};
    }

    pub inline fn renderf(
        self: @This(),
        allocator: Allocator,
        comptime fmt: []const u8,
        args: anytype,
    ) Allocator.Error!void {
        invokeUnwrap(self, "renderf", .{ allocator, fmt, args }) catch |err| {
            switch (err) {
                Allocator.Error.OutOfMemory => |alloc_err| return alloc_err,
                Zhtml.WriterError.WriteFailed,
                Zhtml.Error.ClosingTagMismatch,
                Zhtml.Error.TagAttrMismatch,
                Zhtml.Error.TooManyAttrs,
                => self._internal.setError(err),
            }
        };
    }

    pub inline fn @"<>"(self: @This()) void {
        invokeUnwrap(self, "begin", .{}) catch {};
    }

    pub inline fn @"</>"(self: @This()) void {
        invokeUnwrap(self, "end", .{}) catch {};
    }

    pub fn @"<=>"(self: @This(), str: []const u8) void {
        invokeUnwrap(self, "render", .{str}) catch {};
    }

    pub inline fn attr(self: @This(), key: anytype, value: []const u8) void {
        invokeUnwrap(self, "attr", .{ key, value }) catch {};
    }

    pub inline fn attrs(self: @This(), args: anytype) void {
        invokeUnwrap(self, "attrs", .{args}) catch {};
    }
};

const CommentElem = struct {
    unwrap: Zhtml.CommentElem,
    _internal: *Internal,

    pub inline fn begin_(self: @This()) void {
        invokeUnwrap(self, "begin", .{}) catch {};
    }

    pub inline fn end(self: @This()) void {
        invokeUnwrap(self, "end", .{}) catch {};
    }

    pub inline fn render(self: @This(), str: []const u8) void {
        invokeUnwrap(self, "render", .{str}) catch {};
    }

    pub inline fn renderf(
        self: @This(),
        allocator: Allocator,
        comptime fmt: []const u8,
        args: anytype,
    ) Allocator.Error!void {
        invokeUnwrap(self, "renderf", .{ allocator, fmt, args }) catch |err| {
            switch (err) {
                Allocator.Error.OutOfMemory => |alloc_err| return alloc_err,
                Zhtml.WriterError.WriteFailed,
                Zhtml.Error.ClosingTagMismatch,
                Zhtml.Error.TagAttrMismatch,
                Zhtml.Error.TooManyAttrs,
                => self._internal.setError(err),
            }
        };
    }

    pub inline fn @"<=>"(self: @This(), str: []const u8) void {
        self.render(str);
    }
};

pub const VoidElem = struct {
    unwrap: Zhtml.VoidElem,
    _internal: *Internal,

    pub fn init(tag_name: []const u8, zhtml: ZhtmlWrapped) @This() {
        return .{
            .unwrap = .init(tag_name, zhtml.unwrap),
            ._internal = zhtml._internal,
        };
    }

    pub fn render(self: @This()) void {
        invokeUnwrap(self, "render", .{}) catch {};
    }

    pub inline fn @"<>"(self: @This()) void {
        invokeUnwrap(self, "render", .{}) catch {};
    }

    pub inline fn attr(self: @This(), key: anytype, value: []const u8) void {
        invokeUnwrap(self, "attr", .{ key, value }) catch {};
    }

    pub inline fn attrs(self: @This(), args: anytype) void {
        invokeUnwrap(self, "attr", .{args}) catch {};
    }
};

fn invokeUnwrap(self: anytype, comptime method_name: []const u8, args: anytype) !void {
    const internal = @field(self, "_internal");
    const elem = @field(self, "unwrap");
    Meta.callMethod(internal.*, "getLastError", .{}) catch return;
    Meta.callMethod(elem, method_name, args) catch |err| {
        Meta.callMethod(internal, "setError", .{err});
        return err;
    };
}

const Meta = struct {
    fn DerefType(T: type) type {
        return switch (@typeInfo(T)) {
            .pointer => |ptr| ptr.child,
            else => T,
        };
    }

    fn MethodReturnType(comptime T: type, comptime method_name: []const u8) type {
        const internal = @field(T, method_name);
        switch (@typeInfo(@TypeOf(internal))) {
            .@"fn" => |func| return func.return_type orelse unreachable,
            else => @compileError("not a function"),
        }
    }

    fn callMethod(
        self: anytype,
        comptime method_name: []const u8,
        args: anytype,
    ) MethodReturnType(DerefType(@TypeOf(self)), method_name) {
        const T = DerefType(@TypeOf(self));
        return @call(.always_inline, @field(T, method_name), .{self} ++ args);
    }
};

test {
    const expected =
        \\<html><!--some comment here--><head><title>page title</title><meta charset="utf-8"><style>
        \\body { background: red }
        \\h1 { color: blue }</style></head><body><h1>heading</h1><h1 id="test">heading with id test</h1><p>This is a sentence 1.
        \\ This is a sentence 2.</p></body></html>
    ;

    const allocator = std.testing.allocator;
    var buf: std.Io.Writer.Allocating = .init(allocator);
    defer buf.deinit();

    const z: @This() = if (builtin.mode == .Debug)
        try .init(&buf.writer, allocator)
    else
        .init(&buf.writer, allocator);

    defer z.deinit(allocator);

    z.html.begin();
    {
        z.comment.render("some comment here");
        z.head.begin();
        {
            z.title.render("page title");
            z.meta.attr(.charset, "utf-8");
            z.meta.render();
            z.style.begin();
            {
                z.@"writeUnsafe!?"(
                    \\
                    \\body { background: red }
                    \\h1 { color: blue }
                );
            }
            z.style.end();
        }
        z.head.end();

        z.body.begin();
        {
            z.h1.render("heading");

            z.h1.attr(.id, "test");
            z.h1.render("heading with id test");

            z.p.render(
                \\This is a sentence 1.
                \\ This is a sentence 2.
            );
        }
        z.body.end();
    }
    z.html.end();

    const output = try buf.toOwnedSlice();
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}

test {
    const expected =
        \\<h1 id="id">heading</h1>
        \\<h2>subheading</h2>
        \\<ul>
        \\  <li>item 0</li>
        \\  <li>item 2</li>
        \\  <li>item 4</li>
        \\  <li>item 6</li>
        \\  <li>item 8</li>
        \\</ul>
    ;

    const allocator = std.testing.allocator;
    var buf: std.Io.Writer.Allocating = .init(allocator);
    defer buf.deinit();

    const z: @This() = try .init(&buf.writer, allocator);
    defer z.deinit(allocator);

    const h1 = z.h1;
    const h2 = z.h2;
    const ul = z.ul;
    const li = z.li;

    {
        h1.attr(.id, "id");
        h1.render("heading");

        z.write("\n");
        h2.render("subheading");
        z.write("\n");
        ul.begin();
        z.write("\n");
        for (0..10) |i| {
            if (i % 2 != 0) continue;
            z.write("  ");
            li.begin();
            try z.print(allocator, "item {d}", .{i});
            li.end();
            z.write("\n");
        }
        ul.end();
    }

    const output = try buf.toOwnedSlice();
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}

test "pending attrs" {
    const expected =
        \\<div a="1" c="2"><img id="im" src="/"></div>
        \\<span></span><!---->
    ;

    const allocator = std.testing.allocator;
    var buf: std.Io.Writer.Allocating = .init(allocator);
    defer buf.deinit();

    const z: @This() = try .init(&buf.writer, allocator);
    defer z.deinit(allocator);

    z.div.attr(.a, "1");
    z.div.attrs(.{ .c = "2" });
    z.div.@"<>"();
    {
        z.img.attr(.id, "im");
        z.img.attr(.src, "/");
        z.img.@"<>"();
    }
    z.div.@"</>"();

    z.write("\n");
    try z.span.renderf(allocator, "", .{});
    try z.comment.renderf(allocator, "", .{});

    const output = try buf.toOwnedSlice();
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}

test "last error" {
    const allocator = std.testing.allocator;
    var buf: std.Io.Writer.Allocating = .init(allocator);
    defer buf.deinit();

    const z: @This() = try .init(&buf.writer, allocator);
    defer z.deinit(allocator);

    z.div.attrs(.{ .c = "2" });
    z.p.@"<>"();
    try std.testing.expectError(Zhtml.Error.TagAttrMismatch, z.getError());
    z.clearError();

    z.div.@"<>"();
    z.p.@"</>"();
    try std.testing.expectError(Zhtml.Error.ClosingTagMismatch, z.getError());
}

test {
    if (builtin.mode == .Debug) {
        std.testing.refAllDeclsRecursive(@This());
    }
}
