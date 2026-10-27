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
