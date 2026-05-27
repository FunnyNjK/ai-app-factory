---
description: Draft the Codex Quality Engineer Handoff from this project's approved architecture
---

Produce a **Codex QE Handoff** for this project.

Pre-conditions:

- `ARCHITECTURE.md` exists for this project and Gate B is satisfied (see `CLAUDE.md` Section 3).
- The Cursor handoff exists or is being produced in parallel.

Save the handoff as `CODEX_HANDOFF.md` in this project folder. Use the 15-section structure documented in the factory's `CLAUDE.md` Section 8:

1. Quality Objective
2. Business-Critical User Journeys
3. Requirements to Validate (functional + non-functional)
4. Highest-Risk Areas
5. Acceptance Criteria
6. Test Data Needs (users, records, Stripe test cards, Plaid sandbox tokens, Postmark sandbox)
7. API Checks
8. UI / E2E Checks
9. Integration Checks (Postmark, Stripe, Plaid, database, storage, webhooks)
10. Security Checks
11. Accessibility Checks
12. Performance Checks
13. Regression Suite
14. Release Gate Recommendation
15. Open Questions

Reference the matching worked example under the factory's `examples/` directory.

Quality bar:

- Every check must have a pass/fail criterion. If you cannot describe how to know it passed, rewrite it.
- Avoid banned vague phrases (the factory's validator enforces this). Replace "fast", "easy", "secure" with measurable criteria.

Follow the collaboration style in `CLAUDE.md` Section 6.
