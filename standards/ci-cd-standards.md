# CI/CD Standards

## Goals

Pipelines should provide fast, reliable confidence that code can be safely built, tested, and deployed.

---

## Minimum pipeline stages

1. Install dependencies
2. Lint
3. Type check
4. Unit tests
5. Integration tests where practical
6. Build
7. Security/dependency scan where practical
8. Deploy to target environment
9. Post-deploy smoke test

---

## Pull request pipeline

Must run:

- Lint
- Type check
- Unit tests
- Build

Should run:

- Integration tests
- API contract tests
- E2E smoke tests for critical paths

---

## Local-first verification (do not use CI as a debug loop)

Get the full local gate — lint, type check, tests, build — green BEFORE you push. CI is a confirmation gate, not a debugging tool.

The anti-pattern to avoid: change, push, wait minutes for CI to fail, repeat. If a local fix-cycle is under a minute and a CI fix-cycle is several minutes, you are using the wrong loop. Reserve CI for what only CI can catch — clean-environment reproducibility, cross-platform behavior, integration against shared services — not for errors a local run surfaces in seconds.

Every project's local command set must reproduce the PR pipeline's required checks, so a green local run predicts a green CI run.

---

## Deployment pipeline

Recommended environments:

1. Dev
2. Staging
3. Production

Production deployment should require:

- Passing build
- Passing tests
- Approved release checklist
- Environment variables configured
- Rollback plan known

---

## Secrets in CI/CD

- Store secrets in platform secret store.
- Never echo secrets in logs.
- Use environment-specific secrets.
- Prefer OIDC/managed identity where possible.
- Rotate secrets when people leave or credentials are exposed.

---

## Security guardrails (enforce, do not just document)

Security tooling must actually run, not merely exist as a file. A project's CI must:

- Configure automated dependency updates (Dependabot or Renovate).
- Run at least one real scanner on pull requests — SAST, secret, dependency, or IaC — such as CodeQL, Semgrep, gitleaks, Trivy, OSV-Scanner, or `dependency-review-action`.

`templates/ci-security.yml` is a drop-in guardrail workflow that fails the build unless both hold. It greps the workflow contents to confirm a scanner is genuinely invoked rather than trusting a filename. Copy it into a project's `.github/workflows/` directory.

---

## Deployment validation

After deployment:

- Check app health.
- Run smoke tests.
- Check logs.
- Confirm external integrations.
- Notify stakeholders.

---

## Rollback

Every release should document:

- Previous known-good version
- How to redeploy it
- Data migration rollback limitations
- Who can approve rollback
