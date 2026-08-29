## What it does

`minimal-code` is the discipline of making the smallest change that actually works. Before architecture design, its **existence test** decides whether a structural change earns its place. Before implementation, its **ladder** checks whether the code can be skipped, reused, delegated to the standard library or platform, or reduced to one line before anything larger is written.

The skill pairs those two filters with a short **never-cut list**: validation at trust boundaries, error handling that prevents data loss, security, accessibility, and verification. Minimality shortens the solution, never the reading and never the checking.

## When to reach for it

Type `/minimal-code`, or the [agent](https://www.aihero.dev/ai-coding-dictionary/agent) reaches for it automatically when a task fits.

Reach for it at either of these decision points:

| Decision | What `minimal-code` supplies |
|---|---|
| Should this architecture change exist? | The existence test, before interface design begins |
| How little code should implement an agreed change? | The ladder and the never-cut list |

For the *shape* of a module, including its interface, seam, and depth, use [codebase-design](https://aihero.dev/skills-codebase-design). For a concrete behaviour built test-first, one slice at a time, use [tdd](https://aihero.dev/skills-tdd). For a finished diff reviewed against standards and spec, use [code-review](https://aihero.dev/skills-code-review).

## The existence test

Architecture work starts by asking whether the change earns design effort. The existence test requires current friction or a named upcoming change, then takes the earliest structural move that resolves it: leave the code alone, remove or collapse a shallow module, reuse or deepen an existing module, or introduce a new module. At whichever move holds, a polymorphic seam still needs two real adapters.

A candidate records its evidence and what becomes smaller or disappears. If none passes, "no actionable deepening opportunities" is the result. [Improve-codebase-architecture](https://aihero.dev/skills-improve-codebase-architecture) uses this test before it puts a candidate in its report.

## The ladder

Once a change is justified, the ladder is an ordered list of places code can come from, cheapest first.

| Rung | The question | If it holds |
|---|---|---|
| 1 | Does this need to exist at all? | Skip it, and say so in one line |
| 2 | Already in this codebase? | Reuse the helper that lives here |
| 3 | Standard library does it? | Use it |
| 4 | Native platform feature covers it? | Use it |
| 5 | Installed dependency solves it? | Use it; a few lines beat a new dependency |
| 6 | One line? | Write the one line |
| 7 | None of the above | Write the minimum that works |

Ask for a date picker and rung 4 answers with `<input type="date">`: no library, no wrapper component, no timezone discussion.

The ladder runs *after* the problem is understood, not instead of it. The agent reads the code the change touches and traces the real flow first, then climbs. A small diff built on skimming is a confident wrong fix, not a minimal one.

## The `debt:` marker

Sometimes the minimal version cuts a real corner with a known ceiling: a global lock, an O(n²) scan, a naive heuristic. The skill marks each one with a `debt:` comment naming the ceiling and the trigger that would justify upgrading:

`# debt: global lock, per-account locks if throughput matters`

The marker keeps a deliberate deferral findable with a single grep, so "later" cannot quietly become "never".

## Common questions

**How is the existence test different from [codebase-design](https://aihero.dev/skills-codebase-design)?**

The existence test decides whether architecture work deserves to happen and selects the smallest structural move. `codebase-design` takes a change that passed and shapes its module, interface, and seam. One filters the work; the other designs it.

**Doesn't this conflict with [tdd](https://aihero.dev/skills-tdd)?**

They own different halves of the loop. `tdd` owns *when* code gets written: the red test comes first, one slice at a time. `minimal-code` owns *how much* code and where it comes from: reuse, then stdlib, then native, then one line. The skill is explicit that the ladder shortens the implementation, never the verification: the red test still comes first and agreed seams still get their tests.

**How is this different from [code-review](https://aihero.dev/skills-code-review) catching over-engineering?**

Timing. `code-review` works on a finished diff, where its Standards baseline flags speculative generality and other smells. `minimal-code` is the same instinct moved to write time, before the lines exist. Not writing the abstraction is cheaper than reviewing it and deleting it.

## It's working if

- Architecture reports can return no actionable candidates instead of filling space with unsupported refactors.
- Every architecture candidate names current evidence and what becomes smaller or disappears.
- Diffs get smaller without getting thinner on validation, error handling, or tests.
- New dependencies stop appearing for things the standard library, the platform, or an installed package already do.
- The agent names what it skipped and when to add it ("skipped X, add when Y") instead of building it speculatively.
- Bug fixes land once, in the shared function every caller routes through, rather than as a patch in the one caller a report named.
- Shortcuts ship with a `debt:` comment naming the ceiling and the upgrade trigger.

## Where it fits

`minimal-code` is a **reach-for-it-anytime standalone** and part of the vocabulary layer underneath the engineering skills. [Improve-codebase-architecture](https://aihero.dev/skills-improve-codebase-architecture) consults its existence test before reporting candidates, [codebase-design](https://aihero.dev/skills-codebase-design) shapes candidates that pass, and [tdd](https://aihero.dev/skills-tdd) consults the ladder during each green-phase implementation. When you're unsure which skill or flow fits, [ask-matt](https://aihero.dev/skills-ask-matt) routes you.
