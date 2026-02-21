# UserStory: Rewrite Ralph Engine as Go CLI

## Problem

Ralph's engine is ~3,000 lines of bash across 13 scripts. This causes three
hard problems:

1. **Not testable** — Bash control flow (story scheduling, TDD verification,
   baseline comparison) cannot be unit tested. The only test coverage is a
   coarse E2E script (`test_parallel_ralph.sh`).
2. **Divergence** — When a team uses the template and Ralph evolves upstream,
   the copied scripts drift. No upgrade path exists.
3. **Environment fragility** — Depends on specific versions of `jq`, `bash`,
   `timeout`, `flock`, `curl`. Breaks across macOS/Linux/CI differences.

## Solution

Rewrite the Ralph engine as a standalone Go binary distributed as a single
static executable. The Makefile stays as the user-facing interface, calling
CLI subcommands instead of `bash ralph/scripts/*.sh`.

**Project name:** TBD — decided before first release. See
[docs/NAMING.md](NAMING.md) for candidates, taglines, and availability
research.

### Bootstrap: Ralph builds its replacement

The current bash-based Ralph loop implements the Go rewrite. The PRD stories
are executed by the existing `parallel_ralph.sh` engine — Ralph
bootstraps its own replacement. Once the Go binary passes all acceptance
criteria, the bash scripts become dead code and are removed. One-way
migration, not parallel maintenance.

## Language Decision: Why Go

### Why not Rust

Rust and Go scored within 2% of each other on a weighted evaluation across 12
criteria (subprocess management, concurrency, CLI frameworks, testing, JSON,
git operations, cross-compilation, TUI upgrade path, binary distribution,
ecosystem maturity, learning curve, binary size).

Go wins on the dimensions that matter most for Ralph:

| Factor                 | Go                                          | Rust                                                      |
|------------------------|---------------------------------------------|-----------------------------------------------------------|
| Contributor onboarding | Days                                        | Months (borrow checker)                                   |
| Concurrency model      | Goroutines map directly to N-worker pattern | Tokio async requires runtime, lifetimes, `Arc<Mutex<T>>`  |
| Cross-compilation      | `GOOS=darwin GOARCH=arm64 go build`         | Requires `cross` tool + Docker                            |
| CLI/TUI ecosystem      | Cobra + Charmbracelet                       | clap + ratatui (equally mature)                           |
| Binary size            | 10-15 MB static                             | 3-8 MB static (both acceptable)                           |

Rust would be better if: the team already writes Rust, binary size under 5 MB
matters, or compile-time data race prevention for shared `prd.json` state
becomes critical. OpenAI chose Rust for Codex CLI, but they have a
Rust-experienced team. Ralph is a template project — contributor accessibility
matters more than theoretical safety guarantees.

### Why not TypeScript

Claude Code itself uses TypeScript + React + Ink. OpenAI's Codex CLI started
in TypeScript before rewriting to Rust. TypeScript is a valid CLI language, but
fails on Ralph's core requirement:

- **Binary size** — `deno compile` produces ~135 MB binaries (bundles V8
  runtime). Go produces 10-15 MB. For a tool users `curl` and run, this is
  disqualifying.
- **No true single binary** — Node.js requires a runtime. Deno compile bundles
  it but at massive cost. `pkg` (Node SEA) is experimental and fragile.
- **Subprocess env pollution** — Bundled runtimes modify `LD_LIBRARY_PATH` and
  `NODE_OPTIONS`, which leak into spawned `claude` CLI subprocesses.

TypeScript remains the right choice for Claude Code (distributed via npm/brew,
not as a raw binary). Ralph's distribution model is different: single binary,
no package manager, no runtime.

## User Stories

### US-1: Build and install Ralph CLI

**As a** developer using the template,
**I want to** build Ralph from source as a single binary,
**so that** I don't need to manage bash script dependencies.

**Acceptance criteria:**

- `make setup_ralph` runs `go build -o ralph ./cmd/ralph` (requires Go)
- `ralph --version` and `ralph version` both print version and build info
- Built binary has no runtime dependencies (no Node, no jq, no flock)
- Works on Linux amd64, Linux arm64, macOS amd64, macOS arm64

**Future (not in initial scope):**

- `goreleaser` for pre-built multi-platform binaries on GitHub Releases
- `curl | sh` installer for users without Go toolchain

### US-2: Run parallel worktree loop

**As a** developer,
**I want to** run `make ralph_run N_WT=3 ITERATIONS=2`,
**so that** Ralph executes the TDD loop across 3 worktrees for 2 iterations.

**Acceptance criteria:**

- `ralph run --workers 3 --iterations 2` replicates `parallel_ralph.sh`
- Creates N worktrees, invokes coding agent in each, validates, scores,
  merges best
- Config: see US-8 (`ralph.toml` + CLI flags + env vars)
- `--debug` flag enables verbose logging
- `--judge` flag enables Claude-as-Judge scoring
- `--security-review` flag enables security review pass
- Exit code 0 on success, non-zero on failure

### US-3: Makefile backward compatibility

**As a** existing template user,
**I want** all current `make ralph_*` recipes to work unchanged,
**so that** the rewrite is invisible to my workflow.

**Acceptance criteria:**

- Every current Makefile recipe produces equivalent behavior:

  ```text
  make ralph_run           -> ralph run
  make ralph_status        -> ralph status
  make ralph_watch         -> ralph watch
  make ralph_get_log WT=2  -> ralph log 2
  make ralph_stop          -> ralph stop
  make ralph_clean         -> ralph clean
  make ralph_archive       -> ralph archive
  make ralph_validate_json -> ralph prd validate
  make vibe_start          -> ralph vibe start
  make vibe_stop_all       -> ralph vibe stop
  make vibe_status         -> ralph vibe status
  make vibe_cleanup        -> ralph vibe cleanup
  ```

- `make ralph_init_loop` is multi-step (Claude skill + `generate_prd_json.py`
  + `ralph init` + `ralph prd validate`), not a 1:1 delegation — see
  Makefile integration section
- Env var passthrough (`N_WT`, `ITERATIONS`, `DEBUG`, `RALPH_JUDGE_*`)
  maps to CLI flags via Makefile `$(if ...)` conditionals

### US-4: TDD loop engine

**As a** developer,
**I want** Ralph to enforce TDD commit ordering,
**so that** each story produces `[RED]` then `[GREEN]` commits.

**Acceptance criteria:**

- Detects `[RED]`/`[GREEN]` commit markers in git log
- Rejects stories where `[GREEN]` appears before `[RED]`
- Runs `ralph validate` (language adapter hooks) with configurable timeout
- Fix loop: re-invokes coding agent with error output, up to N retries
- Atomic `prd.json` status updates (file locking, not bash `flock`)

### US-5: Story scheduler

**As a** developer,
**I want** Ralph to schedule stories respecting dependencies,
**so that** blocked stories wait for their prerequisites.

**Acceptance criteria:**

- Reads `prd.json` dependency graph
- Assigns ready stories to idle workers
- Marks stories as `in_progress`, `done`, `failed`
- Skips stories blocked by incomplete dependencies
- Handles circular dependency detection with clear error message

### US-6: Scoring and merge

**As a** developer,
**I want** Ralph to score worktree results and merge the best,
**so that** parallel runs converge to the highest-quality branch.

**Acceptance criteria:**

- Weighted scoring: test pass rate, complexity delta, lint cleanliness
- Optional Claude-as-Judge evaluation (`--judge` flag)
- Merges winning branch into base
- Archives losing branches with logs
- Interactive merge mode (`--merge-interactive`) for manual override

### US-7: Vibe Kanban integration

**As a** developer,
**I want** Ralph to update a Kanban board as stories progress,
**so that** I can watch the loop's progress in a browser.

**Note:** Vibe Kanban is an external process, not bundled with Ralph. Ralph
is an HTTP client only — it calls the Kanban REST API. `ralph vibe start`
launches the pre-installed Kanban server as a subprocess.

**Acceptance criteria:**

Subcommands:

- `ralph vibe start [--port N]` launches the Kanban server process
- `ralph vibe stop` shuts down all instances
- `ralph vibe status` reports running instances and port
- `ralph vibe cleanup` removes all tasks from the board

Auto-detection during `ralph run`:

- On run start, probe configured port (`ralph.toml` `[vibe].port`)
- If Vibe is running: sync automatically, log detection
- If Vibe is not running: silent no-op, no error

Task creation:

- Create one Kanban task per story per worktree on run start
- Task title format: `[run_id] [WTn] STORY-XXX: title`
- Already-passed stories created with `done` status
- Task payload includes: `wave` number, `depends_on` story IDs,
  description, and acceptance criteria from `prd.json`
- Task-to-story mapping held in-memory (no temp file, unlike bash
  `KANBAN_MAP`)

Real-time status sync:

- Each status transition pushes a REST PUT to the Kanban API
- Status mapping:

  | Ralph status       | Kanban status | Trigger                     |
  |--------------------|---------------|-----------------------------|
  | `pending`          | `todo`        | Task creation               |
  | `in_progress`      | `inprogress`  | Worker picks up story       |
  | validation running | `inreview`    | `ralph validate` starts     |
  | `passed`           | `done`        | Validation passes           |
  | `failed`           | `todo`        | Max retries exhausted       |
  | aborted            | `cancelled`   | Worker killed or timeout    |

- Each update includes: `executor` (run_id + worktree number),
  `attempt_count`, and optional `notes` (failure reason)
- Non-blocking: failed Kanban updates log a warning, never block the loop

### US-8: Configuration hierarchy

**As a** developer,
**I want** Ralph to read config from multiple sources with clear precedence,
**so that** I can override defaults per-project or per-run.

**Acceptance criteria:**

- Precedence: CLI flags > env vars > `ralph.toml` > built-in defaults
- `ralph config show` dumps resolved config with source attribution

**`ralph.toml` schema:**

```toml
# ralph.toml — project-level Wiggly configuration
language = "python"                  # Language adapter (US-10)
prd = "ralph/docs/prd.json"         # Path to PRD state file

[agent]
driver = "claude-code"               # Coding agent to invoke
# Supported: "claude-code" (default)
# TODO: "cline", "gh-copilot", "aider", "custom"
command = "claude"                   # Agent CLI binary name
flags = ["-p", "--dangerously-skip-permissions"]

[execution]
max_iterations = 25
max_fix_attempts = 3
validation_timeout = 300             # seconds
fix_timeout = 300                    # seconds

[models]
default = "sonnet"                   # Story implementation
simple = "haiku"                     # Simple changes (docs, typos)
fix = "haiku"                        # Validation error fixes

[judge]
enabled = false
model = "sonnet"
max_worktrees = 4                    # Fall back to metrics above this

[vibe]
port = 5173
```

### US-9: Testability

**As a** contributor,
**I want** Ralph's engine to have unit and integration tests,
**so that** changes don't break the loop.

**Acceptance criteria:**

- Unit tests for: story scheduler, TDD commit parser, scorer, config loader,
  JSON state machine, dependency resolver
- Integration tests for: worktree lifecycle, subprocess invocation,
  file locking
- `go test ./...` runs all tests
- CI runs tests on every PR
- Coverage target: 70% (matching existing Python project threshold)

### US-10: Language adapters for TDD validation

**As a** developer using Ralph to build a project in any language,
**I want** Ralph to enforce TDD with language-appropriate tooling,
**so that** quality gates work regardless of whether I'm writing Python, Go,
TypeScript, Rust, C++, C, or C#.

**Future:** BDD support (Cucumber, behave, Gherkin) via adapter hooks.

**Context:**

The `make validate` pipeline is a core USP of Ralph. Currently it's hardcoded
to Python (ruff + pyright + complexipy + pytest). When Ralph creates or works
on a project in another language, validation breaks because the tools don't
exist. A language adapter system lets Ralph ship with built-in adapters for
common languages and accept custom adapters for anything else.

**Note:** "Language adapters" are Ralph-internal TOML config files that map
validation hooks to language-specific CLI tools. They are unrelated to Claude
Code's MCP plugin/server system.

**Acceptance criteria:**

- `ralph.toml` declares project language: `language = "python"` (see US-8)
- `ralph init` scaffolds the correct validation pipeline for the language,
  runs `generate_prd_json.py` via `make` recipe (stays Python, not absorbed
  into Go binary), replaces `init.sh`, and checks adapter prerequisites
- `ralph validate` delegates to the active language adapter (runs hooks)
- `ralph prd validate` validates `prd.json` syntax only (replaces
  `validate_json.sh`, distinct from `ralph validate`)
- Each adapter defines 6 hooks (all optional except `test`):

  | Hook          | Purpose              | Runs during   |
  |---------------|----------------------|---------------|
  | `format`      | Auto-format source   | Pre-commit    |
  | `lint`        | Static analysis      | Pre-commit    |
  | `typecheck`   | Type checking        | Pre-commit    |
  | `complexity`  | Cognitive complexity | Pre-commit    |
  | `duplication` | Copy-paste detection | Pre-commit    |
  | `test`        | Run tests (required) | TDD RED/GREEN |

- Adapters are TOML files in `ralph/adapters/<language>.toml`
- `ralph validate` runs hooks in order, fails fast on first error
- `ralph validate --quick` skips `complexity`/`duplication`, runs
  `test --last-failed`
- `ralph validate --hook lint` runs a single hook only
- Hooks with `optional = true` skip silently if command not found (no
  error, no prerequisite failure). `duplication` is optional by default
  since `jscpd` requires Node.js which not all language stacks have.
- Custom adapters: user drops a `.toml` in `ralph/adapters/` and sets
  `language = "custom-name"` in `ralph.toml`
- `red_pattern`/`green_pattern` are substring matches against test runner
  stdout (not regex). Case-sensitive. Must match a unique indicator of
  test failure/success for the given runner.

**Future:** Adapter inheritance (`base = "c"` in C++ adapter) to DRY up
similar adapters. YAGNI until a third similar adapter appears.

**Adapter `[prerequisites]` section:**

Each adapter declares required tools. `ralph init` checks them and prints
actionable install instructions on failure:

```toml
[prerequisites]
commands = ["uv", "ruff", "pyright"]
install_hint = "pip install uv && uv sync --all-groups"
```

**Built-in adapters:**

**Python** (reference implementation, based on
[Agents-eval](https://github.com/qte77/Agents-eval)):

```toml
# ralph/adapters/python.toml
[adapter]
name = "python"
description = "Python TDD/BDD with uv, ruff, pyright, pytest"

[prerequisites]
commands = ["uv", "ruff", "pyright"]
install_hint = "pip install uv && uv sync --all-groups"

[hooks.format]
command = "uv run ruff format"
fix_command = "uv run ruff format"

[hooks.lint]
command = "uv run ruff check"
fix_command = "uv run ruff check --fix"

[hooks.typecheck]
command = "uv run pyright"

[hooks.complexity]
command = "uv run complexipy"

[hooks.duplication]
command = "jscpd src/ --reporters console --format python"
optional = true

[hooks.test]
command = "uv run pytest"
quick_command = "uv run pytest --lf -x"
coverage_command = "uv run pytest --cov"
red_pattern = "FAILED"
green_pattern = "passed"
```

**Go:**

```toml
[adapter]
name = "go"
description = "Go TDD with go test, staticcheck, golangci-lint"

[prerequisites]
commands = ["go", "golangci-lint"]
install_hint = "https://go.dev/dl/ && https://golangci-lint.run/welcome/install/"

[hooks.format]
command = "gofmt -l ."
fix_command = "gofmt -w ."

[hooks.lint]
command = "golangci-lint run"
fix_command = "golangci-lint run --fix"

[hooks.typecheck]
command = "go vet ./..."

[hooks.complexity]
command = "gocognit -over 10 ."

[hooks.duplication]
command = "jscpd . --reporters console --format go"
optional = true

[hooks.test]
command = "go test ./..."
quick_command = "go test -run TestFailed ./..."
coverage_command = "go test -coverprofile=coverage.out ./..."
red_pattern = "FAIL"
green_pattern = "PASS"
```

**TypeScript:**

```toml
[adapter]
name = "typescript"
description = "TypeScript TDD with vitest, eslint, tsc"

[prerequisites]
commands = ["node", "npx"]
install_hint = "https://nodejs.org/ && npm install"

[hooks.format]
command = "npx prettier --check ."
fix_command = "npx prettier --write ."

[hooks.lint]
command = "npx eslint ."
fix_command = "npx eslint --fix ."

[hooks.typecheck]
command = "npx tsc --noEmit"

[hooks.complexity]
command = "npx ts-complexity --threshold 10 src/"

[hooks.duplication]
command = "jscpd src/ --reporters console --format typescript"
optional = true

[hooks.test]
command = "npx vitest run"
quick_command = "npx vitest run --reporter=verbose --bail 1"
coverage_command = "npx vitest run --coverage"
red_pattern = "FAIL"
green_pattern = "✓"
```

**Rust:**

```toml
[adapter]
name = "rust"
description = "Rust TDD with cargo test, clippy, rustfmt"

[prerequisites]
commands = ["cargo", "rustfmt", "clippy"]
install_hint = "https://rustup.rs/"

[hooks.format]
command = "cargo fmt --check"
fix_command = "cargo fmt"

[hooks.lint]
command = "cargo clippy -- -D warnings"

[hooks.typecheck]
command = "cargo check"

[hooks.complexity]
command = "cargo cognitive-complexity --threshold 10"

[hooks.duplication]
command = "jscpd src/ --reporters console --format rust"
optional = true

[hooks.test]
command = "cargo test"
quick_command = "cargo test --no-fail-fast"
coverage_command = "cargo tarpaulin --out Xml"
red_pattern = "FAILED"
green_pattern = "ok"
```

**C++:**

```toml
[adapter]
name = "cpp"
description = "C++ TDD with CMake/CTest, clang-tidy, clang-format"

[prerequisites]
commands = ["cmake", "ctest", "clang-format", "clang-tidy"]
install_hint = "apt install cmake clang-tools"

[hooks.format]
command = "clang-format --dry-run -Werror src/**/*.cpp src/**/*.h"
fix_command = "clang-format -i src/**/*.cpp src/**/*.h"

[hooks.lint]
command = "clang-tidy src/**/*.cpp"

# TODO: typecheck — needs universal command (g++ -fsyntax-only or cmake target)

[hooks.complexity]
command = "lizard -T cyclomatic_complexity=10 src/"

[hooks.duplication]
command = "jscpd src/ --reporters console --format cpp"
optional = true

[hooks.test]
command = "cmake --build build && ctest --test-dir build"
quick_command = "ctest --test-dir build --rerun-failed"
coverage_command = "cmake --build build && ctest --test-dir build && lcov --capture --directory build --output-file coverage.info"
red_pattern = "Failed"
green_pattern = "Passed"
```

**C:**

```toml
[adapter]
name = "c"
description = "C TDD with CMake/CTest, clang-tidy, clang-format"

[prerequisites]
commands = ["cmake", "ctest", "clang-format", "clang-tidy"]
install_hint = "apt install cmake clang-tools"

[hooks.format]
command = "clang-format --dry-run -Werror src/**/*.c src/**/*.h"
fix_command = "clang-format -i src/**/*.c src/**/*.h"

[hooks.lint]
command = "clang-tidy src/**/*.c"

[hooks.complexity]
command = "lizard -T cyclomatic_complexity=10 src/"

[hooks.duplication]
command = "jscpd src/ --reporters console --format c"
optional = true

[hooks.test]
command = "cmake --build build && ctest --test-dir build"
quick_command = "ctest --test-dir build --rerun-failed"
coverage_command = "cmake --build build && ctest --test-dir build && lcov --capture --directory build --output-file coverage.info"
red_pattern = "Failed"
green_pattern = "Passed"
```

**C#:**

```toml
[adapter]
name = "csharp"
description = "C# TDD with dotnet test, dotnet format"

[prerequisites]
commands = ["dotnet"]
install_hint = "https://dotnet.microsoft.com/download"

[hooks.format]
command = "dotnet format --verify-no-changes"
fix_command = "dotnet format"

[hooks.lint]
command = "dotnet format analyzers --verify-no-changes"

[hooks.typecheck]
command = "dotnet build --no-restore"

[hooks.complexity]
command = "lizard -T cyclomatic_complexity=10 src/"

[hooks.duplication]
command = "jscpd src/ --reporters console --format csharp"
optional = true

[hooks.test]
command = "dotnet test"
quick_command = "dotnet test --filter FailedTests"
coverage_command = "dotnet test --collect:\"XPlat Code Coverage\""
red_pattern = "Failed!"
green_pattern = "Passed!"
```

**Adapter resolution order:**

1. `ralph/adapters/<language>.toml` in project (user override)
2. Built-in adapters embedded in the `ralph` binary (Go `embed`)
3. Error if no adapter found for declared language

## Future (not in initial scope)

### TUI upgrade path

- `ralph watch --tui` launches a Bubbletea-based terminal UI
- Shows: worker status, current story per worker, pass/fail indicators,
  overall progress bar
- Falls back to plain text streaming when `--tui` is omitted
- Add after the engine works and adapter system is validated

### Bi-directional Vibe Kanban sync

- Ralph reads Kanban state (cancel, re-prioritize) in addition to pushing
- Enables human-in-the-loop steering via the Kanban UI mid-run
- **Risk:** Cancelling a story with dependents breaks the scheduler.
  Requires dependency-aware cancellation (cascade or block) to be safe.
  Uni-directional push is the correct default until the scheduler can
  handle mid-run graph mutations.

### Pre-built binary distribution

- `goreleaser` for multi-platform binaries on GitHub Releases
- `curl -fsSL .../install.sh | bash` for users without Go toolchain
- Add after the CLI is stable

## Architecture Notes

### Go module structure

```text
ralph-cli/
  cmd/
    ralph/
      main.go           # Cobra root command
  internal/
    engine/
      scheduler.go      # Story dependency resolver
      worker.go         # Single worktree TDD loop
      orchestrator.go   # N-worker parallel coordinator
      scorer.go         # Weighted scoring + merge
    git/
      worktree.go       # Create/lock/remove worktrees
      commits.go        # TDD commit parser ([RED]/[GREEN])
    agent/
      driver.go         # Agent driver interface
      claude.go         # Claude Code driver: claude -p --model M
      prompt.go         # Prompt assembly from templates
    config/
      loader.go         # CLI > env > toml > defaults
    adapter/
      loader.go         # TOML adapter parser + resolution
      registry.go       # Built-in adapter registry (go:embed)
      runner.go         # Hook executor (format/lint/typecheck/...)
      adapters/         # Embedded TOML files
        python.toml
        go.toml
        typescript.toml
        rust.toml
        cpp.toml
        c.toml
        csharp.toml
    prd/
      state.go          # prd.json read/write with file lock
      validate.go       # prd.json schema validation (ralph prd validate)
      scheduler.go      # Dependency graph traversal
    vibe/
      client.go         # Kanban REST API client (PUT/POST/GET)
      launcher.go       # Start/stop external Kanban server process
  go.mod
  go.sum
```

### Agent driver interface

The engine invokes a coding agent via the `Driver` interface. Claude Code
is the default and only initial driver. The interface is designed so
alternative agents (Cline, GitHub Copilot, Aider) can be added later
by implementing the same contract:

```go
type Driver interface {
    // Invoke sends a prompt to the coding agent and returns its output.
    Invoke(ctx context.Context, opts InvokeOpts) (Result, error)
}
```

The driver is selected via `ralph.toml` `[agent].driver`. The engine never
imports agent-specific code directly — it only calls the `Driver` interface.

**TODO:** Cline, GitHub Copilot, Aider drivers (after Claude Code driver
is validated).

### Adapter system internals

The adapter system replaces the hardcoded `make validate` call with a
language-aware hook runner.

```text
ralph validate
  |-> load ralph.toml -> language = "python"
  |-> resolve adapter: project adapters/ -> built-in embed -> error
  |-> check prerequisites: verify commands exist, print install_hint on fail
  |-> parse adapter TOML -> [format, lint, typecheck, complexity, duplication, test]
  |-> for each hook (in order, fail-fast):
  |     |-> run command as subprocess
  |     |-> capture stdout/stderr
  |     |-> if exit != 0: log error, return failure
  |     +-> if exit == 0: continue
  +-> all hooks passed -> return success
```

The TDD loop uses the `test` hook's `red_pattern` and `green_pattern` to
detect RED/GREEN state without language-specific knowledge in the engine:

```text
worker.go (TDD verification):
  1. Run adapter.test -> parse output for red_pattern  -> [RED] commit
  2. Agent implements -> run adapter.test again
  3. Parse output for green_pattern                   -> [GREEN] commit
```

The fix loop uses `fix_command` variants when available:

```text
worker.go (fix loop, max N attempts):
  1. Run adapter.lint -> failure
  2. Run adapter.lint.fix_command -> auto-fix
  3. Run adapter.lint -> re-check
```

### Key dependencies

- `github.com/spf13/cobra` — CLI subcommands
- `github.com/spf13/viper` — Config hierarchy (toml + env + flags)
- `github.com/BurntSushi/toml` — Adapter TOML parsing
- `golang.org/x/sync/errgroup` — N-worker orchestration
- `encoding/json` — prd.json state machine (stdlib)
- `embed` — Built-in language adapter files (stdlib)

### Makefile integration

Makefile recipes become thin wrappers:

```makefile
ralph_run:
    ralph run \
        $(if $(N_WT),--workers $(N_WT)) \
        $(if $(ITERATIONS),--iterations $(ITERATIONS)) \
        $(if $(DEBUG),--debug) \
        $(if $(RALPH_JUDGE_ENABLED),--judge)
```

Recipes that stay as-is (not engine logic):

```makefile
ralph_create_userstory_md:
    claude -p '/generating-interactive-userstory-md'

ralph_create_prd_md:
    claude -p '/generating-prd-md-from-userstory-md'

ralph_init_loop:
    claude -p '/generating-prd-json-from-prd-md'
    uv run python ralph/scripts/generate_prd_json.py
    ralph init
    ralph prd validate
```

### Distribution (initial)

- `make setup_ralph` runs `go build` from source (requires Go toolchain)
- Optional: `go install github.com/<org>/ralph-cli/cmd/ralph@latest`
- Pre-built binaries via `goreleaser` deferred to Future section
