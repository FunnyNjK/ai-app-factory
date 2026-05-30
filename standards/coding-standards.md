# Coding Standards

## Goals

Code should be:

- Readable
- Maintainable
- Testable
- Secure
- Consistent
- Boring in the best way

---

## General principles

- Prefer clarity over cleverness.
- Keep functions small and focused.
- Name things for what they mean.
- Avoid hidden side effects.
- Validate inputs at trust boundaries.
- Handle errors intentionally.
- Avoid unnecessary dependencies.
- Document non-obvious decisions.
- Do not commit secrets.

---

## Project structure

Prefer clear separation:

```text
src/
  app/ or pages/
  components/
  features/
  services/
  lib/
  api/
  types/
  config/
tests/
docs/
```

For serverless projects:

```text
api/
  functions/
  shared/
src/
tests/
```

---

## Type safety

- Use TypeScript or strong typing when practical.
- Avoid `any` unless justified.
- Define request and response types.
- Define integration boundary types.
- Validate runtime inputs even when compile-time types exist.

---

## Error handling

- Return safe user-facing messages.
- Log operational details without exposing secrets.
- Do not swallow errors silently.
- Use provider-specific error mapping at integration boundaries.
- Keep error response format consistent.

---

## Configuration

- Use environment variables for configuration.
- Provide `.env.example`.
- Never commit real secret values.
- Keep frontend-exposed variables separate from backend-only secrets.
- Use Key Vault or equivalent for production secrets when appropriate.

---

## Dependencies

Before adding a dependency, ask:

1. Is it necessary?
2. Is it maintained?
3. Does it increase bundle or cold start size significantly?
4. Does it introduce security risk?
5. Can the standard library or platform solve this?

---

## Dependency versions

- Pin the current stable version of each dependency, verified at build time against its canonical source (npm, PyPI, NuGet, or the vendor's release notes) — not from memory or training data, which goes stale.
- Record the version and its source for any significant choice: an ADR for framework, runtime, and datastore choices; a lockfile entry or comment otherwise.
- Treat the lockfile as the source of truth. When docs and the lockfile disagree, fix the docs to match the lockfile — never silently bump the lockfile to match the docs.

---

## Pull request expectations

Each PR should include:

- What changed
- Why it changed
- How it was tested
- Screenshots or API examples when useful
- Known risks
- Follow-up tasks
