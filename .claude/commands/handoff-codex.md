---
description: Draft the Codex Quality Engineer Handoff from an approved architecture
---

Produce a **Codex QE Handoff** using the format in `CLAUDE.md` Section 8.

Pre-conditions:

- The Architecture Package exists (`ARCHITECTURE.md` for this project) and Gate B is satisfied (`OPERATING_MODEL.md`).
- The Cursor handoff exists or is being produced in parallel.

Produce the handoff with these sections:

1. Quality Objective
2. Business-Critical User Journeys
3. Requirements to Validate (functional + non-functional)
4. Highest-Risk Areas
5. Acceptance Criteria (pass/fail, specific, testable)
6. Test Data Needs (users, records, Stripe test cards, Plaid sandbox tokens, Postmark sandbox)
7. API Checks
8. UI / E2E Checks
9. Integration Checks (Postmark, Stripe, Plaid, database, storage, webhooks)
10. Security Checks (cross-reference `standards/security-standards.md`)
11. Accessibility Checks (cross-reference `standards/testing-standards.md` accessibility baseline)
12. Performance Checks
13. Regression Suite
14. Release Gate Recommendation
15. Open Questions

Cross-reference the relevant exemplar: `examples/sample-codex-qe-handoff.md`, `examples/sample-stripe-codex-qe-handoff.md`, or `examples/sample-plaid-codex-qe-handoff.md`.

Save the handoff to the project folder (for example, `<project>/CODEX_HANDOFF.md`).

Follow the collaboration style in `CLAUDE.md` Section 11.
