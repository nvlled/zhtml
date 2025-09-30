const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const Zhtml = @import("./zhtml.zig");

_zhtml: *Zhtml,

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

pub fn initFrom(zhtml: *Zhtml) !@This() {
    var self: @This() = undefined;
    self._zhtml = zhtml;

    inline for (std.meta.fields(@This())) |field| {
        switch (field.type) {
            CommentElem => @field(self, field.name) = .{
                .elem = .init(self._zhtml),
            },
            VoidElem, Elem => @field(self, field.name) = .{
                .elem = .init(field.name, self._zhtml),
            },

            else => {},
        }
    }
    return self;
}

pub fn init(w: *std.Io.Writer, allocator: Allocator) !@This() {
    const zhtml = try allocator.create(Zhtml);
    zhtml.* = try .init(w, allocator);
    return .initFrom(zhtml);
}

pub fn deinit(self: @This(), allocator: Allocator) void {
    self._zhtml.deinit(allocator);
    allocator.destroy(self._zhtml);
}

inline fn setLastError(self: @This(), err: anytype) void {
    self._zhtml._internal.setError(err);
}

pub inline fn getLastError(self: @This()) !void {
    return self._zhtml._internal.getLastError();
}

pub inline fn getLastTrace(self: @This()) ?[]const u8 {
    return self._zhtml._internal.getLastErrorTrace();
}

pub fn attr(self: @This(), key: anytype, value: []const u8) void {
    self._zhtml.attr(key, value) catch |err| {
        self._zhtml.@"error".setError(err);
    };
}

pub fn attrs(self: @This(), args: anytype) void {
    self._zhtml.attrs(args) catch |err| {
        self._zhtml.@"error".set(err);
    };
}

pub inline fn write(self: @This(), str: []const u8) void {
    self._zhtml.write(str) catch |err| {
        self.setLastError(err);
    };
}

pub inline fn @"writeUnsafe!?"(self: @This(), str: []const u8) void {
    self._zhtml.@"writeUnsafe!?"(str) catch |err| {
        self.setLastError(err);
    };
}

pub fn print(
    self: @This(),
    gpa: Allocator,
    comptime fmt: []const u8,
    args: anytype,
) Allocator.Error!void {
    self._zhtml.print(gpa, fmt, args) catch |err| {
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
    self._zhtml.@"printUnsafe!?"(gpa, fmt, args) catch |err| {
        switch (err) {
            Allocator.Error.OutOfMemory => |alloc_err| return alloc_err,
            Zhtml.WriterError.WriteFailed => self.setLastError(err),
        }
    };
}

pub const Elem = struct {
    elem: Zhtml.Elem,

    pub inline fn begin(self: @This()) void {
        self.elem.begin() catch |err| {
            self.elem._internal.setError(err);
        };
    }

    pub inline fn end(self: @This()) void {
        self.elem.end() catch |err| {
            self.elem._internal.setError(err);
        };
    }

    pub inline fn render(
        self: @This(),
        str: []const u8,
    ) void {
        self.elem.render(str) catch |err| {
            self.elem._internal.setError(err);
        };
    }

    pub inline fn renderf(
        self: @This(),
        allocator: Allocator,
        comptime fmt: []const u8,
        args: anytype,
    ) Allocator.Error!void {
        self.elem.renderf(allocator, fmt, args) catch |err| {
            switch (err) {
                Allocator.Error.OutOfMemory => |alloc_err| return alloc_err,
                Zhtml.WriterError.WriteFailed,
                Zhtml.Error.ClosingTagMismatch,
                Zhtml.Error.TagAttrMismatch,
                Zhtml.Error.TooManyAttrs,
                => self.elem._internal.setError(err),
            }
        };
    }

    pub inline fn @"<>"(self: @This()) void {
        self.begin();
    }

    pub fn @"</>"(self: @This()) void {
        return self.end();
    }

    pub fn @"<=>"(
        self: @This(),
        str: []const u8,
    ) void {
        return self.render(str);
    }

    pub inline fn attr(self: @This(), key: anytype, value: []const u8) void {
        self.elem.attr(key, value) catch |err| {
            self.elem._internal.setError(err);
        };
    }

    pub inline fn attrs(self: @This(), args: anytype) void {
        self.elem.attrs(args) catch |err| {
            self.elem._internal.setError(err);
        };
    }
};

const CommentElem = struct {
    elem: Zhtml.CommentElem,

    pub inline fn begin_(self: @This()) void {
        self.elem.begin_() catch |err| {
            self.elem._internal.setError(err);
        };
    }

    pub inline fn end(self: @This()) void {
        self.elem.end() catch |err| {
            self.elem._internal.setError(err);
        };
    }

    pub inline fn render(self: @This(), str: []const u8) void {
        self.elem.render(str) catch |err| {
            self.elem._internal.setError(err);
        };
    }

    pub inline fn renderf(
        self: @This(),
        allocator: Allocator,
        comptime fmt: []const u8,
        args: anytype,
    ) Allocator.Error!void {
        self.elem.renderf(allocator, fmt, args) catch |err| {
            switch (err) {
                Allocator.Error.OutOfMemory => |alloc_err| return alloc_err,
                Zhtml.WriterError.WriteFailed,
                Zhtml.Error.ClosingTagMismatch,
                Zhtml.Error.TagAttrMismatch,
                Zhtml.Error.TooManyAttrs,
                => self.elem._internal.setError(err),
            }
        };
    }

    pub inline fn @"<=>"(
        self: @This(),
        str: []const u8,
    ) void {
        self.render(str) catch |err| {
            self.elem._internal.setError(err);
        };
    }
};

const VoidElem = struct {
    elem: Zhtml.VoidElem,

    pub fn init(tag: []const u8, zhtml: Zhtml) Elem {
        return .{
            .tag = tag,
            ._internal = .{
                .w = zhtml._internal.w,
                .pending_attrs = zhtml._internal.pending_attrs,
            },
        };
    }

    pub fn render(self: @This()) void {
        self.elem.render() catch |err| {
            self.elem._internal.setError(err);
        };
    }

    pub inline fn @"<>"(self: @This()) void {
        self.elem.render() catch |err| {
            self.elem._internal.setError(err);
        };
    }

    pub inline fn attr(self: @This(), key: anytype, value: []const u8) void {
        self.elem.attr(key, value) catch |err| {
            self.elem._internal.setError(err);
        };
    }

    pub inline fn attrs(self: @This(), args: anytype) void {
        self.elem.attrs(args) catch |err| {
            self.elem._internal.setError(err);
        };
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
    try std.testing.expectError(Zhtml.Error.TagAttrMismatch, z.getLastError());

    z.div.@"<>"();
    z.p.@"</>"();
    try std.testing.expectError(Zhtml.Error.ClosingTagMismatch, z.getLastError());
}

test {
    if (builtin.mode == .Debug) {
        std.testing.refAllDeclsRecursive(@This());
    }
}
