---
name: engineering-at-scale
description: Scale-aware software engineering heuristics from Google's practices. Use when designing APIs, writing tests, reviewing code, managing dependencies, planning deprecations, or making architecture decisions where codebase size and team count affect the right answer. Triggers: test strategy, code review, dependency management, API design, deprecation, large-scale refactoring, CI policy.
---

# Engineering at Scale

## When to Use
- Designing or reviewing APIs that other teams/modules will consume
- Choosing test strategy (size, scope, what to test)
- Writing or reviewing tests — especially deciding DRY vs clarity
- Managing dependencies or debating version pinning
- Planning deprecation of any public interface
- Evaluating whether an abstraction is worth it at current scale
- Setting up CI/CD policy or pre-commit checks
- Any architecture decision where "how many people/lines/years" changes the answer

## Core Principles

### 1. Software Engineering = Programming x Time
Code that runs once can be hacky. Code maintained for years must handle API churn, dependency rot, team turnover. Before writing, ask: "Will this be maintained for >1 year by people who didn't write it?" If yes, optimize for readability and changeability over cleverness.

### 2. Hyrum's Law — Every Observable Behavior Becomes a Contract
Any behavior users can observe, they WILL depend on. Do not expose implementation details through public APIs. Hide what you can; document what you expose. If you return a sorted list as an implementation detail, someone will depend on that ordering.

**Action:** Make observable behavior minimal and intentional. Use opaque types, encapsulation, `#[non_exhaustive]` (Rust), `__all__` (Python), barrel exports (TS).

### 3. Shift Left — Catch Problems Earlier
Cost to fix a bug multiplies ~10x per stage (code -> review -> test -> staging -> prod). Push validation as early as possible: type system > compile time > lint > unit test > integration test > staging > prod monitoring.

**Action:** Prefer compile-time guarantees. Use newtypes over raw primitives. Add `assert!` / type constraints before writing runtime checks.

### 4. Beyonce Rule — If You Liked It, Put a CI Test on It
No behavior is guaranteed to survive unless CI enforces it. Verbal agreements, documentation, and code comments are not protection.

**Action:** Any behavior you rely on gets an automated test in CI. No exceptions. If it's not tested, it's not promised.

### 5. Trade-offs Over Rules
Every principle here bends. The question is always: what does this cost vs. what does it buy, at THIS scale? A 500-line project doesn't need the same rigor as a 5M-line monorepo.

## Testing Strategy

### Test Sizes (enforcement boundaries, not suggestions)
| Size | Network | Disk | Duration | When to use |
|------|---------|------|----------|-------------|
| **Small** | No | No | < 1s | Pure logic, transforms, data structures |
| **Medium** | Localhost only | Yes | < 30s | DB interactions, multi-process |
| **Large** | Yes | Yes | < 5min | End-to-end, external services |

**Action:** Default to small tests. Reach for medium/large only when small cannot cover the behavior. A test suite that's 80% small runs fast enough to shift left.

### DAMP > DRY in Tests
Tests are documentation. Extracting shared helpers into test utilities harms readability. Each test should read top-to-bottom without jumping to helper files.

**DOD tension:** Data-oriented design favors tables of test inputs over repeated setup. This is fine — table-driven tests ARE DAMP because each row is self-contained. The anti-pattern is shared mutable fixtures, not shared data.

## Code Review Checklist
1. **Correctness** — Does it do what the description says?
2. **Readability** — Can someone unfamiliar understand it in one pass?
3. **Consistency** — Does it match existing patterns in THIS codebase?
4. **Tests** — Does it test the new behavior? (Beyonce Rule)
5. **API surface** — Does it expose more than necessary? (Hyrum's Law)
6. **Deprecation** — If replacing old behavior, is the old path marked for removal?

## Deprecation as First-Class Work
Every public API, feature flag, or migration path needs a planned removal date. Code without a removal plan is code that lives forever.

**Action:** When adding a public API or feature flag, add a comment with the deprecation condition:
```
// DEPRECATE_WHEN: all callers migrated to v2 endpoint (tracking: JIRA-1234)
```

## Anti-Patterns

### Hyrum's Law Violation
```python
# BAD: leaks implementation detail (sorted order) through public API
def get_users() -> list[User]:
    return sorted(self._users, key=lambda u: u.name)  # caller depends on sort

# GOOD: return frozenset — no ordering contract
def get_users() -> frozenset[User]:
    return frozenset(self._users)
# If caller needs order, they sort. Contract is explicit.
```

### Test Over-Extraction (DRY addiction)
```typescript
// BAD: test reads like a treasure hunt
it("rejects expired token", () => {
  const user = createDefaultUser();        // what's in here?
  const token = createExpiredToken(user);   // what expiry? what claims?
  expect(validate(token)).toBe(false);
});

// GOOD: DAMP — all context inline
it("rejects expired token", () => {
  const user = { id: "u1", role: "reader" };
  const token = sign(user, { expiresIn: "-1h" });
  expect(validate(token)).toBe(false);
});
```

### Missing Deprecation Plan
```rust
// BAD: new API added, old one left to rot
pub fn process_v2(input: &Input) -> Result<Output> { /* ... */ }
pub fn process(input: &Input) -> Result<Output> { /* old, no indication it's dead */ }

// GOOD: old API marked with deprecation intent
#[deprecated(since = "0.4.0", note = "use process_v2; remove after Q3 2025 migration")]
pub fn process(input: &Input) -> Result<Output> { /* ... */ }
```

### Beyonce Rule Violation
```python
# BAD: "we agreed we'd never change the output format"
def export_report() -> str:
    return f"{date},{total},{count}"  # CSV by convention, no test enforces it

# GOOD: CI test locks the contract
def test_export_report_csv_format():
    result = export_report()
    assert result.count(",") == 2  # three fields, comma-separated
    date_part, total_part, count_part = result.split(",")
    assert date_part  # non-empty date
```

## Scale-Aware Decision Table

| Decision | Small scale (1 team, <50k LOC) | Large scale (many teams, >500k LOC) |
|----------|-------------------------------|--------------------------------------|
| Dependency versions | Pin freely, update manually | One Version Rule — single version per dep, automated updates |
| Code style | Team convention, linter | Automated formatter, enforced in CI, no style comments in review |
| API changes | Change and grep callers | LSC infrastructure — automated codemods with staged rollout |
| Test strategy | Medium tests fine as default | Small tests mandatory default, medium/large budgeted |
| Deprecation | Delete when ready | Formal deprecation process with migration tooling |
| Abstraction layers | YAGNI — skip until needed | Abstraction at module boundaries to enable independent team velocity |

**DOD tension:** At large scale, Google adds abstraction layers for team independence. DOD says flatten and co-locate data. Resolution: abstract at TEAM boundaries (API contracts), flatten WITHIN team-owned modules. The abstraction serves organizational scaling, not code elegance.

## Quick Reference
1. Will this code live >1 year? Optimize for readability, not cleverness.
2. Is this behavior observable? It's now a contract. Minimize the surface.
3. Is this tested in CI? If not, it's not guaranteed. Add the test.
4. Am I adding a public API? Write the deprecation plan now.
5. Am I choosing test size? Default small. Justify medium/large.
6. Am I extracting test helpers? Stop. Inline the setup. DAMP > DRY.
7. Am I adding a dependency? Is there exactly one version in the repo?
8. Does the scale of this project change which answer is right? Check the table.
