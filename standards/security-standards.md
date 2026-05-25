# Security Standards

## Security principles

- Secure by default.
- Least privilege.
- Defense in depth.
- No secrets in source control.
- Validate at every trust boundary.
- Log enough to debug, never enough to leak secrets.
- Prefer provider-hosted secure flows for payments.
- Verify all webhooks.
- Make retried operations idempotent.

---

## Secret management

Local development:

- Use `.env.local` or equivalent.
- Use `.env.example` with empty placeholder values.
- Never commit real secrets.

Cloud:

- Use Azure app settings for simple projects.
- Use Azure Key Vault for larger or more sensitive projects.
- Use managed identity where possible.
- Rotate secrets periodically.

---

## Authentication

- Define public and private routes.
- Do not rely only on frontend guards.
- Enforce auth server-side.
- Keep session/token handling documented.
- Use established providers where practical.

---

## Authorization

- Define roles and permissions.
- Enforce authorization in the API/backend.
- Test negative cases.
- Avoid exposing records by guessable IDs without ownership checks.

---

## Webhooks

Every webhook should have:

- Signature verification
- Timestamp or replay protection if provider supports it
- Idempotency
- Safe logging
- Failure handling
- Test events

---

## Payments

- Do not store card data.
- Use Stripe-hosted checkout or provider-hosted flows when possible.
- Treat webhooks as source of truth.
- Store provider IDs and status fields only as needed.
- Use test mode for development and QA.

---

## Plaid / financial data

- Do not expose Plaid secrets to frontend.
- Exchange public tokens on the backend only.
- Store access tokens securely.
- Minimize locally stored financial data.
- Document retention and deletion behavior.

---

## Email

- Do not send secrets in email.
- Avoid logging full email bodies with sensitive data.
- Separate transactional from marketing email.
- Use verified sender domains.
- Handle provider failures safely.

---

## Security smoke checklist

- [ ] No secrets in repository.
- [ ] Dependencies audited.
- [ ] Inputs validated.
- [ ] Auth enforced server-side.
- [ ] Authorization negative cases tested.
- [ ] Webhook signatures verified.
- [ ] CORS configured intentionally.
- [ ] Error responses do not leak sensitive details.
- [ ] Logs reviewed for sensitive data.
