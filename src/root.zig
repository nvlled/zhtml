const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const Zhtml = @This();

const Error = error{
    ClosingTagMismatch,
};

// all elem fields will be initialized with
// comptime reflection, other fields should
// go into the internal sub-field

internal: struct {
    // all non-elem fields must be added here
    // so that the compiler can detect which
    // fields are not initialized
    w: *std.Io.Writer,
    stack: ?*TagStack,
},

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

pub fn init(w: *std.Io.Writer) !@This() {
    return initWithStack(w, null);
}

pub fn initDebug(w: *std.Io.Writer, allocator: Allocator) !@This() {
    const stack = try allocator.create(TagStack);
    stack.* = .{ .allocator = allocator };
    return initWithStack(w, stack);
}

fn initWithStack(w: *std.Io.Writer, stack_arg: ?*TagStack) @This() {
    var self: Zhtml = undefined;

    inline for (std.meta.fields(Zhtml)) |field| {
        switch (field.type) {
            // initialize the stack field for each elem,
            // this is equivalent to doing manually:
            //   self.html.w      = w;
            //   self.html.stack  = stack;
            //   self.head.w      = w;
            //   self.head.stack  = stack;
            //   self.title.w     = w;
            //   self.title.stack = stack;
            // ... and so on
            inline CommentElem, VoidElem, Elem => |t| {
                const EnumTags = std.meta.tags(std.meta.FieldEnum(t));
                switch (t) {
                    CommentElem => {
                        for (EnumTags) |ff| switch (ff) {
                            .w => @field(self, field.name).w = w,
                            .stack => @field(self, field.name).stack = stack_arg,
                        };
                    },
                    VoidElem => {
                        for (EnumTags) |ff| switch (ff) {
                            .w => @field(self, field.name).w = w,
                            .tag => @field(self, field.name).tag = field.name,
                        };
                    },
                    Elem => {
                        for (EnumTags) |ff| switch (ff) {
                            .w => @field(self, field.name).w = w,
                            .tag => @field(self, field.name).tag = field.name,
                            .stack => @field(self, field.name).stack = stack_arg,
                        };
                    },

                    else => unreachable,
                }
            },

            else => {
                // initialize internal fields
                const InternalEnum = std.meta.FieldEnum(@TypeOf(self.internal));
                for (std.meta.tags(InternalEnum)) |ff| switch (ff) {
                    .w => self.internal.w = w,
                    .stack => self.internal.stack = stack_arg,
                    // if a new field is added, initialize them here:
                    //   .new_field => self.internal.new_field = something,
                };
            },
        }
    }

    return self;
}

pub fn deinit(self: Zhtml, allocator: Allocator) void {
    if (self.internal.stack) |stack| {
        stack.items.deinit(allocator);
        allocator.destroy(stack);
    }
}

pub inline fn write(self: @This(), str: []const u8) !void {
    return writeEscapedContent(self.internal.w, str);
}

pub inline fn @"writeUnsafe!?"(self: @This(), str: []const u8) !void {
    return self.internal.w.writeAll(str);
}

pub fn print(
    self: @This(),
    gpa: Allocator,
    comptime fmt: []const u8,
    args: anytype,
) !void {
    const str = try std.fmt.allocPrint(gpa, fmt, args);
    defer gpa.free(str);

    try writeEscapedContent(self.internal.w, str);
}

pub fn @"printUnsafe!?"(
    self: @This(),
    gpa: Allocator,
    comptime fmt: []const u8,
    args: anytype,
) !void {
    const str = try std.fmt.allocPrint(gpa, fmt, args);
    defer gpa.free(str);

    try self.internal.w.writeAll(str);
}

pub const Elem = struct {
    w: *std.Io.Writer,
    stack: ?*TagStack = null,
    tag: []const u8,

    pub fn begin(self: @This()) !void {
        if (builtin.mode == .Debug) if (self.stack) |stack| {
            stack.push(self.tag);
        };

        try self.w.writeAll("<");
        try self.w.writeAll(self.tag);
        try self.w.writeAll(">");
    }

    pub fn begin_(self: @This(), args: anytype) !void {
        if (builtin.mode == .Debug) if (self.stack) |stack| {
            stack.push(self.tag);
        };

        try self.w.writeAll("<");
        try self.w.writeAll(self.tag);
        try writeAttributes(self.w, args);
        try self.w.writeAll(">");
    }

    pub fn end(self: @This()) !void {
        if (builtin.mode == .Debug) if (self.stack) |stack| {
            try stack.checkMatching(self.tag);
        };

        try self.w.writeAll("</");
        try self.w.writeAll(self.tag);
        try self.w.writeAll(">");
    }

    pub inline fn @"<>"(self: @This()) !void {
        return self.begin();
    }

    pub fn @"<=>"(self: @This(), args: anytype) !void {
        return self.begin_(args);
    }

    pub fn @"</>"(self: @This()) !void {
        return self.end();
    }

    pub fn render_(self: @This(), args: anytype, str: []const u8) !void {
        try self.begin_(args);
        try writeEscapedContent(self.w, str);
        try self.end();
    }

    pub fn render(self: @This(), str: []const u8) !void {
        try self.begin();
        try writeEscapedContent(self.w, str);
        try self.end();
    }

    pub fn @"renderUnsafe_!?"(self: @This(), args: anytype, str: []const u8) !void {
        try self.begin_(args);
        try self.w.writeAll(str);
        try self.end();
    }

    pub fn @"renderUnsafe!?"(self: @This(), str: []const u8) !void {
        try self.begin();
        try self.w.writeAll(str);
        try self.end();
    }

    pub inline fn write(self: @This(), str: []const u8) !void {
        return writeEscapedContent(self.w, str);
    }

    pub inline fn @"writeUnsafe!?"(self: @This(), str: []const u8) !void {
        return self.w.writeAll(str);
    }

    pub fn renderPrint(
        self: @This(),
        gpa: Allocator,
        comptime fmt: []const u8,
        args: anytype,
    ) !void {
        const str = try std.fmt.allocPrint(gpa, fmt, args);
        defer gpa.free(str);

        try self.begin();
        try writeEscapedContent(self.w, str);
        try self.end();
    }

    pub fn @"renderPrintUnsafe!?"(
        self: @This(),
        gpa: Allocator,
        comptime fmt: []const u8,
        args: anytype,
    ) !void {
        const str = try std.fmt.allocPrint(gpa, fmt, args);
        defer gpa.free(str);

        try self.begin();
        try self.w.writeAll(str);
        try self.end();
    }
};

const CommentElem = struct {
    w: *std.Io.Writer,
    stack: ?*TagStack = null,

    pub fn begin(self: @This()) !void {
        if (builtin.mode == .Debug) if (self.stack) |stack| {
            stack.push("!----");
        };
        try self.w.writeAll("<!-- ");
    }

    pub fn end(self: @This()) !void {
        if (builtin.mode == .Debug) if (self.stack) |stack| {
            try stack.checkMatching("!----");
        };

        try self.w.writeAll(" -->");
    }

    pub fn render(self: @This(), str: []const u8) !void {
        try self.begin();
        try writeEscapedContent(self.w, str);
        try self.end();
    }

    pub fn @"renderUnsafe!?"(self: @This(), str: []const u8) !void {
        try self.begin();
        try self.w.writeAll(str);
        try self.end();
    }

    pub inline fn write(self: @This(), str: []const u8) !void {
        return writeEscapedContent(self.w, str);
    }

    pub inline fn @"writeUnsafe!?"(self: @This(), str: []const u8) !void {
        return self.w.writeAll(str);
    }
};

const VoidElem = struct {
    w: *std.Io.Writer,
    tag: []const u8,

    pub fn render_(self: @This(), args: anytype) !void {
        try self.w.writeAll("<");
        try self.w.writeAll(self.tag);
        try writeAttributes(self.w, args);
        try self.w.writeAll(">");
    }

    pub fn render(self: @This()) !void {
        try self.w.writeAll("<");
        try self.w.writeAll(self.tag);
        try self.w.writeAll(">");
    }
};

const Formatter = struct {
    arena: std.heap.ArenaAllocator,

    pub fn init(gpa: Allocator) @This() {
        return .{
            .arena = .init(gpa),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
    }

    pub fn print(self: *@This(), comptime fmt: []const u8, args: anytype) ![]const u8 {
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

    pub fn checkMatching(self: *@This(), expected: []const u8) !void {
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

inline fn writeAttributes(w: *std.Io.Writer, args: anytype) !void {
    inline for (std.meta.fields(@TypeOf(args))) |field| {
        try w.print(" {s}=", .{field.name});
        try writeEscapedAttr(w, @field(args, field.name));
    }
}

fn writeEscapedContent(w: *std.Io.Writer, str: []const u8) !void {
    for (str) |ch| {
        switch (ch) {
            '<' => try w.writeAll("&lt;"),
            '>' => try w.writeAll("&gt;"),
            '&' => try w.writeAll("&amp;"),
            else => try w.writeByte(ch),
        }
    }
}

fn writeEscapedAttr(w: *std.Io.Writer, str: []const u8) !void {
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

    const z: Zhtml = try .initDebug(w, allocator);
    defer z.deinit(allocator);

    try z.div.begin();
    const err = z.span.end();

    try std.testing.expectError(Error.ClosingTagMismatch, err);
}

test {
    const expected =
        \\<html><head><title>page title</title><meta charset="utf-8"><style>
        \\body { background: red }
        \\h1 { color: blue }</style></head><body><h1>heading</h1><h1 id="test">heading with id test</h1><p>This is a sentence 1.
        \\ This is a sentence 2.</p></body></html>
    ;

    const allocator = std.testing.allocator;
    var buf: std.Io.Writer.Allocating = .init(allocator);
    defer buf.deinit();

    const z: Zhtml = try .initDebug(&buf.writer, allocator);
    defer z.deinit(allocator);

    try z.html.begin();
    {
        try z.head.begin();
        {
            try z.title.render("page title");
            try z.meta.render_(.{
                .charset = "utf-8",
            });
            try z.style.begin();
            {
                try z.style.@"writeUnsafe!?"(
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

            try z.h1.render_(.{
                .id = "test",
            }, "heading with id test");

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
        \\  <li>item 1</li>
        \\  <li>item 2</li>
        \\  <li>item 3</li>
        \\  <li>item 4</li>
        \\</ul>
    ;

    const allocator = std.testing.allocator;
    var buf: std.Io.Writer.Allocating = .init(allocator);
    defer buf.deinit();

    const z: Zhtml = try .initDebug(&buf.writer, allocator);
    defer z.deinit(allocator);

    const h1 = z.h1;
    const h2 = z.h2;
    const ul = z.ul;
    const li = z.li;

    {
        try h1.render_(.{ .id = "id" }, "heading");
        try z.write("\n");
        try h2.render("subheading");
        try z.write("\n");
        try ul.begin();
        try z.write("\n");
        for (0..5) |i| {
            try z.write("  ");
            try li.renderPrint(allocator, "item {d}", .{i});
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
        \\<div>7 8 9</div>
        \\<div>10 11 12</div>
        \\</div>
    ;

    const allocator = std.testing.allocator;
    var buf: std.Io.Writer.Allocating = .init(allocator);
    defer buf.deinit();

    const z: Zhtml = try .initDebug(&buf.writer, allocator);
    defer z.deinit(allocator);

    var fmt: Formatter = .init(allocator);
    defer fmt.deinit();

    const div = z.div;

    try div.begin_(.{
        .class = try fmt.print("foo-{d}", .{123}),
    });
    {
        try z.print(allocator, "{s}", .{"\n"});
        try div.renderPrint(allocator, "{d} {d} {d}", .{ 1, 2, 3 });
        try z.write("\n");
        try div.render(try fmt.print("{d} {d} {d}", .{ 4, 5, 6 }));
        try z.write("\n");
        try div.@"renderPrintUnsafe!?"(allocator, "{d} {d} {d}", .{ 7, 8, 9 });
        try z.write("\n");
        try div.@"renderUnsafe!?"(try fmt.print("{d} {d} {d}", .{ 10, 11, 12 }));
        try z.write("\n");
    }
    try div.end();

    const output = try buf.toOwnedSlice();
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}
