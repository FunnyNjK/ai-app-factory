# Sample Architecture — Marketing Site with Contact Form

## Executive summary

The system is a static marketing website hosted on Azure Static Web Apps. The contact form submits to an Azure Function API endpoint. The function validates input and sends an email notification through Postmark. No database is required for v1.

---

## Recommended architecture

```mermaid
flowchart LR
    Visitor[Website Visitor] --> Site[Static Website]
    Site --> Form[Contact Form]
    Form --> Api[Azure Function /api/contact]
    Api --> Validate[Validation and Anti-Spam]
    Validate --> Postmark[Postmark API]
    Api --> Logs[Application Logs]
    Postmark --> Inbox[Business Inbox]
```

---

## Components

| Component | Responsibility | Technology |
|---|---|---|
| Static website | Public marketing UI | Azure Static Web Apps |
| Contact form | Collect visitor info | Frontend framework or plain HTML |
| Contact API | Validate and submit contact requests | Azure Functions |
| Email provider | Send transactional notification | Postmark |
| Config/secrets | Store API tokens | Static Web Apps app settings or Key Vault |
| Logs | Diagnose failures | Azure logs/Application Insights |

---

## API design

### `POST /api/contact`

Submits a contact request.

#### Request

```json
{
  "name": "Jane Doe",
  "email": "jane@example.com",
  "company": "Example Co",
  "message": "I would like to discuss a project."
}
```

#### Success

```json
{
  "ok": true,
  "data": {
    "message": "Thanks. Your message was sent."
  }
}
```

#### Validation error

```json
{
  "ok": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Please check the form fields.",
    "details": {
      "fields": {
      "email": "Enter a valid email address."
      }
    }
  }
}
```

---

## Security model

- Postmark token is backend-only.
- CORS is restricted to the production domain.
- Inputs are validated and length-limited.
- Provider errors are logged but not exposed directly to users.
- No secrets are committed to source control.

---

## Trade-offs

| Decision | Benefit | Cost |
|---|---|---|
| No database in v1 | Lower cost and complexity | No contact history in app |
| Serverless endpoint | Cheap and simple | Cold starts possible |
| Postmark | Reliable transactional email | External provider dependency |

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Spam submissions | Add Turnstile/hCaptcha or honeypot |
| Email delivery failure | Log errors and show safe failure message |
| Misconfigured sender domain | Verify domain before launch |
| CORS misconfiguration | Test production origin before release |
