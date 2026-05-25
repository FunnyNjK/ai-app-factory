# First Project Walkthrough — From Vague Idea to Approved Brief

This playbook shows the conversation that produces a factory project brief from a one-sentence idea. It maps directly onto the marketing-site example in `examples/sample-project-brief.md`; reading the brief shows you the output, this walkthrough shows you the process.

Use it as a reference the first time you run Intake Mode. After two or three projects you will not need it.

---

## 0. Setting

A product owner types into the architect agent:

> I want a marketing site for my local services business with a contact form.

That is the entire input. The architect now goes into Intake Mode.

---

## 1. Architect responds with classification and default critical 10

The architect does not ask 100 questions. It classifies the project and asks the default-10 from `CLAUDE.md` section 5, skipping any whose answer is already obvious.

**Architect:**

> Sounds like a marketing-site blueprint with a contact form and transactional email. Before I design anything, I need answers to the questions below. Skip any you have already settled. If you do not have an answer yet, say "open" and I will use a documented assumption.
>
> 1. What is the business goal of this project, in one sentence?
> 2. Who are the primary users, and what is their first session supposed to accomplish?
> 3. What must be in v1, and what is explicitly excluded from v1?
> 4. What are the success criteria for v1?
> 5. What authentication and authorization model is required, if any?
> 6. Classify each stored data type (Public / Internal / Personal / Financial / Health / Secret), and name what must never be stored.
> 7. Which external integrations (Stripe, Plaid, Postmark, Azure services, others) are mandatory in v1?
> 8. Where will this be deployed, and who operates it after launch?
> 9. What is the target launch date or external deadline?
> 10. What is the single biggest risk you already see?

---

## 2. Product owner answers — sometimes incompletely

**Product owner:**

> 1. Generate qualified inbound leads for a local services business.
> 2. Website visitors — prospective customers. First session goal: understand what we offer and contact us.
> 3. In: home page, services section, contact form. Out: blog, CMS, login, payments.
> 4. Open — what should success look like?
> 5. None. Public site.
> 6. Contact-form submissions are Personal. Nothing financial or health. Never store cookies beyond analytics consent.
> 7. Postmark for the contact email.
> 8. Azure Static Web Apps + Azure Functions, hosted in my existing Azure tenant. I operate it.
> 9. 4 weeks.
> 10. That nobody will fill out the form (zero leads).

Notes the architect picks up:

- Q4 is "open" — the architect must propose success criteria, not leave them blank.
- Q10 is a business risk (no demand), not a technical risk. The architect should still capture it; it will inform analytics in v1.

---

## 3. Architect proposes success criteria and surfaces assumptions

**Architect:**

> Two follow-ups before I move to architecture.
>
> **Proposed success criteria for v1** (please accept, reject, or revise each):
>
> 1. The site is reachable on its production domain at the launch date.
> 2. Largest Contentful Paint is under 2.5 seconds on the production home page during release smoke testing.
> 3. Contact-form submissions are delivered to the business inbox.
> 4. The user receives clear feedback for each of: success, validation failure, rate-limited, bot-check failure, provider failure.
> 5. The site has no console errors and meets a keyboard-only, label-present, focus-visible, 4.5:1-contrast accessibility baseline.
> 6. Deployment is documented and reproducible from the runbook.
>
> **Assumptions I am about to make** (correct any of these):
>
> - The site is English-only and US-only.
> - Spam protection is needed because the contact endpoint is public; I will recommend a honeypot + rate limit and add Cloudflare Turnstile as an optional upgrade.
> - You do not want to store contact submissions in a database for v1; Postmark email is the system of record.
> - The biggest delivery risk is Postmark sender-domain verification not being complete by launch day; I will flag this in the release checklist.

---

## 4. Product owner confirms with minor changes

**Product owner:**

> Success criteria all good, but make LCP under 2.0 seconds. Assumptions all good.

---

## 5. Architect closes the intake and announces the next step

**Architect:**

> Intake complete. Moving to Design Mode next. The output will be:
>
> 1. `PROJECT.md` (project brief) — formal version of what we just agreed.
> 2. `ARCHITECTURE.md` (component diagram, data flow, API contract, security model, deployment plan).
> 3. `THREAT_MODEL.md` (STRIDE pass on the contact endpoint).
> 4. `COST_ESTIMATE.md` (monthly Azure + Postmark cost).
> 5. Cursor developer handoff and Codex QE handoff.
>
> If anything in the intake should change between now and Cursor starting, raise it. After Cursor begins, design changes go through an ADR.

The architect then writes the brief — and `examples/sample-project-brief.md` is the result.

---

## What this walkthrough is teaching

- Intake Mode is a few rounds, not one. The architect proposes when the owner gives "open."
- The architect names assumptions explicitly so the owner can override before they harden.
- The output of intake is one paragraph longer than the input but several orders of magnitude more useful.
- The architect closes by naming what is produced next and where design changes will live (ADRs).

For a more complex project, replace the marketing-site classification with the right blueprint (`blueprints/stripe-app.md`, `blueprints/plaid-app.md`, etc.) and run the same loop with the relevant deeper-exploration questions from `prompts/claude-architect.md`.
