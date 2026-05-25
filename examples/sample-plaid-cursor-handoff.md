# Sample Cursor Developer Handoff — Personal Finance Dashboard with Plaid

## Build objective

Implement an authenticated personal-finance dashboard that uses Plaid Link to connect bank accounts, exchanges public tokens server-side, syncs recent transactions via Plaid Transactions Sync, handles Plaid webhooks idempotently, and stores access tokens encrypted via Key Vault.

---

## Scope

- Auth-protected dashboard
- `POST /api/plaid/link-token` Azure Function
- `POST /api/plaid/exchange` Azure Function with Key Vault-backed token encryption
- `POST /api/plaid/webhook` Azure Function with JWT verification and idempotency
- Timer-triggered sync function (6-hour cadence)
- Database tables: `PlaidItem`, `Account`, `Transaction`, `WebhookEvent`
- Postmark notifications for reauth nudges and weekly summary
- Reconnect UI flow for `ITEM_LOGIN_REQUIRED`
- Tests for each endpoint, each webhook handler, and the sync backstop
- `.env.example` updates
- README and `RUNBOOK.md` updates

---

## Non-goals

- Investments, liabilities, or identity products
- Budgeting, categorization beyond Plaid defaults, or alerts
- Multi-user households or sharing
- Export, report generation, or PDFs

---

## Tech stack

- Frontend: React + Vite or Next.js, with the official Plaid Link wrapper
- API: Azure Functions in TypeScript
- Database: Azure SQL or PostgreSQL via Prisma or Drizzle
- Secret store: Azure Key Vault accessed via managed identity
- Email: Postmark
- Tests: Vitest or Jest; Playwright for E2E
- Hosting: Azure Static Web Apps + Azure Functions

---

## Required environment variables

```bash
APP_BASE_URL=
PLAID_CLIENT_ID=
PLAID_SECRET=
PLAID_ENV=sandbox
PLAID_PRODUCTS=transactions
PLAID_COUNTRY_CODES=US
POSTMARK_SERVER_TOKEN=
POSTMARK_FROM_EMAIL=
DATABASE_URL=
AZURE_KEY_VAULT_URL=
```

All of these are declared in `templates/.env.example`. Do not introduce new names without updating the template.

---

## Implementation sequence

1. Add the four new database tables and a migration.
2. Implement the auth-protected dashboard route; confirm anonymous access is redirected.
3. Implement `POST /api/plaid/link-token`. Require auth. Mint the link token using env-driven products and country codes.
4. Integrate Plaid Link on the frontend; on success, send the public token to the exchange endpoint.
5. Implement `POST /api/plaid/exchange`. Exchange server-side, encrypt the access token via Key Vault, persist `PlaidItem` + `Account` rows.
6. Implement `POST /api/plaid/webhook` with Plaid JWT verification before any parsing.
7. Add the `WebhookEvent` idempotency log; only run handlers on first insert.
8. Implement the `TRANSACTIONS / SYNC_UPDATES_AVAILABLE` handler using cursor-based sync; advance the cursor only after a successful upsert.
9. Implement `ITEM / ERROR` and `ITEM / PENDING_EXPIRATION` handlers with the reconnect UI + Postmark nudge.
10. Implement the timer-triggered sync backstop with per-Item advisory locking.
11. Implement the weekly Postmark summary job.
12. Add unit, integration, and E2E tests.
13. Update `README.md` and `RUNBOOK.md` with local setup, Plaid CLI / sandbox usage, webhook forwarding via a tunnel, and deploy steps.

---

## Acceptance criteria

- Anonymous `POST /api/plaid/link-token` returns `401`.
- Authenticated request returns a sandbox-shaped link token.
- Sandbox `user_good` / `pass_good` flow ends with an `Item` and at least one `Account` row.
- The exchange response never contains an access token; the DB stores only a Key Vault reference.
- Duplicate webhook `event_id` writes once and emails once.
- Tampered webhook JWT returns `400` and is never parsed.
- `ITEM_LOGIN_REQUIRED` produces a visible reconnect prompt and a Postmark email.
- Cursor-based sync resumes correctly after a simulated mid-sync crash.
- No Plaid secret or access-token string appears in the frontend bundle or any log line.
- Tests cover the five v1 webhook event flows, the auth and JWT negative paths, and the sync resume case.

---

## Known risks

- Plaid sandbox webhook semantics differ slightly from development and production; staging-against-development is part of the release gate.
- JWT verification requires fetching Plaid's public key set; cache it with a sensible TTL or the webhook becomes Plaid-availability-coupled.
- The timer sync and a webhook can race on the same Item; the advisory-lock pattern must be in place before the timer ships.

---

## Do not do

- Do not store access tokens in the database in plaintext.
- Do not expose access tokens or `PLAID_SECRET` to the frontend.
- Do not parse the webhook body before verifying the JWT.
- Do not depend on Postmark success before responding `200` to Plaid.
- Do not introduce a second sync code path; route everything through the webhook handler and the timer backstop, both gated by the idempotency log and the per-Item lock.
- Do not commit any `access-sandbox-*`, `access-development-*`, or `access-production-*` token, or any `PLAID_CLIENT_ID` / `PLAID_SECRET` value.
