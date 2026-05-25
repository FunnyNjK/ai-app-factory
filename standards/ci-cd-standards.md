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
