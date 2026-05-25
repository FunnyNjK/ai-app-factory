# Security Model

## Project name

`TODO`

## Document metadata

| Field | Value |
|---|---|
| Owner | Architect / Security reviewer |
| Status | Draft / Approved / Superseded |
| Last updated | `TODO` |
| Approval owner | Product owner / technical owner |

---

## Threat model

Every project that handles Personal, Financial, Health, or Secret data must ship a threat model. Use `templates/THREAT_MODEL.md`. The marketing-site example skips a formal threat model because it stores only contact-form submissions (Personal, low blast radius); Stripe and Plaid projects ship one (see `examples/sample-stripe-threat-model.md`).

The threat model is reviewed at Gate D as part of the architect's sign-off.

---

## Security summary

Describe the main security posture and what must be protected.

---

## Data classification scheme

Use these labels when populating the Sensitive data table below and the data-classification section of `PROJECT.md`:

- **Public** — intended for the open web. No protection needed beyond integrity.
- **Internal** — operational data. Not catastrophic to leak, but should not be public.
- **Personal** — PII; identifies a person directly or indirectly. Includes email addresses, names, IP addresses tied to users.
- **Financial** — payment metadata, bank-account ids, transaction history. Card data itself is owned by Stripe and never enters the system.
- **Health** — protected health information; triggers HIPAA-style handling. Not in scope for v1 of any factory blueprint.
- **Secret** — credentials, API keys, webhook secrets, access tokens. Never logged, never returned to the client, never stored unencrypted.

---

## Sensitive data

| Data | Sensitivity | Stored where | Protection |
|---|---|---|---|
| `TODO` | Low/Medium/High | `TODO` | `TODO` |

---

## Authentication

- Provider: `TODO`
- Public routes: `TODO`
- Protected routes: `TODO`
- Session/token behavior: `TODO`

---

## Authorization

| Role | Permissions |
|---|---|
| Anonymous | `TODO` |
| User | `TODO` |
| Admin | `TODO` |

---

## Secret management

Secrets must not be stored in source code.

| Secret | Local dev | Cloud |
|---|---|---|
| `TODO` | `.env.local` | Key Vault / app settings |

---

## Webhook security

For each webhook:

| Provider | Endpoint | Verification | Idempotency |
|---|---|---|---|
| `TODO` | `TODO` | Signature verification | Required/Not required |

---

## Input validation

All external input must be validated:

- Browser form input
- API request body
- Query parameters
- Route parameters
- Webhook payloads
- File uploads
- Third-party callbacks

---

## Logging rules

Do log:

- Correlation IDs
- Request path and status
- Provider event IDs
- Non-sensitive operational metadata
- Validation failure categories

Do not log:

- Passwords
- API keys
- Tokens
- Full payment or financial payloads
- Sensitive personal data
- Raw webhook secrets

---

## Security headers

Recommended baseline:

- `Content-Security-Policy`
- `X-Content-Type-Options`
- `Referrer-Policy`
- `Permissions-Policy`
- `Strict-Transport-Security` where applicable

---

## Dependency security

- Use lockfiles.
- Review new dependencies.
- Run dependency audit checks.
- Keep dependencies updated.
- Avoid abandoned packages.

---

## Security smoke checklist

- [ ] No secrets committed.
- [ ] `.env.example` contains names only, not real values.
- [ ] Auth required where expected.
- [ ] Authorization enforced server-side.
- [ ] Webhook signatures verified.
- [ ] Inputs validated.
- [ ] Sensitive errors not exposed to users.
- [ ] Logs do not contain secrets.
- [ ] CORS is restricted.
- [ ] Payment/financial data handling is minimal.
