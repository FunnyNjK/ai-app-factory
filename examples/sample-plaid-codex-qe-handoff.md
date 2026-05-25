# Sample Codex QE Handoff — Personal Finance Dashboard with Plaid

## Quality objective

Validate that Plaid Link connections, transactions sync, webhook idempotency, reconnect flows, and dashboard isolation all behave correctly and that Plaid credentials and access tokens never leak.

---

## Business-critical workflows

1. Authenticated user connects a sandbox institution and lands on the dashboard with the institution visible.
2. Webhooks deliver transaction updates; the dashboard reflects them within 60 seconds.
3. `ITEM_LOGIN_REQUIRED` produces a visible reconnect prompt and an email.
4. Plaid retries a webhook with the same event id; the app processes it exactly once.
5. The timer-triggered sync backstop fills any gap left by webhook delays.
6. Two users with their own connected Items never see each other's data on the dashboard.

---

## Requirements to validate

- Auth required on all Plaid-initiating endpoints.
- Webhook signature verified via Plaid's JWT flow on the raw body before parsing.
- Idempotency enforced on the webhook `event_id`.
- Cursor-based transactions sync advances cursor only on success.
- Reauth flow surfaces in the UI and via email.
- Per-Item advisory lock prevents timer/webhook sync collisions.
- Dashboard queries are user-scoped server-side.
- Access tokens stored only as Key Vault references; DB rows hold no plaintext tokens.

---

## Highest-risk areas

| Area | Reason |
|---|---|
| Webhook handler | A signature miss or idempotency failure directly causes data drift or duplicate side effects |
| Public-token exchange | An anonymous or cross-user exchange attaches an attacker's Item to the wrong user |
| Cursor-based sync | A lost or replayed cursor causes missing or duplicate transactions |
| Reauth flow | Silent failures leave the user with stale data and no signal |
| Dashboard isolation | Cross-user data exposure is the worst-case failure for a finance product |
| Token handling | Plaid access tokens are high-value; any leak is critical |

---

## API checks

- `POST /api/plaid/link-token` without auth → `401`.
- `POST /api/plaid/link-token` with auth → `200`, body has a sandbox-shaped link token.
- `POST /api/plaid/exchange` without auth → `401`.
- `POST /api/plaid/exchange` with another user's body context → resolves to the authenticated user only; never attaches the Item to the body-supplied user.
- `POST /api/plaid/webhook` with missing or invalid JWT → `400`, no DB write.
- `POST /api/plaid/webhook` with valid `SYNC_UPDATES_AVAILABLE` → `200`, transactions written, cursor advanced.
- Same event id replayed → still `200`, no extra writes, no extra email.
- `ITEM / ERROR` with `ITEM_LOGIN_REQUIRED` → Item status `requires_reauth`, Postmark email queued.

---

## UI / E2E checks

- New user signs up, hits the dashboard with no connections, clicks Connect bank.
- Plaid Link sandbox flow with `user_good` / `pass_good` succeeds; institution appears in under 60 seconds.
- Connecting a second institution shows both.
- Triggering `ITEM_LOGIN_REQUIRED` surfaces a visible banner and a clickable Reconnect action.
- Reconnect flow clears the banner and resumes sync.
- A second test user does not see the first user's Items, accounts, or transactions in any view.

---

## Integration checks

- Plaid sandbox `Item.fireWebhook` for `SYNC_UPDATES_AVAILABLE` produces a valid event the handler accepts.
- Plaid sandbox `Item.fireWebhook` for `ITEM_LOGIN_REQUIRED` produces the reconnect flow.
- Postmark sandbox stream receives the reauth nudge and the weekly summary for a test user.
- Key Vault is the only path used to retrieve access tokens during a sync; DB rows show only references, not tokens.

---

## Security checks

- Frontend bundle contains no `PLAID_SECRET`, no `access-sandbox-*`, no `access-development-*`, no `access-production-*` substring.
- The `/api/plaid/exchange` response payload contains no `access_token` field.
- Server logs after a sync contain no transaction names, no amounts, no header values, no token strings.
- Cross-user IDOR attempts on the dashboard API return `404` or `403`.
- CORS on the Plaid-initiating endpoints is restricted to the production origin.
- `Content-Security-Policy` allows only required Plaid origins.

---

## Accessibility checks

- Connect Bank button is keyboard reachable with a visible focus state and an accessible name.
- Plaid Link's hosted iframe is announced appropriately on open and close.
- The reconnect banner is announced to screen readers and is dismissible by keyboard.
- Color contrast on balance values and status indicators meets 4.5:1.

---

## Release gate recommendation

Release only after:

- All high-priority test cases pass against Plaid sandbox.
- A staging dry run against Plaid development tier with at least one real institution completes connect → sync → dashboard within the latency targets.
- The production webhook URL is registered in the Plaid dashboard and a sandbox `Item.fireWebhook` returns `200` from the production endpoint.
- Postmark sender domain is verified in production.
- Rollback documented: how to revoke an Item, how to flip back to development tier, how to disable sync without losing data.
