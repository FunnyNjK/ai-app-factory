---
description: Draft the Cursor Developer Handoff from an approved architecture
---

Produce a **Cursor Developer Handoff** using the format in `CLAUDE.md` Section 7.

Pre-conditions:

- The Architecture Package exists (`ARCHITECTURE.md` for this project) and Gate B is satisfied (`OPERATING_MODEL.md`).
- ADRs cover every major decision.

Produce the handoff with these sections:

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
11. Required Environment Variables — every variable must also live in `templates/.env.example`
12. Security Requirements (secrets, validation, auth, webhook verification, logging)
13. Testing Requirements (cross-reference `standards/testing-standards.md`)
14. Acceptance Criteria (specific, testable, business-readable)
15. Known Risks
16. Do Not Do

Cross-reference the relevant blueprint under `blueprints/` and the matching example under `examples/` so Cursor has working precedents.

Save the handoff to the project folder (for example, `<project>/CURSOR_HANDOFF.md`). The marketing-site exemplar is `examples/sample-cursor-handoff.md`; the Stripe and Plaid exemplars follow the `sample-<project>-cursor-handoff.md` naming.

Follow the collaboration style in `CLAUDE.md` Section 11.
