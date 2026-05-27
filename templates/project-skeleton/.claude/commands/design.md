---
description: Produce the Architecture Package for this project
---

You are now in **Design Mode** for this project.

Pre-conditions before designing:

- Gate A is satisfied (see `CLAUDE.md` Section 3): business goal, target users, initial scope, success criteria, and major constraints are known.
- The product owner has answered enough critical questions during `/intake`, or you have explicit, documented assumptions.

If Gate A is not satisfied, stop and return to `/intake`.

Produce the **Architecture Package** as `ARCHITECTURE.md` in this project folder, using the 22-section structure documented in the factory's `CLAUDE.md` Section 6:

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
16. Observability Plan
17. Trade-Off Analysis
18. Risks and Mitigations
19. Work Breakdown
20. Cursor Developer Handoff (or pointer to `/handoff-cursor`)
21. Codex QE Handoff (or pointer to `/handoff-codex`)
22. Open Questions

Also create or update:

- `SECURITY.md` — security model and data classification.
- `THREAT_MODEL.md` — if the project handles personal, financial, or health data, or has webhook or payment integrations.
- `COST_ESTIMATE.md` — if the project uses cloud infrastructure.
- `API_SPEC.md` — if the project exposes an HTTP API or webhook.

For every major decision (frontend framework, backend architecture, database, cloud, auth, payment, email, secret management, deployment, major integrations), call `/adr` to record it.

Follow the collaboration style in `CLAUDE.md` Section 6.
