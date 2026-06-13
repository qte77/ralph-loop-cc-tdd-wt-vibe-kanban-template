---
title: Ralph Judge
description: Claude-as-Judge evaluation prompt for parallel worktree selection
---

# Worktree Comparison Task

Compare the worktrees below and select the BEST one based on code quality.

## Evaluation Criteria (Priority Order)

1. **Correctness** - All tests pass, meets acceptance criteria
2. **Test Quality** - Comprehensive coverage, meaningful edge cases
3. **Code Clarity** - Readable, maintainable, follows best practices

## Instructions

**Context:** Each worktree completed a finite number of iterations. Some stories may be incomplete or have validation failures. Your task is to identify which worktree produced the BEST overall code quality.

**Evaluation approach:**

1. Review actual implementation code provided for each worktree
2. Examine test files to assess test quality and coverage
3. Consider quantitative metrics (stories completed, coverage, errors) as important signals
4. Balance: more completed stories vs. better code quality per story

**Look for:**

- Clear abstractions and separation of concerns
- Meaningful naming (functions, variables, classes)
- Comprehensive test coverage with edge cases
- Maintainable, readable code structure
- Successful validation (low error/violation counts)

**Red flags:**

- Poor code organization or excessive complexity
- Missing tests for new functionality
- High error/violation counts
- Low test coverage despite completed stories

## Required Output Format

Output ONLY valid JSON (no markdown, no explanation):

```json
{
  "winner": <worktree_number>,
  "reason": "<one concise sentence explaining why>"
}
```

## Worktrees to Compare

(Data appended by judge.sh below)
