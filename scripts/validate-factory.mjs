import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, extname, join, relative, resolve } from "node:path";

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const root = process.cwd();

const requiredFiles = [
  ".cursor/rules/ai-app-factory-developer.mdc",
  ".github/pull_request_template.md",
  ".github/workflows/ci.yml",
  ".gitattributes",
  ".gitignore",
  ".markdownlint-cli2.jsonc",
  "AGENTS.md",
  "CLAUDE.md",
  "CONTRIBUTING.md",
  "MANIFEST.md",
  "OPERATING_MODEL.md",
  "README.md",
  "blueprints/api-service.md",
  "blueprints/azure-functions.md",
  "blueprints/full-stack-web-app.md",
  "blueprints/marketing-site.md",
  "blueprints/plaid-app.md",
  "blueprints/postmark-email.md",
  "blueprints/static-web-app.md",
  "blueprints/stripe-app.md",
  "docs/adr/0001-default-cloud-azure.md",
  "docs/adr/0002-default-email-postmark.md",
  "docs/adr/0003-default-language-typescript.md",
  "docs/adr/0004-default-iac-bicep.md",
  "docs/adr/0005-greenfield-only-scope.md",
  "docs/adr/0006-three-agent-signoff.md",
  "docs/adr/0007-default-database-postgres-then-sql-then-cosmos.md",
  "docs/adr/0008-per-slice-and-per-phase-gating.md",
  "docs/adr/0009-autonomous-orchestrator.md",
  "docs/adr/0010-gate-d-signoff-adapter.md",
  "docs/playbooks/escalation-trail-example.md",
  "docs/playbooks/first-project-walkthrough.md",
  "examples/sample-architecture.md",
  "examples/sample-codex-qe-handoff.md",
  "examples/sample-cursor-handoff.md",
  "examples/sample-marketing-site-signoffs.md",
  "examples/sample-project-brief.md",
  "examples/sample-test-plan.md",
  "examples/sample-plaid-architecture.md",
  "examples/sample-plaid-codex-qe-handoff.md",
  "examples/sample-plaid-cursor-handoff.md",
  "examples/sample-plaid-project-brief.md",
  "examples/sample-plaid-test-plan.md",
  "examples/sample-stripe-architecture.md",
  "examples/sample-stripe-codex-qe-handoff.md",
  "examples/sample-stripe-cursor-handoff.md",
  "examples/sample-stripe-project-brief.md",
  "examples/sample-stripe-test-plan.md",
  "examples/sample-stripe-threat-model.md",
  "prompts/claude-architect.md",
  "prompts/codex-quality-engineer.md",
  "prompts/cursor-developer.md",
  "scripts/orchestrator/claude-phase-review.sh",
  "scripts/orchestrator/codex-slice-review.sh",
  "scripts/orchestrator/codex-slice-verify.sh",
  "scripts/orchestrator/cursor-slice.sh",
  "scripts/orchestrator/gate-d-signoff.sh",
  "scripts/orchestrator/lib.sh",
  "scripts/orchestrator/orchestrate.sh",
  "scripts/validate-factory.mjs",
  "standards/api-standards.md",
  "standards/ci-cd-standards.md",
  "standards/coding-standards.md",
  "standards/documentation-standards.md",
  "standards/git-workflow.md",
  "standards/observability-standards.md",
  "standards/security-standards.md",
  "standards/testing-standards.md",
  "templates/.env.example",
  "templates/ADR.md",
  "templates/API_SPEC.md",
  "templates/ARCHITECTURE.md",
  "templates/COST_ESTIMATE.md",
  "templates/PROJECT.md",
  "templates/RELEASE_CHECKLIST.md",
  "templates/RUNBOOK.md",
  "templates/SECURITY.md",
  "templates/SIGNOFF.md",
  "templates/TEST_PLAN.md",
  "templates/THREAT_MODEL.md",
  "templates/infra/README.md",
  "templates/infra/main.bicep",
  "templates/infra/main.bicepparam.example",
];

const allowedEnvDefaults = new Map([
  ["APP_ENV", "local"],
  ["APP_BASE_URL", "http://localhost:3000"],
  ["ALLOWED_ORIGIN", "http://localhost:3000"],
  ["PLAID_ENV", "sandbox"],
  ["PLAID_PRODUCTS", "transactions"],
  ["PLAID_COUNTRY_CODES", "US"],
]);

const vagueQualityPhrases = [
  "loads quickly",
  "site loads quickly",
  "basic accessibility checks pass",
  "basic accessibility",
  "useful success/error",
  "useful success and error",
];

const linkCheckIgnoredExactPaths = new Set([
  "src/",
  "tests/",
  "docs/",
  "api/",
  "node_modules/",
  "dist/",
  "build/",
  ".next/",
  ".vercel/",
  ".output/",
  "coverage/",
  "playwright-report/",
  "test-results/",
  ".vscode/",
  ".idea/",
  "src/components/Foo.tsx",
  "api/functions/contact/index.ts",
  "app/ or pages/",
]);

const linkCheckIgnoredPrefixes = ["http://", "https://", "mailto:"];
const linkCheckPathLikePattern = /^[^\s*`]+\/[^\s*`]+$/;
const envVarReferencePattern = /^([A-Z][A-Z0-9_]{2,})=/;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const errors = [];

function fail(message) {
  errors.push(message);
}

function repoPath(path) {
  return join(root, path);
}

function toRepoPath(path) {
  return relative(root, path).replaceAll("\\", "/");
}

function read(path) {
  return readFileSync(repoPath(path), "utf8");
}

function walk(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const fullPath = join(dir, entry.name);
    if (entry.name === ".git" || entry.name === "node_modules") {
      return [];
    }
    if (entry.isDirectory()) {
      return walk(fullPath);
    }
    return [fullPath];
  });
}

function isMarkdown(file) {
  const ext = extname(file).toLowerCase();
  return ext === ".md" || ext === ".mdc";
}

function looksLikeFilePath(candidate) {
  if (!linkCheckPathLikePattern.test(candidate)) return false;
  if (candidate.endsWith("/")) return false;
  if (linkCheckIgnoredExactPaths.has(candidate)) return false;
  if (linkCheckIgnoredPrefixes.some((p) => candidate.startsWith(p))) return false;
  if (/[\s()=]/.test(candidate)) return false;
  if (candidate.startsWith("/api/") || candidate.startsWith("api/v")) return false;
  if (/^ADR-/i.test(candidate)) return false;
  if (/[<>]/.test(candidate)) return false;
  if (!/\.[A-Za-z0-9]+$/.test(candidate)) return false;
  return true;
}

// ---------------------------------------------------------------------------
// Checks
// ---------------------------------------------------------------------------

function checkRequiredFilesExist() {
  for (const file of requiredFiles) {
    if (!existsSync(repoPath(file))) {
      fail(`Missing required factory file: ${file}`);
    }
  }
}

function checkPerFileContent() {
  for (const file of walk(root)) {
    const repoRelativePath = toRepoPath(file);
    const extension = extname(file).toLowerCase();
    const content = readFileSync(file, "utf8");

    if (isMarkdown(file)) {
      const fenceCount = (content.match(/^```/gm) ?? []).length;
      if (fenceCount % 2 !== 0) {
        fail(`Unclosed Markdown code fence in ${repoRelativePath}`);
      }

      if (!repoRelativePath.startsWith("templates/") && /\bTODO\b/.test(content)) {
        fail(`TODO placeholder found outside templates: ${repoRelativePath}`);
      }

      const lowerContent = content.toLowerCase();
      for (const phrase of vagueQualityPhrases) {
        if (lowerContent.includes(phrase)) {
          fail(`Vague quality phrase "${phrase}" found in ${repoRelativePath}`);
        }
      }
    }

    if (extension === ".json" || extension === ".jsonc") {
      try {
        JSON.parse(content.replace(/^\s*\/\/.*$/gm, ""));
      } catch (error) {
        fail(`Invalid JSON-like file ${repoRelativePath}: ${error.message}`);
      }
    }
  }
}

function checkManifestPaths() {
  const manifest = read("MANIFEST.md");
  const manifestPaths = [...manifest.matchAll(/`([^`]+)`/g)]
    .map((match) => match[1])
    .filter((entry) => /[/.]/.test(entry) && !entry.includes("*"))
    .filter((entry) => !entry.endsWith("/"))
    .filter((entry) => !/[<>]/.test(entry));

  for (const path of manifestPaths) {
    if (!existsSync(repoPath(path))) {
      fail(`MANIFEST.md references a missing path: ${path}`);
    }
  }
}

function checkCrossDocBacktickPaths() {
  for (const file of walk(root)) {
    const repoRelativePath = toRepoPath(file);
    if (!isMarkdown(file)) continue;
    if (repoRelativePath === "MANIFEST.md") continue;

    const content = readFileSync(file, "utf8");
    const fileDir = dirname(file);

    for (const match of content.matchAll(/`([^`\n]+)`/g)) {
      let candidate = match[1].trim().replace(/#.*$/, "");
      if (!looksLikeFilePath(candidate)) continue;

      const rootResolved = repoPath(candidate);
      const localResolved = resolve(fileDir, candidate);
      if (existsSync(rootResolved) || existsSync(localResolved)) continue;

      fail(`${repoRelativePath} references a missing path: \`${candidate}\``);
    }
  }
}

function parseEnvExample() {
  const envExample = read("templates/.env.example");
  const envExampleNames = new Set();
  for (const [index, line] of envExample.split(/\r?\n/).entries()) {
    if (!line || line.startsWith("#")) continue;
    const match = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (!match) {
      fail(`Invalid env example line ${index + 1}: ${line}`);
      continue;
    }
    const [, key, value] = match;
    envExampleNames.add(key);
    if (value && allowedEnvDefaults.get(key) !== value) {
      fail(`templates/.env.example contains a non-placeholder value for ${key}`);
    }
  }
  return envExampleNames;
}

function checkCrossDocEnvVars(envExampleNames) {
  for (const file of walk(root)) {
    const repoRelativePath = toRepoPath(file);
    if (!isMarkdown(file)) continue;

    const content = readFileSync(file, "utf8");
    const seen = new Set();
    for (const line of content.split(/\r?\n/)) {
      const match = line.match(envVarReferencePattern);
      if (!match) continue;
      const name = match[1];
      if (seen.has(name)) continue;
      seen.add(name);
      if (!envExampleNames.has(name)) {
        fail(
          `Env variable "${name}" referenced in ${repoRelativePath} but not declared in templates/.env.example`,
        );
      }
    }
  }
}

function checkRequiredFilesNonEmpty() {
  for (const file of requiredFiles) {
    if (!existsSync(repoPath(file))) continue;
    if (statSync(repoPath(file)).size === 0) {
      fail(`Required file is empty: ${file}`);
    }
  }
}

// ---------------------------------------------------------------------------
// Run all checks
// ---------------------------------------------------------------------------

checkRequiredFilesExist();
checkPerFileContent();
checkManifestPaths();
checkCrossDocBacktickPaths();
const envExampleNames = parseEnvExample();
checkCrossDocEnvVars(envExampleNames);
checkRequiredFilesNonEmpty();

if (errors.length > 0) {
  console.error("Factory validation failed:");
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exit(1);
}

console.log("Factory validation passed.");
