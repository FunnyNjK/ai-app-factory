# Sample Gate D Sign-offs — Marketing Site

This is the worked exemplar of the four sign-offs from the marketing-site example (`examples/sample-project-brief.md` through `examples/sample-cursor-handoff.md`). It shows what each agent's written approval should look like under the corresponding checklist in the PR template.

Use this as the model when writing real Gate D sign-offs.

---

## Architect (Claude) sign-off

**Decision:** Approved

**What I reviewed:**

- `ARCHITECTURE.md` matches the deployed Azure footprint: Static Web Apps + a single Azure Function for `/api/contact` + Postmark; no database, as designed.
- ADRs in `docs/adr/` apply unchanged. No project-local ADRs were needed.
- `THREAT_MODEL.md` skipped per `templates/SECURITY.md` — contact-form submissions are Personal but low blast radius and the system has no persistent store. Documented in the project brief.
- `COST_ESTIMATE.md` shows ~$14/month at the v1 success-criteria load (Static Web Apps Standard $9, Postmark $15 amortized below the tier ceiling, Azure Functions effectively free at this volume). The 30-day live cost matches within 10%.
- Observability: Application Insights wired with the default fields from `standards/observability-standards.md`; the request, webhook, and provider dashboards are present; the P1 alerts on 5xx rate and webhook 4xx are configured.

**Notes:**

The implementation matches the architecture without deviation. Spam protection landed as honeypot + rate limit; Turnstile was deferred to v1.1 as planned and documented in the project brief. No accepted risks beyond what is already in the brief.

**Signed:** Claude (architect) — 2026-05-25

---

## Developer (Cursor) sign-off

**Decision:** Approved

**What I reviewed:**

- All acceptance criteria from the Cursor handoff pass: validation, success path, provider-failure path, distinct UI states, accessibility checks, deployment notes.
- Tests pass locally and in CI: 14 unit tests, 6 integration tests against a mocked Postmark client, 4 Playwright E2E tests.
- `.env.example` contains placeholders only. The production bundle was grep'd for `POSTMARK_SERVER_TOKEN` and `sk_` substrings; neither appears.
- `README.md` and `RUNBOOK.md` reflect the current implementation, including the deployment commands the operator will actually run.
- No design deviations were raised during build. Honeypot field name (`hp_company_url`) is documented in the security section so QA tests can verify it stays out of the visible form.

**Notes:**

One known limitation: rate-limit responses currently return `429` with a `Retry-After` header but the frontend treats all 429s as a generic rate-limit message rather than waiting and retrying. This is acceptable for v1 and documented in `RUNBOOK.md` under "Known limitations" for future enhancement.

**Signed:** Cursor (developer) — 2026-05-25

---

## Quality Engineer (Codex) sign-off

**Decision:** Ready with documented risks

**What I reviewed:**

- `TEST_PLAN.md` executed in full. All high-priority test cases pass.
- Critical journey: visitor opens home → reads services → submits valid contact → sees success state → business inbox receives email — verified end-to-end in staging.
- Negative cases: empty form, invalid email, oversized message, duplicate rapid submit, Postmark mock failure — all behave per spec.
- Security smoke checks pass: no secrets in bundle, CORS restricted to the production origin, error responses do not echo provider details, rate-limit triggers without sending email.
- Accessibility baseline passes: keyboard-only completion works, all form fields labelled, focus visible, heading order logical, contrast 4.5:1 or better on all foreground text.
- Observability: correlation id flows from browser through Function to Application Insights; a synthetic 500 from the Postmark mock triggers the configured P1 alert within 5 minutes.

**Notes:**

One documented risk: there is no anti-bot beyond the honeypot and IP rate-limit. If real-world spam exceeds the rate-limit budget after launch, Turnstile is the planned v1.1 mitigation. Risk owner: product owner. Re-review date: 2026-08-25 (3 months post-launch).

**Signed:** Codex (quality engineer) — 2026-05-25

---

## Product owner / technical owner sign-off

**Decision:** Release approved with accepted risks

**What I reviewed:**

- Each of the three agent sign-offs above.
- The single accepted risk (no Turnstile in v1). I accept it on the basis that the rate-limit + honeypot stack has handled comparable contact endpoints for our other businesses; the cost of Turnstile is not zero and the v1.1 migration path is clear.
- Rollback plan in `RUNBOOK.md`: revert the Static Web App and Function App to the previous release tag, then re-verify the contact endpoint. I have done this exact procedure for prior projects.
- Cost: $14/month expected, $20/month at 5x expected load. Acceptable.
- Operational ownership: I operate it.

**Notes:**

Approving release. Schedule the 3-month re-review on the calendar; if spam exceeds 10 submissions/day post-launch, fast-track Turnstile.

**Signed:** Tommy (product owner) — 2026-05-25
