# ADR-0015: The orchestrator requires bash ≥ 4 and self-re-execs to reach it

## Status

Accepted

Validated live on 2026-06-08 during the migration of factory development from the Ubuntu host to a macOS (Apple Silicon) MacBook Pro. Extends [ADR-0009](0009-autonomous-orchestrator.md) (the autonomous orchestrator) by pinning an interpreter floor for its bash scripts and making that floor self-healing.

## Context

The factory orchestrator (`scripts/orchestrator/*.sh`) was written and exercised entirely on an Ubuntu host, where `/usr/bin/env bash` resolves to **bash 5**. Each role adapter builds its agent prompt with a here-document inside a command substitution:

```bash
prompt=$(cat <<PROMPT_EOF
... use `git log --oneline -n 5` and `git diff HEAD~1` ...
PROMPT_EOF
)
```

(The real adapters assign to an upper-case `PROMPT`; lower-cased here only so this
ADR does not trip the factory's env-var cross-reference check.)

**bash 3.2 cannot parse this.** Command substitution `$( … )` containing a heredoc — especially one whose body contains backticks — trips a parser bug that was fixed in bash 4.0. bash 3.2 reads past the intended end of the substitution and then reports a misleading error far below the real cause:

```
codex-slice-review.sh: line 156: syntax error near unexpected token `;;'
```

This bit when factory development moved to a MacBook for a week. **macOS still ships bash 3.2.57** (2007) as `/bin/bash` — Apple froze it at the last GPLv2 release. The crash surfaced mid-run on `simplytammi` slice 2.3: Cursor implemented and committed the slice, then the Codex slice-review adapter died at parse time before executing a single review step, leaving the slice at `awaiting-review` with the quality gate silently skipped (orchestrator `exit 1`).

Three properties made this worse than a normal "install a newer tool" papercut:

- **It was silent about the cause.** The error names a `;;` on a line that is itself valid; nothing pointed at bash version or the heredoc.
- **`brew install bash` alone did not fix it.** On this machine `/opt/homebrew/bin` sits *after* `/usr/bin:/bin` on `PATH`, so `/bin/bash` 3.2 keeps shadowing the Homebrew bash 5.3. The fix depended on per-invocation `PATH` surgery the operator had to remember every run.
- **Six of the seven adapters use the same `$(cat <<EOF …)` pattern.** They happen to parse under 3.2 today only because their heredoc bodies avoid the exact backtick trigger; any future edit could break another one. The latent dependency on bash ≥ 4 was real, undeclared, and unchecked.

## Decision

**1. The orchestrator and its adapters require bash ≥ 4.** This is a declared prerequisite, not an accident of the dev host. bash 4.0 shipped in 2009; every supported Linux, WSL, and Git Bash provides it. Only stock macOS does not.

**2. Each executable entry point self-re-execs under a modern bash.** A new sourced helper, `scripts/orchestrator/require-bash4.sh`, runs as the first action of every adapter (right after `SCRIPT_DIR` is resolved, before any bash-4-only syntax is parsed). If the current interpreter is bash < 4, it locates a bash ≥ 4 (checking `/opt/homebrew/bin/bash`, `/usr/local/bin/bash`, `/opt/local/bin/bash`, then `PATH`) and `exec`s the calling script under it with the original arguments. The guard is idempotent via `FACTORY_BASH_REEXEC`. This works because bash 3.2 executes a script's leading simple commands *before* it parses the later heredoc that it would choke on — so the re-exec happens first. The helper itself is kept strictly bash-3.2-compatible.

**3. If no modern bash exists, fail fast with a clear, actionable message** (`brew install bash` / `apt-get install bash`) and exit 1 — instead of the cryptic syntax error.

**4. The fix does not depend on `PATH` ordering.** Because the guard re-execs by absolute path, the operator no longer needs to prepend `/opt/homebrew/bin` for every run.

The result: the orchestrator runs unmodified on macOS, and the bash-version dependency is now explicit, enforced, and self-healing rather than latent.

## Alternatives Considered

1. **Rewrite every prompt heredoc to avoid `$( … )` (e.g. `IFS= read -r -d '' PROMPT <<'EOF'`).** Makes the scripts bash-3.2-compatible. Rejected: it is whack-a-mole across seven files, risks subtly altering prompt content (quoting/expansion semantics differ), and would have to be re-litigated on every future script. It also leaves the factory pretending to support a 19-year-old shell it has no reason to support.
2. **Document "prepend `/opt/homebrew/bin` to PATH" and stop there.** Rejected: relies on the operator remembering a `PATH=` prefix on every invocation, and silently breaks again the moment they forget. A tool should make the correct thing automatic.
3. **Fix the operator's shell `PATH` ordering globally.** Reasonable hygiene, and recommended separately, but it is a per-machine change outside the repo; the factory cannot assume it and should not break without it.
4. **Add a passive version check that only errors out (no re-exec).** Better than the status quo, but still forces the operator to fix their environment before any run. The re-exec makes the common case (a modern bash exists somewhere) just work.

## Consequences

### Positive

- The orchestrator runs on stock macOS with no per-invocation `PATH` workaround.
- The bash ≥ 4 dependency is declared, enforced at startup, and documented (`README`, `MANIFEST`, `check-cli-tools.sh`).
- Failures are now legible: a clear "install bash" message instead of a phantom syntax error.
- Protects the other six adapters from the same latent bug regardless of future heredoc edits.

### Negative

- One extra sourced file and a one-line source in each of the eight entry points — a small, uniform maintenance surface. `require-bash4.sh` must stay bash-3.2-parseable (it is the one file the old shell still reads), which is a constraint to remember when editing it.
- A bash-3.2 launch pays a one-time `exec` to restart under the modern bash (negligible).

## Follow-Up

- [x] Add `scripts/orchestrator/require-bash4.sh` and source it from all eight entry points.
- [x] `check-cli-tools.sh` reports the resolved bash version and warns when it is < 4.
- [x] Update `scripts/orchestrator/README.md` Prerequisites and `MANIFEST.md`.
- [ ] **Windows support (separate effort).** The re-exec candidate list is Unix-path-only. When Windows development is taken on, extend the candidate search (Git Bash `C:\Program Files\Git\bin\bash.exe`, WSL) and add a Windows section to the README. Tracked as the start of the cross-platform plan the product owner requested alongside the macOS migration.
- [ ] Consider a CI job that runs `bash -n` on every orchestrator script under both bash 3.2 (expected: guard re-execs at runtime) and bash 5 to catch future regressions.
