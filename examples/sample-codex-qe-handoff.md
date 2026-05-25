# Sample Codex QE Handoff

## Quality objective

Validate that the marketing site contact flow works as intended, protects secrets, handles invalid input, and gives users clear feedback.

---

## Business-critical workflows

1. Visitor loads site.
2. Visitor submits invalid contact form and receives useful validation feedback.
3. Visitor submits valid contact form.
4. Business owner receives Postmark email notification.

---

## Requirements to validate

- Site loads on desktop and mobile.
- Contact form has required fields.
- Server validates input.
- Postmark email is sent for valid submission.
- User receives success state.
- Provider failure shows safe error.
- No secrets are exposed client-side.

---

## Highest-risk areas

| Area | Reason |
|---|---|
| Contact endpoint | Directly tied to lead generation |
| Postmark integration | External provider dependency |
| CORS/config | Environment-specific failure risk |
| Validation | Prevents bad payloads and abuse |
| Accessibility | Forms must be usable by all visitors |

---

## API checks

- Missing name returns validation error.
- Missing email returns validation error.
- Invalid email returns validation error.
- Missing message returns validation error.
- Valid payload returns success when email provider succeeds.
- Provider failure returns safe error.
- Long message is rejected or handled safely.

---

## UI/E2E checks

- Required fields are visually indicated.
- Keyboard user can complete the form.
- Errors are clear and near fields.
- Success state is visible.
- Submit button handles loading state.
- Duplicate rapid submissions are prevented or handled safely.

---

## Security checks

- No Postmark token in frontend.
- `.env.example` contains no real values.
- CORS is intentional.
- API does not expose raw Postmark error details.
- Logs do not contain secrets.

---

## Release gate recommendation

Release only after:

- Contact flow passes in production environment.
- Test email is received.
- Logs are checked after test submission.
- Known spam-protection decision is documented.
