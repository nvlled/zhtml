//! This is a wrapper module for zhtml.
//!
//! It wraps each function such that the error is handled and stored internally.
//! What this means is that it avoids having to use `try` or explicitly handle
//! errors (except for allocation errors) for the elem methods. If an error
//! occured, further calls will be no-op, not even an attempt to write.
//!
//! To do explicit error-handling, use `zhtml.unwrap`.
const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const Zhtml = @import("./zhtml.zig");
const ZhtmlWrapped = @This();

const Internal = struct {
    // TODO: should probably just use a fixed buffer
    // Allocator is only used for internal debugging, do not use for other purposes.
    allocator: Allocator,

    last_error: ?struct {
        value: anyerror,
        trace: []const u8,
    } = null,

    fn clearError(self: *@This()) void {
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

    fn getError(self: @This()) !void {
        if (self.last_error) |err| {
            return err.value;
        }
    }

    fn getErrorTrace(self: @This()) ?[]const u8 {
        return if (self.last_error) |err|
            err.trace
        else
            null;
    }

    fn printErrorTrace(self: @This()) ?[]const u8 {
        if (self.last_error) |err| {
            std.debug.print("{s}\n", .{err.trace});
        }
    }
};

_internal: *Internal,

/// The unwrap module. Use this when explicit
/// error-handling is desired.
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
textarea: TextArea,
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
            //
            // The shorthand `.init` isn't used here since
            // this uses reflection, and being explicit
            // gives better compiler error message.
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
            Zhtml.TextArea => @field(self, field.name) = .{
                .unwrap = Zhtml.TextArea.init(self.unwrap),
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

pub fn clearError(self: @This()) void {
    self._internal.clearError();
}

pub fn getError(self: @This()) !void {
    return self._internal.getError();
}

pub fn getErrorTrace(self: @This()) ?[]const u8 {
    return self._internal.getErrorTrace();
}

pub fn attr(self: @This(), key: anytype, value: []const u8) void {
    self.getError() catch return;
    self.unwrap.attr(key, value) catch |err| {
        self.setLastError(err);
    };
}

pub fn attrf(self: @This(), key: anytype, value: []const u8) void {
    self.getError() catch return;
    self.unwrap.attrf(key, value) catch |err| {
        self.setLastError(err);
    };
}

pub fn attrs(self: @This(), args: anytype) void {
    self.getError() catch return;
    self.unwrap.attrs(args) catch |err| {
        self.setLastError(err);
    };
}

pub fn write(self: @This(), str: []const u8) void {
    self.getError() catch return;
    self.unwrap.write(str) catch |err| {
        self.setLastError(err);
    };
}

pub fn @"writeUnsafe!?"(self: @This(), str: []const u8) void {
    self.getError() catch return;
    self.unwrap.@"writeUnsafe!?"(str) catch |err| {
        self.setLastError(err);
    };
}

pub fn print(
    self: @This(),
    comptime fmt: []const u8,
    args: anytype,
) Allocator.Error!void {
    self.getError() catch return;
    self.unwrap.print(fmt, args) catch |err| {
        switch (err) {
            Allocator.Error.OutOfMemory => |alloc_err| return alloc_err,
            Zhtml.WriterError.WriteFailed => self.setLastError(err),
        }
    };
}

pub fn @"printUnsafe!?"(
    self: @This(),
    comptime fmt: []const u8,
    args: anytype,
) Allocator.Error!void {
    self.getError() catch return;
    self.unwrap.@"printUnsafe!?"(fmt, args) catch |err| {
        switch (err) {
            Allocator.Error.OutOfMemory => |alloc_err| return alloc_err,
            Zhtml.WriterError.WriteFailed => self.setLastError(err),
        }
    };
}

// Returns true if anything has been written to the std.Io.Writer.
pub fn written(self: @This()) bool {
    return self.unwrap.written();
}

// Return true if document should be formatted,
// which means nodes will be indented based on depth
// and add corresponding newlines.
pub fn formatted(self: @This()) bool {
    return self.unwrap._internal.formatted;
}

pub fn setFormatted(self: @This(), value: bool) void {
    self.unwrap._internal.formatted = value;
}

pub fn writer(self: @This()) *std.Io.Writer {
    return self.unwrap._internal.w;
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

    pub fn begin(self: @This()) void {
        invokeUnwrap(self, Zhtml.Elem.begin, .{}) catch {};
    }

    pub fn end(self: @This()) void {
        invokeUnwrap(self, Zhtml.Elem.end, .{}) catch {};
    }

    pub fn render(self: @This(), str: []const u8) void {
        invokeUnwrap(self, Zhtml.Elem.render, .{str}) catch {};
    }

    pub fn renderf(
        self: @This(),
        comptime fmt: []const u8,
        args: anytype,
    ) Allocator.Error!void {
        invokeUnwrap(self, Zhtml.Elem.renderf, .{ fmt, args }) catch |err| {
            switch (err) {
                Allocator.Error.OutOfMemory => |alloc_err| {
                    self._internal.clearError();
                    return alloc_err;
                },
                Zhtml.WriterError.WriteFailed,
                Zhtml.Error.ClosingTagMismatch,
                Zhtml.Error.TagAttrMismatch,
                Zhtml.Error.TooManyAttrs,
                => {},
            }
        };
    }

    pub fn @"<>"(self: @This()) void {
        invokeUnwrap(self, Zhtml.Elem.begin, .{}) catch {};
    }

    pub fn @"</>"(self: @This()) void {
        invokeUnwrap(self, Zhtml.Elem.end, .{}) catch {};
    }

    pub fn attr(self: @This(), key: anytype, value: []const u8) void {
        invokeUnwrap(self, Zhtml.Elem.attr, .{ key, value }) catch {};
    }

    pub fn attrf(
        self: @This(),
        key: anytype,
        comptime fmt: []const u8,
        fmt_args: anytype,
    ) Allocator.Error!void {
        invokeUnwrap(self, Zhtml.Elem.attrf, .{ key, fmt, fmt_args }) catch |err| {
            switch (err) {
                Allocator.Error.OutOfMemory => |alloc_err| {
                    self._internal.clearError();
                    return alloc_err;
                },
                Zhtml.Error.ClosingTagMismatch,
                Zhtml.Error.TagAttrMismatch,
                Zhtml.Error.TooManyAttrs,
                => {},
            }
        };
    }

    pub fn attrs(self: @This(), args: anytype) void {
        invokeUnwrap(self, Zhtml.Elem.attrs, .{args}) catch {};
    }

    pub fn withAttr(self: @This(), key: anytype, value: []const u8) @This() {
        invokeUnwrap(self, Zhtml.Elem.attr, .{ key, value }) catch {};
        return self;
    }
};

pub const TextArea = struct {
    unwrap: Zhtml.TextArea,
    _internal: *Internal,

    pub fn init(zhtml: ZhtmlWrapped) @This() {
        return .{
            .unwrap = .init(zhtml.unwrap),
            ._internal = zhtml._internal,
        };
    }

    pub fn render(self: @This(), str: []const u8) void {
        invokeUnwrap(self, Zhtml.TextArea.render, .{str}) catch {};
    }

    pub fn renderf(
        self: @This(),
        comptime fmt: []const u8,
        args: anytype,
    ) Allocator.Error!void {
        invokeUnwrap(self, Zhtml.TextArea.renderf, .{ fmt, args }) catch |err| {
            switch (err) {
                Allocator.Error.OutOfMemory => |alloc_err| {
                    self._internal.clearError();
                    return alloc_err;
                },
                Zhtml.WriterError.WriteFailed,
                Zhtml.Error.ClosingTagMismatch,
                Zhtml.Error.TagAttrMismatch,
                Zhtml.Error.TooManyAttrs,
                => {},
            }
        };
    }

    pub fn attr(self: @This(), key: anytype, value: []const u8) void {
        invokeUnwrap(self, Zhtml.TextArea.attr, .{ key, value }) catch {};
    }

    pub fn attrf(
        self: @This(),
        key: anytype,
        comptime fmt: []const u8,
        fmt_args: anytype,
    ) Allocator.Error!void {
        invokeUnwrap(self, Zhtml.TextArea.attrf, .{ key, fmt, fmt_args }) catch |err| {
            switch (err) {
                Allocator.Error.OutOfMemory => |alloc_err| {
                    self._internal.clearError();
                    return alloc_err;
                },
                Zhtml.Error.ClosingTagMismatch,
                Zhtml.Error.TagAttrMismatch,
                Zhtml.Error.TooManyAttrs,
                => {},
            }
        };
    }

    pub fn attrs(self: @This(), args: anytype) void {
        invokeUnwrap(self, Zhtml.TextArea.attrs, .{args}) catch {};
    }

    pub fn withAttr(self: @This(), key: anytype, value: []const u8) @This() {
        invokeUnwrap(self, Zhtml.TextArea.attr, .{ key, value }) catch {};
        return self;
    }
};

const CommentElem = struct {
    unwrap: Zhtml.CommentElem,
    _internal: *Internal,

    pub fn begin(self: @This()) void {
        invokeUnwrap(self, Zhtml.CommentElem.begin, .{}) catch {};
    }

    pub fn end(self: @This()) void {
        invokeUnwrap(self, Zhtml.CommentElem.end, .{}) catch {};
    }

    pub fn render(self: @This(), str: []const u8) void {
        invokeUnwrap(self, Zhtml.CommentElem.render, .{str}) catch {};
    }

    pub fn renderf(
        self: @This(),
        comptime fmt: []const u8,
        args: anytype,
    ) Allocator.Error!void {
        invokeUnwrap(self, Zhtml.CommentElem.renderf, .{ fmt, args }) catch |err| {
            switch (err) {
                Allocator.Error.OutOfMemory => |alloc_err| {
                    self._internal.clearError();
                    return alloc_err;
                },
                Zhtml.WriterError.WriteFailed,
                Zhtml.Error.ClosingTagMismatch,
                Zhtml.Error.TagAttrMismatch,
                Zhtml.Error.TooManyAttrs,
                => {},
            }
        };
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
        invokeUnwrap(self, Zhtml.VoidElem.render, .{}) catch {};
    }

    pub fn @"<>"(self: @This()) void {
        invokeUnwrap(self, Zhtml.VoidElem.render, .{}) catch {};
    }

    pub fn attr(self: @This(), key: anytype, value: []const u8) void {
        invokeUnwrap(self, Zhtml.VoidElem.attr, .{ key, value }) catch {};
    }

    pub fn attrf(
        self: @This(),
        key: anytype,
        comptime fmt: []const u8,
        fmt_args: anytype,
    ) Allocator.Error!void {
        invokeUnwrap(self, Zhtml.VoidElem.attrf, .{ key, fmt, fmt_args }) catch |err| {
            switch (err) {
                Allocator.Error.OutOfMemory => |alloc_err| {
                    self._internal.clearError();
                    return alloc_err;
                },
                Zhtml.Error.ClosingTagMismatch,
                Zhtml.Error.TagAttrMismatch,
                Zhtml.Error.TooManyAttrs,
                => {},
            }
        };
    }

    pub fn attrs(self: @This(), args: anytype) void {
        invokeUnwrap(self, Zhtml.VoidElem.attrs, .{args}) catch {};
    }

    pub fn withAttr(self: @This(), key: anytype, value: []const u8) @This() {
        invokeUnwrap(self, Zhtml.VoidElem.attr, .{ key, value }) catch {};
        return self;
    }
};

// A helper function for calling elem methods, that
// in addition to invoking the method, it:
// - checks if an error already exists, when then it just returns
// - stores the error returned if any
//
// For instance, `invokeUnwrap(elem, Elem.foo, .{x, y})` would be equivalent to: //
//   elem._internal.getLastError() catch return;
//   elem.foo(x, y) catch |err| {
//       elem._internal.setError(err);
//       return err;
//   }
fn invokeUnwrap(self: anytype, func: anytype, args: anytype) !void {
    const internal = @field(self, "_internal");
    const elem = @field(self, "unwrap");
    Meta.callMethod(internal.*, "getError", .{}) catch return;
    @call(.auto, func, .{elem} ++ args) catch |err| {
        Meta.callMethod(internal, "setError", .{err});
        return err;
    };
}

const Meta = struct {
    /// Returns the child of the pointer type, or
    /// the type as is if not a pointer.
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

    /// Similar to @call, but for methods.
    inline fn callMethod(
        self: anytype,
        comptime method_name: []const u8,
        method_args: anytype,
    ) MethodReturnType(DerefType(@TypeOf(self)), method_name) {
        const T = DerefType(@TypeOf(self));
        return @call(.auto, @field(T, method_name), .{self} ++ method_args);
    }
};

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
    z.clearError();
}

test "comprehensive" {
    const expected =
        \\&lt;p&gt;this is escaped&lt;/p&gt;
        \\<p>this is not escaped</p>
        \\&lt;p&gt;this is not escapedddd&lt;/p&gt;
        \\<p>this is not escapedddd</p>
        \\<div x="1" y="2" z="3" w="4" v="5" v="6&quot;'" q="11-22">div with silly attributes</div>
        \\
        \\<div id="6" class="div-color">div with normal attributes</div>
        \\
        \\<div>
        \\  <img src="image1.png">
        \\  <img class="aa bb" src="image2.png">
        \\  <br>
        \\  <p>
        \\    a paragraph, a barely one, actually a just sentence
        \\  </p>
        \\</div>
        \\<!--a comment-->
        \\<!--another comment-->
        \\<!--
        \\more comment
        \\-->
        \\
    ;

    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var buf: std.Io.Writer.Allocating = .init(allocator);
    defer buf.deinit();

    const z: @This() = try .init(&buf.writer, allocator);
    defer z.deinit(allocator);

    z.write("<p>this is escaped</p>\n");
    z.@"writeUnsafe!?"("<p>this is not escaped</p>\n");
    try z.print("<p>this is not escape{s}</p>\n", .{"dddd"});
    try z.@"printUnsafe!?"("<p>this is not escape{s}</p>\n", .{"dddd"});

    z.attr(.x, "1");
    z.attr("y", "2");
    z.attrs(.{ .z = "3", .w = "4" });
    z.div.attr(.v, "5");
    z.div.attr(.v, "6\"'");
    try z.div.attrf(.q, "{d}-{d}", .{ 11, 22 });
    z.div.render("div with silly attributes");
    z.write("\n");

    z.div.attr(.id, "6");
    try z.div
        .withAttr(.class, "div-color")
        .renderf("div with {s} attributes", .{"normal"});
    z.write("\n");

    z.div.@"<>"();
    {
        z.img.withAttr(.src, "image1.png").render();
        try z.img.attrf(.class, "{s} {s}", .{ "aa", "bb" });
        z.img.attr(.src, "image2.png");
        z.img.@"<>"();
        z.br.@"<>"();
        z.p.begin();
        z.write("a paragraph, a barely one, actually a just sentence");
        z.p.end();
    }
    z.div.@"</>"();

    z.comment.render("a comment");

    try z.comment.renderf("{s} comment", .{"another"});

    z.comment.begin();
    z.write("more comment");
    z.comment.end();

    const output = try buf.toOwnedSlice();
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}

test {
    if (builtin.mode == .Debug) {
        std.testing.refAllDeclsRecursive(@This());
    }
}
