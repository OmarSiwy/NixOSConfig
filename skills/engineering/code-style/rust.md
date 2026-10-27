# Rust companion

Rust 1.95, edition 2024. The file below compiles with no warnings and its test passes under `rustc --edition 2024 --test`.

## A file that passes

Header, `use`, public types, public functions, then the `impl` blocks holding public methods and trait impls, the private separator, private functions and the private `impl` block, the tests separator, tests last. `classify` and `run_end` are extract rule 2. `expect_tags` is shared by both tests, so it lives inside `mod tests`, which `#[cfg(test)]` drops from every non-test build.

```rust
//! Tokenizer: source bytes → `Tokens` (one tag and one start offset per run).
//! Cites: none (house grammar, docs/grammar.md).
//!
//! Contents:
//! - `pub enum Tag`: the byte class a token's run shares.
//! - `pub struct Tokens`: one tag and one start per token, as two columns.
//! - `Tokens::tags(&self) -> &[Tag]`, `Tokens::starts(&self) -> &[u32]`: the columns.
//! - `pub enum LexError`: why `tokenize` stopped.
//! - `pub fn tokenize(src: &[u8], out: &mut Tokens) -> Result<(), LexError>`: appends a token per run.

use std::fmt;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Tag {
    Ident,
    Number,
    Space,
    Punct,
}

/// One entry per token. Fields are private because `tags` and `starts` always have equal length.
#[derive(Default)]
pub struct Tokens {
    tags: Vec<Tag>,
    starts: Vec<u32>,
}

#[derive(Debug)]
pub enum LexError {
    /// The source is longer than `u32::MAX` bytes; `out` is untouched.
    SourceTooLong,
}

/// Appends one token per run of same-tag bytes.
pub fn tokenize(src: &[u8], out: &mut Tokens) -> Result<(), LexError> {
    let len = u32::try_from(src.len()).map_err(|_| LexError::SourceTooLong)?;
    let mut i = 0;
    while i < len {
        let tag = classify(src[i as usize]);
        let end = run_end(src, i, tag);
        out.tags.push(tag);
        out.starts.push(i);
        i = end;
    }
    debug_assert_eq!(out.tags.len(), out.starts.len());
    Ok(())
}

impl Tokens {
    pub fn tags(&self) -> &[Tag] {
        &self.tags
    }

    pub fn starts(&self) -> &[u32] {
        &self.starts
    }
}

impl fmt::Display for LexError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        f.write_str("source longer than u32::MAX bytes")
    }
}

// ---- private ----

fn classify(c: u8) -> Tag {
    match c {
        b'a'..=b'z' | b'A'..=b'Z' | b'_' => Tag::Ident,
        b'0'..=b'9' => Tag::Number,
        b' ' | b'\t' | b'\n' => Tag::Space,
        _ => Tag::Punct,
    }
}

fn run_end(src: &[u8], start: u32, tag: Tag) -> u32 {
    let mut i = start + 1;
    while (i as usize) < src.len() && classify(src[i as usize]) == tag {
        i += 1;
    }
    i
}

// ---- tests ----

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_runs_by_tag() {
        expect_tags(b"ab 12", &[Tag::Ident, Tag::Space, Tag::Number], &[0, 2, 3]);
    }

    #[test]
    fn keeps_a_punct_run_whole() {
        expect_tags(b"+=x", &[Tag::Punct, Tag::Ident], &[0, 2]);
    }

    /// Tokenizes `src` and checks both columns against the expected rows.
    fn expect_tags(src: &[u8], tags: &[Tag], starts: &[u32]) {
        let mut tokens = Tokens::default();
        tokenize(src, &mut tokens).unwrap();
        assert_eq!(tokens.tags(), tags);
        assert_eq!(tokens.starts(), starts);
    }
}
```

## Methods and `impl` blocks

Rust allows any number of `impl` blocks per type, which is what makes the split work: the public methods go in an `impl` above the separator, and the private ones in a second `impl` of the same type below it. Trait impls (`Display`, `From`, `Iterator`) are public surface and sit above the separator.

Inside an `impl`, the public methods are in call order, constructor (`new`, `with_capacity`) first. A method only tests call goes in an `impl` block inside `mod tests`.

## Scope in Rust

The borrow checker writes the scope rule from SKILL.md into the types:

- An owned field (`Vec<T>`, `Box<T>`) means the struct holds that memory for its whole life. The field is right only when its last read is near the struct's drop.
- A borrowed field (`&'a [T]`) makes the struct a view that cannot leave the block holding the borrow. That is the right shape for a short-lived bundle of a phase's inputs, built in the spine and dropped with it.
- A field that fights the borrow checker is mis-scoped. Pass it as a parameter to the calls that read it; `Rc`, `Arc`, `'static`, or a `.clone()` added to quiet the checker keeps the memory alive past its last read.
- To free a phase's data at the phase's end, let it go out of scope there (a block `{ ... }` around the phase) or call `drop(tokens)` on the line after its last read.

## Nested modules

A file only `item.rs` uses moves to `item/` and drops the prefix: `item_bounds.rs` becomes `item/bounds.rs`, `item.rs` becomes `item/mod.rs`, which declares `mod bounds;` without `pub`, so nothing outside `item` can reach it. Re-export with `pub use bounds::Bounds;` only what another module calls today.

## Crates

A crate is the unit Cargo compiles in parallel today, but a crate per owner multiplies public interfaces. A new crate is justified only by HIERARCHY.md's three reasons (enforce single ownership, gate a heavy dependency, split by platform); everything else is a module file inside an existing crate.
