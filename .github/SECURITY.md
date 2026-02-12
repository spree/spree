# Security Policy

## Supported Versions

The following versions are actively maintained and receive security patches.

| Version | Release date | End of life |
| ------- | ------------ | ----------- |
| 5.0     | 26.03.2025   | 26.03.2028  |
| 4.10    | 06.09.2024   | 06.09.2027  |

Versions that are not listed above will not receive any security patches or fixes.

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues, discussions, or pull requests.**

Instead, please send an email to [security@spreecommerce.org](mailto:security@spreecommerce.org).

Please include as much of the following information as possible to help us triage your report:

- Type of vulnerability (e.g. SQL injection, XSS, CSRF, etc.)
- Affected version(s)
- Step-by-step instructions to reproduce the issue
- Proof of concept or exploit code (if available)
- Impact assessment of the vulnerability

### Submitting a Patch

If you would like to provide a patch yourself for the security issue **do not open a pull request for it**. Instead, create a commit on your fork of Spree and run this command:

```bash
git format-patch HEAD~1..HEAD --stdout > patch.txt
```

Email a description of the patch along with the `patch.txt` file to [security@spreecommerce.org](mailto:security@spreecommerce.org).

### Disclosure Process

1. Security report is received and acknowledged within **48 hours**.
2. The issue is confirmed and a severity level is assigned.
3. A fix is developed and tested against all supported versions.
4. A new release is published with the fix and a [GitHub Security Advisory](https://github.com/spree/spree/security/advisories) is created.
5. Reporter is credited in the advisory (unless anonymity is requested).

## Security Advisories

Published security advisories can be found at [GitHub Security Advisories](https://github.com/spree/spree/security/advisories).

## More Information

For detailed security documentation including best practices and enterprise security features, see the [Spree Security Documentation](https://spreecommerce.org/docs/developer/security/security_policy).
