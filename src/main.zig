// To run this file:
// $ zig run src/main.zig

const std = @import("std");
const Zhtml = @import("./zhtml-wrapped.zig");

pub fn example1(allocator: std.mem.Allocator) !void {
    var buf: std.io.Writer.Allocating = .init(allocator);
    defer std.debug.print("{s}\n", .{buf.toOwnedSlice() catch ""});

    const z: Zhtml = try .init(&buf.writer, allocator);
    defer {
        if (z.getErrorTrace()) |trace|
            std.debug.print("{s}", .{trace});
        z.deinit(allocator);
    }

    z.html.@"<>"();
    {
        z.head.@"<>"();
        {
            z.title.@"<=>"("Example 1");
            z.meta.attr(.charset, "utf-8");
            z.meta.@"<>"();
        }
        z.head.@"</>"();

        z.body.@"<>"();
        {
            z.h1.attr(.id, "header");
            z.h1.@"<=>"("Example 1");

            z.p.attr(.id, "para");
            z.p.attr(.class, "a b c");
            z.p.@"<>"();
            {
                z.write("This is a paragraph/sentence. And here is an image:");
                z.img.attrs(.{ .class = "border", .src = "image.png" });
                z.img.@"<>"();
                z.write("And some more text here.");
            }
            z.p.@"</>"();
        }
        z.body.@"</>"();
    }
    z.html.@"</>"();

    return z.getError();
}

// This one is similar to example1(), but with explicit error-handling.
pub fn example2(allocator: std.mem.Allocator) !void {
    var buf: std.io.Writer.Allocating = .init(allocator);
    defer std.debug.print("{s}\n", .{buf.toOwnedSlice() catch ""});

    const zhtml: Zhtml = try .init(&buf.writer, allocator);
    defer {
        if (zhtml.getErrorTrace()) |trace|
            std.debug.print("{s}", .{trace});
        zhtml.deinit(allocator);
    }

    const z = zhtml.unwrap;

    try z.html.@"<>"();
    {
        try z.head.@"<>"();
        {
            try z.title.@"<=>"("Example 2");
            try z.meta.attr(.charset, "utf-8");
            try z.meta.@"<>"();
        }
        try z.head.@"</>"();

        try z.body.@"<>"();
        {
            try z.h1.attr(.id, "Example 2");
            try z.h1.@"<=>"("Page header");

            try z.p.attr(.id, "para");
            try z.p.attr(.class, "a b c");
            try z.p.@"<>"();
            {
                try z.write("This is a paragraph/sentence. And here is an image:");
                try z.img.attrs(.{ .class = "border", .src = "image.png" });
                try z.img.@"<>"();
                try z.write("And some more text here.");
            }
            try z.p.@"</>"();
        }
        try z.body.@"</>"();
    }
    try z.html.@"</>"();
}

// This example uses control flow for rendering the HTML.
// It also uses the alternative non-symbol method names:
//   begin, end, render instead of <>, </>, <=>
pub fn example3(allocator_arg: std.mem.Allocator) !void {
    var arena: std.heap.ArenaAllocator = .init(allocator_arg);
    const allocator = arena.allocator();

    var buf: std.io.Writer.Allocating = .init(allocator);
    defer std.debug.print("{s}\n", .{buf.toOwnedSlice() catch ""});

    const z: Zhtml = try .init(&buf.writer, allocator);
    defer {
        if (z.getErrorTrace()) |trace|
            std.debug.print("{s}", .{trace});
        z.deinit(allocator);
    }

    z.div.begin();
    {
        z.ul.attr(.id, "evens");
        z.ul.begin();
        z.write("\n");
        for (0..20) |i| {
            if (i % 2 == 0) {
                try z.li.renderf(allocator, "item no. {d}", .{i});
                z.write("\n");
            }
        }
        z.ul.end();
    }
    z.div.end();
}

pub fn main() !void {
    var dbg_allocator: std.heap.DebugAllocator(.{}) = .{};
    const allocator = dbg_allocator.allocator();

    std.debug.print("Example 1 output:\n\n", .{});
    try example1(allocator);

    std.debug.print("\n\n", .{});

    std.debug.print("Example 2 output:\n\n", .{});
    try example2(allocator);

    std.debug.print("\n\n", .{});

    std.debug.print("Example 3 output:\n\n", .{});
    try example3(allocator);
}
