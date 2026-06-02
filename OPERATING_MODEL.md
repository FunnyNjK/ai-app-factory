# AI App Factory — Operating Model

## Purpose

**AI App Factory** is a repeatable delivery system for creating web-based software projects, including:

- Marketing sites
- Static web apps
- Full-stack web apps
- REST or GraphQL APIs
- Azure Functions and serverless workflows
- Cloud storage integrations
- SQL or NoSQL databases
- Key vault and secret management
- Stripe or Plaid integrations
- Postmark email workflows
- CI/CD, testing, monitoring, and release checklists

The goal is not just to generate code. The goal is to create a disciplined process where AI agents act like a small software delivery team. The team is five agent roles plus the product owner; which CLI tool drives each role is a per-project decision recorded in `.factory-roles.json` (see `docs/adr/0013-configurable-roles-and-tools.md`). The default mapping:

1. **Architect** (default: Claude) — Software Architect / Solution Designer.
2. **Developer** (default: Cursor) — Software Developer.
3. **Quality Engineer** (default: Codex) — Software Analyst / Quality Engineer.
4. **Security** (default: Codex) — per-phase security reviewer.
5. **Code Review** (default: Claude) — per-phase maintainability reviewer.
6. **You** — Product Owner / Final Decision Maker.

---

---

## Scope

The factory targets **greenfield projects only**. Each blueprint, template, and worked example assumes a fresh start: no legacy database to migrate, no existing API to preserve, no production traffic to dark-launch behind. Brownfield evolution is out of scope; see `docs/adr/0005-greenfield-only-scope.md` for the rationale and the conditions under which this scope would be revisited.

---

## 1. Core Factory Principles

### 1.1 Business-first architecture

Every project starts with the business goal, user goal, constraints, risks, and success criteria before choosing frameworks or cloud services.

### 1.2 Architecture before implementation

Cursor should not start coding until Claude has produced enough architecture, requirements, trade-offs, and acceptance criteria to build against.

### 1.3 Quality is designed in, not inspected in later

Codex should review requirements and architecture before implementation begins. QE work starts at project inception, not after code is complete.

### 1.4 Small vertical slices

Projects should be delivered in thin, usable increments:

- One route
- One API endpoint
- One database table or collection
- One integration path
- One deployed environment
- One tested user flow

### 1.5 Explicit trade-offs

Every major decision should include why it was chosen, what alternatives were considered, and what risks remain.

### 1.6 Secure by default

Secrets never live in source code. Use environment variables locally and cloud secret management in deployed environments. Payment and financial integrations must use provider-recommended secure flows and webhook verification.

### 1.7 Repeatable outputs

Every project should produce reusable artifacts: architecture notes, diagrams, ADRs, API contracts, environment setup, test plan, runbook, and release checklist.

---

## 2. Agent Team Structure

The five roles below are described by their default tools. Any of the four supported CLIs (Claude, Cursor, Codex, Gemini) can fill any role, per project, via `.factory-roles.json` (see `docs/adr/0013-configurable-roles-and-tools.md`).

### 2.1 Claude — Software Architect / Solution Designer

Claude owns system design, technical direction, project framing, and implementation handoff.

#### Responsibilities

- Clarify the business problem.
- Ask the important questions before solutioning.
- Identify assumptions, constraints, and risks.
- Choose an architecture appropriate to the project size.
- Define the cloud, data, integration, and security model.
- Produce implementation-ready specifications.
- Create handoff documents for Cursor and Codex.
- Maintain architectural consistency across projects.

#### Claude should produce

- Project brief
- Question list
- Assumptions and unknowns
- Architecture recommendation
- C4-style diagrams or Mermaid diagrams
- Data flow diagram
- API contract
- Data model
- Security model
- Deployment model
- Environment plan
- Work breakdown structure
- Architectural Decision Records
- Cursor handoff
- Codex/QE handoff

---

### 2.2 Cursor AI — Software Developer

Cursor owns implementation. Cursor turns the architecture into working software.

#### Responsibilities

- Implement the approved architecture.
- Create or update the codebase.
- Build the frontend, backend, APIs, functions, integrations, and infrastructure code.
- Add automated tests.
- Maintain clean code and project structure.
- Follow the agreed conventions.
- Flag blockers and architectural deviations early.
- Keep implementation aligned with acceptance criteria.

#### Cursor should produce

- Working code
- Unit tests
- Integration tests
- API tests
- Local development setup
- Environment variable examples
- Build scripts
- CI/CD pipeline configuration
- Infrastructure as Code when applicable
- README updates
- Implementation notes
- Known issues and follow-up tasks

---

### 2.3 Codex — Software Analyst / Quality Engineer

Codex owns requirements analysis, test strategy, quality risk, and release confidence.

#### Responsibilities

- Review requirements before implementation.
- Identify ambiguity, missing rules, and edge cases.
- Convert business goals into acceptance criteria.
- Create risk-based test plans.
- Design automated test coverage.
- Validate API, UI, data, integration, performance, security, and accessibility behavior.
- Write clear bug reports.
- Recommend release readiness.

#### Codex should produce

- Requirements review
- Ambiguity list
- Acceptance criteria
- Test strategy
- Test cases
- Regression suite outline
- API test plan
- E2E test plan
- Accessibility checklist
- Security smoke checklist
- Performance/load test recommendations
- Defect reports
- Release readiness assessment

---

### 2.4 Security — Per-Phase Security Reviewer

The security role (default tool: Codex) owns the per-phase security gate introduced by `docs/adr/0013-configurable-roles-and-tools.md`.

#### Responsibilities

- Review each completed phase for vulnerabilities before the phase is declared done.
- Verify input validation, authentication, authorization, and webhook signature verification at trust boundaries.
- Verify no secrets are committed and logs do not leak sensitive data.
- Harden in place where the fix is mechanical; escalate judgment calls to the product owner.
- Record a Gate D security sign-off.

#### Security should produce

- Per-phase security gate notes in `TASKS.md`
- Security sub-tasks for findings that block the phase
- A Gate D sign-off with a "Pass" or "Pass with documented risks" decision

---

### 2.5 Code Review — Per-Phase Maintainability Reviewer

The code-review role (default tool: Claude) owns the per-phase code-review gate introduced by `docs/adr/0013-configurable-roles-and-tools.md`.

#### Responsibilities

- Review each completed phase for readability, duplication, naming, and structure.
- Apply behavior-preserving refactors where safe; file sub-tasks for larger ones.
- Confirm the codebase meets `standards/coding-standards.md`.
- Track accepted maintainability debt explicitly rather than letting it accumulate silently.
- Record a Gate D code-review sign-off.

#### Code Review should produce

- Per-phase code-review gate notes in `TASKS.md`
- Refactoring sub-tasks for findings that block the phase
- A Gate D sign-off confirming standards compliance and tracked maintainability debt

---

## 3. Standard Project Workflow

### Phase 0 — Project request

The product owner provides the initial idea.

Example:

> I want a marketing site for a local service business with a contact form, Postmark email notifications, Azure Static Web Apps hosting, and analytics.

Claude starts by classifying the project and determining what questions must be answered.

---

### Phase 1 — Architect intake

Claude asks only the questions needed to move forward.

Output:

- Project type
- Initial scope
- Required answers
- Assumptions
- Risks
- Recommended next step

---

### Phase 2 — Architecture package

Claude creates an implementation-ready design.

Output:

- Executive summary
- Requirements
- Non-functional requirements
- Architecture diagram
- Data flow
- API design
- Integration design
- Security model
- Environment model
- Deployment plan
- Work breakdown
- ADRs
- Cursor handoff
- Codex handoff

---

### Phase 3 — Quality review

Codex reviews the architecture and requirements before Cursor builds.

Output:

- Ambiguities
- Missing requirements
- Testability concerns
- Risk matrix
- Acceptance criteria
- Test plan
- Release gate recommendations

---

### Phase 4 — Implementation

Cursor builds in vertical slices. Each slice is gated by Codex review before the next slice begins (see `docs/adr/0008-per-slice-and-per-phase-gating.md`). Slice status moves through `pending → in-progress → awaiting-review → approved` in the project's `TASKS.md`. If Codex files sub-tasks, the slice returns to `in-progress` until the per-task iteration cap or approval.

Output per slice:

- Code changes
- Tests added
- Local validation commands
- Known issues
- Screenshots or API examples when useful
- Pull request notes
- Slice status updated in `TASKS.md`

---

### Phase 5 — QE verification

Codex validates the build against requirements. Codex performs per-slice review during Phase 4 (filing sub-tasks when slices fail acceptance criteria); at each phase boundary, when every slice in a phase reaches `approved`, Claude performs a per-phase review (see `docs/adr/0008-per-slice-and-per-phase-gating.md`). After the architect's phase review is approved, the security gate and then the code-review gate run; all three must be `approved` before the next phase begins (see `docs/adr/0013-configurable-roles-and-tools.md`). Any iteration cap hit or judgment call routes to `ESCALATIONS.md` for the product owner.

Output:

- Test execution summary
- Bugs found (filed as sub-tasks in `TASKS.md` during slice review)
- Risk assessment
- Regression recommendations
- Release readiness decision
- Phase review notes from Claude

---

### Phase 6 — Release and runbook

Claude and Codex help confirm release readiness.

Output:

- Release checklist
- Deployment notes
- Rollback plan
- Monitoring plan
- Post-release validation checklist

---

### Phase 7 — Factory improvement

After each project, update reusable templates, prompts, standards, and blueprints.

---

## 4. Quality Gates

### Gate A — Project ready for architecture

The project has:

- Business goal
- Target users
- Initial scope
- Success criteria
- Major constraints

### Gate B — Architecture ready for implementation

The architecture has:

- Clear scope
- Chosen tech stack
- Component design
- Data design
- API/integration design
- Security model
- Deployment model
- Acceptance criteria
- Known risks

### Gate C — Implementation ready for QE

The implementation has:

- Working local setup
- Required features complete
- Tests added
- No hardcoded secrets
- README updated
- Known deviations documented

### Gate D — Release candidate ready

The release candidate has:

- Passing automated tests
- Critical user journeys verified
- API behavior verified
- Integration behavior verified
- Security smoke checks complete (including a threat-model review where applicable)
- Accessibility baseline checked
- Monitoring/logging reviewed against `standards/observability-standards.md`
- Cost estimate reviewed against the live cost shape (`templates/COST_ESTIMATE.md`)
- Rollback plan documented

#### Definition of Success — six-party sign-off

A project is **release-ready** only when each of the six parties below has signed off in writing inside the PR or release artifact. A project is **successful** only when all six sign-offs are present and the launch has met its release criteria. Each agent role is driven by whichever tool the project mapped to it in `.factory-roles.json` (`docs/adr/0013-configurable-roles-and-tools.md`); the names below are the default roles.

1. **Architect** — confirms the implementation matches the approved architecture, no silent design deviations, ADRs cover any deviations.
2. **Developer** — confirms acceptance criteria met, tests pass, no hard-coded secrets, runbook and README up to date.
3. **Quality Engineer** — confirms test plan executed, critical journeys pass, security and accessibility smoke checks pass, release readiness decision is "Ready" or "Ready with documented risks."
4. **Security** — confirms the per-phase security gates passed, no secrets in the tree, input validation / authorization / webhook verification hold, decision is "Pass" or "Pass with documented risks."
5. **Code Review** — confirms the per-phase code-review gates passed, the codebase meets the coding standards, and any accepted maintainability debt is tracked.
6. **Human team (Product owner / technical owner)** — confirms business intent satisfied, documented risks accepted, release authorized. Every accepted risk names an owner and an explicit re-review date (`docs/adr/0010-gate-d-signoff-adapter.md`); an acceptance without a re-review date is not a valid sign-off.

A blocked sign-off must name a specific blocker. Vague concerns are not blockers. See `docs/adr/0013-configurable-roles-and-tools.md` (which supersedes `docs/adr/0006-three-agent-signoff.md`) for the decision behind this gate.

### Gate E — Post-release review complete

The factory has captured:

- What worked
- What broke
- What was missing
- What should become a reusable template
- What prompts or standards should be updated

For any SEV2-or-worse incident, capture a full blameless post-incident review using `templates/INCIDENT.md`, and feed its "Lessons and feedback" back into the factory's standards and templates.

---

## 5. First Factory Backlog

### Create prompt files

- `prompts/claude-architect.md`
- `prompts/cursor-developer.md`
- `prompts/codex-quality-engineer.md`

### Create blueprint files

- `blueprints/marketing-site.md`
- `blueprints/static-web-app.md`
- `blueprints/full-stack-web-app.md`
- `blueprints/api-service.md`
- `blueprints/azure-functions.md`
- `blueprints/stripe-app.md`
- `blueprints/plaid-app.md`
- `blueprints/postmark-email.md`

### Create project templates

- `PROJECT.md`
- `ARCHITECTURE.md`
- `API_SPEC.md` for API-first and webhook projects
- `SECURITY.md`
- `TEST_PLAN.md`
- `RELEASE_CHECKLIST.md`
- `RUNBOOK.md`
- `.env.example`

### Create standards

- Coding standards
- API standards
- Testing standards
- Security standards
- Git workflow
- CI/CD expectations
- Documentation expectations

---

## 6. Recommended First Project

Start with:

### Marketing site with contact form, Postmark email, and Azure Static Web Apps hosting

Why:

- Small scope
- Real business use case
- Includes frontend, serverless API, email integration, environment variables, deployment, testing, and release checklist
- Creates reusable patterns for future projects
