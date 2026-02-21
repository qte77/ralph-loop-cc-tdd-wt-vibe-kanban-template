---
name: auditing-website-usability
description: Structured usability audit for web interfaces. Use when evaluating UX friction, form design, navigation, and microcopy.
compatibility: Designed for Claude Code
metadata:
  allowed-tools: Read, Glob, Grep, WebFetch, WebSearch
---

# Usability Auditing

**Target**: $ARGUMENTS

Conducts **structured usability audits** focused on friction reduction,
form optimization, navigation clarity, and microcopy quality.
Not WCAG/accessibility — use `auditing-website-accessibility` for that.

## Evaluation Areas

### Forms

- Smart defaults reduce required input
- Field count minimized (ask only what's needed)
- Progressive disclosure for complex forms
- Inline validation with clear error states
- Auto-save or draft preservation

### Navigation

- Menu depth target: <3 levels
- Breadcrumbs for deep hierarchies
- Mobile-friendly tap targets (minimum 44x44px)
- Search discoverable and functional
- Current location always clear

### Validation and Microcopy

- Error messages explain what went wrong AND how to fix
- Labels describe the expected input format
- Success states confirm completed actions
- Empty states guide next actions
- Help text appears before errors, not after

## Workflow

1. **Define scope** - Pages, user flows, devices to test
2. **Map user journeys** - Identify critical paths (signup, purchase, etc.)
3. **Friction mapping** - Walk each path, note every hesitation point
4. **Form inspection** - Field count, defaults, validation, error handling
5. **Navigation inspection** - Menu depth, wayfinding, mobile behavior
6. **Microcopy evaluation** - Labels, errors, help text, empty states
7. **Classify findings** - Critical blockers vs optimization opportunities
8. **Generate fixes** - Specific CSS selectors, HTML changes, copy rewrites

## Output Format

### Critical Blockers (Users Cannot Complete Task)

```markdown
## Blocker: [Brief Description]

**User Flow**: [Which journey is blocked]
**Element**: `<CSS selector or component>`
**Friction**: [What happens and why it stops users]

**Fix:**
[Specific change with code if applicable]
```

### Optimization Opportunities (Users Can Complete But Struggle)

```markdown
## Optimization: [Brief Description]

**User Flow**: [Which journey is affected]
**Element**: `<CSS selector or component>`
**Friction**: [What causes hesitation or confusion]

**Fix:**
[Specific change with code if applicable]
```

## Quality Standards

- [ ] Every finding includes a specific fix (no generic advice)
- [ ] Findings mapped to specific CSS selectors or components
- [ ] Critical blockers separated from optimizations
- [ ] Fixes are implementable (HTML/CSS/copy changes, not vague suggestions)
