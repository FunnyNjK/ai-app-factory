---
name: draft-handoff
description: Draft a developer or quality-engineer handoff from an approved architecture. Use when the user asks for "the Cursor handoff", "the Codex handoff", "the QE handoff", "the developer handoff", or wants to move an approved architecture into implementation-ready instructions. Produces one or both of CURSOR_HANDOFF.md and CODEX_HANDOFF.md.
---

# Draft a Cursor or Codex handoff

You produce two artifacts from the same approved architecture:

- **Cursor Developer Handoff** — implementation-ready instructions (`CLAUDE.md` Section 7).
- **Codex QE Handoff** — quality-validation instructions (`CLAUDE.md` Section 8).

Ask the user which one (or both) they want.

## Pre-conditions

- The Architecture Package (`ARCHITECTURE.md` for this project) exists and Gate B is satisfied (`OPERATING_MODEL.md`).
- ADRs cover every major decision.
- The relevant blueprint under `blueprints/` and the matching exemplar under `examples/` are known.

If pre-conditions are not met, stop and route the user back to `/design`.

## Cursor handoff sections

Use this order. Do not skip sections; mark "N/A" only if a section genuinely does not apply.

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
11. Required Environment Variables — every variable must also exist in `templates/.env.example` or be added there in the same PR
12. Security Requirements (secrets, validation, auth, webhook verification, logging)
13. Testing Requirements (cross-reference `standards/testing-standards.md`)
14. Acceptance Criteria (specific, testable, business-readable; prefer Gherkin)
15. Known Risks
16. Do Not Do

Reference exemplars:

- `examples/sample-cursor-handoff.md` (marketing site)
- `examples/sample-stripe-cursor-handoff.md`
- `examples/sample-plaid-cursor-handoff.md`

## Codex handoff sections

1. Quality Objective
2. Business-Critical User Journeys
3. Requirements to Validate (functional + non-functional)
4. Highest-Risk Areas
5. Acceptance Criteria
6. Test Data Needs
7. API Checks
8. UI / E2E Checks
9. Integration Checks
10. Security Checks (cross-reference `standards/security-standards.md`)
11. Accessibility Checks (baseline from `standards/testing-standards.md`)
12. Performance Checks
13. Regression Suite
14. Release Gate Recommendation
15. Open Questions

Reference exemplars:

- `examples/sample-codex-qe-handoff.md` (marketing site)
- `examples/sample-stripe-codex-qe-handoff.md`
- `examples/sample-plaid-codex-qe-handoff.md`

## Quality bar

- Every requirement must be testable. If you cannot describe a pass/fail check, rewrite it.
- Acceptance criteria use specific numbers where possible (latency, conversion rate, error budget). Avoid banned vague phrases enforced by `scripts/validate-factory.mjs`.
- Cross-reference the blueprint, the standards, and the relevant ADR for every non-trivial decision.

## Save location

- `<project>/CURSOR_HANDOFF.md`
- `<project>/CODEX_HANDOFF.md`

After saving, summarize the handoff in 3-5 bullets and call out the single biggest risk the receiving agent should know about.
