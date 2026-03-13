# Ralph CLI Rewrite Research

## Executive Summary

Ralph is a ~5,000-line bash + Python autonomous dev loop orchestrator that has
outgrown its shell scripting origins. The codebase has known security bugs
(`eval` injection), cross-platform incompatibilities, and is effectively
untestable. This document evaluates five options for the path forward: bash
hardening, Bun/TypeScript, Go + Cobra/Viper, Deno, and all-Python. **Go is the
recommended rewrite language** based on binary distribution requirements, the
existing UserStory.md architecture work, cross-compilation maturity, and the
subprocess-heavy nature of Ralph's workload. Bash hardening should happen
immediately regardless of rewrite timeline to fix the `eval` injection bugs.

## Current Architecture

### File Inventory

| File | Lines | Role |
|------|------:|------|
| `ralph/scripts/parallel_ralph.sh` | 953 | Parallel orchestrator: N-worktree wave execution |
| `ralph/scripts/generate_prd_json.py` | 795 | PRD.md to prd.json converter (Python) |
| `ralph/scripts/ralph.sh` | 759 | Serial TDD loop orchestrator |
| `ralph/scripts/tests/test_pipeline_e2e.py` | 342 | E2E integration tests (Python) |
| `ralph/scripts/lib/baseline.sh` | 279 | Pre-story state capture for scoped reset |
| `ralph/scripts/init.sh` | 274 | Environment initializer, state file creation |
| `ralph/scripts/lib/teams.sh` | 261 | CC Agent Teams integration |
| `ralph/scripts/tests/test_parallel_ralph.sh` | 233 | Parallel tests (bash) |
| `ralph/scripts/setup_project.sh` | 218 | Project scaffold setup |
| `ralph/scripts/lib/snapshot.sh` | 216 | Codebase map + story context generation |
| `ralph/scripts/lib/vibe.sh` | 181 | Vibe Kanban REST client (curl + jq) |
| `ralph/scripts/vibe.sh` | 151 | Vibe lifecycle: start/stop/status/cleanup |
| `ralph/scripts/lib/judge.sh` | 143 | Per-domain failure tracking, agent heuristic |
| `ralph/scripts/lib/config.sh` | 132 | Central `RALPH_*` env var config with defaults |
| `ralph/scripts/lib/generate_app_docs.sh` | 118 | README.md and example.py auto-generation |
| `ralph/scripts/lib/extract_signatures.py` | 116 | AST-based Python signature extractor |
| `ralph/scripts/archive.sh` | 116 | Tar/archive completed run artifacts |
| `ralph/scripts/watch.sh` | 102 | File watcher, triggers re-runs |
| `ralph/scripts/clean.sh` | 100 | Cleanup: tmp files, logs, worktrees |
| `ralph/scripts/reorganize_prd.sh` | 99 | PRD story reordering / dependency sorting |
| `ralph/scripts/lib/cleanup_worktrees.sh` | 67 | Stale git worktree removal |
| `ralph/scripts/ralph-in-worktree.sh` | 64 | Thin wrapper for worktree context |
| `ralph/scripts/lib/stop_ralph_processes.sh` | 42 | Kill ralph/claude processes by PID |
| `ralph/scripts/lib/validate_json.sh` | 38 | prd.json schema validation via jq |
| `ralph/scripts/stop.sh` | 12 | One-liner calling stop_ralph_processes.sh |

**Totals:** ~4,100 lines bash, ~1,253 lines Python (913 application + 342 test) across 25 files.

### Dependency Graph

```text
ralph.sh (serial loop)
  |-- sources: lib/config.sh, lib/common.sh, lib/baseline.sh,
  |            lib/snapshot.sh, lib/judge.sh, lib/vibe.sh
  |-- calls:   claude -p, make validate, git, jq, timeout
  |-- spawns:  extract_signatures.py (via snapshot.sh)

parallel_ralph.sh (parallel orchestrator)
  |-- sources: lib/config.sh, lib/common.sh, lib/baseline.sh,
  |            lib/snapshot.sh, lib/judge.sh, lib/vibe.sh,
  |            lib/teams.sh, lib/cleanup_worktrees.sh
  |-- calls:   ralph.sh (per-worktree), ralph-in-worktree.sh
  |-- process: disown + PID polling for background workers

vibe.sh (lifecycle)
  |-- calls: npx vibe-kanban, pkill, curl, lsof

init.sh
  |-- sources: lib/config.sh, lib/common.sh, lib/validate_json.sh
  |-- calls:   generate_prd_json.py (optional)
```

### External Binary Dependencies

`bash` (4.0+), `jq`, `git`, `claude` (Claude Code CLI), `make`, `timeout`
(coreutils), `curl`, `npx` (for Vibe Kanban), `flock` (Linux only),
`md5sum`/`sha256sum` (Linux; macOS uses `md5`/`shasum`), `grep` (with `-oP`
for PCRE on Linux), `sed`, `tee`, `mktemp`, `wc`, `pkill`, `lsof`

## Known Issues Driving the Rewrite

### Security Bugs

| Severity | Location | Description |
|----------|----------|-------------|
| **Critical** | `ralph.sh:328,441` | `eval` used to expand `$extra_flags` in `claude -p` invocations. If `RALPH_*` env vars contain shell metacharacters, arbitrary command execution is possible. |
| Medium | `lib/vibe.sh` | String-concatenated JSON payloads for curl POST/PUT. `sed`-based escaping misses backslashes and newlines, enabling JSON injection. |

### Correctness Bugs

| Severity | Location | Description |
|----------|----------|-------------|
| **High** | `parallel_ralph.sh:242,263` | Hardcoded `exit 0` masks worker failures. Parallel runs always report success. |
| High | `lib/teams.sh` | Wrong argument order in function calls (discovered in codebase exploration). |
| Medium | Multiple files | `grep -oP` (PCRE) not available on macOS default grep. Breaks `vibe.sh` and status reporting. |
| Medium | Multiple files | `md5sum`/`sha256sum` not available on macOS. Uses `md5`/`shasum -a 256` instead. |

### Brittleness Patterns

| Pattern | Impact | Files |
|---------|--------|-------|
| `disown` + PID polling | Zombie processes, race conditions on fast exit | `parallel_ralph.sh` |
| Pipe-into-while subshells | Variable assignments lost (SC2031) | `lib/snapshot.sh`, others |
| String-concatenated JSON | No escaping for special chars, injection risk | `lib/vibe.sh` |
| Temp file management | Leaked `/tmp` files on abnormal exit | `ralph.sh`, `parallel_ralph.sh` |
| Shared `KANBAN_MAP` flat file | TOCTOU race when multiple worktrees write concurrently | `lib/vibe.sh` |
| `flock` for file locking | Linux-only, no macOS equivalent | `parallel_ralph.sh` |
| ERR trap inheritance | `-eEuo pipefail` interacts poorly with subshells, masking real errors | All scripts |

### Testability Gap

1 stale bash test file (`test_parallel_ralph.sh`, 233 lines) and 1 Python E2E
test file (`test_pipeline_e2e.py`, 342 lines) for ~4,100 lines of bash. No
unit tests for the core engine logic (scheduler, TDD verification, scoring,
config loading).

## Option 1: Bash Hardening

### Specific Fixes Needed

1. **`eval` injection** (critical): Replace `eval claude -p $extra_flags` with
   bash array expansion: `flags=(...); claude -p "${flags[@]}"`. Requires
   refactoring `build_claude_extra_flags()` to populate an array instead of
   returning a string.

2. **Hardcoded `exit 0`** in `parallel_ralph.sh`: Replace with proper exit code
   propagation from worker subprocesses. Track per-worker exit codes in an array.

3. **`teams.sh` argument bug**: Fix function call argument order.

4. **macOS compatibility shims**:
   - `grep -oP` to `grep -oE` (POSIX ERE) or conditional `ggrep` detection
   - `md5sum` to `md5 -q` / `shasum -a 256` with platform detection
   - `timeout` to `gtimeout` (via `brew install coreutils`) with detection
   - `flock` to `mkdir`-based locking (portable) or `shlock`

5. **JSON payload safety** in `lib/vibe.sh`: Use `jq --arg` for all
   user-controlled values instead of string concatenation + `sed` escaping.

6. **Temp file cleanup**: Add comprehensive `trap` handlers for EXIT/INT/TERM
   that clean up all temp files.

### What Bash Hardening Does NOT Fix

- **No type safety**: Variable typos, wrong argument types, and data shape
  mismatches remain silent until runtime.
- **No unit testing**: Bash functions cannot be meaningfully unit tested in
  isolation. Source-order dependencies, global state, and side effects make
  mocking impractical.
- **jq fragility**: Complex jq pipelines for prd.json manipulation are brittle
  and hard to debug. No schema validation at parse time.
- **Process management hacks**: `disown` + PID polling, background job tracking
  via temp files. No structured concurrency.
- **No IDE support**: No autocompletion, no refactoring tools, no go-to-definition.
- **No binary distribution**: Users must have all external dependencies installed.

### Effort Estimate

~2-3 focused sessions for the critical fixes (`eval`, `exit 0`, macOS shims).
Full hardening including JSON safety, temp file cleanup, and `teams.sh` fix:
~4-5 sessions.

### Verdict

**Necessary regardless of rewrite timeline** -- the `eval` injection must be
fixed before any merge to main. But hardening alone is not sufficient
long-term. The fundamental issues (no types, no tests, process management,
cross-platform fragility) are structural limitations of bash.

## Option 2: Bun (TypeScript) -- Primary Alternative

### Architecture Sketch

```text
ralph-cli/
  src/
    index.ts              # Entry point, Bun.argv dispatch
    commands/
      run.ts              # Parallel TDD loop (Bun.spawn + Promise.all)
      init.ts             # Environment setup, state file creation
      validate.ts         # Language adapter hook runner
      vibe.ts             # Vibe Kanban subcommands
      prd.ts              # prd.json validation and manipulation
      config.ts           # Config show/dump
      watch.ts            # File watcher (Bun.FileSystemWatcher)
      archive.ts          # Tar/archive artifacts
      clean.ts            # Cleanup tmp files, logs, worktrees
      stop.ts             # Kill running processes
    engine/
      scheduler.ts        # Dependency graph resolution
      worker.ts           # Single worktree TDD loop
      orchestrator.ts     # N-worker coordinator
      scorer.ts           # Weighted scoring + merge selection
    git/
      worktree.ts         # Create/remove worktrees via Bun.spawn("git", ...)
      commits.ts          # TDD commit marker parser
    agent/
      driver.ts           # Agent driver interface
      claude.ts           # Claude Code: Bun.spawn("claude", ["-p", ...])
      prompt.ts           # Prompt template assembly
    config/
      loader.ts           # CLI > env > ralph.toml > defaults
      schema.ts           # Zod schema for ralph.toml
    adapter/
      loader.ts           # TOML adapter parser + resolution
      runner.ts           # Hook executor (subprocess per hook)
      adapters/           # Embedded TOML files (bundled at compile)
    vibe/
      client.ts           # KanbanClient class: fetch() + typed payloads
      launcher.ts         # Start/stop external Kanban server
    prd/
      state.ts            # prd.json read/write with typed interfaces
      validate.ts         # Schema validation (Zod)
    types/
      prd.ts              # PrdState, Story, Dependency interfaces
      config.ts           # RalphConfig, AdapterConfig types
      kanban.ts           # KanbanTask, KanbanStatus types
  tests/
    engine/               # Bun test runner, mirrors src/
    ...
  package.json
  tsconfig.json
  bunfig.toml
```

### Bash-to-Bun Component Mapping

| Bash Component | Bun Equivalent | Complexity |
|----------------|----------------|------------|
| `jq` JSON manipulation | Native `JSON.parse`/`JSON.stringify` + Zod | Trivial |
| `source lib/config.sh` (env var layering) | `Bun.env` + TOML parser + CLI args | Easy |
| `claude -p \| tee` (subprocess + logging) | `Bun.spawn()` with `stdout: "pipe"`, tee via `ReadableStream.tee()` | Easy |
| `git worktree add/remove` | `Bun.spawn("git", [...])` | Easy |
| `curl POST/PUT` (Vibe Kanban) | Native `fetch()` with typed request bodies | Easy |
| `grep -oP` pattern matching | `String.match()` with RegExp | Trivial |
| `flock` file locking | `Bun.file().writer()` with lockfile pattern | Medium |
| `jq` prd.json schema validation | Zod schema validation | Easy |
| `disown` + PID polling | `Promise.all()` with `AbortController` for cancellation | Medium |
| ERR trap / `set -eEuo pipefail` | try/catch with typed errors | Easy |
| `timeout` command wrapping | `AbortSignal.timeout()` on subprocess | Easy |
| Background job monitoring | `setInterval()` + async log tailing | Easy |
| `extract_signatures.py` (AST) | tree-sitter WASM (tree-sitter-python npm pkg) or keep as Python subprocess | Medium |
| String-concat JSON (vibe.sh) | Typed `KanbanClient` class, `JSON.stringify()` | Trivial |
| Shared `KANBAN_MAP` flat file | In-memory `Map<string, string>` (per-process) | Trivial |

### Vibe Kanban Migration

The current bash implementation (`lib/vibe.sh`, 181 lines) uses `curl` for HTTP,
`jq` for response parsing, string concatenation for JSON payloads, and a shared
flat file (`KANBAN_MAP`) for task ID mapping. All of these are fragile.

In Bun, this becomes a typed `KanbanClient` class using native `fetch()` and
`JSON.stringify()` for safe serialization. The `KANBAN_MAP` flat file (TOCTOU
race on concurrent writes) becomes an in-memory `Map<string, string>` per
process. In parallel mode, each worker holds its own map subset -- no shared
file needed.

### generate_prd_json.py Migration

Two options:

1. **Keep as Python subprocess** -- `Bun.spawn("python", ["generate_prd_json.py"])`.
   Zero migration cost. The script is 795 lines of mature, tested Python with
   complex markdown parsing. Rewriting it gains nothing.

2. **Port to TypeScript** -- Use a markdown parser (e.g., `marked` or
   `remark`) + custom PRD schema logic. Significant effort (~2-3 sessions) for
   no functional gain.

**Recommendation:** Keep as Python. It's called once per `ralph init`, not in
the hot loop.

### Binary Distribution

`bun build --compile` produces a single executable:

- **Size**: ~56 MB (bundles Bun runtime + JavaScriptCore)
- **Cross-compile targets**: `bun build --compile --target=bun-linux-x64`,
  `bun-linux-arm64`, `bun-darwin-arm64`, `bun-darwin-x64`
- **Limitation**: Cross-compilation is newer and less battle-tested than Go's.
  CI must build on native platforms or use QEMU.

### Submodule Compatibility

`ralph/` directory contains TypeScript source. Makefile detects `ralph` binary:
if present, delegates to it; otherwise falls back to `bun run ralph/src/index.ts`
(requires Bun installed).

### Pros

- Native JSON and `fetch()` eliminate jq, curl, and sed fragility entirely
- Full type safety with TypeScript + Zod runtime validation
- `Bun.spawn()` is ergonomic for subprocess-heavy workloads
- `Promise.all()` with `AbortController` is cleaner than `disown` + PID polling
- Fast startup (~50ms), fast test runner (`bun test`)
- npm ecosystem for tree-sitter, TOML parsing, etc.
- Familiar to JavaScript/TypeScript developers

### Cons

- **56 MB binary** -- 3-10x larger than Go. Acceptable for a dev tool but not
  ideal for `curl | sh` distribution.
- **Bun maturity** -- Bun is young (v1.x). Edge cases in `Bun.spawn()`, file
  locking, and signal handling are less battle-tested than Go's subprocess
  management.
- **No `flock` equivalent** -- Must implement file locking via lockfile pattern
  or `Bun.file()` advisory locks.
- **Subprocess env pollution** -- Bun modifies `BUN_INSTALL` and potentially
  `LD_LIBRARY_PATH`, which could leak into spawned `claude` processes.
- **Cross-compilation maturity** -- Newer than Go's `GOOS/GOARCH`, less CI
  tooling.

### Effort Estimate

~8-12 sessions for core engine (scheduler, worker, orchestrator, TDD
verification, config). ~3-4 additional sessions for Vibe Kanban, adapter
system, and CLI scaffolding. Total: ~11-16 sessions.

## Option 3: Go + Cobra/Viper -- Primary Candidate

### Architecture Sketch

Proposed module structure:

```text
ralph-cli/
  cmd/ralph/main.go          # Cobra root command
  internal/
    engine/                   # scheduler, worker, orchestrator, scorer
    git/                      # worktree, commits (TDD parser)
    agent/                    # driver interface, claude driver, prompt assembly
    config/                   # CLI > env > toml > defaults (Viper)
    adapter/                  # TOML adapter parser, hook runner, embedded adapters
    prd/                      # prd.json state machine with file locking
    vibe/                     # Kanban REST client + server launcher
  go.mod, go.sum
```

### Bash-to-Go Component Mapping

| Bash Component | Go Equivalent | Complexity |
|----------------|---------------|------------|
| `jq` JSON manipulation | `encoding/json` + typed structs | Easy |
| `source lib/config.sh` (env layering) | Viper: TOML + env + CLI flags | Trivial (Viper handles it) |
| `claude -p \| tee` | `exec.CommandContext()` + `io.MultiWriter` | Easy |
| `git worktree add/remove` | `exec.Command("git", ...)` or go-git | Easy |
| `curl POST/PUT` (Vibe Kanban) | `net/http` stdlib + `json.Marshal` | Easy |
| `grep -oP` pattern matching | `regexp.MustCompile()` | Trivial |
| `flock` file locking | `os.OpenFile` with `syscall.Flock` / cross-platform lib | Medium |
| `disown` + PID polling | `errgroup.Group` / `sync.WaitGroup` with context cancellation | Easy |
| ERR trap / `set -eEuo pipefail` | Explicit error returns (Go idiom) | Easy |
| `timeout` command wrapping | `context.WithTimeout()` on subprocess | Trivial |
| Background job monitoring | `time.Ticker` + goroutine | Easy |
| `extract_signatures.py` | Keep as Python subprocess call | Trivial |
| String-concat JSON (vibe.sh) | `json.Marshal` with typed structs | Trivial |
| Shared `KANBAN_MAP` flat file | `sync.Map` for concurrent access | Trivial |

### Vibe Kanban Migration

Go's stdlib handles everything the bash Vibe integration needs. `json.Marshal`
with typed structs eliminates JSON injection risk. `sync.Map` replaces the
shared `KANBAN_MAP` flat file for concurrent worktree access -- no TOCTOU race,
no file I/O overhead. The `net/http` stdlib client replaces `curl`, and typed
Go structs replace `jq` response parsing.

### Where Go Wins Over Bun

- **Binary size**: 10-15 MB static vs 56 MB (Bun) or 60+ MB (Deno)
- **Cross-compilation**: `GOOS=darwin GOARCH=arm64 go build` -- one line, no
  QEMU, no CI platform matrix needed. Battle-tested for 15+ years.
- **Goroutines**: Map directly to Ralph's N-worker pattern. No callback chains
  or Promise orchestration. `errgroup.Group` handles cancellation and error
  propagation out of the box.
- **Viper**: Config layering (TOML + env + CLI flags with precedence) is
  Viper's exact use case. Replaces `lib/config.sh` entirely.
- **Cobra**: Subcommand dispatch (`ralph run`, `ralph vibe start`, `ralph prd
  validate`) maps directly to Cobra's command tree. Tab completion for free.
- **go-git**: Pure-Go git operations without shelling out. Optional but
  available if needed.
- **Static binary**: True zero-dependency binary. No runtime, no modified env
  vars, no subprocess pollution.
- **Maturity**: Go's subprocess management, signal handling, and file locking
  have 15+ years of production use. Edge cases are well-documented.

### Where Go Loses to Bun/Deno

- **JSON verbosity**: Defining Go structs for every JSON shape is more
  boilerplate than `JSON.parse()` + Zod. Ralph has ~5 distinct JSON schemas
  (prd.json, kanban payloads, config, adapter TOML, domain_retries.json), so
  this is moderate but not prohibitive.
- **Error handling**: `if err != nil { return err }` on every operation.
  Verbose but explicit. Some find this tedious, others find it clarifying.
- **Iteration speed**: Compile step between edits. Fast for Go (~1-2s), but
  not as instant as `bun run`.
- **String manipulation**: More ceremony for string processing than
  TypeScript. Relevant for prompt template assembly and log parsing.

### Pros

- Smallest binary (10-15 MB), best for `curl | sh` distribution
- Best cross-compilation story (single-command, no platform-specific CI)
- Goroutines are the natural model for Ralph's parallel workers
- Cobra/Viper solve CLI + config elegantly
- 15+ years of production subprocess management maturity
- No runtime dependencies, no env pollution

### Cons

- JSON struct boilerplate for each data shape
- Verbose error handling
- Slower iteration than TypeScript during development
- Learning curve for contributors unfamiliar with Go
- No native tree-sitter (would need CGO or keep Python subprocess)

### Effort Estimate

~10-14 sessions for core engine. ~3-4 for Vibe Kanban, adapters, CLI
scaffolding. Total: ~13-18 sessions. Slightly higher than Bun due to JSON
struct definitions and error handling boilerplate. Offset by Cobra/Viper doing
heavy lifting for CLI and config.

## Option 4: Deno -- Bun Alternative

### Delta from Bun

Deno and Bun share the TypeScript foundation. The architecture sketch, component
mapping, and effort estimate from Option 2 apply with these differences:

| Aspect | Bun | Deno |
|--------|-----|------|
| Binary size | ~56 MB | ~60-135 MB (bundles V8, varies by version) |
| Subprocess | `Bun.spawn()` | `new Deno.Command()` |
| HTTP | Native `fetch()` | Native `fetch()` (identical) |
| File I/O | `Bun.file()` | `Deno.readFile()` / `Deno.writeFile()` |
| Test runner | `bun test` | `deno test` (built-in) |
| Linter/formatter | External (eslint, prettier) | Built-in (`deno lint`, `deno fmt`) |
| npm compat | Full | Partial (most packages work via `npm:` specifiers) |
| Security | No sandbox | `--allow-net`, `--allow-read`, `--allow-run` by default; compiled binary embeds all permissions |
| Cross-compile | `bun build --compile --target=...` | `deno compile --target=...` |
| TOML parsing | npm package | `@std/toml` (stdlib) |

### Vibe Kanban

Identical to Bun: native `fetch()` + typed interfaces. The only difference is
Deno requires `--allow-net` permission, which is embedded in the compiled binary.

### When to Choose Deno Over Bun

- **Stricter TypeScript**: Deno enforces stricter TS defaults and disallows
  `any` by default. Better for long-term maintainability.
- **Built-in tooling**: No need for eslint, prettier, or a separate test
  framework. `deno lint`, `deno fmt`, `deno test` are built-in.
- **Security-by-default**: Permission system prevents accidental network or
  filesystem access. Good for a tool that runs untrusted PRD-driven code.
- **stdlib**: `@std/toml`, `@std/path`, `@std/fs` reduce external dependencies.

### When to Choose Bun Over Deno

- **npm compatibility**: Some npm packages don't work with Deno's `npm:`
  specifiers. tree-sitter native bindings may be affected.
- **Startup speed**: Bun is consistently faster for short-lived CLI invocations.
- **Community momentum**: Bun has stronger adoption momentum in the CLI space.

### Verdict

Deno is a viable alternative to Bun with better built-in tooling and security
defaults. The binary size disadvantage (60-135 MB vs 56 MB) is marginal. If
choosing TypeScript over Go, Deno's stricter defaults make it slightly
preferable for a tool like Ralph where reliability matters more than startup
latency. However, both share the fundamental 56-135 MB binary size problem
compared to Go's 10-15 MB.

## Option 5: Python (All-In)

### The Case for Python

`generate_prd_json.py` is already 795 lines of Python, `extract_signatures.py`
is 116 lines, and `test_pipeline_e2e.py` is 342 lines. The team already writes
Python. Could `ralph.sh` become `ralph.py`?

### Architecture Sketch

```text
ralph/
  __main__.py               # Entry point: python -m ralph
  cli.py                    # Click/Typer CLI dispatch
  engine/
    scheduler.py            # Dependency graph (networkx or custom)
    worker.py               # Single worktree TDD loop (asyncio.subprocess)
    orchestrator.py         # N-worker coordinator (asyncio.gather)
    scorer.py               # Weighted scoring
  git/
    worktree.py             # subprocess: git worktree add/remove
    commits.py              # TDD commit parser
  agent/
    driver.py               # Protocol class for agent drivers
    claude.py               # asyncio.create_subprocess_exec("claude", ...)
    prompt.py               # Template assembly (pathlib + string.Template)
  config/
    loader.py               # CLI > env > toml > defaults (tomllib + pydantic)
  adapter/
    loader.py               # TOML adapter parser
    runner.py               # Hook executor (asyncio.subprocess)
  vibe/
    client.py               # httpx async client + pydantic models
    launcher.py             # Start/stop Kanban server
  prd/
    state.py                # prd.json typed read/write (pydantic)
    validate.py             # Schema validation
  generate_prd_json.py      # Existing script, integrated directly
```

### Bash-to-Python Component Mapping

| Bash Component | Python Equivalent | Complexity |
|----------------|-------------------|------------|
| `jq` JSON manipulation | `json` stdlib + pydantic models | Easy |
| `source lib/config.sh` | `tomllib` + `pydantic-settings` + Click/Typer | Easy |
| `claude -p \| tee` | `asyncio.create_subprocess_exec()` + `StreamReader` | Medium |
| `git worktree add/remove` | `subprocess.run(["git", ...])` | Easy |
| `curl POST/PUT` (Vibe Kanban) | `httpx.AsyncClient` + pydantic request models | Easy |
| `disown` + PID polling | `asyncio.gather()` with `asyncio.wait()` | Medium |
| `timeout` | `asyncio.wait_for()` | Easy |
| `flock` file locking | `fcntl.flock()` + `filelock` library | Easy |
| `extract_signatures.py` | Direct import (same language) | Trivial |
| `generate_prd_json.py` | Direct import (same language) | Trivial |

### Vibe Kanban Migration

Python with `httpx` and pydantic models provides clean, typed HTTP client
code. `httpx.AsyncClient` replaces `curl`, pydantic `BaseModel` subclasses
replace string-concatenated JSON payloads, and a plain `dict[str, str]`
replaces the shared `KANBAN_MAP` flat file. Safe serialization via
`model_dump(exclude_none=True)` eliminates the JSON injection risk entirely.

### Pros

- **Single language**: All Ralph code (engine + PRD generator + signature
  extractor + tests) in one language. No polyglot maintenance.
- **Team familiarity**: The existing project and team already use Python
  extensively. Zero learning curve.
- **Rich stdlib**: `asyncio`, `subprocess`, `json`, `tomllib` (3.11+),
  `pathlib`, `re`, `fcntl` cover most needs.
- **Pydantic**: Type-safe data validation for prd.json, config, adapter TOML,
  Kanban payloads. Already used in the parent project.
- **generate_prd_json.py integration**: Direct import instead of subprocess
  call. 795 lines of mature code, zero migration.
- **ast module**: `extract_signatures.py` already uses Python's `ast`. No
  tree-sitter dependency needed.

### Cons

- **No single-binary distribution**: Python requires a runtime. Options:
  - **PyInstaller**: Produces ~50-100 MB bundles. Fragile with C extensions,
    breaks on OS updates, false positive antivirus detections.
  - **Nuitka**: Better than PyInstaller but still 30-60 MB, slower compilation.
  - **shiv/zipapp**: Requires Python installed. Not a true standalone binary.
  - **Docker**: Adds container overhead. Not suitable for `curl | sh`.
  - **pipx**: Best UX for Python tools, but requires pipx + Python installed.
- **Startup time**: ~100-300ms for Python import + module loading. Acceptable
  for Ralph's use case (long-running loops) but noticeable for `ralph --version`.
- **GIL**: `asyncio` handles I/O concurrency well (Ralph's main bottleneck is
  waiting on `claude -p`), but CPU-bound scoring would need
  `ProcessPoolExecutor`. Unlikely to matter in practice.
- **asyncio complexity**: `asyncio.create_subprocess_exec()` with proper signal
  handling, cancellation, and timeout is more complex than Go's
  `context.WithTimeout()` approach or Bun's `Bun.spawn()`.

### Distribution Options

| Method | Standalone? | Size | Requires |
|--------|-------------|------|----------|
| `pipx install ralph-cli` | No | ~1 MB (source) | Python 3.11+, pipx |
| `pip install ralph-cli` | No | ~1 MB (source) | Python 3.11+, pip |
| `uv tool install ralph-cli` | No | ~1 MB (source) | uv |
| PyInstaller bundle | Yes | 50-100 MB | Nothing (but fragile) |
| Nuitka compilation | Yes | 30-60 MB | Nothing (but slow build) |
| Docker image | Yes | 100-200 MB | Docker |
| Source in submodule | No | ~50 KB | Python 3.11+, dependencies |

### Verdict

Python is the lowest-friction option for the existing team and eliminates the
polyglot maintenance burden. However, the lack of reliable single-binary
distribution is a fundamental mismatch with Ralph's dual-distribution
requirement (GitHub Releases binary + submodule). If binary distribution is
deprioritized, Python becomes the strongest candidate.

## Distribution Model

### Dual-Track Distribution

Ralph needs to support two distribution models simultaneously:

1. **GitHub Releases**: Pre-built binary per platform, downloadable via
   `curl -fsSL .../install.sh | bash` or direct download. No build tools
   required.

2. **Pinned git submodule**: Current model. Template consumers get Ralph source
   in `ralph/` directory, pinned to a specific tag. Makefile builds from source
   or delegates to pre-installed binary.

### How Each Language Affects Distribution

| Aspect | Bash (current) | Bun | Go | Deno | Python |
|--------|---------------|-----|-----|------|--------|
| **Binary release** | N/A | 56 MB | 10-15 MB | 60-135 MB | 50-100 MB (fragile) |
| **Submodule source** | Works now | Needs Bun or binary | Needs Go or binary | Needs Deno or binary | Needs Python 3.11+ |
| **Cross-compile CI** | N/A | Platform matrix or QEMU | Single `go build` command | Platform matrix | PyInstaller per-platform |
| **Install one-liner** | N/A | `curl \| sh` (56 MB) | `curl \| sh` (12 MB) | `curl \| sh` (80 MB) | `pipx install` (needs Python) |
| **Zero-dep runtime** | No (jq, etc.) | Yes (bundled) | Yes (static) | Yes (bundled) | No (Python required) |
| **Signing/checksums** | N/A | SHA256 + cosign | SHA256 + cosign | SHA256 + cosign | SHA256 + cosign |

### Makefile Integration Pattern

The Makefile detects the best available runtime: pre-built binary first, then
`go run` if Go is available, then falls back to the deprecated bash scripts.
Each `make ralph_*` recipe delegates to `$(RALPH) <subcommand>` with env-var-
to-flag mapping via Makefile `$(if ...)` conditionals.

### Versioning

- Semver tags on the CLI repo (`v1.0.0`, `v1.1.0`, etc.)
- Submodule pins to a specific tag
- `ralph --version` prints version + git commit hash
- Makefile `RALPH_MIN_VERSION` check warns on outdated binary

### Release Automation

- **Go**: `goreleaser` handles multi-platform build, checksums, GitHub Release
  upload, and Homebrew tap in one config file. Most mature release tooling.
- **Bun**: Custom CI workflow with `bun build --compile --target=...` per
  platform. Less standardized.
- **Deno**: `deno compile --target=...` per platform. Similar to Bun.
- **Python**: Per-platform PyInstaller/Nuitka builds. Most fragile CI.

## Decision Framework

| Factor | Bash (harden) | Bun (TS) | Go + Cobra | Deno (TS) | Python |
|--------|:---:|:---:|:---:|:---:|:---:|
| **Rewrite effort** | None (fix only) | Medium | Medium-High | Medium | Medium |
| **Binary distribution** | N/A | Yes (56 MB) | Yes (10-15 MB) | Yes (60-135 MB) | Fragile |
| **Type safety** | None | Full | Full | Full | Optional (mypy) |
| **Testability** | Minimal | Full | Full | Full | Full |
| **macOS compat** | Needs shims | Native | Native | Native | Native |
| **Learning curve** | None | Low-Med | Medium | Low-Med | None |
| **Vibe Kanban** | curl+jq+sed | fetch()+typed | net/http+json | fetch()+typed | httpx+pydantic |
| **generate_prd_json.py** | Keep (subprocess) | Keep (subprocess) | Keep (subprocess) | Keep (subprocess) | Integrate (import) |
| **Concurrency model** | disown+PID | Promise.all | goroutines+errgroup | Promise.all | asyncio.gather |
| **Config layering** | env vars only | Custom or npm lib | Viper (battle-tested) | Custom or npm lib | pydantic-settings |
| **CLI framework** | case statement | yargs/commander | Cobra (best-in-class) | Cliffy | Click/Typer |
| **Cross-compile** | N/A | Newer, needs matrix | One command, 15yr mature | Newer, needs matrix | Per-platform fragile |
| **Binary size** | N/A | 56 MB | 10-15 MB | 60-135 MB | 50-100 MB |
| **Subprocess ergonomics** | Native (bash's job) | Bun.spawn (good) | exec.CommandContext (excellent) | Deno.Command (good) | asyncio (complex) |
| **Release tooling** | N/A | Custom CI | goreleaser (mature) | Custom CI | Fragile CI |

### Decision Scenarios

**"We need binary distribution and cross-platform reliability"** --> Go.
Smallest binary, best cross-compilation, most mature tooling.

**"Team only knows TypeScript, binary size doesn't matter"** --> Bun (or Deno
for stricter defaults). Native JSON handling eliminates the biggest pain point
(jq fragility). 56 MB binary is acceptable for a dev tool.

**"Minimize effort, deprioritize binary distribution"** --> Python. Single
language, zero learning curve, direct integration of existing Python code.
Distribute via `pipx install` + submodule source.

**"Just fix the critical bugs, rewrite later"** --> Bash hardening. Fix `eval`
injection, `exit 0` masking, and macOS shims. Buys time for a proper rewrite
decision.

**"Maximum long-term maintainability"** --> Go. Explicit error handling,
static types, goroutine concurrency, and Go's stability guarantee (code from
Go 1.0 still compiles) make it the lowest-maintenance option over 5+ years.

## Recommendation

### Immediate: Bash Hardening (1-2 sessions)

Fix the `eval` injection in `ralph.sh` and the `exit 0` masking in
`parallel_ralph.sh` before any merge to main. These are security and
correctness bugs that exist regardless of rewrite plans.

### Rewrite: Go + Cobra/Viper

Go is the recommended rewrite language for Ralph CLI. The rationale:

1. **Binary distribution is a core requirement.** Ralph's dual-distribution
   model (GitHub Releases + submodule) demands a small, truly standalone binary.
   Go's 10-15 MB static binary with single-command cross-compilation is
   unmatched. Bun/Deno at 56-135 MB and Python's fragile bundling options
   don't compete.

2. **Concurrency model fits perfectly.** Ralph's N-worker parallel worktree
   pattern maps directly to goroutines + `errgroup.Group`. Go's structured
   concurrency replaces bash's `disown` + PID polling with proper cancellation,
   timeouts, and error propagation.

3. **Subprocess management is Go's strength.** Ralph spends 99% of its time
   waiting on `claude -p` subprocesses. Go's `exec.CommandContext()` with
   `context.WithTimeout()` is the most mature and well-tested option for this
   workload.

4. **Viper replaces config.sh completely.** The TOML + env var + CLI flag
   layering with precedence is exactly what Viper does. No custom config
   code needed.

### Migration Path

1. **Phase 0 (now)**: Bash hardening -- fix `eval`, `exit 0`, macOS shims
2. **Phase 1**: Scaffold Go CLI with Cobra commands matching all `make ralph_*`
   recipes. Implement `ralph run` (serial mode only) as proof of concept.
3. **Phase 2**: Implement parallel orchestrator, story scheduler, TDD
   verification, and adapter system.
4. **Phase 3**: Implement Vibe Kanban client, scoring/merge, and remaining
   subcommands.
5. **Phase 4**: `goreleaser` setup, CI release pipeline, install script.
6. **Phase 5**: Remove bash scripts. Makefile delegates to `ralph` binary only.

`generate_prd_json.py` and `extract_signatures.py` remain as Python, called
via subprocess. They're called infrequently and work well as-is.

### Next Steps

1. Fix `eval` injection and `exit 0` bugs in current bash (prerequisite for any merge)
2. Create UserStory.md and PRD.md for the CLI rewrite (language-neutral until decision is finalized)
3. Bootstrap: use current Ralph loop to implement its own replacement
4. Milestone: `ralph run --workers 1 --iterations 1` completes a single story

## Sources

- [`ralph/TODO.md`](../../ralph/TODO.md) -- Consolidated backlog including rewrite item
- [Cobra](https://github.com/spf13/cobra) -- Go CLI framework
- [Viper](https://github.com/spf13/viper) -- Go config hierarchy (TOML + env + flags)
- [goreleaser](https://goreleaser.com/) -- Go multi-platform release automation
- [Bun](https://bun.sh/) -- JavaScript runtime with `bun build --compile`
- [Deno](https://deno.com/) -- TypeScript runtime with `deno compile`
- [tree-sitter](https://github.com/tree-sitter/tree-sitter) -- Incremental parser generator (relevant for Bun/Deno signature extraction alternative)
