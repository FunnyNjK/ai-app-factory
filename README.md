# AI App Factory

A repeatable operating model and starter repository for building AI-assisted web software projects.

The factory is designed around a small AI delivery team:

- **Claude** — Software Architect / Solution Designer
- **Cursor AI** — Software Developer
- **Codex** — Software Analyst / Quality Engineer
- **You** — Product Owner / Final Decision Maker

The goal is not just to generate code. The goal is to create a disciplined process where AI agents ask the right questions, design intentionally, implement in small slices, verify quality, and produce maintainable software.

---

## Scope

The factory targets **greenfield projects only**. Brownfield migration is out of scope. See `docs/adr/0005-greenfield-only-scope.md`.

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

Not sure which shape fits your idea? `docs/choosing-a-blueprint.md` is a decision tree and complexity-tier guide that maps an idea to one of these blueprints (plus any integration overlays) before design begins.

---

## Repository structure

```text
ai-app-factory/
  .markdownlint-cli2.jsonc
  README.md
  OPERATING_MODEL.md
  MANIFEST.md
  CLAUDE.md
  AGENTS.md

  .cursor/
    rules/
      ai-app-factory-developer.mdc

  .github/
    pull_request_template.md
    workflows/
      ci.yml

  scripts/
    validate-factory.mjs

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
    API_SPEC.md
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

1. Use `CLAUDE.md` as the AI-specific instruction file for Claude as architect.
2. Ask Claude to work in **Intake Mode** for your selected blueprint.
3. When the design is ready, ask Claude for a **Cursor Developer Handoff**.
4. Use `.cursor/rules/ai-app-factory-developer.mdc` as the Cursor rules file for development.
5. Use `AGENTS.md` as the Codex instruction file for analysis, QA, and release readiness.
6. Let Codex produce acceptance criteria, risk-based tests, and release checks.
7. Build in small vertical slices.
8. Use the templates and standards in this repo to keep every project consistent.

The `prompts/` folder contains portable prompt versions of the same role concepts. The root AI instruction files are intended for tools that automatically read repository-level instructions.

---

## Core rule

Do not let the developer agent start coding until the architect has produced enough requirements, assumptions, risks, acceptance criteria, and handoff detail to build responsibly.
