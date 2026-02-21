---
name: testing-python
description: BDD/TDD testing with pytest and Hypothesis for property-based testing. Use when writing tests, creating test suites, or when the user asks to add test coverage.
---

# Python Testing

Creates **focused, comprehensive** test suites using pytest and Hypothesis
following BDD/TDD methodology. Match test complexity to implementation scope.

## Testing Standards

See `docs/python-best-practices.md` for comprehensive Python guidelines.

## Workflow

1. **Understand requirements** from task specifications
2. **Identify test scope** - Unit (isolated) vs Integration (system)
3. **Apply TDD cycle** - Red (failing test) → Green (minimal impl) → Refactor
4. **Write property-based tests** with Hypothesis for edge cases
5. **Run `make test_quick`** for fast feedback during development
6. **Run `make test_coverage`** to verify coverage thresholds

## Testing Strategy

**Unit Tests**: Single function/method, mocked dependencies, fast execution

**Integration Tests**: Multiple components, real dependencies where safe,
realistic scenarios

**Property-Based Tests**: Use Hypothesis for discovering edge cases through
generated inputs

## Test Structure

```python
# BDD-style test naming
def test_should_return_empty_list_when_no_items_exist():
    """Given no items, when listing, then return empty list."""
    ...

# Property-based testing
@given(st.lists(st.integers()))
def test_sorting_preserves_length(items):
    """Any list, when sorted, has same length as original."""
    assert len(sorted(items)) == len(items)
```

## Quality Checks

**During development:**

```bash
make test_quick  # Rerun only failed tests
```

**Before completing:**

```bash
make test_coverage  # Full coverage check with threshold
```

## Output Standards

**Simple Tasks**: Focused unit tests covering happy path and key edge cases
**Complex Tasks**: Comprehensive suite with unit, integration, and property tests
**All tests**: Clear assertions, descriptive names, isolated fixtures
