---
paths:
  - ".github/**"
---

# Pull Request Conventions

## Base Branch

**All PRs target `main` as the base branch.** `main` is the default branch; pushes to `main` auto-deploy to Railway staging. Production deploys are manual via `workflow_dispatch` on `deploy-railway.yml`.

```bash
gh pr create --draft --base main
```

## Other Conventions

- Always open in draft mode
- Titles use conventional commit format: `type(scope): description`
- Check for PR templates at `.github/PULL_REQUEST_TEMPLATE.md` before writing the description
