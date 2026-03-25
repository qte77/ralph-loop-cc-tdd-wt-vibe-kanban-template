# Application

## What



## Why

- Set up BATS test framework for Ralph script testing. Create test directory structure, shared test helpers (setup/teardown with tmp dirs, mock claude binary, mock prd.json fixtures), and a Makefile recipe. This is the foundation all other stories depend on.
- CRITICAL SECURITY. ralph.sh:330 and ralph.sh:445 use `eval` to expand `$extra_flags` in `claude -p` invocations. If any RALPH_* env var contains shell metacharacters (e.g., RALPH_INSTRUCTION='; rm -rf /'), arbitrary commands execute. Replace `eval` with safe array expansion.

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
