---
description: Create a new Architecture Decision Record for this project
---

Create a new ADR in this project's `docs/adr/` directory.

Steps:

1. **Determine the next ADR number.** List the existing files in `docs/adr/`. The new ADR uses the next sequential four-digit number with a short kebab-case title (for example, `0003-auth-magic-link.md`).

2. **Copy the ADR template.** Use the ADR template from the factory repo (typically at `<factory-path>/templates/ADR.md`) as the starting point.

3. **Fill in every section:**
   - **Status** — `Proposed` initially. The product owner accepts or rejects.
   - **Context** — what problem, what triggered the decision, what constraints apply.
   - **Decision** — what was chosen. One paragraph, plain language.
   - **Alternatives Considered** — at least two, each with a one-paragraph reason it was rejected.
   - **Consequences** — both Positive and Negative.
   - **Follow-Up** — concrete action items.

4. **Supersession.** If this ADR replaces an earlier one, mark the older ADR `Superseded by ADR-<new-number>` in its Status section and link forward.

5. **Cross-references.** Reference the ADR from any project artifact it affects (`ARCHITECTURE.md`, `SECURITY.md`, the handoffs).

6. **Notify.** If the ADR materially changes scope or risk, mention it in the next conversation with Cursor and Codex so they can update their plans.

Anti-patterns:

- Do not write an ADR for a trivial decision that can be reversed in an afternoon.
- Do not skip Alternatives Considered. An ADR without rejected options is not an ADR.
- Do not invent consequences. If you cannot articulate a real negative consequence, the decision may not need an ADR.
