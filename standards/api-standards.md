# API Standards

## Goals

APIs should be:

- Predictable
- Consistent
- Secure
- Easy to test
- Easy to document
- Safe to evolve

---

## Resource naming

Use plural nouns for resources:

```text
GET    /api/customers
POST   /api/customers
GET    /api/customers/{customerId}
PATCH  /api/customers/{customerId}
DELETE /api/customers/{customerId}
```

---

## HTTP verbs

| Verb | Purpose |
|---|---|
| GET | Read |
| POST | Create or command |
| PATCH | Partial update |
| PUT | Full replace when needed |
| DELETE | Delete or deactivate |

---

## Response format

### Success

```json
{
  "ok": true,
  "data": {}
}
```

### Error

```json
{
  "ok": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Safe user-facing message.",
    "details": {}
  }
}
```

---

## Status codes

| Status | Use |
|---|---|
| 200 | Successful read/update |
| 201 | Created |
| 202 | Accepted async work |
| 204 | Success with no body |
| 400 | Validation error |
| 401 | Not authenticated |
| 403 | Not authorized |
| 404 | Not found |
| 409 | Conflict |
| 422 | Semantic validation failure |
| 429 | Rate limited |
| 500 | Unexpected server error |

---

## Validation

Validate:

- Body
- Query parameters
- Path parameters
- Headers
- Uploaded files
- Webhook payloads

Return field-level validation errors where useful.

---

## Pagination

Use pagination for list endpoints.

Example:

```json
{
  "ok": true,
  "data": [],
  "page": {
    "cursor": "next-cursor",
    "hasMore": true
  }
}
```

---

## Idempotency

Use idempotency for:

- Payment actions
- Webhook processing
- Retried commands
- Background jobs
- External side effects

---

## Versioning

For small internal APIs, document breaking changes clearly.

For public APIs, consider:

```text
/api/v1/resource
```

---

## Observability

APIs should log:

- Request method and path
- Status code
- Duration
- Correlation/request ID
- Authenticated subject ID when safe
- Provider event ID when applicable

Do not log secrets, raw tokens, or sensitive payloads.
