# Context Management

**MANDATORY for efficient token utilization.** Apply these principles to maintain
optimal context capacity throughout conversations.

## ACE-FCA Principle

**Accuracy > Completeness > Brevity**

When generating output, prioritize:

1. **Accuracy** - Correct information is non-negotiable
2. **Completeness** - Include all necessary details for the task
3. **Brevity** - Eliminate redundancy and unnecessary verbosity

## Capacity Guidelines

- **Target utilization**: Maintain 40-60% context capacity
- **Warning threshold**: Above 70% triggers compaction consideration
- **Critical threshold**: Above 85% requires immediate compaction

## Compaction Triggers

Apply context compression when:

- [ ] Output exceeds 500 lines for simple tasks
- [ ] Repeating information already in conversation
- [ ] Including full file contents when excerpts suffice
- [ ] Verbose explanations for straightforward operations

## Compaction Strategies

1. **Reference existing context** - "As shown above" instead of repeating
2. **Use file:line references** - `src/module.py:42` instead of quoting code
3. **Summarize rather than enumerate** - "All 15 tests pass" vs listing each
4. **Delegate to skills** - Use `/compacting-context` for verbose outputs

## Delegation to Skills

When context is constrained, delegate to specialized skills:

- `/researching-codebase` - For deep exploration without polluting main context
- `/compacting-context` - For summarizing verbose outputs
- `/reviewing-code` - For detailed analysis in isolated context

## Output Format Guidelines

**Prefer concise formats:**

```
- Single-line summaries for status updates
- Bullet points over paragraphs
- Tables for structured comparisons
- Code snippets with context, not full files
```

**Avoid:**

- Multi-paragraph explanations for simple changes
- Repeating user instructions back verbatim
- Including unchanged code in edit descriptions
- Verbose error messages when line references suffice
