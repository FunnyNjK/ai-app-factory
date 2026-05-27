#!/usr/bin/env python3
"""Lint AI-maintained planning markdown for the structure /ai/AI_RULES.md requires.

This is a machine-readable check of the (Hard) rules in /ai/AI_RULES.md:

  - Task Quality Rules — every task block in TASKS.md has the required
    subsections (Goal, Prerequisites, Scope Included/Excluded, Acceptance
    Criteria, Verification, Test Requirements, Security Considerations,
    Cost Considerations, Rollback / Recovery, Known Blockers, Dev
    Environment Constraints, Handoff Notes) plus the metadata header
    (Status, Owner, Priority).

  - DECISIONS.md — every ADR has Date, Status, Decision, Reason,
    Tradeoffs, Related Tasks. (The ADR Template block in DECISIONS.md is
    skipped — it's a template, not an ADR.)

  - Planning-File Hygiene Rules — every planning file we lint has a
    "Last Updated: YYYY-MM-DD" line; CURRENT_STATE.md ≤ 80 lines;
    HANDOFF.md ≤ 50 lines.

Run from repo root:
    python3 scripts/lint-planning.py

Exit codes:
    0 — all checks passed
    1 — one or more violations found

The linter is intentionally lightweight (stdlib only) so CI doesn't need
extra dependencies. Add new checks by extending the `check_*` functions.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Files we lint. Paths are relative to repo root.
PLANNING_FILES = [
    "ai/TASKS.md",
    "ai/DECISIONS.md",
    "ai/CURRENT_STATE.md",
    "ai/HANDOFF.md",
    "ai/ARCHITECTURE.md",
    "ai/SOLUTION.md",
    "ai/ROADMAP.md",
    "ai/SPEC.md",
    "ai/TESTING.md",
    "ai/DEPLOYMENT.md",
    "ai/BUDGET.md",
    "ai/DEV_ENVIRONMENT.md",
    "ai/DONE_LOG.md",
    "ai/WORKFLOW.md",
    "ai/AI_RULES.md",
    "ai/START_HERE.md",
]

# Required sections in every task block.
# Header metadata appear as "Status: ...", "Owner: ...", "Priority: ..."
# Subsections appear as H4 ("#### Goal", etc).
TASK_HEADER_FIELDS = ["Status", "Owner", "Priority"]
TASK_REQUIRED_SECTIONS = [
    "Goal",
    "Prerequisites",
    "Scope Included",
    "Scope Excluded",
    "Acceptance Criteria",
    "Verification",
    "Test Requirements",
    "Security Considerations",
    "Cost Considerations",
    "Rollback / Recovery",
    "Known Blockers",
    "Dev Environment Constraints",
    "Handoff Notes",
]

# Required ADR fields.
ADR_HEADER_FIELDS = ["Date", "Status"]
ADR_REQUIRED_SECTIONS = [
    "Decision",
    "Reason",
    "Tradeoffs",
    "Related Tasks",
]

# Line caps (Hygiene Rules in AI_RULES.md).
LINE_CAPS = {
    "ai/CURRENT_STATE.md": 80,
    "ai/HANDOFF.md": 50,
}

LAST_UPDATED_RE = re.compile(r"^Last Updated:\s*(\d{4}-\d{2}-\d{2})\s*$")
TASK_HEADING_RE = re.compile(r"^###\s+(P\d+-T\d+):\s+(.+)$")
ADR_HEADING_RE = re.compile(r"^##\s+(ADR-\d+):\s+(.+)$")
ADR_TEMPLATE_HEADING_RE = re.compile(r"^##\s+ADR-XXX", re.IGNORECASE)


@dataclass
class Finding:
    severity: str  # "error" or "warning"
    file: str
    line: int
    message: str

    def format(self) -> str:
        return f"{self.severity.upper():7} {self.file}:{self.line}: {self.message}"


@dataclass
class LintResult:
    findings: list[Finding] = field(default_factory=list)

    def error(self, file: str, line: int, message: str) -> None:
        self.findings.append(Finding("error", file, line, message))

    def warning(self, file: str, line: int, message: str) -> None:
        self.findings.append(Finding("warning", file, line, message))

    @property
    def errors(self) -> list[Finding]:
        return [f for f in self.findings if f.severity == "error"]

    @property
    def warnings(self) -> list[Finding]:
        return [f for f in self.findings if f.severity == "warning"]


def read_lines(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8").splitlines()


def find_last_updated(lines: list[str]) -> tuple[int, str] | None:
    """Return (line_number_1indexed, date_string) or None."""
    # Look in the first ~10 lines (after title and any blank line).
    for i, line in enumerate(lines[:10], start=1):
        m = LAST_UPDATED_RE.match(line.strip())
        if m:
            return i, m.group(1)
    return None


def split_blocks(
    lines: list[str], heading_re: re.Pattern[str], skip: re.Pattern[str] | None = None
) -> list[tuple[int, str, str, list[str]]]:
    """Return blocks as (start_line_1idx, id, title, body_lines).

    A block runs from one matching heading until the next matching heading
    of the same level, or EOF. ``skip`` lets us ignore template blocks
    (e.g. the literal ADR Template inside DECISIONS.md).
    """
    blocks: list[tuple[int, str, str, list[str]]] = []
    current: tuple[int, str, str, list[str]] | None = None
    for i, line in enumerate(lines, start=1):
        if skip is not None and skip.match(line):
            # Close any open block and skip this section entirely.
            if current is not None:
                blocks.append(current)
                current = None
            continue
        m = heading_re.match(line)
        if m:
            if current is not None:
                blocks.append(current)
            current = (i, m.group(1), m.group(2), [])
            continue
        if current is not None:
            current[3].append(line)
    if current is not None:
        blocks.append(current)
    return blocks


def has_header_field(body: list[str], field_name: str) -> bool:
    needle = re.compile(rf"^{re.escape(field_name)}:\s*.+", re.MULTILINE)
    return any(needle.match(line) for line in body)


def has_subsection(body: list[str], section_name: str) -> bool:
    # H4 marker per /ai/templates/TASK_TEMPLATE.md and DECISIONS.md ADR template.
    # ADRs use H3 ("### Decision"); tasks use H4 ("#### Goal"). Accept H3 or H4.
    needle = re.compile(rf"^#{{3,4}}\s+{re.escape(section_name)}\s*$")
    return any(needle.match(line) for line in body)


def check_last_updated(rel: str, lines: list[str], result: LintResult) -> None:
    if not find_last_updated(lines):
        result.error(rel, 1, "missing 'Last Updated: YYYY-MM-DD' line near the top")


def check_line_cap(rel: str, lines: list[str], result: LintResult) -> None:
    cap = LINE_CAPS.get(rel)
    if cap is None:
        return
    n = len(lines)
    if n > cap:
        result.error(
            rel,
            n,
            f"file is {n} lines; hygiene rule caps {rel} at {cap}. "
            "Compact: move detail into DONE_LOG.md.",
        )


def check_tasks(rel: str, lines: list[str], result: LintResult) -> None:
    blocks = split_blocks(lines, TASK_HEADING_RE)
    for start, task_id, title, body in blocks:
        for fieldname in TASK_HEADER_FIELDS:
            if not has_header_field(body, fieldname):
                result.error(
                    rel,
                    start,
                    f"task {task_id} ({title!r}) missing header field '{fieldname}:'",
                )
        for section in TASK_REQUIRED_SECTIONS:
            if not has_subsection(body, section):
                result.error(
                    rel,
                    start,
                    f"task {task_id} ({title!r}) missing required section '#### {section}'",
                )


def check_adrs(rel: str, lines: list[str], result: LintResult) -> None:
    # Skip the literal ADR Template block at the top of DECISIONS.md.
    blocks = split_blocks(lines, ADR_HEADING_RE, skip=ADR_TEMPLATE_HEADING_RE)
    for start, adr_id, title, body in blocks:
        for fieldname in ADR_HEADER_FIELDS:
            if not has_header_field(body, fieldname):
                result.error(
                    rel,
                    start,
                    f"ADR {adr_id} ({title!r}) missing header field '{fieldname}:'",
                )
        for section in ADR_REQUIRED_SECTIONS:
            if not has_subsection(body, section):
                result.error(
                    rel,
                    start,
                    f"ADR {adr_id} ({title!r}) missing required section '### {section}'",
                )


def lint_file(rel: str, result: LintResult) -> None:
    path = REPO_ROOT / rel
    if not path.exists():
        result.warning(rel, 0, "planning file missing (skipping)")
        return
    lines = read_lines(path)
    check_last_updated(rel, lines, result)
    check_line_cap(rel, lines, result)
    if rel.endswith("TASKS.md"):
        check_tasks(rel, lines, result)
    if rel.endswith("DECISIONS.md"):
        check_adrs(rel, lines, result)


def main() -> int:
    result = LintResult()
    for rel in PLANNING_FILES:
        lint_file(rel, result)

    for f in result.findings:
        print(f.format())

    n_err = len(result.errors)
    n_warn = len(result.warnings)
    print(f"\n{n_err} error(s), {n_warn} warning(s).")
    return 1 if n_err else 0


if __name__ == "__main__":
    sys.exit(main())
