# Sample Codex QE Handoff — Subscription SaaS with Stripe

## Quality objective

Validate that the subscription flow is correct, idempotent, and secret-safe end to end. Pay special attention to webhook reliability and dashboard gating.

---

## Business-critical workflows

1. Authenticated user starts a checkout, completes Stripe-hosted payment, and lands on an active dashboard.
2. Stripe webhook delivers `checkout.session.completed` and `customer.subscription.created`, app mirrors state.
3. User cancels from the Customer Portal; dashboard becomes gated within one minute.
4. Stripe retries a webhook with the same `event.id`; app processes it exactly once.
5. Operator receives Postmark notifications on subscription created, payment failure, and cancellation.

---

## Requirements to validate

- Auth required on all Stripe-initiating endpoints.
- Webhook signature verified against raw body using `STRIPE_WEBHOOK_SECRET`.
- Idempotency enforced on `stripe_event_id`.
- Subscription state mirror matches Stripe for the five v1 event types.
- Dashboard gating is server-side, not client-only.
- No card data stored locally.
- No secrets in frontend bundle, logs, or error responses.
- Postmark notifications fire for the three trigger events and never block the webhook 200.

---

## Highest-risk areas

| Area | Reason |
|---|---|
| Webhook handler | Signature failure or idempotency miss directly causes billing-state defects |
| Auth on Checkout / Portal endpoints | Lets a bad actor attach payments to another customer |
| Dashboard gate | A wrong gate means cancelled users keep paid access |
| Secret handling | Stripe live keys are high-value targets |
| Postmark notifications | Silent failure means operator never learns about cancellations |

---

## API checks

- `POST /api/checkout-session` without auth → `401`.
- `POST /api/checkout-session` with auth → `200`, body has a `checkout.stripe.com` URL.
- `POST /api/portal-session` without auth → `401`.
- `POST /api/portal-session` with auth → `200`, body has a `billing.stripe.com` URL.
- `POST /api/stripe-webhook` with missing `Stripe-Signature` → `400`, no DB write.
- `POST /api/stripe-webhook` with tampered signature → `400`, no DB write.
- `POST /api/stripe-webhook` with a valid `checkout.session.completed` → `200`, `Subscription` row exists, Postmark sent.
- Same event replayed → still `200`, second invocation does not write again and does not email again.
- `customer.subscription.deleted` → row updated, dashboard gate flips, Postmark sent.

---

## UI / E2E checks

- New user can sign up, hit the paywall, click Subscribe, and reach Stripe Checkout.
- Test card `4242 4242 4242 4242` succeeds and returns the user to the dashboard with active state.
- Test card `4000 0000 0000 9995` fails gracefully; the user sees a user-safe error and is not marked active.
- Cancel via Customer Portal; dashboard is gated within one minute on a hard reload.
- Loading and error states are visible during the Checkout redirect and the success-page state hydration.

---

## Integration checks

- Stripe CLI `trigger checkout.session.completed` produces a valid event that the app accepts.
- Stripe CLI `listen --forward-to localhost` works end-to-end against the local handler.
- Postmark sandbox stream receives the three notifications for a single test subscription lifecycle.

---

## Security checks

- Frontend bundle contains no `sk_test_`, `sk_live_`, or `whsec_` substring.
- Logs after a webhook run contain no header values, no payment-method metadata, and no full event payload.
- A request to `POST /api/portal-session` carrying another user's id in the body is rejected; only the authenticated subject is used.
- CORS on `/api/checkout-session` and `/api/portal-session` is restricted to the production origin.
- Replaying a captured webhook by an attacker is accepted only once and never reveals the secret.

---

## Accessibility checks

- Paywall page is keyboard usable; the Subscribe button has an accessible name.
- Loading and error states announce themselves to a screen reader.
- Color contrast on the subscription status indicator meets 4.5:1.

---

## Release gate recommendation

Release only after:

- All high-priority test cases pass in staging against Stripe test mode.
- A live-mode dry run in staging with a real card and immediate refund succeeds.
- Webhook signing secret in production is confirmed by sending a Stripe test event from the production dashboard.
- Rollback path is documented: how to disable the price, how to flip back to test mode, how to refund.
- Postmark sender domain is verified in production.
