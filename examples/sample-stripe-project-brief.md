# Sample Project Brief — Subscription SaaS with Stripe Checkout

## Project name

Example Subscription SaaS

## Project type

Full-stack web app with Stripe Checkout, Stripe Customer Portal, Stripe webhooks, and Postmark transactional email.

---

## Executive summary

Build a small SaaS application where authenticated users can subscribe to a single monthly paid plan through Stripe-hosted Checkout, manage their subscription through the Stripe Customer Portal, and receive Postmark confirmation emails on subscription state changes. Entitlement state is mirrored in a local database driven by Stripe webhook events.

---

## Business goal

Convert authenticated users into paying subscribers with the smallest amount of custom payment code possible. Treat Stripe as the source of truth for billing state and the local database as a thin entitlement cache.

---

## Target users

| User type | Description | Primary needs |
|---|---|---|
| New visitor | Prospective subscriber | Understand the offer, sign up, pay quickly |
| Authenticated user | Trial or paid user | Upgrade, manage billing, cancel without contacting support |
| Business owner | Operator | See active subscriptions, reconcile against Stripe, handle failed payments |
| Developer/operator | Maintainer | Deploy safely, rotate keys, replay webhooks |

---

## Primary user journeys

1. New user signs up, lands on a paywalled dashboard.
2. User clicks "Subscribe", is redirected to Stripe Checkout, completes payment.
3. User is redirected back to the app and sees their subscription active.
4. User opens the Customer Portal to update payment method or cancel.
5. Operator receives a Postmark notification on payment failure and on cancellation.

---

## In scope for v1

- Email + password (or OAuth) authentication
- Single recurring price (monthly)
- Stripe-hosted Checkout session creation server-side
- Stripe Customer Portal session creation
- Stripe webhook endpoint with signature verification and idempotent processing
- Local `Customer`, `Subscription`, and `WebhookEvent` tables
- Postmark notifications for payment success, payment failure, and cancellation
- Dashboard route gated by subscription status
- `.env.example` and runbook
- Release checklist

---

## Out of scope for v1

- Multiple plans or tiers
- Proration and plan changes
- Coupons, discounts, or referrals
- Invoicing for custom amounts
- Marketplace or Connect flows
- Tax (rely on Stripe Tax defaults where available, do not build custom)
- Refund self-service

---

## Success criteria

- Test-mode end-to-end flow (signup → checkout → active → cancel) completes in under 90 seconds with no manual intervention.
- All webhook events for the test flow are processed exactly once even when Stripe retries.
- Postmark emails are delivered for the three notification triggers above.
- No Stripe secret or webhook secret ever appears in client-side bundles or logs.
- Largest Contentful Paint is under 2.5 seconds on the marketing landing page during release smoke testing.

---

## Constraints

| Constraint | Details |
|---|---|
| Timeline | 2 weeks to first paid customer in test mode |
| Budget | Single Azure resource group, Stripe test mode until live cutover |
| Technology | Default factory stack (TypeScript, Azure Functions, Azure SQL or PostgreSQL) unless ADR overrides |
| Compliance | Do not store raw card data. Stripe Checkout handles PCI scope. |
| Maintenance | Single operator handles deploys and incidents |

---

## Assumptions

- One product, one price, monthly billing in USD.
- Stripe handles tax calculation via Stripe Tax.
- Postmark sender domain is already verified.
- Auth provider can be added later without rewriting the subscription module.

---

## Open questions

| Question | Owner | Needed by |
|---|---|---|
| Which auth provider (Entra ID, Auth0, Clerk, custom)? | Product owner | Before Phase 2 |
| Free trial length, or none? | Product owner | Before Stripe price is created |
| Do we need annual billing in v1.1? | Product owner | Post-v1 review |
