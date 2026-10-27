#!/usr/bin/env python3
"""Mechanical rows of the code-style checklist, over every .zig and .rs file under a path.

Checks: `//!` header first, header Contents names every `pub` item, file-level order
(imports, pub types, private types, pub fns, private separator, private fns, tests
separator, tests), each separator present where its region starts, no top-level helper or
type above the tests separator that only tests use, code lines before tests <=
MAX_CODE_LINES, no `item_x` file beside `item` (nest it as `item/x`), and no source folder
holding a single file. Prints `path:line: rule: message` per violation and exits 1
if any. `--self-test` runs the built-in cases.

Usage: check_style.py <dir-or-file>... | --self-test
"""

import os
import re
import sys
import tempfile

MAX_CODE_LINES = 500
SEPARATOR = re.compile(r"^// -+ private -+$")
TEST_SEPARATOR = re.compile(r"^// -+ tests -+$")
SKIP_DIRS = {".git", "target", "zig-out", ".zig-cache", "zig-cache", "zig-pkg", "node_modules"}
CARGO_DIRS = {"src", "tests", "benches", "examples"}

IMPORT, PUB_TYPE, PRIV_TYPE, PUB_FN, SEP, PRIV_FN, TEST_SEP, TEST = range(8)
RANK_NAME = ["import", "pub type", "private type", "pub fn", "private separator", "private fn",
             "tests separator", "test"]

RS_PUB_NAME = re.compile(r"^\s*pub(?:\([^)]*\))?\s+(?:unsafe\s+|async\s+|const\s+(?=fn))*"
                         r"(?:fn|struct|enum|trait|type|const|static|union)\s+(\w+)")
ZIG_PUB_NAME = re.compile(r"^\s*pub\s+(?:inline\s+|export\s+|extern\s+)*(?:fn|const|var)\s+(@?\w+)")
ZIG_PRIV_NAME = re.compile(r"^(?:inline\s+|export\s+)*(?:fn|const|var)\s+(\w+)")
RS_PRIV_NAME = re.compile(r"^(?:const\s+|async\s+|unsafe\s+)*(?:fn|struct|enum|union|trait|type|const|static)\s+(\w+)")


def classify_zig(line):
    if line.startswith("test ") or line.startswith("test{"):
        return TEST
    if re.match(r"^(pub\s+)?(const|var)\s+\w+(\s*:[^=]+)?\s*=\s*@import\(", line):
        return IMPORT
    if re.match(r"^const\s+\w+\s*=\s*[A-Za-z_]\w*(\.\w+)+;\s*$", line):  # alias: `const Allocator = std.mem.Allocator;`
        return IMPORT
    if re.match(r"^pub\s+(inline\s+|export\s+)*fn\b", line):
        return PUB_FN
    if re.match(r"^(inline\s+|export\s+)*fn\b", line):
        return PRIV_FN
    if line.startswith("pub "):
        return PUB_TYPE
    if re.match(r"^(const|var|threadlocal)\s", line):
        return PRIV_TYPE
    if re.match(r"^@?\w+\s*:", line):  # file-as-struct field
        return PUB_TYPE
    return None


def zig_items(lines):
    in_tests = False
    for n, line in enumerate(lines, 1):
        if SEPARATOR.match(line):
            yield n, SEP
        elif TEST_SEPARATOR.match(line):
            in_tests = True
            yield n, TEST_SEP
        elif line and not line[0].isspace() and not line.startswith("//") and line[0] != "}":
            rank = classify_zig(line)
            if rank is not None:
                yield n, TEST if in_tests else rank


def rs_block_end(lines, start):
    """Index of the line closing the column-0 block opened at `start`."""
    for i in range(start, len(lines)):
        if lines[i].startswith("}"):
            return i
        if i == start and lines[i].rstrip().endswith(";"):
            return i
    return len(lines) - 1


def rs_items(lines):
    i = 0
    pending_test = False
    in_tests = False
    while i < len(lines):
        line = lines[i]
        n = i + 1
        if SEPARATOR.match(line):
            yield n, SEP
        elif TEST_SEPARATOR.match(line):
            in_tests = True
            yield n, TEST_SEP
        elif line.startswith("#[cfg(test)]"):
            pending_test = True
        elif not line or line[0].isspace() or line.startswith("//") or line.startswith("#") or line[0] == "}":
            pass
        else:
            rank = None
            if pending_test or in_tests:
                rank = TEST
            elif re.match(r"^(pub(\([^)]*\))?\s+)?(use|extern\s+crate)\b", line) or re.match(r"^(pub(\([^)]*\))?\s+)?mod\s+\w+\s*;", line):
                rank = IMPORT
            elif re.match(r"^impl\b", line) or re.match(r"^unsafe\s+impl\b", line):
                end = rs_block_end(lines, i)
                body = lines[i:end + 1]
                is_trait = re.match(r"^(unsafe\s+)?impl\b[^{]*\bfor\b", line) is not None
                has_pub = any(re.match(r"^\s+pub(\([^)]*\))?\s", b) for b in body)
                rank = PUB_FN if (is_trait or has_pub) else PRIV_FN
                yield n, rank
                i = end + 1
                pending_test = False
                continue
            elif re.match(r"^pub(\([^)]*\))?\s+(const\s+|async\s+|unsafe\s+|extern\s+\S+\s+)*fn\b", line):
                rank = PUB_FN
            elif re.match(r"^(const\s+|async\s+|unsafe\s+|extern\s+\S+\s+)*fn\b", line):
                rank = PRIV_FN
            elif line.startswith("pub"):
                rank = PUB_TYPE
            elif re.match(r"^(struct|enum|union|trait|type|const|static|macro_rules!)", line):
                rank = PRIV_TYPE
            if rank is not None:
                yield n, rank
            pending_test = False
            end = rs_block_end(lines, i) if line.rstrip().endswith("{") else i
            i = end + 1
            continue
        i += 1


def check_file(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    lines = text.split("\n")
    zig = path.endswith(".zig")
    suite = "tests" in os.path.normpath(path).split(os.sep)[:-1]  # all test code: no tests split
    out = []

    first = next((k for k, l in enumerate(lines) if l.strip()), None)
    if first is None:
        return out
    if not lines[first].startswith("//!"):
        out.append((first + 1, "header", "file must open with a `//!` header (in -> out, cites, Contents)"))
    header = []
    for l in lines[first:]:
        if l.startswith("//!"):
            header.append(l)
        elif l.startswith("#!") or not l.strip():
            continue
        else:
            break
    header_text = "\n".join(header)

    items = list((zig_items if zig else rs_items)(lines))
    test_line = next((n for n, r in items if r in (TEST_SEP, TEST)), len(lines) + 1)
    first_test = next((n for n, r in items if r == TEST), None)
    if not suite and first_test is not None and not any(r == TEST_SEP for n, r in items if n < first_test):
        out.append((first_test, "tests", "test without `// ---- tests ----` above it"))

    pub_name = ZIG_PUB_NAME if zig else RS_PUB_NAME
    for n, l in enumerate(lines[:test_line - 1], 1):
        m = pub_name.match(l)
        if m and not re.search(r"\b" + re.escape(m.group(1).lstrip("@")) + r"\b", header_text):
            out.append((n, "contents", f"`{m.group(1)}` is pub but missing from the header's Contents"))

    highest = -1
    seen_sep = False
    for n, rank in items:
        if rank == SEP:
            seen_sep = True
        if rank == PRIV_FN and not seen_sep:
            out.append((n, "separator", "private fn above `// ---- private ----`"))
            seen_sep = True  # report once
        if rank < highest and not (rank == SEP and highest == SEP):
            out.append((n, "order", f"{RANK_NAME[rank]} after {RANK_NAME[highest]}"))
        highest = max(highest, rank)

    code_lines = lines[:test_line - 1]
    test_text = "\n".join(lines[test_line - 1:])
    priv_name = ZIG_PRIV_NAME if zig else RS_PRIV_NAME
    for n, l in enumerate(code_lines, 1):
        m = priv_name.match(l)
        if suite or not m or (zig and classify_zig(l) == IMPORT):
            continue
        word = re.compile(r"\b" + m.group(1) + r"\b")
        used = any(word.search(c) for k, c in enumerate(code_lines, 1)
                   if k != n and not c.lstrip().startswith("//"))
        if not used and word.search(test_text):
            out.append((n, "test-only", f"`{m.group(1)}` is used only by tests: move it below `// ---- tests ----`"))

    code = sum(1 for l in code_lines if l.strip() and not l.lstrip().startswith("//"))
    if code > MAX_CODE_LINES:
        out.append((1, "size", f"{code} code lines before tests (max {MAX_CODE_LINES}): split along its transforms"))
    return out


def check_folders(root):
    out = []
    for d, dirs, files in os.walk(root):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS and not x.startswith(".")]
        src = [f for f in files if f.endswith((".zig", ".rs"))]
        if dirs or len(files) != 1 or not src or os.path.abspath(d) == os.path.abspath(root):
            continue
        parent = os.path.dirname(d)
        if os.path.basename(d) in CARGO_DIRS and os.path.exists(os.path.join(parent, "Cargo.toml")):
            continue
        if src[0] == "mod.rs" and "tests" in os.path.relpath(d, root).split(os.sep):
            continue  # tests/common/mod.rs: keeps Cargo from building the helpers as a test crate
        out.append((os.path.join(d, src[0]), 1, "folder", f"`{d}` holds one file: flatten it"))
    return out


def check_prefixes(root):
    """`item_x.zig` beside `item.zig` or `item/`: the flat form of a file only `item` uses."""
    out = []
    for d, dirs, files in os.walk(root):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS and not x.startswith(".")]
        stems = {os.path.splitext(f)[0] for f in files if f.endswith((".zig", ".rs"))} | set(dirs)
        for f in sorted(files):
            stem, ext = os.path.splitext(f)
            if ext not in (".zig", ".rs"):
                continue
            for k in range(1, len(stem)):
                if stem[k] == "_" and stem[:k] in stems:
                    item = stem[:k]
                    out.append((os.path.join(d, f), 1, "prefix",
                                f"`{f}` sits beside `{item}`: if only `{item}` uses it, nest it as `{item}/{stem[k + 1:]}{ext}`"))
                    break
    return out


def run(paths):
    found = []
    for p in paths:
        if os.path.isfile(p):
            found += [(p, n, r, m) for n, r, m in check_file(p)]
            continue
        found += check_folders(p) + check_prefixes(p)
        for d, dirs, files in os.walk(p):
            dirs[:] = [x for x in dirs if x not in SKIP_DIRS and not x.startswith(".")]
            for f in sorted(files):
                if f.endswith((".zig", ".rs")):
                    fp = os.path.join(d, f)
                    found += [(fp, n, r, m) for n, r, m in check_file(fp)]
    for fp, n, r, m in sorted(found):
        print(f"{fp}:{n}: {r}: {m}")
    return 1 if found else 0


def self_test():
    good_zig = """//! Demo: bytes -> count.
//! Contents: `pub const Count`, `pub fn count(src: []const u8) Count`
const std = @import("std");

pub const Count = struct { n: u32 };

const Scratch = struct { i: u32 };

pub fn count(src: []const u8) Count {
    return .{ .n = helper(src) };
}

// ---- private ----

fn helper(src: []const u8) u32 {
    return @intCast(src.len);
}

// ---- tests ----

test "count" {
    try expectCount("ab", 2);
}

fn expectCount(src: []const u8, n: u32) !void {
    try std.testing.expectEqual(n, count(src).n);
}
"""
    bad_zig = """const std = @import("std");
//! late header
fn helper() void {}
pub fn count() void {}
"""
    good_rs = """//! Demo: bytes -> count.
//! Contents: `pub struct Count`, `pub fn count(src: &[u8]) -> Count`, `Count::get`

use std::fmt;

pub struct Count(u32);

pub fn count(src: &[u8]) -> Count {
    Count(helper(src))
}

impl Count {
    pub fn get(&self) -> u32 {
        self.0
    }
}

impl fmt::Display for Count {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

// ---- private ----

fn helper(src: &[u8]) -> u32 {
    src.len() as u32
}

impl Count {
    fn bump(&mut self) {
        self.0 += 1;
    }
}

// ---- tests ----

#[cfg(test)]
mod tests {
    #[test]
    fn t() {}
}
"""
    bad_rs = """//! Contents: `pub fn count`
pub fn count() {}
pub struct Hidden;
fn helper() {}
"""
    bad_tests_zig = """//! Demo.
const std = @import("std");

// ---- private ----

fn fixture() u32 {
    return 1;
}

test "t" {
    try std.testing.expectEqual(1, fixture());
}
"""
    with tempfile.TemporaryDirectory() as t:
        def write(rel, body):
            p = os.path.join(t, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w") as f:
                f.write(body)
            return p

        assert check_file(write("good.zig", good_zig)) == [], check_file(os.path.join(t, "good.zig"))
        assert check_file(write("good.rs", good_rs)) == [], check_file(os.path.join(t, "good.rs"))
        bad = {r for _, r, _ in check_file(write("bad.zig", bad_zig))}
        assert bad == {"header", "contents", "separator", "order"}, bad
        bad = {r for _, r, _ in check_file(write("bad.rs", bad_rs))}
        assert bad == {"contents", "order", "separator"}, bad
        bad = {r for _, r, _ in check_file(write("bad_tests.zig", bad_tests_zig))}
        assert bad == {"tests", "test-only"}, bad
        assert check_file(write("tests/suite.zig", bad_tests_zig)) == []
        big = "//! Big.\n" + "".join(f"pub const c{i} = {i};\n" for i in range(MAX_CODE_LINES + 1))
        assert "size" in {r for _, r, _ in check_file(write("big.zig", big))}

        write("tree/lone/only.zig", good_zig)
        write("tree/pair/a.zig", good_zig)
        write("tree/pair/b.zig", good_zig)
        write("tree/crate/Cargo.toml", "")
        write("tree/crate/src/lib.rs", good_rs)
        write("tree/crate/tests/common/mod.rs", good_rs)
        write("tree/crate/tests/a.rs", good_rs)
        flagged = [m for _, _, _, m in check_folders(os.path.join(t, "tree"))]
        assert len(flagged) == 1 and "lone" in flagged[0], flagged

        write("flat/item.zig", good_zig)
        write("flat/item_bounds.zig", good_zig)
        write("flat/itemize.zig", good_zig)
        write("flat/other_x.zig", good_zig)
        flagged = [p for p, _, _, _ in check_prefixes(os.path.join(t, "flat"))]
        assert flagged == [os.path.join(t, "flat", "item_bounds.zig")], flagged
    print("check_style: self-test passed")
    return 0


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        sys.exit(self_test())
    if len(sys.argv) < 2:
        print(__doc__.strip().splitlines()[-1])
        sys.exit(2)
    sys.exit(run(sys.argv[1:]))
