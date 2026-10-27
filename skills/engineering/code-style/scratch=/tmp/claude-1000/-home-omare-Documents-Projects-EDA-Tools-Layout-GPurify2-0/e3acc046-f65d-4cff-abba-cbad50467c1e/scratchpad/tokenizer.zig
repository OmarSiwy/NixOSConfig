//! Tokenizer: source bytes → `Tokens` (one tag and one start offset per run).
//! Cites: none (house grammar, docs/grammar.md).
//!
//! Contents:
//! - `pub const Tag = enum(u8)`: the byte class a token's run shares.
//! - `pub const Tokens = struct`: one tag and one start per token, as two columns.
//! - `Tokens.deinit(tokens: *Tokens, gpa: Allocator) void`: frees both columns.
//! - `pub const Error = error{ OutOfMemory, SourceTooLong }`: why `tokenize` stopped.
//! - `pub fn tokenize(gpa: Allocator, src: []const u8, out: *Tokens) Error!void`: appends a token per run.

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const Tag = enum(u8) { ident, number, space, punct };

/// `tags` and `starts` always have equal length; `tokenize` asserts it on return.
pub const Tokens = struct {
    tags: std.ArrayList(Tag) = .empty,
    starts: std.ArrayList(u32) = .empty,

    pub fn deinit(tokens: *Tokens, gpa: Allocator) void {
        tokens.tags.deinit(gpa);
        tokens.starts.deinit(gpa);
    }
};

pub const Error = error{ OutOfMemory, SourceTooLong };

/// Appends one token per run of same-tag bytes. On error, `out` holds the tokens before the failing run.
pub fn tokenize(gpa: Allocator, src: []const u8, out: *Tokens) Error!void {
    if (src.len > std.math.maxInt(u32)) return error.SourceTooLong;
    var i: u32 = 0;
    while (i < src.len) {
        const tag = classify(src[i]);
        const end = runEnd(src, i, tag);
        try out.tags.append(gpa, tag);
        try out.starts.append(gpa, i);
        i = end;
    }
    assert(out.tags.items.len == out.starts.items.len);
}

// ---- private ----

fn classify(c: u8) Tag {
    return switch (c) {
        'a'...'z', 'A'...'Z', '_' => .ident,
        '0'...'9' => .number,
        ' ', '\t', '\n' => .space,
        else => .punct,
    };
}

fn runEnd(src: []const u8, start: u32, tag: Tag) u32 {
    var i = start + 1;
    while (i < src.len and classify(src[i]) == tag) i += 1;
    return i;
}

// ---- tests ----

test "tokenize splits runs by tag" {
    try expectTags("ab 12", &.{ .ident, .space, .number }, &.{ 0, 2, 3 });
}

test "tokenize keeps a punct run whole" {
    try expectTags("+=x", &.{ .punct, .ident }, &.{ 0, 2 });
}

/// Tokenizes `src` and checks both columns against the expected rows.
fn expectTags(src: []const u8, tags: []const Tag, starts: []const u32) !void {
    const gpa = std.testing.allocator;
    var tokens: Tokens = .{};
    defer tokens.deinit(gpa);
    try tokenize(gpa, src, &tokens);
    try std.testing.expectEqualSlices(Tag, tags, tokens.tags.items);
    try std.testing.expectEqualSlices(u32, starts, tokens.starts.items);
}
