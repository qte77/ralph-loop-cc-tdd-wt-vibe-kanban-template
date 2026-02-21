---
name: securing-mas
description: Multi-Agent System (MAS) security patterns. Use when designing or reviewing security for agent-based architectures.
---

# MAS Security

Applies **security patterns** for Multi-Agent Systems (MAS). Addresses unique
threats in distributed agent architectures.

## Security Principles

**Defense in Depth:** Multiple security layers
**Least Privilege:** Minimal permissions per agent
**Zero Trust:** Verify all agent communications
**Fail Secure:** Safe defaults on failure

## Threat Model

### Agent-Specific Threats

1. **Prompt Injection** - Malicious inputs manipulating agent behavior
2. **Agent Impersonation** - Unauthorized agents claiming identity
3. **Data Exfiltration** - Agents leaking sensitive context
4. **Privilege Escalation** - Agents exceeding authorized capabilities
5. **Denial of Service** - Resource exhaustion attacks

### Communication Threats

1. **Message Tampering** - Altering inter-agent messages
2. **Replay Attacks** - Reusing valid messages maliciously
3. **Man-in-the-Middle** - Intercepting agent communications

## Security Controls

### Input Validation

```python
# Sanitize all agent inputs
def validate_agent_input(input: str) -> str:
    # Remove control characters
    # Escape special sequences
    # Validate against schema
    return sanitized_input
```

### Permission Boundaries

```python
# Define explicit capabilities per agent
AGENT_PERMISSIONS = {
    "reader": ["read_file", "list_directory"],
    "writer": ["read_file", "write_file"],
    "executor": ["read_file", "execute_command"],
}
```

### Audit Logging

```python
# Log all agent actions
def log_agent_action(agent_id: str, action: str, target: str):
    logger.info(f"AUDIT: {agent_id} performed {action} on {target}")
```

## Security Checklist

### Design Phase

- [ ] Threat model documented
- [ ] Agent capabilities defined
- [ ] Communication protocol secured
- [ ] Authentication mechanism chosen

### Implementation Phase

- [ ] Input validation on all boundaries
- [ ] Permission checks before actions
- [ ] Secrets not in agent context
- [ ] Audit logging enabled

### Review Phase

- [ ] Penetration testing completed
- [ ] Privilege escalation tested
- [ ] Injection attacks tested
- [ ] Error handling reviewed

## Output Standards

**Security Review:** Issue, severity, remediation, verification steps
**Design Document:** Threat model, controls, residual risks
**Audit Report:** Findings, evidence, recommendations
