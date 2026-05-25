# Contributing to the AI App Factory

This repository is itself the contribution model: it defines how Claude, Cursor, and Codex deliver software. Changes to the factory are governance changes for every future project, so they get the same care as any other architecture decision.

This document explains how to add, change, or remove factory artifacts without breaking the operating model.

---

## Before you change anything

1. Run the validator and confirm it passes on `main` first:

   ```bash
   node scripts/validate-factory.mjs
   ```

2. Branch from `main` using the naming convention in `standards/git-workflow.md` (for example, a `feat/<short-name>` branch).
3. Identify which artifact type you are changing — the rest of this document is organized by artifact type.

---

## Quality gates for every PR

Every PR that touches factory files must satisfy:

- [ ] `node scripts/validate-factory.mjs` exits 0.
- [ ] Markdownlint passes (CI runs it; locally you can run `npx markdownlint-cli2`).
- [ ] No real secrets in any file. `templates/.env.example` may only contain placeholders and the small allow-list of safe defaults declared in the validator.
- [ ] Every referenced backtick path resolves. The validator enforces this.
- [ ] Every `^[A-Z]...=` env-var assignment in any `.md`/`.mdc` file is declared in `templates/.env.example`.
- [ ] `MANIFEST.md` lists every file you added or removed.
- [ ] If the change is significant (new blueprint, new template, new standard), an ADR exists in the `docs/adr/` directory documenting why.

---

## Source of truth: root files vs `prompts/`

The repository ships two parallel surfaces for each role:

- **Canonical** (loaded automatically by the relevant tool): `CLAUDE.md`, `AGENTS.md`, `.cursor/rules/ai-app-factory-developer.mdc`.
- **Portable mirrors** (copy-paste form, kept in sync by hand): `prompts/claude-architect.md`, `prompts/codex-quality-engineer.md`, `prompts/cursor-developer.md`.

When the role's behavior changes:

1. Edit the canonical file first.
2. Update the portable mirror in the prompts directory in the same PR.
3. Note the change in your PR description so reviewers can confirm both files agree on the behavior.

Do not let the two surfaces drift. If they diverge, the canonical (auto-loaded) file wins.

---

## How to add a blueprint

A blueprint defines a reusable project type — marketing site, API service, Stripe app, and so on.

1. Create the blueprint file under the blueprints directory. Match the section order used in `blueprints/marketing-site.md`:
   - Purpose
   - Typical features
   - Recommended v1 scope
   - Explicit non-goals for v1
   - Recommended architecture (with Mermaid diagram)
   - Suggested stack
   - Architect intake questions
   - Required environment variables
   - API endpoints if applicable
   - Acceptance criteria
   - Test plan summary
   - Release checklist
2. Add every new env var to `templates/.env.example` in the appropriate section.
3. Add the blueprint to the file inventory in `MANIFEST.md` and `README.md`.
4. Add the path to `requiredFiles` in `scripts/validate-factory.mjs`.
5. Strongly recommended: ship a worked example. See "How to add a worked example" below.

Be specific about quality requirements. The validator rejects unmeasurable performance and accessibility claims; prefer numeric targets such as Largest Contentful Paint under 2.5 seconds, or named acceptance criteria such as keyboard-only navigation, visible focus, and 4.5:1 text contrast.

---

## How to add a worked example

Worked examples make a blueprint usable. Each blueprint should have a matching set of five files in the examples directory, covering:

- Project brief
- Architecture
- Test plan
- Cursor developer handoff
- Codex QE handoff

Use file names of the form `sample-<project>-<artifact>.md`. For example, the Stripe example uses `examples/sample-stripe-architecture.md` and four siblings. The original marketing-site example shipped first and omits the `<project>` prefix; new examples must use the prefixed naming.

After adding the five files:

1. Add each path to `requiredFiles` in `scripts/validate-factory.mjs` and to `MANIFEST.md`.
2. Link the example from the matching blueprint with an inline backtick reference to one of the new files.

---

## How to add or change a template

Templates in the templates directory are what each new project copies. They are the only files allowed to contain the unfilled-placeholder marker; the validator rejects that marker anywhere else.

1. Edit or add the template.
2. Keep placeholder markers for every value the user must fill in.
3. If you add a new template file, also add it to `requiredFiles` and to `MANIFEST.md`.
4. If the template introduces new env vars, add them to `templates/.env.example`.

---

## How to add or change a standard

Standards in the standards directory are cross-cutting rules referenced by role prompts. They should be short, opinionated, and free of buzzwords.

1. Edit or add the standard.
2. If the standard creates a new gate or expectation, update the relevant role files (`CLAUDE.md`, `AGENTS.md`, `.cursor/rules/ai-app-factory-developer.mdc`) and their `prompts/` mirrors.
3. If you add a new standard file, register it in `requiredFiles` and `MANIFEST.md`.

---

## How to write an Architecture Decision Record (ADR)

Create an ADR when the change is expensive to undo, security-sensitive, or likely to be questioned later. Examples: switching the default frontend framework, replacing Postmark with another provider, changing the default deploy target.

1. Create a file under the ADR directory named with a sequential number and a short kebab-case title.
2. Use the ADR template from `CLAUDE.md` section 9 (Status, Context, Decision, Alternatives Considered, Consequences, Follow-Up).
3. Reference the ADR from the affected blueprint or standard with an inline backtick path.

---

## How to update environment variables

`templates/.env.example` is the single source of truth for variable names.

1. Add the new variable in the section that fits (App, Azure, Database, Postmark, Stripe, Plaid, Anti-spam, etc.).
2. Use a placeholder value (empty string) unless the variable is one of the small allow-list of safe defaults already coded into the validator (`APP_ENV=local`, `PLAID_ENV=sandbox`, and so on).
3. Reference the same name in any blueprint, role file, or example that uses it. The validator fails the build if a doc references a variable that is not declared.

---

## How to deprecate or remove an artifact

1. Remove the file.
2. Remove its entry from `requiredFiles` in the validator.
3. Remove its row from `MANIFEST.md`.
4. Search the repo for backtick references to the removed path. The validator's link checker will surface any that remain.
5. If the artifact is replaced by another, add an ADR explaining the migration.

---

## Validator coverage at a glance

`scripts/validate-factory.mjs` enforces:

- Required files exist and are non-empty.
- All markdown code fences are balanced.
- The unfilled-placeholder marker only appears inside the templates directory.
- A small list of banned vague phrases never appears anywhere.
- JSON/JSONC files parse.
- `MANIFEST.md` backtick paths resolve.
- Every backtick path in any `.md`/`.mdc` file resolves (with sensible exemptions for placeholder syntax, branch-name-style strings, and HTTP routes).
- `templates/.env.example` contains only safe placeholders.
- Every env-var assignment referenced in any doc is declared in `templates/.env.example`.

When adding a new automated check, prefer extending this script over introducing a second tool, and keep each check self-contained.

---

## Release rhythm

This repository is the factory, not a shipping application, so there is no semver release cadence. Treat `main` as the canonical state. Tag a release when the operating model changes in a way downstream projects must adopt.
