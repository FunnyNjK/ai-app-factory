# Runbook

## Project name

`TODO`

## Document metadata

| Field | Value |
|---|---|
| Owner | Operator / technical owner |
| Status | Draft / Approved |
| Last updated | `TODO` |
| Escalation owner | `TODO` |

---

## Purpose

Operational instructions for running, deploying, troubleshooting, and maintaining this project.

---

## Local setup

### Prerequisites

- `TODO` Node.js version
- `TODO` package manager
- `TODO` Azure Functions Core Tools if needed
- `TODO` Azure CLI if needed

### Install

```bash
TODO
```

### Configure environment

Copy the example environment file:

```bash
# macOS/Linux
cp .env.example .env.local

# Windows PowerShell
Copy-Item .env.example .env.local
```

Fill in required values.

### Run locally

```bash
TODO
```

### Run tests

```bash
TODO
```

---

## Environments

| Environment | URL | Purpose |
|---|---|---|
| Local | `localhost` | Developer testing |
| Dev | `TODO` | Shared testing |
| Staging | `TODO` | Release validation |
| Production | `TODO` | Live system |

---

## Environment variables

| Name | Required | Description |
|---|---|---|
| `TODO` | Yes/No | `TODO` |

---

## Deployment

### Manual deployment

```bash
TODO
```

### CI/CD deployment

Describe pipeline trigger and stages.

---

## Common operational tasks

### Rotate a secret

1. Create new secret value.
2. Update cloud configuration or Key Vault.
3. Restart/redeploy app if required.
4. Verify integration still works.
5. Revoke old secret.

### Replay a webhook

1. Confirm provider event ID.
2. Confirm event has not already been processed.
3. Replay from provider dashboard or internal tool.
4. Verify idempotency behavior.
5. Check logs.

### Check failed emails

1. Check app logs.
2. Check Postmark activity.
3. Confirm sender verification.
4. Confirm recipient address.
5. Retry if appropriate.

---

## Troubleshooting

| Symptom | Likely cause | What to check |
|---|---|---|
| App will not start | Missing config | Environment variables |
| API returns 500 | Provider/database failure | Logs and provider status |
| Email not delivered | Postmark config issue | Sender, stream, token |
| Webhook fails | Signature/config issue | Webhook secret and payload |
| Auth fails | Provider config issue | Redirect URLs and credentials |

---

## Incident response notes

1. Assess impact.
2. Stop or mitigate the failing workflow.
3. Check logs and monitoring.
4. Roll back if needed.
5. Communicate status.
6. Record root cause and follow-up actions.
