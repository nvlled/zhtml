const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const Zhtml = @This();

pub const Error = error{ ClosingTagMismatch, TooManyAttrs, TagAttrMismatch };
pub const AllocatorError = Allocator.Error;
pub const WriterError = std.Io.Writer.Error;

const Internal = struct {
    w: *std.Io.Writer,
    stack: TagStack,
    pending_attrs: PendingAttrs,

    // used for temporry allocated formatted strings
    fmt_arena: std.heap.ArenaAllocator,

    depth: i16 = 0,
    last_written: u8 = 0,

    inline fn resetArena(self: *@This()) void {
        _ = self.fmt_arena.reset(.{ .retain_with_limit = 2048 });
    }

    inline fn writeByte(self: *@This(), ch: u8) !void {
        try self.w.writeByte(ch);
        if (builtin.mode == .Debug) {
            self.last_written = ch;
        }
    }
    inline fn writeAll(self: *@This(), str: []const u8) !void {
        try self.w.writeAll(str);
        if (builtin.mode == .Debug) {
            if (str.len > 0) self.last_written = str[str.len - 1];
        }
    }

    inline fn writeIndent(self: *@This()) !void {
        if (builtin.mode == .Debug) {
            if (self.last_written != '\n' and self.last_written != 0) {
                try self.w.writeByte('\n');
                for (0..@intCast(self.depth)) |_|
                    try self.w.writeAll("  ");
                self.last_written = ' ';
            } else if (self.last_written == '\n') {
                for (0..@intCast(self.depth)) |_|
                    try self.w.writeAll("  ");
                self.last_written = ' ';
            }
        }
    }

    inline fn writeEscapedContent(self: *@This(), str: []const u8) WriterError!void {
        const w = self.w;
        for (str) |ch| {
            switch (ch) {
                '<' => try w.writeAll("&lt;"),
                '>' => try w.writeAll("&gt;"),
                '&' => try w.writeAll("&amp;"),
                else => try w.writeByte(ch),
            }
        }
        if (builtin.mode == .Debug) {
            if (str.len > 0) self.last_written = str[str.len - 1];
        }
    }
};

// All elem fields will be initialized with
// comptime reflection, other fields should
// go here so that it's easier to initialize
// them properly.
//
// It also keeps the public API clean and tidy.
_internal: *Internal,

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
    var self: Zhtml = undefined;

    self._internal = try allocator.create(Internal);
    self._internal.* = .{
        .w = w,
        .stack = .{ .allocator = allocator },
        .pending_attrs = .{},
        .fmt_arena = .init(allocator),
    };

    inline for (std.meta.fields(Zhtml)) |field| {
        switch (field.type) {
            // initialize the stack field for each elem,
            // this is equivalent to doing manually:
            //   self.html  = .{ ... };
            //   self.head  = .{ ... };
            //   self.title = .{ ... };
            // ... and so on
            CommentElem => @field(self, field.name) = .{
                ._internal = self._internal,
            },

            VoidElem, Elem => @field(self, field.name) = .{
                .tag = field.name,
                ._internal = self._internal,
            },

            else => {},
        }
    }

    return self;
}

pub fn deinit(self: Zhtml, allocator: Allocator) void {
    self._internal.stack.items.deinit(allocator);
    self._internal.fmt_arena.deinit();
    allocator.destroy(self._internal);
}

pub fn attr(self: @This(), key: anytype, value: []const u8) Error!void {
    return self._internal.pending_attrs.add(null, key, value, false);
}

pub fn attrf(
    self: @This(),
    key: anytype,
    comptime fmt: []const u8,
    fmt_args: anytype,
) (AllocatorError || Error)!void {
    const allocator = self._internal.fmt_arena.allocator();
    return self._internal.pending_attrs.addFormatted(
        allocator,
        null,
        key,
        fmt,
        fmt_args,
    );
}

pub fn attrs(self: @This(), args: anytype) Error!void {
    return self._internal.pending_attrs.addMany(null, args);
}

pub inline fn write(self: @This(), str: []const u8) WriterError!void {
    try self._internal.writeIndent();
    try self._internal.writeEscapedContent(str);
}

pub inline fn @"writeUnsafe!?"(self: @This(), str: []const u8) WriterError!void {
    return self._internal.writeAll(str);
}

pub fn print(
    self: @This(),
    comptime fmt: []const u8,
    args: anytype,
) (WriterError || AllocatorError)!void {
    const allocator = self._internal.fmt_arena.allocator();
    const str = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(str);

    try self._internal.writeIndent();
    try self._internal.writeEscapedContent(str);
}

pub fn @"printUnsafe!?"(
    self: @This(),
    comptime fmt: []const u8,
    args: anytype,
) (WriterError || AllocatorError)!void {
    const allocator = self._internal.fmt_arena.allocator();
    const str = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(str);

    try self._internal.writeIndent();
    try self._internal.writeAll(str);
}

pub const Elem = struct {
    tag: []const u8,
    _internal: *Internal,

    pub fn init(tag: []const u8, zhtml: *Zhtml) Elem {
        return .{
            .tag = tag,
            ._internal = zhtml._internal,
        };
    }

    pub fn begin(self: @This()) (Error || WriterError)!void {
        const z = self._internal;
        if (builtin.mode == .Debug) {
            z.stack.push(self.tag);
        }
        errdefer z.writeAll(">") catch {};

        try z.writeIndent();
        try z.writeAll("<");
        try z.writeAll(self.tag);
        try z.pending_attrs.writeAndClear(self.tag, z.w);
        self._internal.resetArena();
        try z.writeAll(">\n");
        z.depth += 1;
    }

    pub fn end(self: @This()) (Error || WriterError)!void {
        if (builtin.mode == .Debug) {
            try self._internal.stack.checkMatching(self.tag);
        }

        const z = self._internal;
        z.depth -= 1;

        errdefer z.writeAll(">") catch {};
        try z.writeIndent();
        try z.writeAll("</");
        try z.writeAll(self.tag);
        try z.writeAll(">\n");
    }

    pub fn render(
        self: @This(),
        str: []const u8,
    ) (Error || WriterError)!void {
        const z = self._internal;
        errdefer z.writeAll(">") catch {};

        try z.writeIndent();
        try z.writeAll("<");
        try z.writeAll(self.tag);
        try z.pending_attrs.writeAndClear(self.tag, z.w);
        self._internal.resetArena();
        try z.writeAll(">");
        try z.writeEscapedContent(str);
        try z.writeAll("</");
        try z.writeAll(self.tag);
        try z.writeAll(">\n");
    }

    pub fn renderf(
        self: @This(),
        comptime fmt: []const u8,
        args: anytype,
    ) (Error || AllocatorError || WriterError)!void {
        const allocator = self._internal.fmt_arena.allocator();
        const str = try std.fmt.allocPrint(allocator, fmt, args);
        defer allocator.free(str);
        try self.render(str);
    }

    pub inline fn @"<>"(self: @This()) (Error || WriterError)!void {
        return self.begin();
    }

    pub inline fn @"</>"(self: @This()) (Error || WriterError)!void {
        return self.end();
    }

    pub fn attr(self: @This(), key: anytype, value: []const u8) Error!void {
        return self._internal.pending_attrs.add(self.tag, key, value, false);
    }

    pub fn attrf(
        self: @This(),
        key: anytype,
        comptime fmt: []const u8,
        fmt_args: anytype,
    ) (AllocatorError || Error)!void {
        const allocator = self._internal.fmt_arena.allocator();
        return self._internal.pending_attrs.addFormatted(
            allocator,
            self.tag,
            key,
            fmt,
            fmt_args,
        );
    }

    pub fn attrs(self: @This(), args: anytype) Error!void {
        return self._internal.pending_attrs.addMany(self.tag, args);
    }
};

pub const CommentElem = struct {
    _internal: *Internal,

    pub fn init(zhtml: *Zhtml) CommentElem {
        return .{
            ._internal = zhtml._internal,
        };
    }

    pub fn begin(self: @This()) WriterError!void {
        if (builtin.mode == .Debug) {
            self._internal.stack.push("!----");
        }

        const z = self._internal;
        errdefer z.writeAll(">") catch {};
        try z.writeIndent();
        try z.writeAll("<!--\n");
    }

    pub fn end(self: @This()) (Error || WriterError)!void {
        if (builtin.mode == .Debug) {
            try self._internal.stack.checkMatching("!----");
        }

        const z = self._internal;
        try z.writeIndent();
        try z.writeAll("-->\n");
    }

    pub fn render(self: @This(), str: []const u8) (Error || WriterError)!void {
        const z = self._internal;
        z.pending_attrs.clear();
        errdefer z.writeAll(">") catch {};
        try z.writeIndent();
        try z.writeAll("<!--");
        try z.writeEscapedContent(str);
        try z.writeAll("-->\n");
    }

    pub fn renderf(
        self: @This(),
        comptime fmt: []const u8,
        args: anytype,
    ) (Error || AllocatorError || WriterError)!void {
        const allocator = self._internal.fmt_arena.allocator();
        const str = try std.fmt.allocPrint(allocator, fmt, args);
        defer allocator.free(str);
        try self.render(str);
    }
};

pub const VoidElem = struct {
    tag: []const u8,
    _internal: *Internal,

    pub fn init(tag: []const u8, zhtml: *Zhtml) VoidElem {
        return .{
            .tag = tag,
            ._internal = zhtml._internal,
        };
    }

    pub fn render(self: @This()) (Error || WriterError)!void {
        const z = self._internal;
        errdefer z.writeAll(">") catch {};
        try z.writeIndent();
        try z.writeAll("<");
        try z.writeAll(self.tag);
        try z.pending_attrs.writeAndClear(self.tag, z.w);
        self._internal.resetArena();
        try z.writeAll(">\n");
    }

    pub fn attr(self: @This(), key: anytype, value: []const u8) Error!void {
        return self._internal.pending_attrs.add(self.tag, key, value, false);
    }

    pub fn attrf(
        self: @This(),
        key: anytype,
        comptime fmt: []const u8,
        fmt_args: anytype,
    ) (AllocatorError || Error)!void {
        const allocator = self._internal.fmt_arena.allocator();
        return self._internal.pending_attrs.addFormatted(
            allocator,
            self.tag,
            key,
            fmt,
            fmt_args,
        );
    }

    pub fn attrs(self: @This(), args: anytype) Error!void {
        return self._internal.pending_attrs.addMany(self.tag, args);
    }
};

const PendingAttrs = struct {
    index: usize = 0,
    tag: []const u8 = "",
    attrs: [512]Entry = undefined,

    const Entry = struct {
        key: []const u8,
        value: []const u8,
        allocated: bool = false,
    };

    fn add(
        self: *@This(),
        tag: ?[]const u8,
        key_arg: anytype,
        value: []const u8,
        allocated: bool,
    ) Error!void {
        if (builtin.mode == .Debug) if (tag) |name| {
            if (self.tag.len > 0 and !std.mem.eql(u8, name, self.tag)) {
                std.debug.print(
                    "can't mix <{s}> and <{s}> attributes\n",
                    .{ self.tag, name },
                );
                return Error.TagAttrMismatch;
            }
        };

        self.tag = tag orelse "";

        if (self.index >= self.attrs.len) return Error.TooManyAttrs;
        const key = switch (@typeInfo(@TypeOf(key_arg))) {
            .enum_literal => @tagName(key_arg),
            else => key_arg,
        };
        self.attrs[self.index] = .{
            .key = key,
            .value = value,
            .allocated = allocated,
        };
        self.index += 1;
    }

    fn addFormatted(
        self: *@This(),
        allocator: Allocator,
        tag: ?[]const u8,
        key_arg: anytype,
        comptime fmt: []const u8,
        fmt_args: anytype,
    ) (AllocatorError || Error)!void {
        const value = try std.fmt.allocPrint(allocator, fmt, fmt_args);
        return self.add(tag, key_arg, value, true);
    }

    fn addMany(self: *@This(), tag: ?[]const u8, args: anytype) Error!void {
        if (builtin.mode == .Debug) if (tag) |name| {
            if (self.tag.len > 0 and !std.mem.eql(u8, name, self.tag)) {
                std.debug.print(
                    "can't mix <{s}> and <{s}> attributes\n",
                    .{ self.tag, name },
                );
                return Error.TagAttrMismatch;
            }
        };

        self.tag = tag orelse "";

        inline for (std.meta.fields(@TypeOf(args))) |field| {
            if (self.index >= self.attrs.len) return Error.TooManyAttrs;
            const fname = field.name;
            const key = switch (@typeInfo(@TypeOf(fname))) {
                .enum_literal => @tagName(fname),
                else => fname,
            };
            self.attrs[self.index] = .{ .key = key, .value = @field(args, field.name) };
            self.index += 1;
        }
    }

    fn clear(self: *@This()) void {
        self.index = 0;
    }

    fn writeAndClear(self: *@This(), tag: []const u8, w: *std.Io.Writer) !void {
        if (self.index == 0) return;

        defer self.index = 0;
        defer self.tag = "";

        if (builtin.mode == .Debug) {
            if (self.tag.len > 0 and !std.mem.eql(u8, tag, self.tag)) {
                std.debug.print(
                    "can't put <{s}> attributes on <{s}>\n",
                    .{ self.tag, tag },
                );
                return Error.TagAttrMismatch;
            }
        }

        for (0..self.index) |i| {
            const item = &self.attrs[i];
            try w.writeByte(' ');
            try w.writeAll(item.key);
            try w.writeByte('=');
            try writeEscapedAttr(w, item.value);

            item.key = "";
            item.value = "";
        }
    }
};

pub const Formatter = struct {
    arena: std.heap.ArenaAllocator,

    pub fn init(gpa: Allocator) @This() {
        return .{
            .arena = .init(gpa),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
    }

    pub fn string(
        self: *@This(),
        comptime fmt: []const u8,
        args: anytype,
    ) AllocatorError![]const u8 {
        const arena = self.arena.allocator();
        return std.fmt.allocPrint(arena, fmt, args);
    }
};

const TagStack = struct {
    allocator: Allocator,
    items: std.ArrayList([]const u8) = .empty,
    index: u8 = 0,

    pub fn push(self: *@This(), item: []const u8) void {
        self.items.append(self.allocator, item) catch {
            if (builtin.mode == .Debug) {
                @panic("failed to allocator memory");
            }
        };
    }

    pub fn pop(self: *@This()) ?[]const u8 {
        return self.items.pop();
    }

    pub fn checkMatching(self: *@This(), expected: []const u8) Error!void {
        if (self.pop()) |tag| {
            if (!std.mem.eql(u8, tag, expected)) {
                std.debug.print(
                    "\ncan't close tag <{s}> : <{s}> is still open\n",
                    .{ expected, tag },
                );
                return Error.ClosingTagMismatch;
            }
        } else {
            std.debug.print(
                "\ncan't close tag <{s}> : no previous tag was opened\n",
                .{
                    expected,
                },
            );
            return Error.ClosingTagMismatch;
        }
    }
};

fn writeEscapedAttr(w: *std.Io.Writer, str: []const u8) WriterError!void {
    try w.writeByte('"');
    var pos: usize = 0;

    while (true) {
        const i = std.mem.indexOfScalarPos(u8, str, pos, '"') orelse break;
        try w.writeAll(str[pos..i]);
        try w.writeAll("&quot;");
        pos = i + 1;
    }
    try w.writeAll(str[pos..]);
    try w.writeByte('"');
}

test "matching mismatch closing tag" {
    const allocator = std.testing.allocator;
    var buf: std.Io.Writer.Discarding = .init(&.{});
    const w = &buf.writer;

    const z: Zhtml = try .init(w, allocator);
    defer z.deinit(allocator);

    try z.div.begin();
    const err = z.span.end();

    try std.testing.expectError(Error.ClosingTagMismatch, err);
}

test {
    const expected =
        \\<html>
        \\  <!--some comment here-->
        \\  <head>
        \\    <title>page title</title>
        \\    <meta charset="utf-8">
        \\    <style>
        \\body { background: red }
        \\h1 { color: blue }
        \\    </style>
        \\  </head>
        \\  <body>
        \\    <h1>heading</h1>
        \\    <h1 id="test">heading with id test</h1>
        \\    <p>This is a sentence 1.
        \\ This is a sentence 2.</p>
        \\  </body>
        \\</html>
        \\
    ;

    const allocator = std.testing.allocator;
    var buf: std.Io.Writer.Allocating = .init(allocator);
    defer buf.deinit();

    const z: Zhtml = try .init(&buf.writer, allocator);
    defer z.deinit(allocator);

    try z.html.begin();
    {
        try z.comment.render("some comment here");
        try z.head.begin();
        {
            try z.title.render("page title");
            try z.meta.attr(.charset, "utf-8");
            try z.meta.render();
            try z.style.begin();
            {
                try z.@"writeUnsafe!?"(
                    \\body { background: red }
                    \\h1 { color: blue }
                );
            }
            try z.style.end();
        }
        try z.head.end();

        try z.body.begin();
        {
            try z.h1.render("heading");

            try z.h1.attr(.id, "test");
            try z.h1.render("heading with id test");

            try z.p.render(
                \\This is a sentence 1.
                \\ This is a sentence 2.
            );
        }
        try z.body.end();
    }
    try z.html.end();

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
        \\
    ;

    const allocator = std.testing.allocator;
    var buf: std.Io.Writer.Allocating = .init(allocator);
    defer buf.deinit();

    const z: Zhtml = try .init(&buf.writer, allocator);
    defer z.deinit(allocator);

    const h1 = z.h1;
    const h2 = z.h2;
    const ul = z.ul;
    const li = z.li;

    {
        try h1.attr(.id, "id");
        try h1.render("heading");

        try h2.render("subheading");
        try ul.begin();
        for (0..10) |i| {
            if (i % 2 != 0) continue;
            try li.renderf("item {d}", .{i});
        }
        try ul.end();
    }

    const output = try buf.toOwnedSlice();
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}

test "formatting and printing" {
    const expected =
        \\<div class="foo-123">
        \\  <div>1 2 3</div>
        \\  <div>4 5 6</div>
        \\</div>
        \\
    ;

    const allocator = std.testing.allocator;
    var buf: std.Io.Writer.Allocating = .init(allocator);
    defer buf.deinit();

    const z: Zhtml = try .init(&buf.writer, allocator);
    defer z.deinit(allocator);

    var fmt: Formatter = .init(allocator);
    defer fmt.deinit();

    const div = z.div;

    try div.attr(.class, try fmt.string("foo-{d}", .{123}));
    try div.@"<>"();
    {
        try z.div.renderf("{d} {d} {d}", .{ 1, 2, 3 });
        try div.render(try fmt.string("{d} {d} {d}", .{ 4, 5, 6 }));
    }
    try div.@"</>"();

    const output = try buf.toOwnedSlice();
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}

test "pending attrs" {
    const expected =
        \\<div a="1" c="2">
        \\  <img id="im" src="/">
        \\</div>
        \\
    ;

    const allocator = std.testing.allocator;
    var buf: std.Io.Writer.Allocating = .init(allocator);
    defer buf.deinit();

    const z: Zhtml = try .init(&buf.writer, allocator);
    defer z.deinit(allocator);

    try z.div.attr(.a, "1");
    try z.div.attrs(.{ .c = "2" });
    try z.div.@"<>"();
    {
        try z.img.attr(.id, "im");
        try z.img.attr(.src, "/");
        try z.img.render();
    }
    try z.div.@"</>"();

    const output = try buf.toOwnedSlice();
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}

test "mismatched tag-attr" {
    const allocator = std.testing.allocator;
    var buf: std.Io.Writer.Allocating = .init(allocator);
    defer buf.deinit();

    const z: Zhtml = try .init(&buf.writer, allocator);
    defer z.deinit(allocator);

    try z.p.attrs(.{ .c = "2" });
    const err = z.div.@"<>"();
    try std.testing.expectError(Error.TagAttrMismatch, err);
}

test "invalid closing tag" {
    const allocator = std.testing.allocator;
    var buf: std.Io.Writer.Allocating = .init(allocator);
    defer buf.deinit();

    const z: Zhtml = try .init(&buf.writer, allocator);
    defer z.deinit(allocator);

    const err = z.div.@"</>"();
    try std.testing.expectError(Error.ClosingTagMismatch, err);
}

test {
    if (builtin.mode == .Debug) {
        std.testing.refAllDeclsRecursive(Zhtml);
    }
}

// TODO: dreaded documentation
