---
name: auditing-accessibility
description: Website accessibility audits following WCAG guidelines. Use when reviewing web interfaces for accessibility compliance.
---

# Accessibility Auditing

Conducts **comprehensive accessibility audits** following WCAG 2.1 guidelines.
Identifies barriers and provides actionable remediation steps.

## Workflow

1. **Define audit scope** - Pages, components, conformance level (A/AA/AAA)
2. **Automated scanning** - Use tooling for initial detection
3. **Manual testing** - Keyboard navigation, screen reader, zoom
4. **Document findings** - Issue, location, WCAG criterion, remediation
5. **Prioritize fixes** - Critical, High, Medium, Low

## WCAG Principles (POUR)

**Perceivable:**

- Text alternatives for images
- Captions for video/audio
- Sufficient color contrast
- Resizable text without loss

**Operable:**

- Keyboard accessible
- No timing traps
- Seizure-safe (no flashing)
- Navigable structure

**Understandable:**

- Readable content
- Predictable behavior
- Input assistance

**Robust:**

- Valid HTML
- Compatible with assistive tech

## Audit Checklist

### Level A (Minimum)

- [ ] All images have alt text
- [ ] Form inputs have labels
- [ ] No keyboard traps
- [ ] Page has title
- [ ] Link purpose is clear

### Level AA (Standard)

- [ ] Color contrast 4.5:1 (text), 3:1 (large text)
- [ ] Resize to 200% without horizontal scroll
- [ ] Focus indicator visible
- [ ] Error suggestions provided
- [ ] Consistent navigation

### Level AAA (Enhanced)

- [ ] Color contrast 7:1 (text)
- [ ] Sign language for video
- [ ] Extended audio description
- [ ] Reading level consideration

## Finding Format

```markdown
## Issue: [Brief Description]

**Severity:** Critical | High | Medium | Low
**WCAG Criterion:** [Number] - [Name] (Level A/AA/AAA)
**Location:** [Page/Component]

**Problem:**
[Description of the accessibility barrier]

**Impact:**
[Who is affected and how]

**Remediation:**
[Specific steps to fix]

**Code Example:**
[Before/After code if applicable]
```

## Quality Standards

- [ ] All POUR principles addressed
- [ ] Issues mapped to WCAG criteria
- [ ] Remediation is actionable
- [ ] Priority reflects user impact
