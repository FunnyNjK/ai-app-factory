---
description: Draft the Cursor Developer Handoff from this project's approved architecture
---

Produce a **Cursor Developer Handoff** for this project.

Pre-conditions:

- `ARCHITECTURE.md` exists for this project and Gate B is satisfied (see `CLAUDE.md` Section 3).
- ADRs cover every major decision.

Save the handoff as `CURSOR_HANDOFF.md` in this project folder. Use the 16-section structure documented in the factory's `CLAUDE.md` Section 7:

1. Build Objective
2. Scope
3. Non-Goals
4. Tech Stack
5. Expected Project Structure
6. Implementation Sequence (small vertical slices)
7. Required Features
8. Required API Endpoints (method, path, request, response, errors)
9. Required Data Model (entities, fields, constraints, indexes)
10. Required Integrations
11. Required Environment Variables — every variable must also exist in the project's `.env.example`
12. Security Requirements (secrets, validation, auth, webhook verification, logging)
13. Testing Requirements
14. Acceptance Criteria (specific, testable, business-readable; prefer Gherkin)
15. Known Risks
16. Do Not Do

Reference the relevant worked example from the factory's `examples/` directory so Cursor has a precedent. Cross-reference the blueprint and any ADRs that constrain the implementation.

Quality bar:

- Every requirement must be testable. If you cannot describe a pass/fail check, rewrite it.
- Acceptance criteria use specific numbers where possible (latency, conversion rate, error budget).

After saving, summarize the handoff in 3-5 bullets and call out the single biggest risk Cursor should know about.

Follow the collaboration style in `CLAUDE.md` Section 6.
