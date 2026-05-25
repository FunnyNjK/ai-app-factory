# Observability Standards

## Goal

Every factory project ships with enough logs, metrics, traces, and alerts to detect a problem, diagnose it, and decide whether to roll back — without leaking secrets or sensitive data along the way.

The defaults below are the factory's starting points. Override them with project-specific values in `ARCHITECTURE.md` only when the override is justified.

---

## Log fields

Every log line emitted by application code must include:

- `timestamp` — ISO 8601, UTC, millisecond precision
- `level` — `debug` / `info` / `warn` / `error`
- `correlation_id` — request-scoped, propagated across calls and into webhook handlers
- `route` — HTTP method + path (or trigger type for non-HTTP functions)
- `status` — HTTP status code, or `success`/`failure` for non-HTTP
- `duration_ms` — milliseconds elapsed
- `subject_id` — authenticated user id when safe; never a session token

For provider-driven work, also include:

- `provider` — `stripe`, `plaid`, `postmark`, etc.
- `provider_event_id` — for webhooks and async events

Never log:

- Passwords, API keys, webhook secrets, signing secrets, bearer tokens
- Card data, CVV, full PAN
- Full webhook payloads with sensitive content (log structured metadata only)
- Personal data beyond the minimum needed to debug (no email body, no SSN, no full name unless required)
- Plaid access tokens or institution credentials

---

## Default alert thresholds

These are the starting points. Override per project when load characteristics justify it.

| Alert | Trigger | Severity | Action |
|---|---|---|---|
| API 5xx error rate | > 1% over 5 minutes | P1 | Page on-call |
| API p95 latency | > 800 ms over 10 minutes | P2 | Investigate within 30 minutes |
| Webhook handler failure rate | > 0.1% over 15 minutes | P1 | Page on-call |
| Webhook backlog age | Any event older than 5 minutes unprocessed | P1 | Page on-call |
| Auth failure spike | > 10x baseline over 5 minutes | P2 | Investigate within 30 minutes |
| Postmark delivery failure rate | > 1% over 1 hour | P3 | Investigate within 24 hours |
| Stripe webhook 4xx response (signature failures) | > 0 over 5 minutes | P1 | Page on-call |
| Plaid `ITEM_LOGIN_REQUIRED` rate | > 5% of active items over 24 hours | P3 | Notify product |
| Application restart loop | > 3 restarts in 10 minutes | P1 | Page on-call |
| Disk / storage usage | > 80% of provisioned capacity | P2 | Capacity plan within 7 days |

P1 = page immediately, on call required. P2 = same-day human attention. P3 = next-business-day review.

---

## Required dashboards

Every project gets at least these dashboards in Application Insights or equivalent:

1. **Request overview** — request rate, error rate, p50 / p95 / p99 latency by route.
2. **Webhook overview** — events received, processed, deduped, failed, by provider.
3. **Auth overview** — successful logins, failed logins, lockouts.
4. **Provider health** — outbound calls to Postmark / Stripe / Plaid, success rate, p95 latency.
5. **Cost watch** — Application Insights data ingestion, Function execution count, database DTU/RU consumption.

Link these from `RUNBOOK.md` under "How do I check if X is working?".

---

## Correlation and tracing

- Generate a correlation id at the public ingress (web request, webhook receipt, queue dequeue) if the request does not carry one.
- Propagate it via `x-correlation-id` (HTTP) and `correlationId` (queue / event payload).
- Include it in every log line and every outbound provider call.
- Surface it in user-visible error pages so support can find the request.

Use OpenTelemetry-style attributes where the platform supports it.

---

## SLOs and SLIs

For business-critical user journeys, define and review monthly:

| SLI | Default SLO target |
|---|---|
| Public-page availability | 99.9% over 30 days |
| API success rate (non-5xx) | 99.5% over 30 days |
| Critical journey completion rate | 99% over 30 days |
| Webhook process-within-60s rate | 99.5% over 30 days |

A miss does not auto-page — it triggers a post-mortem at the next monthly review.

---

## Retention defaults

| Signal | Default retention | Override when |
|---|---|---|
| Logs (warn + error) | 90 days | Compliance requires longer |
| Logs (info + debug) | 14 days | Investigation actively underway |
| Metrics | 90 days | Capacity work needs higher fidelity |
| Traces (sampled at 5%) | 30 days | Higher fidelity needed for capacity work |
| Audit logs | 365 days minimum | Compliance demands more |

---

## Pre-release observability checklist

Codex enforces this at Gate D as part of release readiness:

- [ ] Required log fields are present on every public route.
- [ ] No banned fields appear in logs from a representative end-to-end run.
- [ ] All required dashboards exist and are linked from the runbook.
- [ ] All P1 alerts are wired and tested via synthetic failure.
- [ ] Correlation id flows from the browser through to the database row.
- [ ] Ingestion sampling and retention are configured so the cost estimate holds.
