---
title: Engine, Model-Provider & UI Adapter Contracts
scope: Language-neutral interface contracts extending the Go CLI rewrite to make Ralph engine-, model-, and GUI-agnostic
status: draft
created: 2026-06-13
---

# Engine, Model-Provider & UI Adapter Contracts

## Purpose

This document specifies three language-neutral contracts that make the Ralph
engine **engine-agnostic** (drive Claude Code, Gemini, Codex, OpenCode, …),
**model/provider-agnostic** (route through Anthropic direct, OpenRouter,
Mammouth, …), and **GUI-agnostic** (Vibe Kanban *or another GUI* as an optional,
swappable add-on).

It **extends**, and does not replace, the committed design:

- [`docs/UserStory.md`](../UserStory.md) — Go CLI rewrite, US-1–US-10. These
  contracts are proposed **US-11 / US-12 / US-13**.
- [`docs/research/ralph-cli-rewrite.md`](./ralph-cli-rewrite.md) — language
  evaluation. **Language is decided: Go** (TypeScript was rejected on
  binary-size grounds). Contracts here are language-neutral but realised in Go.
- [`TODO.md`](../../TODO.md) — the "Everything-Agnostic Ecosystem" program.
  Today it covers *target language / toolchain* agnosticism via the `adapter_*`
  hook seam; engine/model/GUI agnosticism is the missing dimension this doc adds.

The language decision is **out of scope** here — see UserStory.md.

## Gap statement

| Requirement | Current design (UserStory.md) | Gap |
|---|---|---|
| Multiple coding engines | `Driver` interface exists; only `claude-code`; TODO Cline/Copilot/Aider | No capability model; gemini/codex/opencode not covered; no per-task engine selection |
| Multiple models/providers | `[models]` maps task→Claude model name | No provider/gateway concept (OpenRouter/Mammouth); no `(engine,model,provider)` binding |
| Optional/other GUI | Vibe REST client (US-7) + future TUI | Vibe hard-wired as *the* GUI; no event contract that arbitrary GUIs consume |

---

## Contract US-11 — Engine driver registry & capability descriptor

Generalise the existing single `Driver` into a **registry** of drivers, each
declaring a **capability descriptor** so the engine can route safely.

**Driver contract** (unchanged shape from UserStory.md `agent.Driver`):

```
Invoke(ctx, InvokeOpts{ prompt, workdir, model, provider, env, timeout }) -> (Result{ exitCode, stdout, committed }, error)
```

The engine never imports engine-specific code; it calls `Driver.Invoke` and
reads the capability descriptor.

**Capability descriptor** (per driver):

| Field | Meaning |
|---|---|
| `headless_flag` | non-interactive invocation (e.g. `claude -p`, `codex exec`) |
| `accepts_model_flag` | can select model per invocation |
| `accepts_base_url` | can target an OpenAI-compatible gateway (gates US-12 provider routing) |
| `auth_env` | env var(s) for credentials (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, …) |
| `auto_commits` | engine commits its own changes vs. worker commits after |
| `skip_permissions_flag` | non-interactive permission bypass, if any |

**Config** (`ralph.toml`), extends US-8 `[agent]`:

```toml
[agent]
default_driver = "claude-code"

[drivers.claude-code]
command = "claude"
flags   = ["-p", "--dangerously-skip-permissions"]
protocol = "anthropic"            # native

[drivers.gemini]                  # capabilities/flags TBD — verify CLI docs
command = "gemini"
[drivers.codex]
command = "codex"
[drivers.opencode]
command = "opencode"
```

**Relates to:** issue #34 (decouple `init.sh` from `claude --print-skills` /
`~/.claude/plugins/cache/` — the only remaining hard Claude coupling at init;
generalise to a driver capability query). Bug **C1/eval-injection** in
[`ralph/TODO.md`](../../ralph/TODO.md): the driver MUST build args as a vector,
never `eval`.

**Edge cases to test:** unknown driver name; driver binary missing; driver
without `accepts_model_flag` while a model is requested; `auto_commits=false`
driver that makes no commit (worker must commit or fail clearly).

---

## Contract US-12 — Model & provider routing

Separate **what model** from **through which gateway**, and let routing pick
`(driver, model, provider)` per task class. This is the OpenRouter / Mammouth
piece, and the generalisation of the current `classify_story`.

**Provider table** (`ralph.toml`):

```toml
[providers.anthropic]
protocol     = "anthropic"
api_key_env  = "ANTHROPIC_API_KEY"

[providers.openrouter]
protocol     = "openai-compatible"
base_url     = "https://openrouter.ai/api/v1"
api_key_env  = "OPENROUTER_API_KEY"

[providers.mammouth]              # VERIFY: confirm a programmatic OpenAI-compatible endpoint exists
protocol     = "openai-compatible"
base_url     = "TBD"
api_key_env  = "MAMMOUTH_API_KEY"
```

**Routing table** — extend US-8 `[models]` from `task -> name` to
`task -> {driver, model, provider}` (string shorthand still resolves to
`default_driver` + native provider for backward compatibility):

```toml
[models]
default = { driver = "claude-code", model = "claude-sonnet-4-6", provider = "anthropic" }
simple  = { driver = "claude-code", model = "claude-haiku-4-5",  provider = "anthropic" }
fix     = "claude-haiku-4-5"      # shorthand -> default_driver + native provider
# Example cross-engine routing through a gateway:
# heavy = { driver = "codex", model = "google/gemini-2.x", provider = "openrouter" }
```

**Routing function** (pure, testable): `route(task_class) -> (driver, model, provider)`.
A `(driver, provider)` pair is **valid only if** the driver's
`accepts_base_url` capability (US-11) permits that provider's protocol.

**Relates to:** issue #35 (Model-Selection ADRs — the *why* behind each route);
issue #29 (token-economics signals could feed routing). Both currently assume
Claude only.

**Edge cases to test:** unknown provider; `api_key_env` unset; provider requires
`base_url` the driver can't accept (capability mismatch → clear error, not
silent fallback); shorthand vs. full-form parsing; routing fallback when a task
class is unmapped.

---

## Contract US-13 — Pluggable UI adapter & event API

Decouple the core from any specific GUI by emitting a **stable event stream**;
GUIs become **consumers**. Vibe Kanban becomes *one* adapter; a second GUI,
a TUI, or headless are equally valid. This formalises the "Streaming progress /
WebSocket for dashboards" item in [`ralph/TODO.md`](../../ralph/TODO.md).

**Event schema:**

```
Event { ts, run_id, worktree, story_id, type, payload }
```

**Event vocabulary** (the US-7 Kanban status table is the story-status subset):

```
run.started · worktree.created · story.selected · tdd.red · tdd.green
validate.started · validate.passed · validate.failed · fix.attempt
story.passed · story.failed · story.aborted · worktree.scored
merge.completed · run.completed
```

**Transports** (an adapter chooses one):

| Transport | Use |
|---|---|
| in-process callback | TUI (Bubbletea) |
| JSONL → stdout/file | headless, logging, CI |
| HTTP push (PUT/POST) | **Vibe Kanban** (current US-7 model) |
| SSE / WebSocket | external dashboards / "another GUI" |

**UI adapter contract:** `consume(Event) -> void`, non-blocking; a failing
adapter logs a warning and never blocks the loop (per US-7). Multiple adapters
run concurrently (fan-out).

**Config:**

```toml
[ui]
adapters = ["vibe"]               # e.g. ["vibe", "tui"]; [] = headless
```

The **Vibe adapter** translates events → the US-7 Kanban REST mapping; it stays
an external process Ralph only talks to over HTTP (unchanged from US-7).
"Another GUI" subscribes to the SSE/WebSocket transport — no core changes.

**Edge cases to test:** no adapters (headless); adapter endpoint unreachable
(warn, continue); one of several adapters fails (others unaffected); event
ordering under parallel worktrees; backpressure on a slow consumer.

---

## Cross-cutting

- **Config precedence** follows US-8: CLI flags > env > `ralph.toml` > defaults.
  All three contracts add only declarative `ralph.toml` tables.
- **Portability rule** (resolves the CC-native vs. engine-agnostic tension in
  issues #53/#55/#56): *the canonical artifact always lives outside `.claude/`;
  any `.claude/` path is a consumer/alias, never the source of truth* — e.g.
  `.git/hooks/pre-push` is canonical, a CC `PreToolUse` hook is optional; a
  per-subtree `AGENTS.md` is canonical, `.claude/rules/` is an enhancement.
  The compound-learning items (#28/#29/#30) that read `~/.claude/**` must move
  behind a driver-neutral capability/telemetry seam under this rule.
- **Testability (US-9):** each contract exposes pure units —
  `route(task_class)`, capability validation, event serialisation, the Vibe
  status mapping — unit-testable without spawning engines. The "edge cases to
  test" lists above are the strict-TDD backlog for these contracts.

## Non-goals

- Reopening the language decision (Go, per UserStory.md). TypeScript already
  rejected on binary size; this doc does not revisit it.
- Implementation (these are contracts; code follows in the Go rewrite).
- Bi-directional Vibe sync (stays Future in UserStory.md).
- The experimental in-session CC dynamic-workflow front-end ([issue #61]) — it is
  an *alternative invocation surface* on Claude only, orthogonal to these
  engine-/GUI-neutral contracts; it stays parked.

## Open questions

1. **Mammouth**: confirm it exposes a programmatic (ideally OpenAI-compatible)
   API + auth. If not, drop it from initial providers; OpenRouter is confirmed.
2. **gemini / codex / opencode**: confirm exact headless flags, model flag,
   `base_url`/OpenAI-compat support, auth env, and auto-commit behaviour to fill
   their capability descriptors.
3. **"openclaude"** (from discussion): clarify — possible alias for OpenCode or
   a Claude-compatible router.
4. Do providers bind per-driver or globally? (Capability descriptor suggests
   per-driver validation.)

## References

- [`docs/UserStory.md`](../UserStory.md) — Go CLI rewrite (US-1–US-10)
- [`docs/research/ralph-cli-rewrite.md`](./ralph-cli-rewrite.md) — language eval
- [`TODO.md`](../../TODO.md) — Everything-Agnostic Ecosystem
- [`ralph/TODO.md`](../../ralph/TODO.md) — rewrite item, streaming progress, bug backlog
- [`docs/audits/quality-audit-2026-03.md`](../audits/quality-audit-2026-03.md) — bug source for the hardening backlog
- Issues: #61 (CC workflow, parked), #34 (init decoupling), #35 (model ADRs), #29 (token economics), #28 (compound learning)
