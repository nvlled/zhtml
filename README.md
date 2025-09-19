
# zhtml

A simple low-abstraction HTML templating library for zig.

The templating language uses ordinary zig code: 

```zig
try h1.render(.{ .id = "id" }, "heading");
try h2.render_("subheading");

try ul.begin();
for (0..10) |i| {
    if (i % 2 == 0)
      try li.renderPrint(allocator, "item {d}", .{i});
}
try ul.end();

// output:
// <h1 id="id">heading</h1>
// <h2>subheading</h2>
// <ul>
//   <li>blah</li>
//   <li>blah</li>
//   <li>blah</li>
// </ul>
```

Depending on one's taste, this may or may look horribly verbose,
or criminally procedural for a declarative markup.
On the plus side, it's fairly close to the "metal",
so it shoud be quite fast.

Basically this is almost just a wrapper for the Io.Writer interface,
but with the supposed benefits:
- prevents silly HTML syntax errors
- prevents common XSS mistakes
- allows looping and conditionals
- composable HTML components
- low-overhead in contrast to other interpreted templating
  languages

## Why not just use
- **Writer.print**
  Not maintainable for larger HTML docs. Also not 
  as composable and is more error-prone, since it's all
  stringly typed.
  
- **jetzig-framework/zmpl**
  I would have nearly just used this instead, since it allows
  using zig code in the template. But it uses it's own
  DSL and file format, which means added tooling dependency
  and configuration. It also uses its own zig interpreter
  that probably supports only a subset of the language.
  In short, too complex of a dependency for my simple needs.

- **kristoff-it/superhtml**
  This one uses only plain HTML with DSL that is
  still compatible syntax-wise with HTML. Alas,
  I'm not sure how to use it as a templating engine
  that I could import directly. It's 
  probably possible but not yet documented.
  Like zmpl, this one has custom tooling and even
  its own LSP server. But the added nice stuffs exceeds
  my complexity budget.
  
 - **something else** 
   I haven't found any other alternatives.
   To be fair, I didn't spend much time/effort searching
   for more. Writing and dogfooding my own templating
   engine seems easier though (or funner).
   
