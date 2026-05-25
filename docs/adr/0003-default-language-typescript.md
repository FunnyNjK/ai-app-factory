# ADR-0003: Default implementation language is TypeScript

## Document metadata

| Field | Value |
|---|---|
| Number | 0003 |
| Date | 2026-05-25 |
| Author | Architect (Claude) |
| Approval owner | Product owner |
| Supersedes | None |

## Status

Accepted

## Context

The factory builds web frontends, REST APIs, Azure Functions, webhook handlers, and small integrations. A single language across frontend and backend removes context switches, lets the architect share types between the API contract and the React client, and means tests, lint, and tooling can be standardized.

Cursor and Codex both produce more reliable output when the language is one they have strong, current knowledge of.

## Decision

TypeScript is the factory's default implementation language for both frontend and backend code. The `.cursor/rules` file, blueprints, sample handoffs, and Bicep starter all assume Node.js / TypeScript.

Projects may use another language when justified (a Python data pipeline, a C# integration with a Windows ecosystem). Doing so requires an ADR naming the language and explaining why TypeScript is unsuitable for the specific work.

## Alternatives considered

1. JavaScript (no TypeScript) — faster to write small things, but loses the cross-stack typing benefits and produces brittle handoffs at the API boundary.
2. Python — excellent for data and ML work. Not chosen as default because the factory's typical projects are web apps and integrations, where the frontend ends up in JS anyway and splitting the stack adds context overhead.
3. C# — strong fit for Azure Functions and enterprise integration, weaker fit for modern frontends.
4. Go — strong fit for services, weaker fit for frontends and the factory's "small and fast to ship" sweet spot.

## Consequences

### Positive

- Frontend and backend share types via a small `types/` package per project.
- Linting, formatting, and test tooling are uniform across projects.
- Cursor produces higher-quality output for TypeScript than for less-common stacks.
- Azure Functions Node 20 runtime is well-supported.

### Negative

- Bundle size and cold start are slightly worse than a Go or Rust equivalent. Acceptable for the small-app scale the factory targets.
- Locks the factory out of ecosystems where TypeScript is not idiomatic. Acceptable given the scope (web apps + integrations).

### Neutral

- The architect role file (CLAUDE.md) names TypeScript as the default but explicitly permits override.

## Follow-up

- `standards/coding-standards.md` calls out TypeScript expectations.
- `.cursor/rules/ai-app-factory-developer.mdc` names TypeScript as the default for backend and frontend.

## References

- `standards/coding-standards.md`
- `.cursor/rules/ai-app-factory-developer.mdc`
