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
    allocator.destroy(self._internal);
}

pub fn attr(self: @This(), key: anytype, value: []const u8) Error!void {
    return self._internal.pending_attrs.add(key, value);
}

pub fn attrs(self: @This(), args: anytype) Error!void {
    return self._internal.pending_attrs.addMany(args);
}

pub inline fn write(self: @This(), str: []const u8) WriterError!void {
    return writeEscapedContent(self._internal.w, str);
}

pub inline fn @"writeUnsafe!?"(self: @This(), str: []const u8) WriterError!void {
    return self._internal.w.writeAll(str);
}

pub fn print(
    self: @This(),
    gpa: Allocator,
    comptime fmt: []const u8,
    args: anytype,
) (WriterError || AllocatorError)!void {
    const str = try std.fmt.allocPrint(gpa, fmt, args);
    defer gpa.free(str);

    try writeEscapedContent(self._internal.w, str);
}

pub fn @"printUnsafe!?"(
    self: @This(),
    gpa: Allocator,
    comptime fmt: []const u8,
    args: anytype,
) (WriterError || AllocatorError)!void {
    const str = try std.fmt.allocPrint(gpa, fmt, args);
    defer gpa.free(str);

    try self._internal.w.writeAll(str);
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

        try z.w.writeAll("<");
        try z.w.writeAll(self.tag);
        try z.pending_attrs.writeAndClear(self.tag, z.w);
        try z.w.writeAll(">");
    }

    pub fn end(self: @This()) (Error || WriterError)!void {
        const z = self._internal;
        if (builtin.mode == .Debug) {
            try z.stack.checkMatching(self.tag);
        }

        try z.w.writeAll("</");
        try z.w.writeAll(self.tag);
        try z.w.writeAll(">");
    }

    pub fn render(
        self: @This(),
        str: []const u8,
    ) (Error || WriterError)!void {
        try self.begin();
        try writeEscapedContent(self._internal.w, str);
        try self.end();
    }

    pub fn renderf(
        self: @This(),
        allocator: Allocator,
        comptime fmt: []const u8,
        args: anytype,
    ) (Error || AllocatorError || WriterError)!void {
        const str = try std.fmt.allocPrint(allocator, fmt, args);
        defer allocator.free(str);
        try self.render(str);
    }

    pub inline fn @"<>"(self: @This()) (Error || WriterError)!void {
        return self.begin();
    }

    pub fn @"</>"(self: @This()) (Error || WriterError)!void {
        return self.end();
    }

    pub fn @"<=>"(
        self: @This(),
        str: []const u8,
    ) (Error || WriterError)!void {
        return self.render(str);
    }

    pub fn attr(self: @This(), key: anytype, value: []const u8) Error!void {
        self._internal.pending_attrs.tag = self.tag;
        return self._internal.pending_attrs.add(key, value);
    }

    pub fn attrs(self: @This(), args: anytype) Error!void {
        self._internal.pending_attrs.tag = self.tag;
        return self._internal.pending_attrs.addMany(args);
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
        try self._internal.w.writeAll("<!--");
    }

    pub fn end(self: @This()) (Error || WriterError)!void {
        if (builtin.mode == .Debug) {
            try self._internal.stack.checkMatching("!----");
        }

        try self._internal.w.writeAll("-->");
    }

    pub fn render(self: @This(), str: []const u8) (Error || WriterError)!void {
        self._internal.pending_attrs.clear();
        try self.begin();
        try writeEscapedContent(self._internal.w, str);
        try self.end();
    }

    pub fn renderf(
        self: @This(),
        allocator: Allocator,
        comptime fmt: []const u8,
        args: anytype,
    ) (Error || AllocatorError || WriterError)!void {
        const str = try std.fmt.allocPrint(allocator, fmt, args);
        defer allocator.free(str);
        try self.render(str);
    }

    pub fn @"<=>"(
        self: @This(),
        str: []const u8,
    ) (Error || WriterError)!void {
        return self.render(str);
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
        try z.w.writeAll("<");
        try z.w.writeAll(self.tag);
        try z.pending_attrs.writeAndClear(self.tag, z.w);
        try z.w.writeAll(">");
    }

    pub inline fn @"<>"(self: @This()) (Error || WriterError)!void {
        return self.render();
    }

    pub fn attr(self: @This(), key: anytype, value: []const u8) Error!void {
        self._internal.pending_attrs.tag = self.tag;
        return self._internal.pending_attrs.add(key, value);
    }

    pub fn attrs(self: @This(), args: anytype) Error!void {
        self._internal.pending_attrs.tag = self.tag;
        return self._internal.pending_attrs.addMany(args);
    }
};

const PendingAttrs = struct {
    index: usize = 0,
    tag: []const u8 = "",
    attrs: [512]struct { []const u8, []const u8 } = undefined,

    fn add(self: *@This(), key_arg: anytype, value: []const u8) Error!void {
        if (self.index >= self.attrs.len) return Error.TooManyAttrs;
        const key = switch (@typeInfo(@TypeOf(key_arg))) {
            .enum_literal => @tagName(key_arg),
            else => key_arg,
        };
        self.attrs[self.index] = .{ key, value };
        self.index += 1;
    }

    fn addMany(self: *@This(), args: anytype) Error!void {
        inline for (std.meta.fields(@TypeOf(args))) |field| {
            try self.add(field.name, @field(args, field.name));
        }
    }

    fn clear(self: *@This()) void {
        self.index = 0;
    }

    fn writeAndClear(self: *@This(), tag: []const u8, w: *std.Io.Writer) !void {
        if (self.index > 0) {
            if (builtin.mode == .Debug and
                self.tag.len > 0 and
                !std.mem.eql(u8, tag, self.tag))
            {
                std.debug.print(
                    "can't put <{s}> attributes on <{s}>",
                    .{ self.tag, tag },
                );
                return Error.TagAttrMismatch;
            }
        }

        for (0..self.index) |i| {
            const key, const value = self.attrs[i];
            try w.writeByte(' ');
            try w.writeAll(key);
            try w.writeByte('=');
            try writeEscapedAttr(w, value);
        }
        self.index = 0;
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
        const tag = self.pop();
        if (tag == null or !std.mem.eql(u8, tag.?, expected)) {
            std.debug.print(
                "\ncan't close tag <{s}> : <{s}> is still open\n",
                .{ expected, if (tag) |s| s else "null" },
            );
            return Error.ClosingTagMismatch;
        }
    }
};

inline fn writeAttributes(w: *std.Io.Writer, args: anytype) WriterError!void {
    inline for (std.meta.fields(@TypeOf(args))) |field| {
        try w.print(" {s}=", .{field.name});
        try writeEscapedAttr(w, @field(args, field.name));
    }
}

fn writeEscapedContent(w: *std.Io.Writer, str: []const u8) WriterError!void {
    for (str) |ch| {
        switch (ch) {
            '<' => try w.writeAll("&lt;"),
            '>' => try w.writeAll("&gt;"),
            '&' => try w.writeAll("&amp;"),
            else => try w.writeByte(ch),
        }
    }
}

fn writeEscapedAttr(w: *std.Io.Writer, str: []const u8) WriterError!void {
    try w.writeByte('"');
    for (str) |ch| {
        switch (ch) {
            '\'' => try w.writeAll("\\'"),
            '"' => try w.writeAll("\\\""),
            else => try w.writeByte(ch),
        }
    }
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
        \\<html><!--some comment here--><head><title>page title</title><meta charset="utf-8"><style>
        \\body { background: red }
        \\h1 { color: blue }</style></head><body><h1>heading</h1><h1 id="test">heading with id test</h1><p>This is a sentence 1.
        \\ This is a sentence 2.</p></body></html>
    ;

    const allocator = std.testing.allocator;
    var buf: std.Io.Writer.Allocating = .init(allocator);
    defer buf.deinit();

    const z: Zhtml = if (builtin.mode == .Debug)
        try .init(&buf.writer, allocator)
    else
        .init(&buf.writer, allocator);

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
                    \\
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

        try z.write("\n");
        try h2.render("subheading");
        try z.write("\n");
        try ul.begin();
        try z.write("\n");
        for (0..10) |i| {
            if (i % 2 != 0) continue;
            try z.write("  ");
            try li.begin();
            try z.print(allocator, "item {d}", .{i});
            try li.end();
            try z.write("\n");
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
        \\<div>1 2 3</div>
        \\<div>4 5 6</div>
        \\</div>
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
        try z.print(allocator, "{s}", .{"\n"});
        try z.div.renderf(allocator, "{d} {d} {d}", .{ 1, 2, 3 });

        try z.write("\n");
        try div.@"<=>"(try fmt.string("{d} {d} {d}", .{ 4, 5, 6 }));
        try z.write("\n");
    }
    try div.@"</>"();

    const output = try buf.toOwnedSlice();
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}

test "pending attrs" {
    const expected =
        \\<div a="1" c="2"><img id="im" src="/"></div>
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
        try z.img.@"<>"();
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

test {
    if (builtin.mode == .Debug) {
        std.testing.refAllDeclsRecursive(Zhtml);
    }
}

// TODO: dreaded documentation
