# AI App Factory

A repeatable operating model and starter repository for building AI-assisted web software projects.

The factory is designed around a small AI delivery team:

- **Claude** — Software Architect / Solution Designer
- **Cursor AI** — Software Developer
- **Codex** — Software Analyst / Quality Engineer
- **You** — Product Owner / Final Decision Maker

The goal is not just to generate code. The goal is to create a disciplined process where AI agents ask the right questions, design intentionally, implement in small slices, verify quality, and produce maintainable software.

---

## What this factory is for

This repository focuses on web development projects such as:

- Marketing sites
- Static web apps
- Full-stack web apps
- APIs
- Azure Functions
- Cloud storage integrations
- SQL or NoSQL databases
- Azure Key Vault and secret management
- Stripe payments
- Plaid financial-data integrations
- Postmark transactional email
- CI/CD, testing, release checklists, and runbooks

---

## Repository structure

```text
ai-app-factory/
  README.md
  OPERATING_MODEL.md
  MANIFEST.md

  prompts/
    claude-architect.md
    cursor-developer.md
    codex-quality-engineer.md

  blueprints/
    marketing-site.md
    static-web-app.md
    full-stack-web-app.md
    api-service.md
    azure-functions.md
    stripe-app.md
    plaid-app.md
    postmark-email.md

  templates/
    PROJECT.md
    ARCHITECTURE.md
    SECURITY.md
    TEST_PLAN.md
    RELEASE_CHECKLIST.md
    RUNBOOK.md
    .env.example

  standards/
    coding-standards.md
    testing-standards.md
    security-standards.md
    api-standards.md
    git-workflow.md
    ci-cd-standards.md
    documentation-standards.md

  examples/
    sample-project-brief.md
    sample-architecture.md
    sample-test-plan.md
    sample-cursor-handoff.md
    sample-codex-qe-handoff.md
```

---

## Recommended first use

Start with the simplest complete project blueprint:

```text
blueprints/marketing-site.md
```

That project gives you a small but realistic proof of the whole factory process:

- Frontend
- Contact form
- Serverless API endpoint
- Postmark email integration
- Environment variables
- Basic security
- Automated tests
- Deployment notes
- Release checklist

---

## Suggested workflow

1. Give Claude the role prompt in `prompts/claude-architect.md`.
2. Ask Claude to work in **Intake Mode** for your selected blueprint.
3. When the design is ready, ask Claude for a **Cursor Developer Handoff**.
4. Give the handoff to Cursor using `prompts/cursor-developer.md`.
5. Give the requirements and architecture to Codex using `prompts/codex-quality-engineer.md`.
6. Let Codex produce acceptance criteria, risk-based tests, and release checks.
7. Build in small vertical slices.
8. Use the templates and standards in this repo to keep every project consistent.

---

## Core rule

Do not let the developer agent start coding until the architect has produced enough requirements, assumptions, risks, acceptance criteria, and handoff detail to build responsibly.
