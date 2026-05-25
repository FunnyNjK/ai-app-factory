# Sample Test Plan — Subscription SaaS with Stripe

## Quality objective

Confirm that authenticated users can subscribe through Stripe Checkout, that subscription state is mirrored correctly via webhooks, that idempotency holds under retries, and that secrets and card data never leak.

---

## Risk matrix

| Area | Risk | Likelihood | Impact | Priority |
|---|---|---:|---:|---:|
| Webhook signature verification | Accept forged events | Low | High | High |
| Webhook idempotency | Duplicate state writes or emails on retry | Medium | High | High |
| Auth gating on Checkout endpoint | Anonymous user creates checkout for another customer | Medium | High | High |
| Subscription state mirror | Drift between Stripe and local DB | Medium | High | High |
| Dashboard gating | Cancelled user retains access | Medium | Medium | Medium |
| Postmark notification | Email never sent, or sent with wrong template | Medium | Medium | Medium |
| Secret exposure | Stripe key reachable from frontend bundle | Low | High | High |
| Payment failure flow | App treats failed payment as active | Medium | High | High |

---

## Acceptance criteria

- Anonymous request to `POST /api/checkout-session` returns `401`.
- Authenticated request creates a Stripe Checkout session and returns a `https://checkout.stripe.com/...` URL.
- Successful Stripe test card flow ends with `Subscription.status = 'active'` for the user.
- Failed test card flow does not mark the subscription active.
- `checkout.session.completed` retried by Stripe produces exactly one DB write and exactly one Postmark email.
- Customer Portal cancellation produces `customer.subscription.deleted` and gates the dashboard within 60 seconds.
- Webhook request with a tampered signature returns `400` and is not processed.
- `STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET` are absent from any built frontend bundle and any log line.
- No card PAN or CVV appears in any log line or DB row.

---

## Unit tests

- Stripe Checkout session payload builder includes `mode=subscription`, the configured `price_id`, the correct `success_url` and `cancel_url`, and the customer's `stripe_customer_id` when known.
- Customer Portal session builder returns the current user's `stripe_customer_id`.
- Webhook signature verifier rejects mismatched signatures, expired timestamps, and missing header.
- Idempotency-log helper returns `processed` on second insert with the same `stripe_event_id`.
- Event handler dispatcher maps the five v1 event types to the right handler and ignores unknown types.

---

## Integration tests

- `POST /api/checkout-session` with no auth header returns `401`.
- `POST /api/checkout-session` with a valid session returns a URL and records a `Customer` row if one did not exist.
- `POST /api/stripe-webhook` with an invalid signature returns `400`.
- `POST /api/stripe-webhook` with a valid `checkout.session.completed` event inserts a `Subscription` row.
- `POST /api/stripe-webhook` with the same `event.id` twice writes only once.
- `customer.subscription.updated` with `cancel_at_period_end=true` updates the row and triggers no email yet.
- `customer.subscription.deleted` clears `active` status and sends the cancellation email.
- `invoice.payment_failed` sends the payment-failure email and does not mark inactive immediately.

---

## E2E tests

- Test card `4242 4242 4242 4242` completes the full Checkout flow and lands on the dashboard with active status visible.
- Test card `4000 0000 0000 9995` (insufficient funds) lands on the cancel/error page and does not activate the subscription.
- From the Customer Portal, cancel the subscription and confirm the dashboard becomes gated within one minute.
- Reload the dashboard after cancellation in a fresh session and confirm the gate holds.

---

## Security smoke tests

- Build the production frontend bundle and grep for `sk_live_`, `sk_test_`, `whsec_` — none should appear.
- Inspect server logs after a webhook run — no header values, no full event payloads, no card metadata.
- Attempt `POST /api/portal-session` with the user ID of another customer in the body — must be ignored; the server uses the authenticated subject only.
- Replay a captured valid webhook request against the endpoint — must be accepted only once (idempotency) and never expose the secret.

---

## Performance checks

- Checkout endpoint p95 latency under 300 ms (Stripe API call dominates; this is a sanity gate).
- Webhook handler p95 latency under 500 ms; long work moved to a queue if any handler exceeds it.

---

## Test data

| Data set | Purpose |
|---|---|
| Stripe test prices (one monthly) | Drives Checkout |
| Stripe test customers | Mapped to seeded app users |
| Stripe CLI `trigger` events | Drives webhook integration tests locally |
| Postmark sandbox stream | Avoid sending real email during E2E |

---

## Release criteria

- All high-priority test cases above pass.
- A live-mode dry run in staging with a real card and immediate refund succeeds.
- Stripe webhook endpoint is registered in the production Stripe Dashboard and emits a successful test event.
- Rollback path documented in the runbook: how to disable the price, how to flip the env to test mode, how to refund.
