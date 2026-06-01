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

## Six-party sign-off (Gate D — release candidates only)

Required only for PRs that mark a release candidate. Skip for incremental work. Each agent role is driven by the tool the project mapped to it in `.factory-roles.json`.

- [ ] **Architect** — implementation matches approved architecture; deviations are documented as ADRs.
- [ ] **Developer** — acceptance criteria met; tests pass; no hard-coded secrets; README and RUNBOOK current.
- [ ] **Quality Engineer** — test plan executed; critical journeys pass; security and accessibility smoke checks pass; release readiness is Ready or Ready with documented risks.
- [ ] **Security** — per-phase security gates passed; no secrets in the tree; input validation, authorization, and webhook verification hold; decision is Pass or Pass with documented risks.
- [ ] **Code Review** — per-phase code-review gates passed; codebase meets the coding standards; accepted maintainability debt is tracked.
- [ ] **Product owner / technical owner** — business intent satisfied; risks accepted; release authorized.

See `docs/adr/0013-configurable-roles-and-tools.md`.
