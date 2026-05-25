# Testing Standards

## Testing philosophy

Testing is part of development, not a separate final phase.

The goal is not 100% coverage for its own sake. The goal is confidence that critical business behavior works and stays working.

---

## Test pyramid

Use a practical mix:

1. Unit tests for logic and validation.
2. Integration tests for APIs, databases, and providers.
3. E2E tests for critical user journeys.
4. Manual exploratory testing for usability and edge cases.

---

## What must be tested

- Business-critical user journeys
- Input validation
- Authorization rules
- API success and failure paths
- Webhook verification and idempotency
- Payment state changes
- Email payload creation
- Database persistence
- Error states
- Accessibility basics

---

## Unit test standards

Unit tests should be:

- Fast
- Deterministic
- Easy to understand
- Focused on behavior
- Independent of external services

---

## Integration test standards

Integration tests should cover:

- API request/response behavior
- Database read/write behavior
- Provider client behavior with mocks or test environment
- Authentication/authorization checks
- Failure and retry paths

---

## E2E test standards

E2E tests should cover:

- Highest-value user journeys
- Form validation
- Success and failure states
- Navigation
- Auth flows when applicable
- Payment or financial flows in sandbox/test mode only

---

## Test data

- Use realistic but fake data.
- Do not use real customer data.
- Keep test data deterministic.
- Document test users and test accounts.

---

## Release test gate

A release candidate should not ship if:

- Critical tests fail.
- Critical paths are untested.
- Security smoke checks fail.
- Known blocker defects remain open.
- The team cannot explain rollback.
