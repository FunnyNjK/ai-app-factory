# Manifest

This repository contains a starter operating system for an AI-assisted app delivery factory.

## Root files

| File | Purpose |
|---|---|
| `README.md` | Start here. Explains the repo purpose and workflow. |
| `OPERATING_MODEL.md` | Full AI App Factory operating model and quality gates. |
| `MANIFEST.md` | Inventory of files and how to use them. |
| `CONTRIBUTING.md` | How to add or change factory artifacts without breaking the operating model. |
| `CLAUDE.md` | Repository-level instruction file for Claude as Software Architect / Solution Designer. |
| `AGENTS.md` | Repository-level instruction file for Codex as Software Analyst / Quality Engineer. |
| `.cursor/rules/ai-app-factory-developer.mdc` | Cursor rules file for Cursor as Software Developer. |
| `.gitattributes` | Normalizes line endings to LF for all text files. |
| `.gitignore` | Standard ignore list for build outputs, env files, and editor metadata. |
| `.markdownlint-cli2.jsonc` | Repository markdown lint configuration used by CI. |

## CI/CD automation

| File | Purpose |
|---|---|
| `.github/workflows/ci.yml` | Starter CI workflow that validates markdown quality and required factory files. |
| `.github/pull_request_template.md` | PR checklist template including the four-party Gate D sign-off. |
| `scripts/validate-factory.mjs` | Dependency-free validation script for required artifacts, manifest references, backtick path resolution, placeholder safety, and env-var cross-consistency. |
| `scripts/scaffold-new-project.sh` | Scaffolds a new factory project — copies the skeleton + starter templates, replaces placeholders, optionally git-inits. Backs the new-project slash command and the `spawn-new-project` skill. |
| `scripts/check-cli-tools.sh` | Preflight check for the three headless CLIs (`claude`, `codex`, `agent`) the orchestrator depends on. Reports presence, version, and whether auth env vars are set. |
| `scripts/validate-project.sh` | Lints a spawned project — required files, unfilled placeholders, TASKS.md and ESCALATIONS.md structure, sensitive-path scan. |

## Orchestrator (Stage 2 of the gating model)

Bash scripts that autonomously drive the per-slice (Cursor ↔ Codex) and per-phase (Claude) gating loop defined in `docs/adr/0008-per-slice-and-per-phase-gating.md` and `docs/adr/0009-autonomous-orchestrator.md`. Run from a project root that has a project TASKS.md and ESCALATIONS.md (see `templates/project-skeleton/`).

| File | Purpose |
|---|---|
| `scripts/orchestrator/orchestrate.sh` | Top-level loop. Reads the project task tracker, picks next action, dispatches, loops. |
| `scripts/orchestrator/cursor-slice.sh` | Adapter — one slice implementation via Cursor CLI. |
| `scripts/orchestrator/codex-slice-review.sh` | Adapter — one slice review via Codex CLI. |
| `scripts/orchestrator/claude-phase-review.sh` | Adapter — one phase review via Claude Code CLI. |
| `scripts/orchestrator/lib.sh` | Shared safety + task-tracker helpers. Sourced by every script. |
| `scripts/orchestrator/README.md` | Usage, env vars, status-line contract, debugging. |
| `docs/research/headless-cli/run-phase.sh` | Reference — original Claude harness from prior project. |
| `docs/research/headless-cli/run-phase-codex.sh` | Reference — original Codex harness from prior project. |
| `docs/research/headless-cli/run-phase-cursor.sh` | Reference — original Cursor harness from prior project. |
| `docs/research/headless-cli/run-phase-copilot.sh` | Reference — original Copilot harness from prior project. |
| `docs/research/headless-cli/run-phase-gemini.sh` | Reference — original Gemini harness from prior project. |
| `docs/research/headless-cli/run-phase-lib.sh` | Reference — shared safety library that `scripts/orchestrator/lib.sh` is adapted from. |
| `docs/research/headless-cli/mark-task-done.py` | Reference — prior project's task-done utility (different planning-file convention). |
| `docs/research/headless-cli/lint-planning.py` | Reference — prior project's planning-file linter (different planning-file convention). |

## AI Instruction Files

| File | Purpose |
|---|---|
| `CLAUDE.md` | Canonical instruction file for Claude as architect (auto-loaded). |
| `.cursor/rules/ai-app-factory-developer.mdc` | Canonical rules file for Cursor as developer (auto-loaded). |
| `AGENTS.md` | Canonical instruction file for Codex as analyst/QE (auto-loaded). |

## Claude Code tooling

Workflows Claude Code reads from `.claude/`. Slash commands are user-invoked; skills are model-invoked when the task matches their description; agents are specialized subagents the architect can delegate to.

| File | Purpose |
|---|---|
| `.claude/commands/intake.md` | Slash command — enter Project Intake Mode. |
| `.claude/commands/design.md` | Slash command — produce the Architecture Package. |
| `.claude/commands/adr.md` | Slash command — create a new Architecture Decision Record. |
| `.claude/commands/handoff-cursor.md` | Slash command — draft the developer handoff. |
| `.claude/commands/handoff-codex.md` | Slash command — draft the QE handoff. |
| `.claude/commands/new-project.md` | Slash command — scaffold a new project folder from the project skeleton. |
| `.claude/skills/create-adr/SKILL.md` | Model-invoked skill: create an ADR following the factory template. |
| `.claude/skills/draft-handoff/SKILL.md` | Model-invoked skill: draft a Cursor or Codex handoff from an approved architecture. |
| `.claude/skills/spawn-new-project/SKILL.md` | Model-invoked skill: scaffold a new project folder using the project skeleton. |
| `.claude/agents/requirements-clarifier.md` | Subagent: deep requirements clarification on a partial intake. |
| `.claude/agents/threat-modeler.md` | Subagent: produce or review a STRIDE threat model. |

## Prompts

Portable copy-paste mirrors of the canonical instruction files above. Keep both surfaces in sync; the canonical files win on conflict.

| File | Purpose |
|---|---|
| `prompts/claude-architect.md` | Portable role prompt for Claude as Software Architect / Solution Designer. |
| `prompts/cursor-developer.md` | Portable role prompt for Cursor AI as Software Developer. |
| `prompts/codex-quality-engineer.md` | Portable role prompt for Codex as Software Analyst / Quality Engineer. |

## Blueprints

| File | Purpose |
|---|---|
| `blueprints/marketing-site.md` | Reusable blueprint for a marketing site with contact form and Postmark. |
| `blueprints/static-web-app.md` | Reusable blueprint for a static web app. |
| `blueprints/full-stack-web-app.md` | Reusable blueprint for an authenticated full-stack app. |
| `blueprints/api-service.md` | Reusable blueprint for an API-first service. |
| `blueprints/azure-functions.md` | Reusable blueprint for serverless workflows and webhook processors. |
| `blueprints/stripe-app.md` | Reusable blueprint for Stripe checkout, billing, and webhooks. |
| `blueprints/plaid-app.md` | Reusable blueprint for Plaid Link and financial data sync. |
| `blueprints/postmark-email.md` | Reusable blueprint for transactional email workflows. |

## Templates

| File | Purpose |
|---|---|
| `templates/PROJECT.md` | Project brief template (includes data classification table). |
| `templates/ARCHITECTURE.md` | Architecture package template (cross-references threat model, cost, observability). |
| `templates/API_SPEC.md` | API contract template for API/webhook projects. |
| `templates/SECURITY.md` | Security model template (includes data classification scheme). |
| `templates/THREAT_MODEL.md` | STRIDE-based threat model template. |
| `templates/COST_ESTIMATE.md` | Monthly cost worksheet. |
| `templates/TEST_PLAN.md` | Test strategy and test plan template. |
| `templates/RELEASE_CHECKLIST.md` | Release readiness checklist template. |
| `templates/RUNBOOK.md` | Operational runbook template. |
| `templates/SIGNOFF.md` | Four-party Gate D sign-off note template (one section per role). |
| `templates/ADR.md` | Architecture decision record template. |
| `templates/.env.example` | Canonical environment variable inventory. |

## Project skeleton

The starter folder structure copied into a new project folder by the new-project command (or the `spawn-new-project` skill). Each placeholder is filled during scaffolding.

| File | Purpose |
|---|---|
| `templates/project-skeleton/CLAUDE.md` | Project-level Claude instructions (architect persona, teammate traits, project snapshot, role boundaries, quality gates, default workflow, per-phase gating). |
| `templates/project-skeleton/AGENTS.md` | Project-level Codex instructions (QE persona, teammate traits, project snapshot, role boundaries, quality gates, per-slice review workflow). |
| `templates/project-skeleton/.cursor/rules/developer.mdc` | Project-level Cursor rules (developer persona, teammate traits, project snapshot, role boundaries, quality gates, per-slice implementation workflow). |
| `templates/project-skeleton/TASKS.md` | Per-project task tracker for the per-slice and per-phase gating loop. |
| `templates/project-skeleton/ESCALATIONS.md` | Human review queue for iteration-cap hits and judgment calls. |
| `templates/project-skeleton/README.md` | Documentation of what the skeleton ships and how it is customized at scaffold time. |
| `templates/project-skeleton/.gitignore` | Standard ignore list for node, build output, env files, editor metadata, and per-developer Claude settings. |
| `templates/project-skeleton/.claude/commands/intake.md` | Project-level intake slash command. |
| `templates/project-skeleton/.claude/commands/design.md` | Project-level design slash command. |
| `templates/project-skeleton/.claude/commands/adr.md` | Project-level adr slash command. |
| `templates/project-skeleton/.claude/commands/handoff-cursor.md` | Project-level handoff-cursor slash command. |
| `templates/project-skeleton/.claude/commands/handoff-codex.md` | Project-level handoff-codex slash command. |
| `templates/project-skeleton/.claude/commands/next-slice.md` | Project-level next-slice slash command (read-only status from TASKS.md). |

## Infrastructure starter (Bicep)

| File | Purpose |
|---|---|
| `templates/infra/main.bicep` | Default Azure footprint: Static Web App, Function App, Storage, Key Vault, App Insights, Log Analytics. |
| `templates/infra/main.bicepparam.example` | Example parameter file for the Bicep template. |
| `templates/infra/README.md` | How to deploy and extend the Bicep starter. |

## Standards

| File | Purpose |
|---|---|
| `standards/coding-standards.md` | Coding expectations. |
| `standards/testing-standards.md` | Testing expectations. |
| `standards/security-standards.md` | Security guardrails. |
| `standards/api-standards.md` | API design standards. |
| `standards/observability-standards.md` | Required log fields, alert thresholds, dashboards, SLOs. |
| `standards/git-workflow.md` | Branching, commits, PRs, and release workflow. |
| `standards/ci-cd-standards.md` | Build, test, and deployment pipeline standards. |
| `standards/documentation-standards.md` | Documentation requirements. |

## Architecture decision records

| File | Purpose |
|---|---|
| `docs/adr/0001-default-cloud-azure.md` | Azure as the factory's default cloud. |
| `docs/adr/0002-default-email-postmark.md` | Postmark as the default transactional email provider. |
| `docs/adr/0003-default-language-typescript.md` | TypeScript as the default implementation language. |
| `docs/adr/0004-default-iac-bicep.md` | Bicep as the default infrastructure-as-code language. |
| `docs/adr/0005-greenfield-only-scope.md` | The factory targets greenfield projects only. |
| `docs/adr/0006-three-agent-signoff.md` | Gate D requires architect + developer + QE + team sign-off. |
| `docs/adr/0007-default-database-postgres-then-sql-then-cosmos.md` | PostgreSQL is the default relational store, with Azure SQL and Cosmos DB as fallbacks. |
| `docs/adr/0008-per-slice-and-per-phase-gating.md` | Per-slice (Cursor↔Codex) and per-phase (Codex→Claude) gating model with budget caps and ESCALATIONS.md. |
| `docs/adr/0009-autonomous-orchestrator.md` | Bash orchestrator design — per-role adapters, shared safety lib, status-line contract, budget enforcement. |

## Playbooks

| File | Purpose |
|---|---|
| `docs/playbooks/first-project-walkthrough.md` | Worked Intake Mode conversation showing how to turn a one-sentence idea into an approved project brief. |
| `docs/playbooks/escalation-trail-example.md` | Worked example of the architect escalation protocol firing: Codex flags an issue, architect amends via ADR. |

## Examples

Worked end-to-end examples that exercise specific blueprints. The marketing-site example shipped first and uses unprefixed file names; subsequent examples use a `sample-<project>-<artifact>.md` naming pattern.

### Marketing-site example

| File | Purpose |
|---|---|
| `examples/sample-project-brief.md` | Marketing-site project brief. |
| `examples/sample-architecture.md` | Marketing-site architecture package. |
| `examples/sample-test-plan.md` | Marketing-site Codex/QE test plan. |
| `examples/sample-cursor-handoff.md` | Marketing-site developer handoff. |
| `examples/sample-codex-qe-handoff.md` | Marketing-site quality engineer handoff. |
| `examples/sample-marketing-site-signoffs.md` | Marketing-site worked exemplar of the four Gate D sign-offs. |

### Stripe-subscription example

| File | Purpose |
|---|---|
| `examples/sample-stripe-project-brief.md` | Subscription SaaS project brief using Stripe Checkout. |
| `examples/sample-stripe-architecture.md` | Subscription SaaS architecture with webhook idempotency. |
| `examples/sample-stripe-threat-model.md` | Subscription SaaS STRIDE threat model. |
| `examples/sample-stripe-test-plan.md` | Subscription SaaS Codex/QE test plan. |
| `examples/sample-stripe-cursor-handoff.md` | Subscription SaaS developer handoff. |
| `examples/sample-stripe-codex-qe-handoff.md` | Subscription SaaS quality engineer handoff. |

### Plaid personal-finance example

| File | Purpose |
|---|---|
| `examples/sample-plaid-project-brief.md` | Personal-finance dashboard project brief using Plaid Link. |
| `examples/sample-plaid-architecture.md` | Personal-finance dashboard architecture with Key Vault-backed token storage. |
| `examples/sample-plaid-test-plan.md` | Personal-finance dashboard Codex/QE test plan. |
| `examples/sample-plaid-cursor-handoff.md` | Personal-finance dashboard developer handoff. |
| `examples/sample-plaid-codex-qe-handoff.md` | Personal-finance dashboard quality engineer handoff. |
