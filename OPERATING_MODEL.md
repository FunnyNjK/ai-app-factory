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

The goal is not just to generate code. The goal is to create a disciplined process where AI agents act like a small software delivery team:

1. **Claude** acts as the Software Architect / Solution Designer.
2. **Cursor AI** acts as the Software Developer.
3. **Codex** acts as the Software Analyst / Quality Engineer.
4. **You** act as the Product Owner / Final Decision Maker.

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

Cursor builds in vertical slices.

Output per slice:

- Code changes
- Tests added
- Local validation commands
- Known issues
- Screenshots or API examples when useful
- Pull request notes

---

### Phase 5 — QE verification

Codex validates the build against requirements.

Output:

- Test execution summary
- Bugs found
- Risk assessment
- Regression recommendations
- Release readiness decision

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

#### Definition of Success — four-party sign-off

A project is **release-ready** only when each of the four parties below has signed off in writing inside the PR or release artifact. A project is **successful** only when all four sign-offs are present and the launch has met its release criteria.

1. **Claude (Architect)** — confirms the implementation matches the approved architecture, no silent design deviations, ADRs cover any deviations.
2. **Cursor (Developer)** — confirms acceptance criteria met, tests pass, no hard-coded secrets, runbook and README up to date.
3. **Codex (Quality Engineer)** — confirms test plan executed, critical journeys pass, security and accessibility smoke checks pass, release readiness decision is "Ready" or "Ready with documented risks."
4. **Human team (Product owner / technical owner)** — confirms business intent satisfied, documented risks accepted, release authorized.

A blocked sign-off must name a specific blocker. Vague concerns are not blockers. See `docs/adr/0006-three-agent-signoff.md` for the decision behind this gate.

### Gate E — Post-release review complete

The factory has captured:

- What worked
- What broke
- What was missing
- What should become a reusable template
- What prompts or standards should be updated

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

**Marketing site with contact form, Postmark email, and Azure Static Web Apps hosting**

Why:

- Small scope
- Real business use case
- Includes frontend, serverless API, email integration, environment variables, deployment, testing, and release checklist
- Creates reusable patterns for future projects
