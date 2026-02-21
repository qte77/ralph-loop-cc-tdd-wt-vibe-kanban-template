# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.x.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please
report it responsibly.

### How to Report

1. **Do NOT** open a public issue
2. Use [GitHub Security Advisories](../../security/advisories) to report privately,
   or email security concerns to the project maintainers
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 7 days
- **Resolution Timeline**: Depends on severity
  - Critical: 24-48 hours
  - High: 7 days
  - Medium: 30 days
  - Low: Next release

### Disclosure Policy

- We follow a **90-day disclosure timeline**
- If a fix is not available within 90 days of the initial report, the reporter
  may disclose the vulnerability publicly
- Credit will be given to reporters (unless anonymity requested)
- Public disclosure after fix is released

## Security Best Practices

When contributing:

- Never commit secrets, API keys, or credentials
- Use environment variables for sensitive configuration
- Validate all external inputs
- Follow OWASP guidelines for web components
- Run `make validate` to catch security issues

## Security Features

This project includes:

- Static analysis via ruff security rules
- Type checking via pyright
- Dependency scanning (when configured)
- CodeQL analysis in CI/CD

## Contact

For security concerns, contact the project maintainers through appropriate
channels.
