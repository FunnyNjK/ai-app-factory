# Sample Cursor Developer Handoff

## Build objective

Implement a marketing site with a contact form that submits to an Azure Function and sends a Postmark email notification.

---

## Scope

- Static home page
- Services section
- Contact form
- Client-side validation
- `POST /api/contact` Azure Function
- Server-side validation
- Postmark email send
- Basic tests
- README updates
- `.env.example`

---

## Non-goals

- CMS
- Database
- Authentication
- Payments
- Admin dashboard

---

## Tech stack

- Frontend: React/Vite or selected static framework
- API: Azure Functions
- Email: Postmark
- Tests: Vitest/Jest and Playwright if available
- Hosting: Azure Static Web Apps

---

## Required environment variables

```bash
POSTMARK_SERVER_TOKEN=
POSTMARK_FROM_EMAIL=
CONTACT_TO_EMAIL=
CONTACT_REPLY_TO_EMAIL=
ALLOWED_ORIGIN=
```

---

## Implementation sequence

1. Create static landing page shell.
2. Add contact form component.
3. Add frontend validation and accessible error messages.
4. Create `/api/contact` function.
5. Add server-side validation.
6. Add Postmark email service wrapper.
7. Add tests for validation and API behavior.
8. Update README and `.env.example`.
9. Run build and tests.

---

## Acceptance criteria

- Form rejects invalid input.
- Form submits valid input.
- Backend sends Postmark email.
- User sees useful success/error state.
- Secrets are backend-only.
- Tests cover validation and email payload behavior.
- Documentation explains local setup.

---

## Known risks

- Postmark domain/sender may not be verified yet.
- Spam protection may need to be added after launch.
- CORS must be configured correctly in production.
