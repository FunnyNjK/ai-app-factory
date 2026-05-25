# Sample Project Brief — Personal Finance Dashboard with Plaid

## Project name

Example Personal Finance Dashboard

## Project type

Full-stack web app with Plaid Link account connections, Plaid Transactions sync, and Postmark notifications.

---

## Executive summary

Build a personal-finance dashboard where authenticated users connect their bank accounts through Plaid Link, see a unified balance and recent-transactions view, and receive a weekly Postmark email summary. Plaid is the source of truth for account and transaction data; the local database stores only the minimum metadata and last-sync state needed to serve the dashboard fast.

---

## Business goal

Give a single user a clear, trustworthy view of cash flow across multiple accounts without building bank integrations from scratch and without storing sensitive credentials.

---

## Target users

| User type | Description | Primary needs |
|---|---|---|
| Account holder | Authenticated user managing personal accounts | Connect banks, see balances, scan recent activity |
| Operator | Maintainer | Deploy safely, rotate keys, handle reauth flows |

---

## Primary user journeys

1. Authenticated user clicks "Connect bank", completes Plaid Link, and lands back on the dashboard with the new institution listed.
2. User opens the dashboard and sees current balances and the most recent 30 days of transactions across all connected institutions.
3. User receives a weekly Postmark summary email.
4. When an Item enters error state (for example, the user changed their bank password), the user is prompted to reconnect.

---

## In scope for v1

- Email + password (or OAuth) authentication
- Plaid Link integration on the frontend
- Backend link-token creation and public-token exchange
- Local storage of Plaid `item_id`, `account_id`, and recent-transaction metadata
- Transactions sync via Plaid Transactions endpoint and `TRANSACTIONS` webhooks
- `ITEM` webhook handling for error and reauth states
- Postmark weekly summary email
- Dashboard with balance overview and recent transactions
- Reconnect flow for `ITEM_LOGIN_REQUIRED`
- `.env.example`, README, and runbook

---

## Out of scope for v1

- Investments, liabilities, or identity products
- Categorization beyond Plaid's default
- Budgeting, goals, or alerts
- Multi-user households or sharing
- Export / report generation
- Mobile native apps

---

## Success criteria

- A user can connect a Plaid sandbox institution and see at least one account on the dashboard within 60 seconds of completing Link.
- A user can connect two institutions and see both in the consolidated view.
- Transactions data is no more than 24 hours stale at any time.
- `ITEM_LOGIN_REQUIRED` produces a visible, actionable reconnect prompt within five minutes of the webhook arriving.
- No Plaid secret, access token, or institution credential ever appears in client bundles or logs.

---

## Constraints

| Constraint | Details |
|---|---|
| Timeline | 3 weeks to first sandbox-connected user, 2 more weeks to live (development credentials) |
| Budget | Single Azure resource group; Plaid sandbox first, then development tier |
| Technology | Default factory stack (TypeScript, Azure Functions, Azure SQL or PostgreSQL) unless ADR overrides |
| Compliance | Do not store account credentials. Limit stored financial data to what the dashboard needs. |
| Maintenance | Single operator handles deploys and incidents |

---

## Assumptions

- US-only institutions in v1 (`PLAID_COUNTRY_CODES=US`).
- Single Plaid product set: Transactions and Auth.
- Postmark sender domain is already verified.
- Access tokens are stored encrypted at rest using a Key Vault-managed key.

---

## Open questions

| Question | Owner | Needed by |
|---|---|---|
| Which auth provider? | Product owner | Before Phase 2 |
| Acceptable transaction history depth (30, 90, 365 days)? | Product owner | Before sync design freezes |
| Do we go straight to Plaid development tier or stay in sandbox for v1? | Product owner | Before v1 launch |
