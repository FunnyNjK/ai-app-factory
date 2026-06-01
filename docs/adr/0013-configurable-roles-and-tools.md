# ADR-0013: Configurable role→tool mapping and a five-role delivery team

## Status

Accepted

Supersedes [ADR-0006](0006-three-agent-signoff.md) (three-agent sign-off → five-agent + product-owner sign-off). Extends [ADR-0008](0008-per-slice-and-per-phase-gating.md) (adds two post-phase gates), [ADR-0009](0009-autonomous-orchestrator.md) (tool-agnostic adapters), [ADR-0010](0010-gate-d-signoff-adapter.md) (Gate D ceremony grows to six parties), and [ADR-0012](0012-interactive-factory-tui.md) (the launcher gains tool detection and a role-configuration wizard).

## Context

The factory builds **apps**. Each app is delivered by a small team of AI agents. Until now that team was hard-coded into the orchestrator: the Architect was always Claude, the Developer always Cursor, the Quality Engineer always Codex. Three facts drove this ADR:

1. **Tool choice should belong to the app, not the factory.** Different projects (and different operators) may want a different CLI driving a given role — Gemini as architect on one project, Codex as developer on another. The CLI is a per-project decision, like the blueprint or the budget caps, not a factory-wide constant.
2. **Two quality functions were missing from the loop.** Nothing ran a dedicated security review or a code-review/refactoring pass between phases. Both belong *after every phase completes*, as blocking gates, so a phase cannot be declared done while it carries an un-reviewed security or maintainability problem.
3. **Agents should be nameable.** Operators want to refer to "Sentinel" (the security reviewer) or "Athena" (the architect), not "the codex sub-session." Names make the TASKS.md trail, the escalation queue, and the launcher readable.

The constraint: the orchestrator's `TASKS.md`/`SIGNOFF.md` machinery parses those files with anchored regexes keyed on stable role tokens. Renaming the *structural anchors* per project would shatter every parser in `scripts/orchestrator/lib.sh`.

## Decision

**1. Five roles, configured per project.** Every scaffolded project carries a `.factory-roles.json` describing its delivery team:

```json
{
  "roles": {
    "architect":   { "tool": "claude", "name": "Claude" },
    "developer":   { "tool": "cursor", "name": "Cursor" },
    "tester":      { "tool": "codex",  "name": "Codex" },
    "security":    { "tool": "codex",  "name": "Security" },
    "code_review": { "tool": "claude", "name": "Code Review" }
  }
}
```

The factory ships defaults in `templates/factory-roles.default.json`; the launcher's new-project wizard overrides `tool` and `name` per role from the detected CLIs. Reads fall back to the built-in defaults so a project without the file still runs.

**2. Four supported tools.** The tool registry is **claude**, **cursor**, **codex**, **gemini**. Each has one headless invocation, consolidated in `tool_invoke` (`scripts/orchestrator/lib.sh`):

| Tool | Binary | Invocation |
|---|---|---|
| claude | `claude` | `claude -p "<prompt>" --dangerously-skip-permissions` |
| cursor | `agent` | `agent -p <flags> -- "<prompt>"` |
| codex | `codex` | `codex exec --sandbox workspace-write "<prompt>"` |
| gemini | `gemini` | `gemini -p "<prompt>" --yolo` |

VS Code is intentionally **not** in the registry: its `code` CLI opens an editor and cannot drive an unattended agent loop, so offering it as a role would create a role that silently cannot execute.

**3. Names are display/prompt-level, not structural.** The `TASKS.md` and `SIGNOFF.md` parser anchors stay the canonical role tokens (`architect`, `developer`, `tester`, `security`, `code_review`). Custom names are injected into the agent prompts ("You are **Sentinel**, the Security reviewer…") and rendered in the launcher and human-facing prose. The machine never keys on the custom name.

**4. Two new blocking phase gates.** After a phase's `review` is approved, the loop runs `Phase N security`, then `Phase N code-review`. **Both must reach `approved`** before `main` fast-forwards and the next phase begins. Each is a tool-agnostic adapter (`security-phase-review.sh`, `codereview-phase-review.sh`) that drives whichever tool the config assigns to that role. Sequence per phase: slices → review → security → code-review.

**5. Gate D grows to six parties.** Security and Code-Review each record a Gate D sign-off, alongside Architect, Developer, and Quality Engineer, plus the human product owner. This supersedes the three-agent model of ADR-0006.

## Alternatives Considered

1. **Keep three hard-coded roles; add security/code-review as factory-wide constants.** Rejected: tool choice is genuinely a per-project decision, and hard-coding two more tools repeats the rigidity this ADR removes.
2. **Make custom names the structural identifiers in TASKS.md/SIGNOFF.md.** Rejected: every parser in `lib.sh` anchors on the role token; per-project names would require per-project regexes and break `validate-project.sh`. Names as a display layer get the readability without the fragility.
3. **Run security and code-review per *slice* instead of per *phase*.** Rejected: per-slice doubles the gate count and reviews work before it is integrated. Per-phase matches where the architect already reviews cohesively (ADR-0008) and is where security/maintainability problems actually surface.
4. **Advisory (non-blocking) security/code-review gates.** Rejected by the product owner: a security finding that does not stop the loop is a finding that ships. Both gates block.
5. **Include VS Code as an assignable tool.** Rejected: not a headless agent; would create non-executable role assignments.

## Consequences

### Positive

- Any of the four tools can fill any role, per project, without code changes.
- Security and maintainability are gated every phase, not deferred to release.
- The TASKS.md trail, escalations, sign-off, and launcher read in the operator's chosen names.
- Tool invocation lives in one place (`tool_invoke`), removing the duplicated CLI flag handling across adapters and the Gate D ceremony.

### Negative

- More moving parts per phase (two extra gates) → longer wall-clock per phase and more iteration-cap surface.
- Gate D now needs six sign-offs; a stuck agent sign-off blocks release until resolved.
- Every tool must keep a stable headless contract; a CLI changing its flags breaks `tool_invoke` for that tool until updated.
- `.factory-roles.json` is a new per-project artifact the refresh tooling must understand.

## Follow-Up

- Wire `tool_invoke` into the three existing adapters and the Gate D ceremony so role→tool is honored everywhere (not just the two new gates).
- Teach `scripts/validate-project.sh` the new phase-gate entries and `.factory-roles.json`.
- Teach `scripts/refresh-project.sh` to detect a missing `.factory-roles.json` on older projects.
- Update `OPERATING_MODEL.md`, `CLAUDE.md`, `AGENTS.md`, and the blueprints to describe five roles and six-party Gate D.
