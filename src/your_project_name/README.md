# Application

## What

Fix 8 confirmed bugs from quality-audit-2026-03.md using BATS test-driven development. Critical security fixes first (eval injection, exit 0 masking), then teams.sh correctness, then medium/low improvements. Each story requires a BATS test written first (RED), then the minimal fix (GREEN), then optional refactor.

## Why

- Set up BATS test framework for Ralph script testing. Create test directory structure, shared test helpers (setup/teardown with tmp dirs, mock claude binary, mock prd.json fixtures), and a Makefile recipe. This is the foundation all other stories depend on.

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
└── __init__.py
tests/  [error opening dir]
src/your_project_name/ and tests/
```

## Development

Built with Ralph Loop autonomous development using TDD.
