# Security Policy

This policy covers the `vulnlog/setup-vulnlog` action. For the Vulnlog CLI itself, see
the [CLI security policy](https://github.com/vulnlog/vulnlog/security/policy).

## Supported versions

Security fixes are released against the latest `v1.x` release. The floating `v1` tag is moved to it, so workflows pinned
to `@v1` pick the fix up on their next run. Older releases do not receive backported fixes.

## Reporting a vulnerability

Please report security issues privately. Do not open a public GitHub issue for a suspected vulnerability.

Use GitHub private vulnerability reporting: go to the
[Security advisories](https://github.com/vulnlog/setup-vulnlog/security/advisories/new) page of this repository and
click "Report a vulnerability". This keeps the report private until a fix is available.

Include as much detail as you can:

- The action version you used (`vulnlog/setup-vulnlog@v1.2.3` or the pinned commit SHA).
- The runner OS and architecture, for example `ubuntu-24.04-arm`.
- A description of the issue and its impact.
- Steps to reproduce, ideally a minimal workflow file.
- A link to a failing workflow run, if one is public.

If the issue is in the CLI rather than in this action, report it against
[vulnlog/vulnlog](https://github.com/vulnlog/vulnlog/security/advisories/new) instead.

## Scope

This action downloads a release asset from `github.com` and puts it on `PATH`. It needs no token and no `permissions`
block.

Downloads are not yet cryptographically verified, because Vulnlog releases publish neither `checksums.txt` nor build
attestations. This is a known gap, not a vulnerability report. It is tracked for the CLI release pipeline, and this
action will verify by default once the artifacts exist.

## Response

We aim to acknowledge a report within a few business days. We provide a triage outcome and a remediation timeline after
the initial assessment. We will coordinate disclosure with you. We credit your report unless you prefer to remain
anonymous.
