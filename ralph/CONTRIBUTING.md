# Ralph Contributing

Command reference for the Ralph autonomous development loop.
For project-level development workflows, see the root
[CONTRIBUTING.md](../CONTRIBUTING.md).

## Command Reference

| Command | Purpose | Flags |
|---------|---------|-------|
| `make ralph_create_userstory_md` | Create UserStory.md interactively via Claude | |
| `make ralph_create_prd_md` | Generate PRD.md from UserStory.md | |
| `make ralph_init_loop` | Initialize Ralph loop (prd.json + environment) | |
| `make ralph_run` | Run Ralph loop (always uses worktrees) | `N_WT=`, `ITERATIONS=`, `DEBUG=1` |
| `make ralph_init_and_run` | Initialize and run in one command | `N_WT=`, `ITERATIONS=`, `DEBUG=1` |
| `make ralph_reorganize_prd` | Archive current PRD and activate new one | `NEW_PRD=`, `VERSION=` |
| `make ralph_stop` | Stop all running Ralph loops | |
| `make ralph_status` | Show story progress from prd.json | |
| `make ralph_watch` | Live-watch Ralph log output with process tree | |
| `make ralph_get_log` | Show specific worktree log | `WT=` (worktree number) |
| `make ralph_clean` | Reset Ralph state (worktrees + local) | |
| `make ralph_archive` | Archive current run state | `ARCHIVE_LOGS=1` |

### Upstream Command Mapping

This template uses different command names from the upstream
[Agents-eval](https://github.com/qte77/Agents-eval) project:

| Upstream | Local | Notes |
|----------|-------|-------|
| `make ralph_userstory` | `make ralph_create_userstory_md` | Interactive UserStory creation |
| `make ralph_prd_md` | `make ralph_create_prd_md` | PRD.md generation |
| `make ralph_prd_json` | `make ralph_init_loop` | Combined: prd.json + env init |
| `make ralph_init` | `make ralph_init_loop` | Combined: prd.json + env init |
| `make ralph_worktree` | N/A | Use `make ralph_run` with `N_WT=` |
| `make ralph_run_worktree` | N/A | Use `make ralph_run` with `N_WT=` |

## Common Flags

| Flag | Values | Default | Description |
|------|--------|---------|-------------|
| `N_WT` | integer | `1` | Number of parallel worktrees |
| `ITERATIONS` | integer | `25` | Max loop iterations per worktree |
| `DEBUG` | `1` | (none) | Debug mode: auto-watch, persist worktrees |
| `WT` | integer | `1` | Worktree number for `ralph_get_log` |
| `RALPH_JUDGE_ENABLED` | `true`, `false` | `false` | Enable Claude-as-Judge for N_WT>1 |
| `RALPH_SECURITY_REVIEW` | `true`, `false` | `false` | Security review before merge |
| `RALPH_MERGE_INTERACTIVE` | `true`, `false` | `false` | Human approval before merge |
| `RALPH_JUDGE_MODEL` | `sonnet`, `opus`, `haiku` | `sonnet` | Model for judge evaluation |
| `RALPH_JUDGE_MAX_WT` | integer | `5` | Max worktrees for judge (falls back to metrics) |
| `NEW_PRD` | path | (required) | New PRD path for `ralph_reorganize_prd` |
| `VERSION` | integer | (none) | Version number for `ralph_reorganize_prd` |
| `ARCHIVE_LOGS` | `1` | (none) | Include logs in archive |

## Typical Workflows

### First run (from scratch)

```bash
make ralph_create_userstory_md       # Interactive Q&A -> UserStory.md
make ralph_create_prd_md             # UserStory.md -> PRD.md
make ralph_init_loop                 # PRD.md -> prd.json + validate env
make ralph_run ITERATIONS=25         # Start autonomous loop
```

### Quick start (PRD.md already exists)

```bash
make ralph_init_loop                 # Generate prd.json + validate
make ralph_run                       # Run with defaults
```

### Parallel execution with judge

```bash
RALPH_JUDGE_ENABLED=true make ralph_run N_WT=3 ITERATIONS=25
```

### Monitor and inspect

```bash
make ralph_watch                     # Live output (all worktrees)
make ralph_status                    # Story progress summary
make ralph_get_log WT=2              # Specific worktree log
```

### Resume paused run

```bash
# If existing worktrees found (not locked), auto-resumes:
make ralph_run                       # Detects and resumes paused worktrees
```

### Archive and iterate

```bash
make ralph_archive ARCHIVE_LOGS=1    # Archive current state + logs
make ralph_reorganize_prd NEW_PRD=docs/PRD-v2.md VERSION=2
make ralph_run                       # Start new sprint
```
