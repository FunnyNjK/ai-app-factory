# ADR-0002: Default transactional email provider is Postmark

## Document metadata

| Field | Value |
|---|---|
| Number | 0002 |
| Date | 2026-05-25 |
| Author | Architect (Claude) |
| Approval owner | Product owner |
| Supersedes | None |

## Status

Accepted

## Context

Most factory projects need transactional email — contact-form submissions, payment receipts, reauth nudges, weekly summaries. Picking a default provider lets the factory ship a blueprint, a worked example, and a Cursor handoff that all assume the same API surface.

Transactional email has different operational characteristics from marketing email: high deliverability, low volume per recipient, strict separation from marketing streams, and aggressive monitoring of bounce / complaint rates. The default must be a transactional-first provider.

## Decision

Postmark is the factory's default transactional email provider. The factory ships a blueprint, a sample integration, env-var conventions, and a per-email workflow definition for Postmark.

This is a default. A project may choose another provider with an ADR explaining why (for example, an existing contract with SendGrid, or a need for inbound parsing Postmark does not handle as well).

## Alternatives considered

1. SendGrid (Twilio) — comparable deliverability and broader product surface. Not chosen because the broader surface increases the chance of accidentally mixing transactional and marketing flows; the factory wants the simpler transactional-only default.
2. Amazon SES — cheapest at high volume. Not chosen because operational tooling, templating, and deliverability reporting are weaker, and the factory's projects are unlikely to hit volumes where SES's cost advantage matters.
3. Mailgun — comparable. Not chosen because the project owner has prior Postmark experience and Postmark's deliverability reputation is excellent for the transactional-only use case.
4. Roll our own SMTP — explicit non-goal for a factory whose principle is "use managed services for non-differentiating work."

## Consequences

### Positive

- A single Postmark blueprint (`blueprints/postmark-email.md`) covers contact forms, receipts, reauth emails, and operational alerts.
- Cursor handoffs and tests can reference Postmark's specific message-stream model.
- Deliverability is strong out of the box.

### Negative

- Costs roughly $15/month at low volumes — non-zero floor for projects that send tiny amounts of email.
- Vendor lock-in to Postmark's template format. Mitigated by keeping templates as data, not embedded in code.

### Neutral

- Marketing email is intentionally out of scope. Projects that need it pick a marketing provider separately and document the choice in an ADR.

## Follow-up

- `blueprints/postmark-email.md` lists the canonical workflow definition.
- `templates/.env.example` includes Postmark env vars.
- Webhook receipt for Postmark inbound mail is out of scope for v1 of the factory.

## References

- `blueprints/postmark-email.md`
- `examples/sample-architecture.md` — marketing-site example uses Postmark.
