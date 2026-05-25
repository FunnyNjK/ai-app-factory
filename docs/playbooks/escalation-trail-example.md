# Escalation Trail Example — Stripe Webhook Race Condition

This playbook shows the architect's escalation protocol (`CLAUDE.md` Section 12) firing in practice. It is a realistic mid-implementation scenario from the Stripe subscription example (`examples/sample-stripe-architecture.md`), reconstructed to show what each agent actually says and what the architect produces in response.

Use this as the model when Cursor or Codex raises a real concern during build.

---

## Setting

Cursor is in the middle of implementing `examples/sample-stripe-cursor-handoff.md`. The webhook handler and the idempotency log are working. The Postmark notification on `customer.subscription.deleted` is the next slice. Codex is running its integration tests against the staging environment.

---

## 1. Codex flags the concern

Codex posts in the PR:

> **Concern raised, severity: P1 (architectural).**
>
> While running the Stripe subscription lifecycle integration suite, I exercised the case where the `checkout.session.completed` webhook arrives *before* the user's session has redirected back from Stripe Checkout. The current handler upserts `Customer` and `Subscription` rows correctly, but the `Customer` row's `user_id` is `null` at that moment because the redirect handler is the only path that links the Stripe customer id back to the app user id.
>
> Reproduction: trigger a sandbox `checkout.session.completed` via `stripe trigger` immediately after the Stripe Checkout redirect URL is generated but before the user has actually completed Checkout. The race window in production is small (typically < 5 seconds) but it is non-zero, and a determined attacker who controls the timing of the redirect can produce orphaned `Subscription` rows that bypass the dashboard gate.
>
> Affected artifact: `examples/sample-stripe-architecture.md` Data flow section and `examples/sample-stripe-cursor-handoff.md` step 5.
>
> Requesting architect review before I sign off the test plan.

---

## 2. Architect (Claude) evaluates

The protocol requires picking one of: amend via new ADR, amend via existing ADR, push back with reasoning, or escalate. The architect runs through that decision tree:

- **Is the concern real?** Yes. The race window exists and the consequence (orphaned subscription, gate bypass) is high-impact. STRIDE Elevation-of-Privilege coverage in `examples/sample-stripe-threat-model.md` missed this specific ordering case.
- **Was the original design correct?** No. The design implicitly assumed redirect-before-webhook ordering, which Stripe does not guarantee.
- **Is this a misunderstanding I should push back on?** No. The reproduction is clear and the threat is plausible.
- **Is there a business question for the product owner?** Not at this stage. The fix is purely architectural.

Decision: amend the architecture via a new ADR.

---

## 3. Architect writes ADR-0008

The architect drafts `docs/adr/<NNNN>-stripe-checkout-customer-linkage-ordering.md` and attaches it to the PR.

Excerpt (the full ADR follows the template):

> **Status:** Accepted
>
> **Context:** Stripe does not guarantee that the user's redirect back from Checkout precedes the `checkout.session.completed` webhook. Our handler assumed it did. Codex identified the resulting race in staging.
>
> **Decision:** Move the `user_id ↔ stripe_customer_id` linkage to *Checkout session creation time*, not redirect time. When `/api/checkout-session` mints the Stripe session, it persists the mapping in the `Customer` table with `user_id` already populated, using `client_reference_id` on the Stripe session as the durable correlation key. The webhook handler then idempotently upserts using `client_reference_id` and never produces an orphaned `Subscription`.
>
> **Alternatives considered:** (1) hold the webhook in a queue until the redirect arrives — adds latency, fragile timeout policy. (2) accept the orphan and reconcile on the next user login — leaves a real attack window. (3) reject webhooks for unknown `stripe_customer_id` — generates Stripe webhook retries indefinitely and breaks the existing idempotency design.
>
> **Consequences (positive):** No race window. Reduced reliance on redirect ordering. Cleaner idempotency.
>
> **Consequences (negative):** `/api/checkout-session` is no longer a pure pass-through; it must persist a row. Adds one DB write per checkout attempt; trivial cost.
>
> **Follow-up:** Update `examples/sample-stripe-architecture.md` and `examples/sample-stripe-cursor-handoff.md`. Add an integration test that fires the webhook before the redirect handler is reached.

---

## 4. Architect notifies the team

The architect comments on the PR:

> Accepting Codex's concern. ADR-0008 documents the fix. Three artifacts need updates in this PR:
>
> - `examples/sample-stripe-architecture.md` — data-flow section now shows linkage at session creation, not redirect.
> - `examples/sample-stripe-cursor-handoff.md` — Implementation sequence step 3 grows a sub-step: persist the `Customer` row with `user_id` before returning the session URL.
> - `examples/sample-stripe-test-plan.md` — add a test case for the webhook-arrives-before-redirect ordering.
>
> Cursor: please re-sequence step 3 per the ADR. Codex: please confirm the new test case is what you had in mind. I will update the two affected example files in a sibling PR; do not block on those updates if you are otherwise green.

---

## 5. Cursor and Codex respond

Cursor:

> Acknowledged. Re-sequencing step 3 now. Estimated 2 hours including the unit test for the linkage write. Will report back.

Codex:

> Confirmed. Adding the ordering test case to the test plan. Will mark Codex sign-off pending until the new test case passes against the updated handler.

---

## 6. Outcome

The PR ships with:

- The ADR (`docs/adr/<NNNN>-stripe-checkout-customer-linkage-ordering.md`).
- Cursor's revised implementation.
- Codex's new test case, now passing.
- A note in the PR description naming the escalation: "ADR-0008 closes Codex P1 concern raised during integration tests."

At Gate D, all three agent sign-offs reference ADR-0008 explicitly. The product owner's sign-off accepts no residual risk because the race window was eliminated, not deferred.

---

## What this playbook is teaching

- The architect does not defend the original design reflexively. When the concern is real, ship an ADR fast and update the affected artifacts.
- The architect's options are explicit: amend via new ADR, amend an existing one, push back with reasoning, or escalate to the product owner. "Silent change" is never one of the options.
- Codex's concern survives in the audit trail through the ADR and the new test case, not just a closed Slack thread.
- Cursor receives a precise re-sequencing instruction tied to a referenceable decision, not a vague rewrite.
- At Gate D, every sign-off references the escalation, so future readers can reconstruct why the design has the shape it has.

For the policy this playbook implements, see `CLAUDE.md` Section 12 (Architect Escalation Protocol) and `docs/adr/0006-three-agent-signoff.md`.
