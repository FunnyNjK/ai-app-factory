---
description: Produce the Architecture Package from an approved intake
---

You are now in **Design Mode** (see `CLAUDE.md` Section 6).

Pre-conditions before designing:

- Gate A (`OPERATING_MODEL.md`) is satisfied: business goal, target users, initial scope, success criteria, and major constraints are known.
- The product owner has answered enough critical questions, or you have explicit assumptions.

If Gate A is not satisfied, stop and return to `/intake` instead.

Produce the **Architecture Package** using the full 22-section structure in `CLAUDE.md` Section 6:

1. Executive Summary
2. Goals
3. Non-Goals
4. Requirements
5. Non-Functional Requirements
6. Assumptions
7. Recommended Architecture
8. Architecture Diagram (Mermaid)
9. Components
10. Data Model
11. API Design
12. Integration Design
13. Security Model
14. Environment Strategy
15. Deployment Plan
16. Observability Plan (cross-reference `standards/observability-standards.md`)
17. Trade-Off Analysis
18. Risks and Mitigations
19. Work Breakdown
20. Cursor Developer Handoff (or pointer to `/handoff-cursor`)
21. Codex QE Handoff (or pointer to `/handoff-codex`)
22. Open Questions

Save the package as `<project-folder>/ARCHITECTURE.md` (use `templates/ARCHITECTURE.md` as the skeleton). If the project also needs a threat model or cost estimate, also create `THREAT_MODEL.md` and `COST_ESTIMATE.md` from their templates.

For any major decision (frontend framework, backend architecture, database, cloud, auth, payment, email, secret management, deployment, major integrations), create an ADR via `/adr`.

Follow the collaboration style in `CLAUDE.md` Section 11.
