# Sample Test Plan — Marketing Site with Contact Form

## Quality objective

Confirm that visitors can understand the site, submit the contact form, and that valid contact requests are delivered to the business inbox without exposing secrets or failing silently.

---

## Risk matrix

| Area | Risk | Likelihood | Impact | Priority |
|---|---|---:|---:|---:|
| Contact form | Leads fail to send | Medium | High | High |
| Email provider | Postmark misconfigured | Medium | High | High |
| Validation | Bad input causes errors | Medium | Medium | Medium |
| Accessibility | Form unusable by keyboard/screen reader users | Medium | Medium | Medium |
| Spam | Form receives bot submissions | High | Medium | Medium |

---

## Acceptance criteria

- Home page loads.
- Contact form has required fields.
- Invalid email is rejected.
- Empty required fields are rejected.
- Valid submission sends Postmark email.
- User sees success message.
- Provider failures show safe error message.
- No secrets are exposed in frontend code.
- Basic keyboard and label accessibility checks pass.

---

## Unit tests

- Validate required fields.
- Validate email format.
- Validate message length.
- Create expected Postmark payload.

---

## Integration tests

- `POST /api/contact` returns validation error for missing fields.
- `POST /api/contact` returns success when Postmark mock succeeds.
- `POST /api/contact` returns safe error when Postmark mock fails.

---

## E2E tests

- Visitor opens the home page.
- Visitor submits empty form and sees validation errors.
- Visitor submits valid form and sees success state.

---

## Security smoke tests

- Confirm `POSTMARK_SERVER_TOKEN` is not in frontend bundle.
- Confirm `.env.example` has no real secrets.
- Confirm CORS is restricted.
- Confirm long messages are rejected or truncated safely.

---

## Release criteria

- All high-priority tests pass.
- Production contact test email is received.
- Logs show no unexpected errors.
- Known risks are documented.
