# Documentation Standards

## Purpose

Documentation should help future developers, architects, quality engineers, and operators understand what exists, why it exists, and how to work with it.

---

## Required documents

Each project should maintain:

- `README.md`
- `PROJECT.md`
- `ARCHITECTURE.md`
- `API_SPEC.md` for API/webhook projects (or OpenAPI spec)
- `SECURITY.md`
- `TEST_PLAN.md`
- `RELEASE_CHECKLIST.md`
- `RUNBOOK.md`
- ADRs for important decisions

---

## Document metadata

Every project document should identify:

- Owner
- Status
- Last updated date
- Approval owner when the document is part of a quality gate
- Source document or decision record when another artifact depends on it

---

## README should include

- Project summary
- Tech stack
- Local setup
- Environment variables
- Run commands
- Test commands
- Deployment summary
- Links to deeper docs

---

## Architecture docs should include

- System overview
- Diagrams
- Components
- Data flow
- API design
- Data model
- Integrations
- Security model
- Deployment model
- Trade-offs
- Risks

---

## ADRs

Create an ADR when a decision is:

- Expensive to change later
- Security-sensitive
- Data-modeling related
- Infrastructure related
- Integration related
- Likely to be questioned later

---

## Writing style

- Be direct.
- Separate facts from assumptions.
- Prefer diagrams for flows.
- Include examples.
- Keep docs close to the code.
- Update docs in the same PR as related code.
