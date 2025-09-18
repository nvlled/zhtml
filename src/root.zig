const std = @import("std");

const Self = @This();

w: *std.Io.Writer,

html: Elem,
head: Elem,
title: Elem,
body: Elem,
meta: VoidElem,

script: Elem,
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
    return .{
        .w = w,
        .html = .{ .w = w, .tag = "html" },
        .head = .{ .w = w, .tag = "head" },
        .title = .{ .w = w, .tag = "title" },
        .body = .{ .w = w, .tag = "body" },
        .meta = .{ .w = w, .tag = "meta" },

        .script = .{ .w = w, .tag = "script" },
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
}

pub inline fn write(self: @This(), str: []const u8) !void {
    return writeEscapedContent(self.w, str);
}

pub inline fn writeUnsafe(self: @This(), str: []const u8) !void {
    return self.w.writeAll(str);
}

const Elem = struct {
    w: *std.Io.Writer,
    tag: []const u8,

    pub fn begin(self: @This()) !void {
        try self.w.writeAll("</");
        try self.w.writeAll(self.tag);
        try self.w.writeAll(">");
    }
    pub fn begin_(self: @This(), args: anytype) !void {
        try self.w.writeAll("<");
        try self.w.writeAll(self.tag);
        try writeAttributes(self.w, args);
        try self.w.writeAll(">");
    }

    pub fn end(self: @This()) !void {
        try self.w.writeAll("</");
        try self.w.writeAll(self.tag);
        try self.w.writeAll(">");
    }

    pub fn @"<>"(self: @This()) !void {
        try self.w.writeAll("</");
        try self.w.writeAll(self.tag);
        try self.w.writeAll(">");
    }

    pub fn @"<=>"(self: @This(), args: anytype) !void {
        try self.w.writeAll("<");
        try self.w.writeAll(self.tag);
        try writeAttributes(self.w, args);
        try self.w.writeAll(">");
    }

    pub fn @"</>"(self: @This()) !void {
        try self.w.writeAll("</");
        try self.w.writeAll(self.tag);
        try self.w.writeAll(">");
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

    pub fn renderUnsafe_(self: @This(), args: anytype, str: []const u8) !void {
        try self.begin_(args);
        try self.w.writeAll(str);
        try self.end();
    }

    pub fn renderUnsafe(self: @This(), str: []const u8) !void {
        try self.begin();
        try self.w.writeAll(str);
        try self.end();
    }

    pub inline fn write(self: @This(), str: []const u8) !void {
        return writeEscapedContent(self.w, str);
    }

    pub inline fn writeUnsafe(self: @This(), str: []const u8) !void {
        return self.w.writeAll(str);
    }
};

const CommentElem = struct {
    w: *std.Io.Writer,

    pub fn begin(self: @This()) !void {
        try self.w.writeAll("<!-- ");
    }

    pub fn end(self: @This()) !void {
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
    var stderr = std.fs.File.stderr().writer(&.{});
    const w = &stderr.interface;
    const h: Self = .init(w);
    const div, const span, const img = .{
        h.div,
        h.span,
        h.img,
    };

    try span.@"<>"();
    try span.write("asdfafds");
    try span.@"</>"();
    try h.write("\n");
    try span.render("inside span");
    try h.write("\n");

    try img.render_(.{ .src = "blah" });

    try h.write("\n");

    try h.comment.begin();
    try h.comment.end();
    try h.write("\n");

    try div.@"<=>"(.{ .id = "foo", .class = "blah" });
    {
        try span.render("<asdf");
        try span.renderUnsafe("<asdf");
        try h.write("<test>");
        try h.writeUnsafe("<test>");
        //try component1.write();
        //try component2.start();
        {
            // stuffs here
        }
        //try component2.end();
    }

    try div.@"</>"();
}
