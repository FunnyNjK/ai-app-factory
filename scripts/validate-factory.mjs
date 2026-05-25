import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { extname, join, relative } from "node:path";

const root = process.cwd();

const requiredFiles = [
  ".cursor/rules/ai-app-factory-developer.mdc",
  ".github/pull_request_template.md",
  ".github/workflows/ci.yml",
  ".gitignore",
  ".markdownlint-cli2.jsonc",
  "AGENTS.md",
  "CLAUDE.md",
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
  "examples/sample-architecture.md",
  "examples/sample-codex-qe-handoff.md",
  "examples/sample-cursor-handoff.md",
  "examples/sample-project-brief.md",
  "examples/sample-test-plan.md",
  "prompts/claude-architect.md",
  "prompts/codex-quality-engineer.md",
  "prompts/cursor-developer.md",
  "scripts/validate-factory.mjs",
  "standards/api-standards.md",
  "standards/ci-cd-standards.md",
  "standards/coding-standards.md",
  "standards/documentation-standards.md",
  "standards/git-workflow.md",
  "standards/security-standards.md",
  "standards/testing-standards.md",
  "templates/.env.example",
  "templates/API_SPEC.md",
  "templates/ARCHITECTURE.md",
  "templates/PROJECT.md",
  "templates/RELEASE_CHECKLIST.md",
  "templates/RUNBOOK.md",
  "templates/SECURITY.md",
  "templates/TEST_PLAN.md",
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

for (const file of requiredFiles) {
  if (!existsSync(repoPath(file))) {
    fail(`Missing required factory file: ${file}`);
  }
}

for (const file of walk(root)) {
  const repoRelativePath = toRepoPath(file);
  const extension = extname(file).toLowerCase();
  const content = readFileSync(file, "utf8");

  if ([".md", ".mdc"].includes(extension)) {
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

const manifest = read("MANIFEST.md");
const manifestPaths = [...manifest.matchAll(/`([^`]+)`/g)]
  .map((match) => match[1])
  .filter((entry) => /[/.]/.test(entry) && !entry.includes("*"))
  .filter((entry) => !entry.endsWith("/"));

for (const path of manifestPaths) {
  if (!existsSync(repoPath(path))) {
    fail(`MANIFEST.md references a missing path: ${path}`);
  }
}

const envExample = read("templates/.env.example");
for (const [index, line] of envExample.split(/\r?\n/).entries()) {
  if (!line || line.startsWith("#")) {
    continue;
  }
  const match = line.match(/^([A-Z0-9_]+)=(.*)$/);
  if (!match) {
    fail(`Invalid env example line ${index + 1}: ${line}`);
    continue;
  }
  const [, key, value] = match;
  if (value && allowedEnvDefaults.get(key) !== value) {
    fail(`templates/.env.example contains a non-placeholder value for ${key}`);
  }
}

for (const file of requiredFiles) {
  if (statSync(repoPath(file)).size === 0) {
    fail(`Required file is empty: ${file}`);
  }
}

if (errors.length > 0) {
  console.error("Factory validation failed:");
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exit(1);
}

console.log("Factory validation passed.");
