# Security Model

## Project name

`TODO`

---

## Security summary

Describe the main security posture and what must be protected.

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
