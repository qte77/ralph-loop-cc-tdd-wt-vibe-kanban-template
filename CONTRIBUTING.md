---
title: Contribution Guidelines
version: 3.0
applies-to: Agents and humans
purpose: Developer setup, workflow, and contribution guidelines
---

# Contributing

Contributions welcome! Follow these guidelines for both human and agent
contributors.

## Quick Start

```bash
# Clone and setup
git clone <repository-url>
cd <project-name>
make setup_scaffold LANG=python  # or: embedded
make setup_dev

# Run validation
make validate
```bash

## Core Principles

- **KISS** (Keep It Simple, Stupid) - Simplest solution that works
- **DRY** (Don't Repeat Yourself) - Single source of truth
- **YAGNI** (You Aren't Gonna Need It) - Implement only what's requested
- **User Experience, Joy, and Success** - Optimize for user value

See `.claude/rules/core-principles.md` for complete guidelines.

## Scaffold System

This template is language-agnostic. All language-specific tooling, rules, and
CI workflows are provided by **scaffold plugins**.

### Available Scaffolds

| Scaffold | Plugin | Provides |
|----------|--------|----------|
| `python` | `python-dev` | uv, ruff, pyright, pytest, complexipy |
| `embedded` | `embedded-dev` | gcc, cppcheck, clang-tidy, cmake |

### How It Works

1. `make setup_scaffold LANG=<name>` writes the selection to `.scaffold`
2. `Makefile.<lang>` is auto-included (provides `validate`, `test_all`, etc.)
3. Plugin hook deploys adapter to `.scaffolds/<name>.sh` (used by Ralph scripts)
4. Plugin hook deploys `.claude/settings.local.json` (tool permissions)

Language-specific coding standards, testing rules, and best practices are
provided by your scaffold plugin's skills and rules.

## Development Workflow

### 1. Setup Environment

```bash
make setup_scaffold LANG=python  # Select scaffold
make setup_dev                   # Install toolchain + dev tools
```

### 2. Make Changes

Follow TDD: Write tests before implementing features.

### 3. Validate

```bash
make validate       # Run all checks (required before committing)
make validate_quick # Quick validation (faster iteration)
make test_all       # Run tests only
```bash

### 4. Commit

All changes must pass `make validate` before committing.

## Testing Requirements

### Unit Tests

- Location: `tests/` (mirroring `src/` structure)
- Run: `make test_all`

### Security Testing

- Static analysis via scaffold linter
- Type checking via scaffold type checker
- Run: `make validate`

## Commit Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```bash

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting (no code change)
- `refactor`: Code change (no feature/fix)
- `test`: Adding/updating tests
- `chore`: Maintenance tasks

## Ralph Loop Commands

For Ralph-specific command reference (autonomous development loop),
see [`ralph/CONTRIBUTING.md`](ralph/CONTRIBUTING.md).

## Pre-Commit Checklist

Before submitting PR:

- [ ] `make validate` passes
- [ ] Tests cover new functionality
- [ ] Documentation updated if needed
- [ ] Commit messages follow convention
- [ ] No secrets in code
- [ ] No debug code left behind
