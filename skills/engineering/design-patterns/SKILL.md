---
name: design-patterns
description: GoF design pattern recognition and application. Use when refactoring class hierarchies, decoupling modules, reviewing code for structural smells, or when user mentions pattern names (Factory, Strategy, Observer, Adapter, etc.). NOT for greenfield code — prefer functions and closures first.
---

# Design Patterns (GoF) — Recognition Toolkit

Patterns are vocabulary for recurring structures. Recognize them in existing code; do NOT inject them into new code unprompted. A function that solves the problem beats a pattern that "might help later."

## When to Use

- User explicitly asks for a pattern by name
- Refactoring existing code that has a structural smell (giant switch, deep inheritance, God object)
- Reviewing code and naming what's already there helps communication
- Decoupling two modules that change independently
- **DOD tension**: GoF patterns organize behavior around objects. If the hot path is data-throughput, prefer SoA layouts and free functions over pattern classes. Use patterns at architectural boundaries, not in inner loops.

## Core Decision: Do You Need a Pattern?

Ask in order. Stop at the first YES:

1. **Does a plain function solve it?** Use the function. Most "Strategy" and "Command" needs are just passing a closure.
2. **Does a language feature solve it?** Rust traits, Python protocols, TS unions — these replace Visitor, Abstract Factory, and half of Strategy.
3. **Is the variability axis real TODAY?** If only one variant exists, write the concrete code. Extract the pattern when the second variant arrives.
4. **Only now**: apply the minimal pattern.

## Pattern Quick Reference

| Need | Pattern | Modern equivalent | Use when |
|------|---------|-------------------|----------|
| Swap algorithm at runtime | Strategy | Closure / fn pointer | 2+ algorithms exist TODAY |
| React to state changes | Observer | Event channel / signal | Multiple independent subscribers |
| Undo / queue operations | Command | Closure + stack | Need serialize, queue, or undo |
| Traverse collection | Iterator | Language built-in (`iter()`, `for..of`) | Always use language built-in |
| Object creation varies | Factory Method | Constructor fn / `new_*()` | Creation logic is complex or conditional |
| Complex object assembly | Builder | Builder (keep it) | 4+ optional params, validation on build |
| Wrap incompatible interface | Adapter | Newtype / wrapper struct | Integrating third-party code you can't change |
| Add behavior without subclass | Decorator | Middleware / wrapper fn | Cross-cutting concerns (logging, auth, retry) |
| Simplify complex subsystem | Facade | Module public API | Hiding internal complexity from callers |
| Control access | Proxy | Smart pointer / guard | Lazy init, access control, remote call |
| Tree structures | Composite | Enum with recursive variant | UI trees, ASTs, file systems |
| Decouple abstraction from impl | Bridge | Trait + impl split | Abstraction AND implementation vary independently |
| Finite state transitions | State | Enum + match | States are well-defined, transitions are complex |
| Algorithm skeleton with hooks | Template Method | Trait with default methods | Shared skeleton, varying steps |
| **AVOID** | Singleton | Module-level state / DI | Almost never — use DI or module scope |
| **AVOID** | Visitor | Enum + match (sum types) | Only if you can't add variants to the enum |
| **CAUTION** | Abstract Factory | Feature flags / config | Only if families of objects vary together |

## Anti-Patterns

### BAD: Strategy pattern where a closure suffices

```python
# BAD — ceremony for nothing
class SortStrategy(ABC):
    @abstractmethod
    def sort(self, data: list) -> list: ...

class QuickSort(SortStrategy):
    def sort(self, data: list) -> list:
        return sorted(data)  # lol

class Sorter:
    def __init__(self, strategy: SortStrategy):
        self.strategy = strategy

    def do_sort(self, data):
        return self.strategy.sort(data)

# GOOD — it's a function
def process(data: list, sort_fn=sorted):
    return sort_fn(data)
```

### BAD: Singleton masking global state

```rust
// BAD — hidden global, untestable
static CONFIG: Lazy<Config> = Lazy::new(|| load_config());

fn do_work() {
    let timeout = CONFIG.timeout; // invisible dependency
}

// GOOD — pass it
fn do_work(config: &Config) {
    let timeout = config.timeout;
}
```

### BAD: Visitor when you have sum types

```rust
// BAD — Visitor in a language with enums
trait Visitor { fn visit_add(&mut self, a: &Expr, b: &Expr); fn visit_lit(&mut self, v: i64); }
trait Visitable { fn accept(&self, v: &mut dyn Visitor); }

// GOOD — just match
enum Expr { Add(Box<Expr>, Box<Expr>), Lit(i64) }

fn eval(expr: &Expr) -> i64 {
    match expr {
        Expr::Lit(v) => *v,
        Expr::Add(a, b) => eval(a) + eval(b),
    }
}
```

### BAD: Premature Factory

```typescript
// BAD — one product, factory adds nothing
interface Logger { log(msg: string): void }
class ConsoleLogger implements Logger { log(msg: string) { console.log(msg) } }
class LoggerFactory { create(): Logger { return new ConsoleLogger() } }

// GOOD — just use the thing
const log = (msg: string) => console.log(msg)
// Extract factory when you actually need FileLogger AND ConsoleLogger
```

## Workflows

### Refactoring toward a pattern

1. Identify the **concrete smell**: duplicated switch/match, shotgun surgery, deep inheritance
2. Name the pattern that fits (use quick reference above)
3. Check: does a function/closure/enum solve it without the pattern? If yes, stop
4. Apply the **minimum** version — one interface, one or two implementations
5. Do NOT add "room for growth" — YAGNI

### Reviewing code that uses patterns

1. Name the pattern being used
2. Count implementations/variants — if only one, flag as premature abstraction
3. Check if a simpler construct (closure, enum, module) would work
4. If pattern is justified, verify it's the right one (e.g., not Strategy when State is meant)

## DOD Tension Notes

- **Composite/Visitor/Iterator** on object trees: fine for low-frequency operations (UI layout, config parsing). For hot-path tree walks, flatten to arrays and index.
- **Observer** with many subscribers: event channels are allocation-heavy. For perf-critical paths, poll or batch instead of push.
- **Decorator chains**: each layer is a vtable indirection. In hot loops, inline the behavior or use compile-time composition (generics/templates).
- Patterns organize **behavior around types**. DOD organizes **data for the access pattern**. Use patterns at module boundaries; use DOD inside modules where throughput matters.
