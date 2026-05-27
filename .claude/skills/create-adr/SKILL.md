---
name: create-adr
description: Create a new Architecture Decision Record. Use when the user wants to document an architecture decision, choose between options with explicit trade-offs, capture a design choice for the record, or supersede an existing ADR. Triggers on phrases like "write an ADR", "document this decision", "we need to decide between X and Y", or when the architect's choice is expensive to undo or security-sensitive.
---

# Create an Architecture Decision Record

You are creating a new ADR in `docs/adr/` (for factory-level decisions) or in `<project>/docs/adr/` (for project-level decisions).

## When to create an ADR

Per `CONTRIBUTING.md`: "Create an ADR when the change is expensive to undo, security-sensitive, or likely to be questioned later." Examples: switching the default frontend framework, replacing Postmark with another provider, changing the default deploy target, choosing an auth strategy, picking a primary datastore.

## Procedure

1. **Determine the next ADR number.** List the existing ADR directory:
   - Factory: `docs/adr/`
   - Project: `<project>/docs/adr/`

   The new ADR uses the next sequential four-digit number with a short kebab-case title. Example: `0008-default-auth-magic-link.md`.

2. **Copy the template.** Use `templates/ADR.md` as the starting point. Do not invent a different structure.

3. **Fill in every section:**
   - **Status** — `Proposed` initially. The product owner moves it to `Accepted` (or `Rejected`). If superseded later, set it to `Superseded by ADR-XXXX`.
   - **Context** — what problem are we solving, what triggered the decision, what constraints apply.
   - **Decision** — what was chosen. One paragraph, plain language.
   - **Alternatives Considered** — at least two, each with a one-paragraph reason it was rejected.
   - **Consequences** — both Positive and Negative. Be honest about the negatives.
   - **Follow-Up** — concrete action items (update affected docs, register with the validator, notify Cursor/Codex).

4. **Cross-references.** Reference the ADR from any blueprint, standard, template, or handoff it affects. Use backtick paths so the validator's link checker can verify.

5. **Supersession.** If this ADR replaces an earlier one:
   - Open the earlier ADR.
   - Change its Status to `Superseded by ADR-<new-number>`.
   - Link forward to the new ADR with a backtick path.

6. **Register the ADR (factory level only).**
   - Add it to `MANIFEST.md` under "Architecture decision records".
   - Add it to `requiredFiles` in `scripts/validate-factory.mjs`.

7. **Validate.** Run `node scripts/validate-factory.mjs` and confirm a clean exit before declaring done.

## Anti-patterns

- Do not write an ADR for a trivial decision that can be reversed in an afternoon. Use a code comment or commit message instead.
- Do not skip Alternatives Considered. An ADR without rejected options is not an ADR.
- Do not invent consequences after the fact. If you cannot articulate a real negative consequence, the decision may not need an ADR — or you have not thought it through.
