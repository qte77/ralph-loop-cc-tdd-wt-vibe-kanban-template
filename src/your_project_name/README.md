# Application

## What



## Why

- Set up BATS test framework for Ralph script testing. Create test directory structure, shared test helpers (setup/teardown with tmp dirs, mock claude binary, mock prd.json fixtures), and a Makefile recipe. This is the foundation all other stories depend on.
- CRITICAL SECURITY. ralph.sh:330 and ralph.sh:445 use `eval` to expand `$extra_flags` in `claude -p` invocations. If any RALPH_* env var contains shell metacharacters (e.g., RALPH_INSTRUCTION='; rm -rf /'), arbitrary commands execute. Replace `eval` with safe array expansion.
- HIGH. parallel_ralph.sh:264 hardcodes `WORKTREE_EXIT_CODES[$i]=0` for all completed disowned processes because exit codes cannot be retrieved from disowned PIDs. This means parallel runs always report success even when workers fail. Fix by using a sentinel file written by the worker subshell.
- HIGH. ralph.sh:226 and teams.sh:195 both define `verify_teammate_stories()` with completely different semantics. ralph.sh version checks that only the current story was modified in prd.json (isolation check). teams.sh version verifies TDD commits and scoped quality for teammate stories. Whichever is sourced last silently wins. Rename the ralph.sh version.

## Quick Start

```bash
# Run validation
make validate

# Run tests
make test_all
```

## Architecture

```text
src/your_project_name
├── __init__.py
└── README.md
tests/  [error opening dir]
src/your_project_name/ and tests/
```

## Development

Built with Ralph Loop autonomous development using TDD.
