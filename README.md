# Ralph-Loop Template

> What a time to be alive

Ship a TDD + Ralph-loop + Vibe-Kanban agent harness without writing boilerplate.

**Write-up:** the autonomous loop at the center of an open agentic coding harness — [An Open Agentic Coding Harness](https://qte77.github.io/open-agentic-coding-harness/).

![Version](https://img.shields.io/badge/version-0.0.0-58f4c2.svg)
[![License](https://img.shields.io/badge/license-Apache--2.0-58f4c2.svg)](LICENSE)
[![CodeQL](https://github.com/qte77/ralph-loop-cc-tdd-wt-vibe-kanban-template/actions/workflows/codeql.yaml/badge.svg)](https://github.com/qte77/ralph-loop-cc-tdd-wt-vibe-kanban-template/actions/workflows/codeql.yaml)
[![CodeFactor](https://www.codefactor.io/repository/github/qte77/ralph-loop-cc-tdd-wt-vibe-kanban-template/badge)](https://www.codefactor.io/repository/github/qte77/ralph-loop-cc-tdd-wt-vibe-kanban-template)

## What

- **Ralph Loop** - Autonomous agent development via a shell loop; write requirements, let Ralph implement
- **Claude Code** - Pre-configured skills, rules, plugins, and model routing for AI-assisted development
- **Language-agnostic scaffold** - Python, embedded C, and TypeScript toolchains installed on demand
- **GitHub Actions CI/CD** - CodeQL, ruff, pyright, pytest, link checking, and docs deployment wired up
- **MkDocs** - Auto-generated documentation with GitHub Pages deployment
- **DevContainers** - Template (Alpine ~10MB) and project (Python/Node/Docker ~1GB+) variants
- **Vibe Kanban** - Real-time visual monitoring for Ralph task progress

## How

```bash
# 1. Choose your language scaffold (written to .scaffold, gitignored)
make setup_scaffold LANG=python

# 2. Install toolchain (also runs automatically in devcontainer)
make setup_toolchain

# 3. Write requirements in docs/PRD.md, then run Ralph
make ralph_init_loop             # Initialize (creates prd.json)
make ralph_run [ITERATIONS=25]   # Run autonomous development
```

For DevContainer sizes, Makefile details, submodule consumption, advanced Ralph
options, and Vibe Kanban setup, see
[docs/TEMPLATE_USAGE.md](docs/TEMPLATE_USAGE.md).

## Why

Hand-rolling an agent-loop setup per project wastes hours on boilerplate. The
incumbent approach requires assembling TDD harnesses, agent config, CI pipelines,
and kanban tooling from scratch for every new project. This template ships the
complete Ralph-loop + TDD + Vibe-Kanban stack ready to go: clone, write a PRD,
run Ralph.

## References

- [Ralph README](./ralph/README.md)
- [docs/TEMPLATE_USAGE.md](docs/TEMPLATE_USAGE.md)
- [qte77/claude-code-plugins](https://github.com/qte77/claude-code-plugins)
- [An Open Agentic Coding Harness](https://qte77.github.io/open-agentic-coding-harness/)
- [CONTRIBUTING.md](CONTRIBUTING.md)

## License

Apache-2.0 - see [LICENSE](LICENSE).
