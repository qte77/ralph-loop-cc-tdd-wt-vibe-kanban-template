---
name: compacting-context
description: Context compression for verbose outputs. Use when conversation context exceeds 70% capacity or when summarizing large outputs.
---

# Context Compaction

Compresses **verbose outputs** into concise summaries while preserving
essential information. Use proactively to maintain context efficiency.

## Trigger Conditions

- Context utilization exceeds 70%
- Output exceeds 500 lines
- Repeating information from earlier in conversation
- Full file contents included when excerpts suffice

## Workflow

1. **Identify verbose content** - Large outputs, repeated info, full files
2. **Extract essential information** - Key facts, decisions, action items
3. **Apply compression strategy** - Summarize, reference, abbreviate
4. **Verify completeness** - Ensure no critical information lost
5. **Output compact summary** - Concise format with references

## Compression Strategies

**Reference Instead of Repeat:**

```
# Before
The function in src/auth.py handles authentication by...
[50 lines of explanation]

# After
See `src/auth.py:42-85` for auth implementation details.
```

**Summarize Lists:**

```
# Before
Test 1 passed, Test 2 passed, Test 3 passed... [15 more]

# After
All 18 tests pass. Coverage: 87%.
```

**Table Format:**

```
| File | Status | Lines Changed |
|------|--------|---------------|
| auth.py | Modified | +15, -3 |
| tests/test_auth.py | Added | +45 |
```

## Output Format

**Status Updates:** Single line with metrics
**Code Changes:** File:line references, not full content
**Test Results:** Summary counts, only show failures in detail
**Errors:** Line reference + brief description

## Quality Standards

- [ ] No critical information lost
- [ ] References are accurate (file:line)
- [ ] Summary is actionable
- [ ] Format is consistent
