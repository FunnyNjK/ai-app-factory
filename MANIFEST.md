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
| `.github/workflows/ci.yml` | Starter CI workflow: markdown quality, required factory files, and the bash test suites (`scripts/test/`). |
| `.github/pull_request_template.md` | PR checklist template including the six-party Gate D sign-off. |
| `scripts/validate-factory.mjs` | Dependency-free validation script for required artifacts, manifest references, backtick path resolution, placeholder safety, and env-var cross-consistency. |
| `scripts/scaffold-new-project.sh` | Scaffolds a new factory project — copies the skeleton + starter templates, replaces placeholders, optionally git-inits. Backs the new-project slash command and the `spawn-new-project` skill. |
| `scripts/check-cli-tools.sh` | Preflight check for the four supported agent CLIs (`claude`, `codex`, `agent`, `gemini`) and the supporting tools. Reports presence, version, install help for any missing tool, and whether auth env vars are set. A missing agent CLI is informational (install only the ones your roles use); a missing supporting tool fails. |
| `scripts/validate-project.sh` | Lints a spawned project — required files, unfilled placeholders, TASKS.md and ESCALATIONS.md structure, sensitive-path scan, lifecycle consistency, planning completeness, and the .factory-roles.json role configuration (ADR-0013). |
| `scripts/refresh-project.sh` | Read-only drift detector — reports where a scaffolded project has fallen behind current factory conventions (TASKS.md legends and phase gates, slash commands, the Gate D sign-off artifact, the .factory-roles.json role config, the version stamp). |
| `scripts/factory-status.sh` | Quick factory health check — git state, CLI tool presence, ADR/blueprint/standard counts, validator pass/fail. Run before starting a new project. |
| `scripts/factory.sh` | Context-aware interactive launcher (TUI) wrapping the existing scripts: in the factory, status / scaffold / open-a-project; in a project, status / next step / autopilot / drift-check / settings. Inline Claude Code-style UI (accent ❯ arrow-key picker, rounded banner, post-action pause) — no fullscreen dialogs, dependency-free. Settings persist per project. Has non-interactive `--next [dir]` / `--status [dir]` modes. See ADR-0012 and its inline-UI amendment. |

## Tests

Dependency-free bash test suites — no framework, nothing beyond bash and the python3 the orchestrator already requires. Run them locally with the runner `scripts/test/run.sh`; CI runs them in the `Script Tests` job.

| File | Purpose |
|---|---|
| `scripts/test/run.sh` | Test runner — executes every `*.test.sh` in the directory, each in its own process, and reports totals. |
| `scripts/test/lib-assert.sh` | Tiny assertion helpers (`assert_eq`, `assert_contains`, `assert_code`, `assert_summary`) sourced by every suite. |
| `scripts/test/factory.test.sh` | Tests `scripts/factory.sh`: the non-interactive `--help`/`--next`/`--status` surface (incl. a path argument), the shared `factory_adapter_for` dispatch map, and role-config reads. |
| `scripts/test/menu.test.sh` | Tests the launcher's `_select` menu helper and inline UI: the numbered fallback (chosen key to stdout, UI to stderr), the arrow-key/digit/cancel picker paths under a pty, the banner, and a guard that `whiptail`/`fzf` are never invoked. |
| `scripts/test/settings.test.sh` | Tests the launcher's per-project settings persistence (`load_settings` / `save_settings`). |
| `scripts/test/project-scripts.test.sh` | Tests the per-project scripts: .factory-roles.json validation in `scripts/validate-project.sh` and the ADR-0013 drift markers in `scripts/refresh-project.sh`. |

## Orchestrator (Stage 2 of the gating model)

Bash scripts that autonomously drive the per-slice and per-phase gating loop defined in `docs/adr/0008-per-slice-and-per-phase-gating.md` and `docs/adr/0009-autonomous-orchestrator.md`, with the five configurable roles and the per-phase security + code-review gates from `docs/adr/0013-configurable-roles-and-tools.md`. Which tool drives each role is read from the project's per-project .factory-roles.json config. Run from a project root that has a project TASKS.md and ESCALATIONS.md (see `templates/project-skeleton/`).

| File | Purpose |
|---|---|
| `scripts/orchestrator/orchestrate.sh` | Top-level loop. Reads the project task tracker, picks next action, dispatches, loops. |
| `scripts/orchestrator/cursor-slice.sh` | Adapter — one slice implementation via Cursor CLI. |
| `scripts/orchestrator/codex-slice-review.sh` | Adapter — one slice review via Codex CLI. |
| `scripts/orchestrator/codex-slice-verify.sh` | Adapter — one verification slice via Codex CLI (Owner: codex; no separate implementer). |
| `scripts/orchestrator/claude-phase-review.sh` | Adapter — one phase review via the architect role's tool (ADR-0013; default Claude). |
| `scripts/orchestrator/security-phase-review.sh` | Adapter — post-phase security gate via the security role's tool (ADR-0013). Approves in place or escalates; blocks the phase. |
| `scripts/orchestrator/codereview-phase-review.sh` | Adapter — post-phase code-review & refactoring gate via the code-review role's tool (ADR-0013). Approves in place or escalates; blocks the phase. |
| `scripts/orchestrator/gate-d-signoff.sh` | Adapter — Gate D six-party sign-off ceremony (five agent sub-sessions fill SIGNOFF.md; product-owner sign-off escalated). See ADR-0013. |
| `scripts/orchestrator/lib.sh` | Shared safety + task-tracker helpers, the tool registry, and per-project role config (ADR-0013). Sourced by every script. |
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
| `.claude/skills/refresh-project/SKILL.md` | Model-invoked skill: bring an existing scaffolded project up to current factory conventions, preserving project content. |
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

`docs/choosing-a-blueprint.md` is the selector — a decision tree and complexity-tier guide that maps a project idea to one of these blueprints (plus any integration overlays) before design begins.

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
| `templates/INCIDENT.md` | Blameless incident post-mortem template (Gate E / post-release review). |
| `templates/SIGNOFF.md` | Six-party Gate D sign-off note template (one section per role — five agents plus the product owner). |
| `templates/factory-roles.default.json` | Default per-project delivery-team config (role → tool → name). Seeded into each project as .factory-roles.json. See ADR-0013. |
| `templates/ADR.md` | Architecture decision record template. |
| `templates/.env.example` | Canonical environment variable inventory. |
| `templates/ci-security.yml` | Security-guardrails CI workflow for generated projects (fails unless dependency automation and a real scanner both run). |

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
| `docs/adr/0006-three-agent-signoff.md` | Gate D requires architect + developer + QE + team sign-off. Superseded by ADR-0013 (six-party sign-off). |
| `docs/adr/0007-default-database-postgres-then-sql-then-cosmos.md` | PostgreSQL is the default relational store, with Azure SQL and Cosmos DB as fallbacks. |
| `docs/adr/0008-per-slice-and-per-phase-gating.md` | Per-slice (Cursor↔Codex) and per-phase (Codex→Claude) gating model with budget caps and ESCALATIONS.md. |
| `docs/adr/0009-autonomous-orchestrator.md` | Bash orchestrator design — per-role adapters, shared safety lib, status-line contract, budget enforcement. |
| `docs/adr/0010-gate-d-signoff-adapter.md` | Gate D sign-off adapter — three agent sub-sessions fill SIGNOFF.md; product-owner sign-off escalated to a human. |
| `docs/adr/0011-recurring-security-review-for-sensitive-projects.md` | Superseded by ADR-0013 — its per-phase security gate (`scripts/orchestrator/security-phase-review.sh`) realizes the recurring-security-review intent for every project, so the proposed data-classification gate was dropped. |
| `docs/adr/0012-interactive-factory-tui.md` | Accepted — a thin, context-aware bash TUI launcher (inline Claude Code-style UI) wrapping scaffold and the build loop. |
| `docs/adr/0013-configurable-roles-and-tools.md` | Five per-app roles, each mapped to a tool (claude/cursor/codex/gemini) in .factory-roles.json; per-phase security + code-review gates; six-party Gate D. Supersedes ADR-0006 and ADR-0011. |

## Playbooks

| File | Purpose |
|---|---|
| `docs/playbooks/first-project-walkthrough.md` | Worked Intake Mode conversation showing how to turn a one-sentence idea into an approved project brief. |
| `docs/playbooks/escalation-trail-example.md` | Worked example of the architect escalation protocol firing: Codex flags an issue, architect amends via ADR. |
| `docs/playbooks/running-a-project.md` | End-to-end runbook: shell setup, scaffold, intake/design, manual step-by-step gating loop OR autonomous orchestrate.sh. Codex sandbox guidance. |

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
