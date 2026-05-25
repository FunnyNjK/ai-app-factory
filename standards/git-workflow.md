# Git Workflow

## Branching

Use short-lived branches.

Recommended naming:

```text
feature/contact-form
fix/postmark-error-handling
docs/update-runbook
chore/dependency-updates
```

---

## Commits

Use clear commit messages.

Recommended format:

```text
type(scope): summary
```

Examples:

```text
feat(contact): add contact form endpoint
fix(email): handle Postmark failure safely
test(api): add validation tests
docs(runbook): add deployment steps
```

Types:

- `feat`
- `fix`
- `test`
- `docs`
- `refactor`
- `chore`
- `ci`

---

## Pull requests

Each PR should include:

- Summary
- Related requirement/ticket
- Screenshots or API examples when useful
- Testing performed
- Security considerations
- Known risks
- Follow-up tasks

---

## Review expectations

Review for:

- Correctness
- Simplicity
- Security
- Test coverage
- Maintainability
- Alignment with architecture
- Documentation updates

---

## Merge criteria

Do not merge unless:

- Build passes.
- Tests pass.
- Required review is complete.
- Secrets are not included.
- Architecture deviations are documented.
- Release notes are updated when needed.

---

## Release tags

Suggested format:

```text
v0.1.0
v0.2.0
v1.0.0
```

Use semantic versioning when practical.
