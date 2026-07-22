---
name: codex-delegate
description: Session-level awareness of Codex as an implementation backend. Claude does all the thinking — reads code, traces flows, plans the approach, resolves all ambiguity — then writes a closed-ended Codex prompt and delegates execution. Codex is great at implementation but bad at thinking; Claude is the opposite. Use when the task is closed-ended implementation work — feature implementation, mechanical refactors, applying a known fix across files, writing code to a decided spec. Do not use for open-ended exploration, architecture decisions, or tasks requiring judgment mid-implementation.
---

# Codex Delegate

You have access to Codex (GPT-5.6) as an implementation backend via the `codex:codex-rescue` subagent. Codex is fast and good at one thing: writing code to a precise, closed-ended spec. It does not think. It does not make judgment calls. It does not explore. It implements.

You are the thinker. Codex is the typist.

## The Loop

1. **You think.** Read the code. Trace the flow end-to-end. Understand the problem fully. Identify every file, function, and edge case the change touches.
2. **You decide.** Pick the approach. Resolve all ambiguity. Make every judgment call. Choose names, types, signatures, error handling strategy — everything.
3. **You write the prompt.** Produce a closed-ended Codex prompt with zero room for interpretation. Exact files, exact functions, exact behavior.
4. **Codex executes.** Dispatch via `codex:codex-rescue` subagent with `--write`.
5. **You review.** Read what Codex changed. Verify it matches your plan. Fix or re-delegate if it doesn't.

## When to Delegate

Delegate when ALL of these are true:

- **Closed-ended** — you can fully specify what "done" looks like before Codex starts
- **Substantial** — more than ~30 lines or spans multiple files (small changes: just do them)
- **Decided** — no judgment calls remain; every design question is answered
- **Mechanical** — implement spec X, apply pattern Y across files Z, write function to signature

Do NOT delegate:

- Exploratory work, architecture, design choices
- Tasks where you'd say "figure out the best way to..."
- Anything requiring mid-implementation judgment (API design, naming decisions, tradeoffs)
- Small changes — round-trip overhead costs more than just doing it

## Writing the Prompt

Codex needs a prompt that is a **complete implementation spec**. No ambiguity. No "think about". No open questions. Every decision already made.

### Structure

```xml
<task>
[Exact task. Name every file path, function, type. Describe the precise change.]
</task>

<files_to_change>
[Every file path and what changes in each one]
</files_to_change>

<done_state>
[What does "done" look like — test passes, behavior changes, output matches X]
</done_state>

<completeness_contract>
Resolve the task fully before stopping.
Do not stop after partial implementation.
</completeness_contract>

<action_safety>
Keep changes tightly scoped to the stated task.
No unrelated refactors, renames, or cleanup.
</action_safety>

<verification_loop>
Before finalizing, verify the implementation against the task requirements and the done state.
</verification_loop>
```

### The Prompt Must

- **Name every file** — `src/auth/middleware.rs:42-58`, not "the auth module"
- **Specify signatures** — `fn validate_token(token: &str) -> Result<Claims, AuthError>`, not "add a validation function"
- **List edge cases** — if you thought about them, they go in the prompt. Codex won't think of them itself
- **Include or describe the test** — Codex should know what passing looks like
- **Have zero open questions** — if a design choice is unresolved, YOU resolve it first

### BAD vs GOOD

BAD: "Refactor the database layer to be more efficient"

GOOD: "In `src/db/queries.rs`, replace the N+1 query in `fetch_users_with_posts()` (line 84-102) with a single JOIN query. The function signature stays `pub fn fetch_users_with_posts(pool: &PgPool) -> Result<Vec<UserWithPosts>>`. The SQL: `SELECT u.*, p.id as post_id, p.title FROM users u LEFT JOIN posts p ON u.id = p.user_id ORDER BY u.id`. Group results by user in Rust using `itertools::group_by`, not SQL GROUP BY."

BAD: "Add error handling to the API"

GOOD: "In `src/api/handlers.rs`, change the return type of `create_item()` (line 45) and `delete_item()` (line 78) from `Json<T>` to the existing `ApiResult<T>` from `src/api/types.rs:12`. Map `DbError::NotFound` to status 404, `DbError::Conflict` to 409, all other `DbError` variants to 500. The `ApiResult` type already handles serialization."

BAD: "Write tests for the parser"

GOOD: "In `tests/parser_test.rs`, add 4 tests for `parse_config()` from `src/config/parser.rs:23`:
1. `test_valid_toml` — input: `[server]\nport = 8080`, expect: `Config { server: Server { port: 8080 } }`
2. `test_missing_section` — input: `port = 8080` (no `[server]`), expect: `Err(ParseError::MissingSection(\"server\"))`
3. `test_invalid_port_type` — input: `[server]\nport = \"foo\"`, expect: `Err(ParseError::TypeMismatch { .. })`
4. `test_empty_input` — input: `\"\"`, expect: `Err(ParseError::Empty)`"

## Model Selection

GPT-5.6 comes in three tiers — pick the cheapest one that fits:

- **Luna** (`--model gpt-5.6-luna`): Fast, cheap. Use for trivial mechanical changes — rename across files, apply a known pattern everywhere, boilerplate. The default for `spark` requests.
- **Terra** (default, unset): The workhorse. Good for most standard implementation work. Codex picks this when you don't specify.
- **Sol** (`--model gpt-5.6-sol`): Full capability. Use for complex multi-file implementations, tricky edge cases, or when Terra's output isn't cutting it.

Leave `--effort` unset unless the implementation is genuinely complex.

## Dispatching

Invoke via the Agent tool with the `codex:codex-rescue` subagent type:

```
Agent({
  subagent_type: "codex:codex-rescue",
  prompt: "<your closed-ended prompt> --write"
})
```

For large tasks, add `--background` so you're not blocked waiting.

## Reviewing the Result

After Codex returns, you own verification:

1. **Read the changed files** — don't trust the summary, read the actual code
2. **Match against your plan** — does the implementation match what you specified?
3. **Check edge cases** — did Codex handle the ones you listed?
4. **Check scope** — no unrelated changes snuck in?
5. **Fix or re-delegate** — small misses: fix yourself. Large misses: write a tighter prompt and re-delegate

Report to the user: what was done, what you verified, and any concerns.

## What This Is NOT

- Not a replacement for thinking. You do MORE thinking, not less — the prompt quality depends on it.
- Not for exploration. If you don't know the answer yet, don't delegate the question.
- Not for small tasks. If it's under 30 lines, the overhead of writing a good prompt exceeds doing it.
- Not for vague requests. "Make it better" cannot become a Codex prompt. Sharpen it yourself or ask the user.
