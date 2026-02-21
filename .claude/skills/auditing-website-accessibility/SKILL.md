---
name: auditing-website-accessibility
description: Systematic WCAG 2.1 AA compliance audit. Use when reviewing web interfaces for accessibility compliance.
compatibility: Designed for Claude Code
metadata:
  allowed-tools: Read, Glob, Grep, WebFetch, WebSearch
---

# Accessibility Auditing (WCAG 2.1 AA)

**Target**: $ARGUMENTS

Conducts **systematic accessibility audits** following WCAG 2.1 guidelines.
Identifies barriers and provides actionable remediation with specific code fixes.

## Evaluation Areas

### Keyboard Navigation

- Tab ordering follows logical reading order
- Focus indicators visible (minimum 2px outline)
- All interactive elements reachable via keyboard
- No keyboard traps
- Custom keyboard shortcuts documented

### Screen Reader Compatibility

- Semantic HTML structure (headings, landmarks, lists)
- ARIA roles, states, and properties correct
- Alt text meaningful (not decorative descriptions)
- Live regions for dynamic content
- Form error announcements

### Visual Accessibility

- Color contrast minimum 4.5:1 (text), 3:1 (large text/UI)
- No information conveyed by color alone
- Zoom to 200% without horizontal scroll
- Reflow at 320px viewport width
- Animation respects `prefers-reduced-motion`

### Forms and Data Tables

- Every input has associated `<label>`
- Required fields indicated (not just by color)
- Error messages linked to fields via `aria-describedby`
- Tables use `<th>`, `scope`, and `<caption>`

## Workflow

1. **Define scope** - Pages, components, conformance level (A/AA)
2. **Automated checks** - axe-core, Lighthouse, WAVE results
3. **Keyboard-only navigation** - Tab through all interactive elements
4. **Screen reader testing** - Verify announcements and flow
5. **Classify by WCAG** - Map each finding to success criterion
6. **Generate fixes** - Specific code changes per finding

## Output Format

### Findings by Compliance Tier

**Critical (Level A)** - Must fix for basic accessibility:

```markdown
## Finding: [Brief Description]

**WCAG**: [Criterion Number] - [Name] (Level A)
**Impact**: [Users affected and how]
**Element**: `<selector>` or component name

**Problem:**
[Current HTML/CSS causing the barrier]

**Fix:**
[Corrected HTML/CSS with explanation]
```

**Standard (Level AA)** - Required for compliance:

Same format, grouped after Level A findings.

### Implementation Checklist

- [ ] All Level A findings addressed
- [ ] All Level AA findings addressed
- [ ] Keyboard navigation verified
- [ ] Screen reader flow verified
- [ ] Color contrast verified
- [ ] Zoom/reflow verified

## Quality Standards

- [ ] Every finding maps to a WCAG success criterion
- [ ] Every finding includes a specific code fix
- [ ] Findings organized: Critical Level A first, then Level AA
- [ ] No generic advice - all recommendations tied to specific elements
