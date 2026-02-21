---
name: designing-mas-plugins
description: Designing agent plugins or evaluation components. Use when building stateless evaluator plugins for multi-agent systems.
compatibility: Designed for Claude Code
metadata:
  allowed-tools: Read, Write, Edit, Glob, Grep
---

# Designing MAS Plugins

**Target**: $ARGUMENTS

## Core Principles

### Stateless Reducer Pattern

Each plugin is a pure function: `evaluate(context: BaseModel) -> BaseModel`

### Own Context Window

Plugin manages its own context — no global state access.

### Structured Outputs

All data uses validated models — no raw dicts.

### Own Control Flow

Plugin handles its own errors and timeouts.

### Compact Errors

Errors produce structured partial results, not exceptions.

### Single Responsibility

One metric or tier per plugin.

## Plugin Design Checklist

- [ ] Stateless: No class attributes, no global state
- [ ] Own Context: All inputs via evaluate() parameter
- [ ] Typed I/O: Validated models for inputs and outputs
- [ ] Own Errors: Returns error results, doesn't raise
- [ ] Own Timeout: Respects configured timeout
- [ ] Single Responsibility: One metric or tier
- [ ] Explicit Context: Filters output for next stage
- [ ] Env Config: All config via env vars / settings
- [ ] Observable: Emits structured logs for debugging
- [ ] Graceful Degradation: Partial results on failures

## Anti-Patterns

- **Shared State**: `self.cache = {}` (breaks stateless)
- **Raw Dicts**: `return {"score": 0.5}` (use models)
- **Raising Exceptions**: `raise ValueError()` (return error)
- **Global Access**: `config.get_global()` (use settings)
- **Implicit Context**: Passing entire result to next tier
- **Multiple Responsibilities**: One plugin, 3 metrics

## Implementation Template

```python
from abc import ABC, abstractmethod
from pydantic import BaseModel


class PluginContext(BaseModel):
    """Input context for the plugin."""
    pass


class PluginResult(BaseModel):
    """Output result from the plugin."""
    score: float = 0.0
    error: str | None = None
    partial: bool = False


class EvaluatorPlugin(ABC):
    """Base class for stateless evaluator plugins."""

    @abstractmethod
    def evaluate(self, context: PluginContext) -> PluginResult:
        """Pure function: context in, result out."""
        ...
```

## Testing Strategy

- Isolation tests with mocked context
- Happy path: valid input → expected output
- Error handling: invalid input → structured error result
- Timeout: long-running → partial result within deadline
