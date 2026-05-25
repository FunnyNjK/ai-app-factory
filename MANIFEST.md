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

## AI Instruction Files

| File | Purpose |
|---|---|
| `CLAUDE.md` | Canonical instruction file for Claude as architect (auto-loaded). |
| `.cursor/rules/ai-app-factory-developer.mdc` | Canonical rules file for Cursor as developer (auto-loaded). |
| `AGENTS.md` | Canonical instruction file for Codex as analyst/QE (auto-loaded). |

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
| `templates/ADR.md` | Architecture decision record template. |
| `templates/.env.example` | Canonical environment variable inventory. |

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

## Playbooks

| File | Purpose |
|---|---|
| `docs/playbooks/first-project-walkthrough.md` | Worked Intake Mode conversation showing how to turn a one-sentence idea into an approved project brief. |

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
