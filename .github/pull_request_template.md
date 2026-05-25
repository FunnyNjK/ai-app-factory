# Pull Request

## Summary

Describe what changed and why.

## Scope

- In scope:
- Out of scope:

## Standards Alignment

- [ ] Follows architecture and role boundaries
- [ ] Follows coding, API, security, and testing standards
- [ ] No architecture deviations without explicit note

## Validation

- [ ] Lint passed
- [ ] Type check passed (if applicable)
- [ ] Unit tests passed (if applicable)
- [ ] Integration/API tests passed (if applicable)
- [ ] Build passed (if applicable)

Commands run:

```text
PASTE_COMMANDS_AND_RESULTS
```

## Security Review

- [ ] No secrets committed
- [ ] Inputs validated at trust boundaries
- [ ] Error responses are safe
- [ ] Webhook signature/idempotency handled (if applicable)
- [ ] CORS/auth/authz reviewed (if applicable)

## Quality and Release Readiness

- [ ] Acceptance criteria satisfied
- [ ] Critical user journeys tested
- [ ] Accessibility smoke checks completed (if UI changes)
- [ ] Release checklist updated/reviewed
- [ ] Runbook/README updated

## Risk and Rollback

Known risks:

- None / list risks

Rollback plan:

- Describe how to revert safely

## Follow-up Tasks

- None / list follow-ups

## Four-party sign-off (Gate D — release candidates only)

Required only for PRs that mark a release candidate. Skip for incremental work.

- [ ] **Architect (Claude)** — implementation matches approved architecture; deviations are documented as ADRs.
- [ ] **Developer (Cursor)** — acceptance criteria met; tests pass; no hard-coded secrets; README and RUNBOOK current.
- [ ] **Quality Engineer (Codex)** — test plan executed; critical journeys pass; security and accessibility smoke checks pass; release readiness is Ready or Ready with documented risks.
- [ ] **Product owner / technical owner** — business intent satisfied; risks accepted; release authorized.

See `docs/adr/0006-three-agent-signoff.md`.
