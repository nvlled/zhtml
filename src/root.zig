const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const Zhtml = @This();

const Error = error{ClosingTagMismatch};
const AllocatorError = Allocator.Error;
const WriterError = std.Io.Writer.Error;

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

pub fn initDebug(w: *std.Io.Writer, allocator: Allocator) AllocatorError!@This() {
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

pub inline fn write(self: @This(), str: []const u8) WriterError!void {
    return writeEscapedContent(self.internal.w, str);
}

pub inline fn @"writeUnsafe!?"(self: @This(), str: []const u8) WriterError!void {
    return self.internal.w.writeAll(str);
}

pub fn print(
    self: @This(),
    gpa: Allocator,
    comptime fmt: []const u8,
    args: anytype,
) (WriterError || AllocatorError)!void {
    const str = try std.fmt.allocPrint(gpa, fmt, args);
    defer gpa.free(str);

    try writeEscapedContent(self.internal.w, str);
}

pub fn @"printUnsafe!?"(
    self: @This(),
    gpa: Allocator,
    comptime fmt: []const u8,
    args: anytype,
) (WriterError || AllocatorError)!void {
    const str = try std.fmt.allocPrint(gpa, fmt, args);
    defer gpa.free(str);

    try self.internal.w.writeAll(str);
}

pub const Elem = struct {
    w: *std.Io.Writer,
    stack: ?*TagStack = null,
    tag: []const u8,

    pub fn begin_(self: @This()) WriterError!void {
        if (builtin.mode == .Debug) if (self.stack) |stack| {
            stack.push(self.tag);
        };

        try self.w.writeAll("<");
        try self.w.writeAll(self.tag);
        try self.w.writeAll(">");
    }

    pub fn begin(self: @This(), args: anytype) WriterError!void {
        if (builtin.mode == .Debug) if (self.stack) |stack| {
            stack.push(self.tag);
        };

        try self.w.writeAll("<");
        try self.w.writeAll(self.tag);
        try writeAttributes(self.w, args);
        try self.w.writeAll(">");
    }

    pub fn end(self: @This()) (Error || WriterError)!void {
        if (builtin.mode == .Debug) if (self.stack) |stack| {
            try stack.checkMatching(self.tag);
        };

        try self.w.writeAll("</");
        try self.w.writeAll(self.tag);
        try self.w.writeAll(">");
    }

    pub inline fn @"<>"(self: @This()) WriterError!void {
        return self.begin_();
    }

    pub fn @"<=>"(self: @This(), args: anytype) WriterError!void {
        return self.begin(args);
    }

    pub fn @"</>"(self: @This()) (Error || WriterError)!void {
        return self.end();
    }

    pub fn render(
        self: @This(),
        args: anytype,
        str: []const u8,
    ) (Error || AllocatorError || WriterError)!void {
        try self.begin(args);
        try writeEscapedContent(self.w, str);
        try self.end();
    }

    pub fn render_(
        self: @This(),
        str: []const u8,
    ) (Error || AllocatorError || WriterError)!void {
        try self.begin_();
        try writeEscapedContent(self.w, str);
        try self.end();
    }
};

const CommentElem = struct {
    w: *std.Io.Writer,
    stack: ?*TagStack = null,

    pub fn begin_(self: @This()) WriterError!void {
        if (builtin.mode == .Debug) if (self.stack) |stack| {
            stack.push("!----");
        };
        try self.w.writeAll("<!-- ");
    }

    pub fn end(self: @This()) (Error || WriterError)!void {
        if (builtin.mode == .Debug) if (self.stack) |stack| {
            try stack.checkMatching("!----");
        };

        try self.w.writeAll(" -->");
    }

    pub fn render(self: @This(), str: []const u8) (Error || WriterError)!void {
        try self.begin_();
        try writeEscapedContent(self.w, str);
        try self.end();
    }
};

const VoidElem = struct {
    w: *std.Io.Writer,
    tag: []const u8,

    pub fn render(self: @This(), args: anytype) WriterError!void {
        try self.w.writeAll("<");
        try self.w.writeAll(self.tag);
        try writeAttributes(self.w, args);
        try self.w.writeAll(">");
    }

    pub fn render_(self: @This()) WriterError!void {
        try self.w.writeAll("<");
        try self.w.writeAll(self.tag);
        try self.w.writeAll(">");
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

    const z: Zhtml = try .initDebug(w, allocator);
    defer z.deinit(allocator);

    try z.div.begin_();
    const err = z.span.end();

    try std.testing.expectError(Error.ClosingTagMismatch, err);
}

test {
    const expected =
        \\<html><!-- some comment here --><head><title>page title</title><meta charset="utf-8"><style>
        \\body { background: red }
        \\h1 { color: blue }</style></head><body><h1>heading</h1><h1 id="test">heading with id test</h1><p>This is a sentence 1.
        \\ This is a sentence 2.</p></body></html>
    ;

    const allocator = std.testing.allocator;
    var buf: std.Io.Writer.Allocating = .init(allocator);
    defer buf.deinit();

    const z: Zhtml = try .initDebug(&buf.writer, allocator);
    defer z.deinit(allocator);

    try z.html.begin_();
    {
        try z.comment.render("some comment here");
        try z.head.begin_();
        {
            try z.title.render_("page title");
            try z.meta.render(.{
                .charset = "utf-8",
            });
            try z.style.begin_();
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

        try z.body.begin_();
        {
            try z.h1.render_("heading");

            try z.h1.render(.{
                .id = "test",
            }, "heading with id test");

            try z.p.render_(
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

    const z: Zhtml = try .initDebug(&buf.writer, allocator);
    defer z.deinit(allocator);

    const h1 = z.h1;
    const h2 = z.h2;
    const ul = z.ul;
    const li = z.li;

    {
        try h1.render(.{ .id = "id" }, "heading");
        try z.write("\n");
        try h2.render_("subheading");
        try z.write("\n");
        try ul.begin_();
        try z.write("\n");
        for (0..10) |i| {
            if (i % 2 != 0) continue;
            try z.write("  ");
            try li.begin_();
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

    const z: Zhtml = try .initDebug(&buf.writer, allocator);
    defer z.deinit(allocator);

    var fmt: Formatter = .init(allocator);
    defer fmt.deinit();

    const div = z.div;

    try div.begin(.{
        .class = try fmt.string("foo-{d}", .{123}),
    });
    {
        try z.print(allocator, "{s}", .{"\n"});

        try div.begin_();
        try z.print(allocator, "{d} {d} {d}", .{ 1, 2, 3 });
        try div.end();

        try z.write("\n");
        try div.render_(try fmt.string("{d} {d} {d}", .{ 4, 5, 6 }));
        try z.write("\n");
    }
    try div.end();

    const output = try buf.toOwnedSlice();
    defer allocator.free(output);

    try std.testing.expectEqualStrings(expected, output);
}

test {
    if (builtin.mode == .Debug)
        std.testing.refAllDeclsRecursive(Zhtml);
}
