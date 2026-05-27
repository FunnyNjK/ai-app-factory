# Escalations — <project-name>

> Human review queue. Any agent (Cursor, Codex, Claude) appends here when it hits an iteration cap, cannot make progress, or needs a judgment call. The product owner reviews this file after each Claude phase review — or sooner if `TASKS.md` shows `human-needed` items blocking work.

## Entry format

Each escalation gets its own subsection. Use the next sequential ID (`ESC-001`, `ESC-002`, ...). Do not delete entries; move them to the **Resolved** section with a resolution note when handled.

```markdown
### ESC-NNN: <short-title>

- Created: <YYYY-MM-DD>
- From: cursor | codex | claude
- Phase/Slice: <e.g., 1.2 or "Phase 1 review">
- Reason: iteration-cap-hit | judgment-call | secret-needed | external-dependency | other
- Context: <one paragraph: what was being attempted and why it stopped>
- What was tried: <bullet list of iterations or alternatives>
- Recommended action: <what the agent suggests the human do>
- Status: open
```

When the product owner reviews:

- **Approve and resume** — add a resolution note and route work back to the relevant agent.
- **Defer** — note the deferral reason and move to Resolved if the deferral is permanent, otherwise leave open with a `defer-until` date.
- **Reject the work** — close the slice/phase with a different decision (smaller scope, different approach, cancel).

---

## Open

(No open escalations yet.)

---

## Resolved

(No resolved escalations yet.)

---

## Escalation reasons in detail

- **iteration-cap-hit** — Per-task or per-phase cap from `TASKS.md` reached. The work is either mis-scoped, has ambiguous acceptance criteria, or hit a real bug the agent cannot resolve. Human reads the iterations history and decides.
- **judgment-call** — A decision requires business or design judgment the agent cannot make alone (visual design, copy, brand voice, pricing, compliance interpretation).
- **secret-needed** — The agent needs an API key, certificate, service principal, or other secret it cannot create. Human provides via the project's secret store (Key Vault for cloud, `.env` for local).
- **external-dependency** — Waiting on a vendor (Stripe activation, Plaid production access, DNS propagation, Postmark domain verification, etc.).
- **other** — Anything that does not fit the above. Use the Context field to explain.
