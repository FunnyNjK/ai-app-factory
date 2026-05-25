# Release Checklist

## Project name

`TODO`

## Release version

`TODO`

## Release date

`TODO`

## Release ownership

| Field | Value |
|---|---|
| Release owner | `TODO` |
| Technical approver | `TODO` |
| Quality approver | `TODO` |
| Business approver | `TODO` |
| Last updated | `TODO` |

---

## Build verification

- [ ] Production build succeeds.
- [ ] Linting passes.
- [ ] Type checking passes.
- [ ] Unit tests pass.
- [ ] Integration tests pass.
- [ ] E2E tests pass or known exceptions are documented.
- [ ] Build artifact is produced correctly.

---

## Configuration verification

- [ ] Required environment variables are configured.
- [ ] No production secrets are stored in source control.
- [ ] API URLs are correct.
- [ ] Allowed origins are correct.
- [ ] Feature flags are set correctly.
- [ ] Provider keys are environment-appropriate.

---

## Infrastructure verification

- [ ] Hosting resource exists.
- [ ] Database/storage resources exist.
- [ ] Key Vault or secret store exists if required.
- [ ] Managed identity or service principal permissions are correct.
- [ ] Logging is enabled.
- [ ] Monitoring is enabled.
- [ ] Alerts are configured if required.

---

## Integration verification

- [ ] Postmark sender is verified.
- [ ] Stripe webhook endpoint is configured if used.
- [ ] Stripe webhook secret is configured if used.
- [ ] Plaid environment is correct if used.
- [ ] External API credentials are correct.
- [ ] Webhook test event succeeds where applicable.

---

## Security verification

- [ ] No secrets in repository.
- [ ] Auth required where expected.
- [ ] Authorization enforced.
- [ ] Webhook signatures verified.
- [ ] Sensitive logs avoided.
- [ ] CORS configured.
- [ ] Security headers configured where applicable.

---

## Functional smoke test

- [ ] Home page loads.
- [ ] Main user journey works.
- [ ] Forms validate correctly.
- [ ] API returns expected responses.
- [ ] Email workflow works if applicable.
- [ ] Payment or financial flow works in test mode if applicable.
- [ ] Error states are usable.

---

## Accessibility smoke test

- [ ] App is keyboard usable.
- [ ] Form fields have labels.
- [ ] Focus indicators are visible.
- [ ] Obvious contrast issues are resolved.
- [ ] Error messages are understandable.

---

## Rollback plan

Describe how to roll back:

1. `TODO`
2. `TODO`
3. `TODO`

---

## Post-release validation

- [ ] Production URL loads.
- [ ] Logs show no immediate errors.
- [ ] Test transaction/form/API call completed.
- [ ] Monitoring checked.
- [ ] Stakeholder notified.

---

## Release decision

Choose one:

- [ ] Release approved.
- [ ] Release approved with known risks.
- [ ] Release blocked.

Known risks:

- `TODO`
