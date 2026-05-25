# Sample Cursor Developer Handoff — Subscription SaaS with Stripe

## Build objective

Implement an authenticated subscription SaaS that uses Stripe Checkout to start subscriptions, Stripe Customer Portal for self-service billing, and a single webhook endpoint to mirror Stripe state into a local database. Send Postmark emails on subscription state changes.

---

## Scope

- Auth-protected dashboard
- `POST /api/checkout-session` Azure Function
- `POST /api/portal-session` Azure Function
- `POST /api/stripe-webhook` Azure Function with signature verification and idempotency
- Database tables: `Customer`, `Subscription`, `WebhookEvent`
- Postmark notifications for subscription created, payment failed, and cancelled
- Tests for each endpoint and each webhook event handler
- `.env.example` updates
- README and `RUNBOOK.md` updates

---

## Non-goals

- Multiple plans or pricing tiers
- Coupons or proration
- Refund self-service
- Marketplace / Connect flows
- Custom-built card form (use Stripe Checkout)

---

## Tech stack

- Frontend: Next.js or React + Vite (whichever the auth provider integrates with most cleanly)
- API: Azure Functions in TypeScript
- Database: Azure SQL or PostgreSQL via Prisma or Drizzle
- Email: Postmark
- Tests: Vitest or Jest; Playwright for E2E
- Hosting: Azure Static Web Apps + Azure Functions

---

## Required environment variables

```bash
APP_BASE_URL=
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
STRIPE_PRICE_ID=
POSTMARK_SERVER_TOKEN=
POSTMARK_FROM_EMAIL=
DATABASE_URL=
```

All of these are already declared in `templates/.env.example`. Do not introduce new names without updating the template.

---

## Implementation sequence

1. Add the three new database tables and a migration.
2. Implement auth-protected dashboard route. Confirm an anonymous request is redirected.
3. Implement `POST /api/checkout-session`. Require auth. Create-or-fetch the user's `Customer` row before creating the Stripe session.
4. Add success/cancel landing pages.
5. Implement `POST /api/stripe-webhook` with raw-body signature verification. Reject invalid signatures before any parsing.
6. Add the `WebhookEvent` idempotency log. Insert with `stripe_event_id` as a unique constraint; only run handlers on first insert.
7. Implement handlers for `checkout.session.completed`, `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted`, and `invoice.payment_failed`.
8. Implement Postmark notifications, fired best-effort after the DB write.
9. Implement `POST /api/portal-session`.
10. Gate the dashboard on `Subscription.status in ('active','trialing')` and `current_period_end > now`.
11. Add unit and integration tests for the items above.
12. Update `README.md` and `RUNBOOK.md` with local setup, Stripe CLI forwarding, and deploy steps.

---

## Acceptance criteria

- Anonymous `POST /api/checkout-session` returns `401`.
- Authenticated request returns a Stripe Checkout URL.
- Successful test-card flow ends with `Subscription.status = 'active'`.
- Duplicate `event.id` from Stripe writes once and emails once.
- Tampered webhook signature returns `400` and is never parsed.
- Cancelled subscription gates the dashboard within 60 seconds.
- No Stripe secret appears in the frontend bundle or any log line.
- Tests cover the five event types and the auth + signature negative paths.

---

## Known risks

- Stripe SDK error mapping: bubbled error messages may include detail unsafe for end users. Map to a generic message before returning.
- Local Stripe webhook testing needs the Stripe CLI; document the exact command in the runbook.
- Database migrations must run before the first webhook delivery in production. Sequence the deploy.

---

## Do not do

- Do not store card data, CVV, or full PAN.
- Do not parse the webhook body before verifying the signature.
- Do not depend on Postmark success before responding `200` to Stripe.
- Do not introduce a third event-handling path; route everything through the single webhook function and the idempotency log.
- Do not commit `sk_live_*`, `sk_test_*`, or `whsec_*` values.
