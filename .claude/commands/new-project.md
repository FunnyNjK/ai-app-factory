---
description: Scaffold a new project folder with its own Claude-specific instructions and templates
---

Scaffold a new project folder under a sibling directory (default: `../<project-name>/`, sibling to this factory repo) with project-specific Claude instructions and a starter set of factory templates.

Before scaffolding, confirm with the product owner:

1. **Project name** — short, kebab-case (for example, `acme-marketing-site`).
2. **Target location** — sibling folder by default; ask if they want a different parent directory.
3. **Project type** — pick the closest blueprint under `blueprints/`:
   - `marketing-site.md`
   - `static-web-app.md`
   - `full-stack-web-app.md`
   - `api-service.md`
   - `azure-functions.md`
   - `stripe-app.md`
   - `plaid-app.md`
   - `postmark-email.md`

Then run the scaffold script:

```bash
<factory-path>/scripts/scaffold-new-project.sh \
  --name <project-name> \
  --blueprint <blueprint> \
  --goal "<one-line-goal>" \
  --users "<primary-users>"
```

The script is the authoritative implementation; the skill `.claude/skills/spawn-new-project/SKILL.md` describes the procedure and inputs in more detail. After it finishes, run `scripts/validate-project.sh <new-project-path>` to confirm placeholders are filled and required files exist.

After scaffolding completes:

- Tell the product owner the absolute path to the new project folder.
- Recommend they run `/intake` inside the new folder to begin Project Intake Mode.

Follow the collaboration style in `CLAUDE.md` Section 11.
