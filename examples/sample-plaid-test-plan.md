# Sample Test Plan — Personal Finance Dashboard with Plaid

## Quality objective

Confirm that authenticated users can connect bank accounts via Plaid Link, that transactions stay current via webhooks and the timer backstop, that idempotency holds under retry, and that Plaid credentials and access tokens never leak.

---

## Risk matrix

| Area | Risk | Likelihood | Impact | Priority |
|---|---|---:|---:|---:|
| Webhook verification | Accept forged events | Low | High | High |
| Webhook idempotency | Duplicate transactions or emails on retry | Medium | High | High |
| Public-token exchange | Anonymous caller exchanges a stolen public token | Medium | High | High |
| Access token at rest | Token stored in plain text in DB or logs | Low | High | High |
| Transactions sync | Cursor lost or replayed, causing duplicate or missing rows | Medium | High | High |
| Reauth flow | User never learns the Item needs reconnection | Medium | High | High |
| Dashboard isolation | One user's accounts visible to another | Low | High | High |
| Secret exposure | Plaid secret reachable from frontend bundle | Low | High | High |
| Sandbox vs production drift | Different shapes break production-only paths | Medium | Medium | Medium |

---

## Acceptance criteria

- Anonymous request to `POST /api/plaid/link-token` returns `401`.
- Authenticated request returns a `link-...` token usable with Plaid Link.
- Authenticated `POST /api/plaid/exchange` with a sandbox public token persists an `Item` and one or more `Account` rows.
- A `TRANSACTIONS / SYNC_UPDATES_AVAILABLE` webhook results in transactions appearing on the dashboard within 60 seconds.
- A duplicated webhook with the same provider event id writes only once and emails only once.
- An `ITEM / ERROR` webhook with `ITEM_LOGIN_REQUIRED` flips the Item to `requires_reauth=true` and emails the user.
- Logs after a sync run contain `item_id` and `account_id` only — no transaction names, no amounts, no headers, no tokens.
- The DB never contains a row whose `access_token_ref` resolves to a plaintext token; tokens are always Key Vault references.
- Webhook handler rejects requests whose JWT verification fails with `400`.

---

## Unit tests

- Link-token request builder includes the correct `country_codes`, `products`, and `language` per env.
- Public-token exchange wrapper returns the expected `access_token` and `item_id` shape when Plaid is mocked.
- Webhook JWT verifier rejects mismatched signatures, expired tokens, and missing headers.
- Idempotency-log helper returns `processed` on a second insert with the same provider event id.
- Transactions sync handler advances the stored cursor only after a successful upsert.
- Webhook dispatcher routes `TRANSACTIONS / SYNC_UPDATES_AVAILABLE` to the sync handler and ignores unknown codes.

---

## Integration tests

- `POST /api/plaid/link-token` without auth → `401`.
- `POST /api/plaid/link-token` with auth → `200`, returns a Plaid sandbox-shaped link token.
- `POST /api/plaid/exchange` with a valid sandbox public token persists an `Item` + `Account` rows and returns the expected client-safe payload.
- `POST /api/plaid/exchange` with an invalid public token returns a user-safe error.
- `POST /api/plaid/webhook` with an invalid JWT → `400`, no DB write.
- `POST /api/plaid/webhook` with `SYNC_UPDATES_AVAILABLE` → `200`, transactions present in DB, cursor advanced.
- Same event replayed → `200`, no extra writes.
- `ITEM_LOGIN_REQUIRED` event flips the Item status and sends a Postmark notification.
- Timer-triggered sync, when run while a webhook handler is mid-sync for the same Item, is skipped (advisory lock honored).

---

## E2E tests

- New user signs up, clicks Connect bank, completes Plaid Link with the sandbox `user_good` / `pass_good` flow, and lands on a dashboard showing the connected institution.
- Connecting a second institution adds it to the consolidated dashboard view.
- Triggering `ITEM_LOGIN_REQUIRED` via Plaid sandbox tools surfaces a visible reconnect prompt on the dashboard and an email in the Postmark sandbox stream.
- Completing the reconnect flow clears the prompt and resumes transactions sync.

---

## Security smoke tests

- Build the production frontend bundle and grep for `PLAID_SECRET`, `access-sandbox-`, `access-development-`, `access-production-` — none should appear.
- Inspect the request payload of `/api/plaid/exchange` from the browser; confirm the response does not contain an access token.
- Inspect server logs after a sync — no transaction names, no amounts, no headers, no token strings.
- Attempt to GET another user's `item_id` via the dashboard API — must return `404` or `403`, never the other user's data.
- Confirm `Content-Security-Policy` is enforced and allows only required Plaid origins (`cdn.plaid.com`, `production.plaid.com` or env-equivalent).

---

## Performance checks

- Dashboard p95 latency under 600 ms with three connected Items and 1,000 transactions.
- Webhook handler p95 latency under 800 ms; longer sync work moved to a queue if any handler exceeds it.
- Timer-triggered sync completes for 100 Items in under 5 minutes.

---

## Test data

| Data set | Purpose |
|---|---|
| Plaid sandbox `user_good` / `pass_good` | Drives Link happy path |
| Plaid sandbox `user_custom` config | Forces specific institutions, account types, or webhook events |
| Plaid sandbox `Item.fireWebhook` invocations | Drives integration tests for webhook handlers |
| Postmark sandbox stream | Captures notification emails without sending real mail |

---

## Release criteria

- All high-priority test cases above pass against Plaid sandbox and (for staging) against the development tier.
- A staging dry run with at least one real institution completes connect → sync → dashboard within the success-criteria latency targets.
- Plaid webhook URL is registered in the production Plaid dashboard and a sandbox `Item.fireWebhook` returns `200` from the production endpoint.
- Rollback path is documented: how to revoke an Item, how to flip back to development tier, how to disable sync without losing existing data.
- Postmark sender domain is verified in production.
