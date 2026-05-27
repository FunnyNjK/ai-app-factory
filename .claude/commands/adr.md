---
description: Create a new Architecture Decision Record
---

Create a new ADR using the template at `templates/ADR.md` and the format in `CLAUDE.md` Section 9.

Steps:

1. Determine the next ADR number by listing `docs/adr/`. The new ADR uses the next sequential number with a short kebab-case title (for example, `0008-default-auth-magic-link.md`).
2. Copy `templates/ADR.md` into `docs/adr/<number>-<short-title>.md` and fill it in:
   - **Status** — `Proposed` initially; the product owner accepts or rejects.
   - **Context** — what problem are we solving and what triggered the decision.
   - **Decision** — what was chosen.
   - **Alternatives Considered** — at least two, with why each was rejected.
   - **Consequences** — positive and negative.
   - **Follow-Up** — concrete action items.
3. If the new ADR supersedes an existing one, mark the older ADR `Superseded by ADR-XXXX` in its Status section.
4. Register the new ADR in `MANIFEST.md` and add it to `requiredFiles` in `scripts/validate-factory.mjs` if it is a project-level factory ADR.
5. Reference the ADR from any blueprint, standard, or handoff it affects (use a backtick path so the validator catches breakages).

Follow `CONTRIBUTING.md` rules: every PR that touches factory files must pass `node scripts/validate-factory.mjs`.
