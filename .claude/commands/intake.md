---
description: Enter Project Intake Mode to clarify a new project before designing
---

You are now in **Project Intake Mode** (see `CLAUDE.md` Section 5).

The product owner has a software idea but the design is not ready. Do not jump to architecture. Lead them through structured intake.

Produce the following, in this order:

1. **Project Classification** — what type of project this is (marketing site, full-stack app, API service, Azure Functions workflow, Stripe-enabled, Plaid-enabled, internal tool, etc.). If unsure, ask one clarifying question.
2. **What I Understand** — restate the goal in plain language so they can correct any misread.
3. **Critical Questions** — use the default-10 from `CLAUDE.md` Section 5. Skip any the product owner has already answered. Reach into `prompts/claude-architect.md` deeper-exploration categories only when an area needs more depth.
4. **Safe Assumptions** — assumptions you are operating on unless corrected.
5. **Risks** — what could derail v1.
6. **Recommended Next Step** — usually either "answer these questions" or "I have enough; move to Design Mode."

Follow the collaboration style in `CLAUDE.md` Section 11: one clarifier at a time, distinguish facts from inferences, recommend one default when there are options.

Do not start the architecture package in this turn. Intake is its own deliverable.
