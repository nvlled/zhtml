const std = @import("std");
const builtin = @import("builtin");

const Self = @This();

const Error = error{
    ClosingTagMismatch,
};

w: *std.Io.Writer,
stack: ?*TagStack,

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

pub fn init(w: *std.Io.Writer) @This() {
    return initWithStack(w, null);
}

pub fn initDebug(w: *std.Io.Writer, allocator: std.mem.Allocator) @This() {
    const stack = allocator.create(TagStack) catch {
        @panic("failed to allocate memory for the stack");
    };
    stack.* = .{ .allocator = allocator };
    return initWithStack(w, stack);
}

fn initWithStack(w: *std.Io.Writer, stack_arg: ?*TagStack) @This() {
    var self: @This() = .{
        .w = w,
        .stack = stack_arg,

        .html = .{ .w = w, .tag = "html" },
        .head = .{ .w = w, .tag = "head" },
        .title = .{ .w = w, .tag = "title" },
        .body = .{ .w = w, .tag = "body" },
        .meta = .{ .w = w, .tag = "meta" },

        .script = .{ .w = w, .tag = "script" },
        .style = .{ .w = w, .tag = "style" },
        .noscript = .{ .w = w, .tag = "noscript" },
        .link = .{ .w = w, .tag = "link" },

        .a = .{ .w = w, .tag = "a" },
        .base = .{ .w = w, .tag = "base" },

        .p = .{ .w = w, .tag = "p" },
        .div = .{ .w = w, .tag = "div" },
        .span = .{ .w = w, .tag = "span" },

        .details = .{ .w = w, .tag = "details" },
        .summary = .{ .w = w, .tag = "summary" },

        .b = .{ .w = w, .tag = "b" },
        .i = .{ .w = w, .tag = "i" },
        .em = .{ .w = w, .tag = "em" },
        .strong = .{ .w = w, .tag = "strong" },
        .small = .{ .w = w, .tag = "small" },
        .s = .{ .w = w, .tag = "s" },
        .pre = .{ .w = w, .tag = "pre" },
        .code = .{ .w = w, .tag = "code" },

        .br = .{ .w = w, .tag = "br" },
        .hr = .{ .w = w, .tag = "hr" },

        .blockQuote = .{ .w = w, .tag = "blockQuote" },

        .ol = .{ .w = w, .tag = "ol" },
        .ul = .{ .w = w, .tag = "ul" },
        .li = .{ .w = w, .tag = "li" },

        .form = .{ .w = w, .tag = "form" },
        .input = .{ .w = w, .tag = "input" },
        .textarea = .{ .w = w, .tag = "textarea" },
        .button = .{ .w = w, .tag = "button" },
        .label = .{ .w = w, .tag = "label" },
        .select = .{ .w = w, .tag = "select" },
        .option = .{ .w = w, .tag = "option" },

        .h1 = .{ .w = w, .tag = "h1" },
        .h2 = .{ .w = w, .tag = "h2" },
        .h3 = .{ .w = w, .tag = "h3" },
        .h4 = .{ .w = w, .tag = "h4" },
        .h5 = .{ .w = w, .tag = "h5" },
        .h6 = .{ .w = w, .tag = "h6" },
        .h7 = .{ .w = w, .tag = "h7" },

        .table = .{ .w = w, .tag = "table" },
        .thead = .{ .w = w, .tag = "thead" },
        .tbody = .{ .w = w, .tag = "tbody" },
        .col = .{ .w = w, .tag = "col" },
        .tr = .{ .w = w, .tag = "tr" },
        .td = .{ .w = w, .tag = "td" },

        .svg = .{ .w = w, .tag = "svg" },
        .img = .{ .w = w, .tag = "img" },
        .area = .{ .w = w, .tag = "area" },

        .iframe = .{ .w = w, .tag = "iframe" },

        .video = .{ .w = w, .tag = "video" },
        .embed = .{ .w = w, .tag = "embed" },
        .track = .{ .w = w, .tag = "track" },
        .source = .{ .w = w, .tag = "source" },

        .comment = .{ .w = w },
    };

    if (stack_arg) |stack| {
        inline for (std.meta.fields(Self)) |field| {
            // initialize the stack field for each elem,
            // this is equivalent to doing manually:
            //   self.html.stack  = stack;
            //   self.head.stack  = stack;
            //   self.title.stack = stack;
            // ... and so on
            const f: std.builtin.Type.StructField = field;
            switch (f.type) {
                Elem, CommentElem => {
                    @field(self, f.name).stack = stack;
                },
                else => {},
            }
        }
    }

    return self;
}

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    if (self.stack) |stack| {
        stack.items.deinit(allocator);
        allocator.destroy(stack);
    }
}

pub inline fn write(self: @This(), str: []const u8) !void {
    return writeEscapedContent(self.w, str);
}

pub inline fn writeUnsafe(self: @This(), str: []const u8) !void {
    return self.w.writeAll(str);
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

const TagStack = struct {
    allocator: std.mem.Allocator,
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

fn writeAttributes(w: *std.Io.Writer, args: anytype) !void {
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

test {
    const allocator = std.testing.allocator;
    var stderr = std.fs.File.stderr().writer(&.{});
    const w = &stderr.interface;

    const z: Self = .initDebug(w, allocator);
    defer z.deinit(allocator);

    const div, const span, const img = .{
        z.div,
        z.span,
        z.img,
    };

    try span.@"<>"();
    try span.write("asdfafds");
    try span.@"</>"();
    try z.write("\n");
    try span.render("inside span");
    try z.write("\n");

    try img.render_(.{ .src = "blah" });

    try z.write("\n");

    try z.comment.begin();
    try z.comment.end();
    try z.write("\n");

    try div.@"<=>"(.{ .id = "foo", .class = "blah" });
    {
        try span.render("<asdf");
        try span.@"renderUnsafe!?"("<asdf");
        try z.write("<test>");
        try z.writeUnsafe("<test>");
        //try component1.write();
        //try component2.start();
        {
            // stuffs here
        }
        //try component2.end();
    }

    try div.@"</>"();
    try z.write("\n");
}

test "matching mismatch closing tag" {
    const allocator = std.testing.allocator;
    var buf: std.Io.Writer.Discarding = .init(&.{});
    const w = &buf.writer;

    const z: Self = .initDebug(w, allocator);
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

    const w = &buf.writer;
    const z: Self = .initDebug(w, allocator);
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
            try z.h1.render_(.{ .id = "test" }, "heading with id test");
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
