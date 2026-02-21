---
title: Contribution Guidelines
version: 2.0
applies-to: Agents and humans
purpose: Developer setup, workflow, and contribution guidelines
---

Contributions welcome! Follow these guidelines for both human and agent
contributors.

## Quick Start

```bash
# Clone and setup
git clone <repository-url>
cd <project-name>
make setup_dev

# Run validation
make validate
```

## Core Principles

- **KISS** (Keep It Simple, Stupid) - Simplest solution that works
- **DRY** (Don't Repeat Yourself) - Single source of truth
- **YAGNI** (You Aren't Gonna Need It) - Implement only what's requested
- **User Experience, Joy, and Success** - Optimize for user value

See `.claude/rules/core-principles.md` for complete guidelines.

## Development Workflow

### 1. Setup Environment

```bash
make setup_dev  # Install dependencies and configure tools
```

### 2. Make Changes

Follow TDD: Write tests before implementing features.

### 3. Validate

```bash
make ruff           # Format and lint
make type_check     # Type checking
make test_all       # Run tests
make test_quick     # Rerun only failed tests (faster iteration)
make validate       # Run all checks (required before committing)
make validate_quick # Quick validation without coverage (faster iteration)
```

### 4. Commit

All changes must pass `make validate` before committing.

## Testing Requirements

### Unit Tests

- Location: `tests/unit/`
- Coverage threshold: 70% (configured in pyproject.toml)
- Run: `make test_quick` (failed only) or `make test_all`

### Integration Tests

- Location: `tests/integration/`
- Run with: `make test_all`

### E2E Tests

- Location: `tests/e2e/`
- Run with: `make test_e2e`

### Security Testing

- Static analysis via ruff security rules
- Type checking via pyright
- Run: `make validate`

## Code Standards

### Python Style

- **Imports**: Use absolute imports (`from src.module import X`)
- **Models**: Use Pydantic for data validation
- **Types**: Full type hints on public functions
- **Docstrings**: Google-style for public functions

### Example

```python
from pydantic import BaseModel

class UserRequest(BaseModel):
    """Request model for user operations."""

    name: str
    email: str


def create_user(request: UserRequest) -> dict[str, str]:
    """Create a new user.

    Args:
        request: Validated user data.

    Returns:
        Dictionary with user ID and status.

    Raises:
        ValueError: If user already exists.
    """
    return {"id": "123", "status": "created"}
```

## Commit Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

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
