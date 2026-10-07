# minimal-startup-pipeline

Companion repo for **Production Stories 101, Issue #1: "The Pipeline You Need Before You Have a Team"** (Tech Times newsletter on LinkedIn).

This is the smallest CI/CD setup I'd put in place as a founding engineer going from -1 to 0. It's not a showcase. It's meant to be boring, cheap, and easy for the second engineer to understand.

---

## ⭐ Important results (read this first)

What this pipeline gives you, qualitatively. **No benchmark numbers here on purpose.** Your timings and costs depend on your stack and plan.

| You get | How |
|---|---|
| **Same build everywhere** | Runtime pinned in `.nvmrc`, installs with `npm ci` from the lockfile, CI runs the exact `npm run ci` you run locally |
| **"What's in prod?" has an answer** | Deploys only happen from CI, and each build is stamped with the commit SHA (`dist/VERSION`) |
| **Boring rollback** | `Deploy` workflow has a manual trigger that redeploys any SHA you give it |
| **No wasted minutes on stale pushes** | CI `concurrency` group with `cancel-in-progress: true` |
| **No runaway jobs** | Explicit `timeout-minutes` (GitHub's default is 360) |
| **Green CI, broken prod gets caught** | Post-deploy smoke check hits `/healthz` and fails loudly |
| **Least-privilege token** | `permissions: contents: read` on both workflows |

What it deliberately **does not** include yet: staging, preview deploys, matrix builds, test sharding, self-hosted runners, manual approval gates. Add those when the specific pain shows up (see the article's "add things only when pain shows up" section).

---

## Repo layout

The runnable starter is [`example/`](example/). The shortened article is [`article.md`](article.md). Excalidraw-style diagrams are in [`diagrams/`](diagrams/).

```
.
├── article.md
├── SOURCES.md
├── caption.txt
├── diagrams/
│   ├── cicd-friday-failure.png
│   └── cicd-mvp-pipeline.png
└── example/
    ├── .github/workflows/
    │   ├── ci.yml        # PRs + pushes to main: install, lint, test, build
    │   └── deploy.yml    # After CI passes on main (or manual): build, deploy, smoke check
    ├── .nvmrc            # Node version, read by both laptops and CI
    ├── package.json      # All real logic lives in npm scripts, not YAML
    ├── src/              # Tiny HTTP app with a /healthz endpoint
    ├── test/             # node:test tests
    └── scripts/
        ├── build.js      # Stand-in build, stamps commit SHA into dist/VERSION
        ├── deploy.sh     # Placeholder deploy, replace with your platform CLI
        └── smoke.js      # Post-deploy check against SMOKE_URL
```

Zero runtime dependencies. Uses Node's built-in test runner.

## Run it locally

Requirements: Node 22+ (`nvm use` from `example/` picks up `example/.nvmrc`).

```bash
cd example
npm ci          # install from lockfile, exactly like CI
npm run ci      # lint + test + build, exactly like CI
npm start       # serves on http://localhost:3000
curl localhost:3000/healthz
```

Run the smoke check against your local server:

```bash
cd example
SMOKE_URL=http://localhost:3000 npm run smoke
```

## The starter pipeline

### `example/.github/workflows/ci.yml`

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

# Pushing three quick fixes should not run three full pipelines.
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

# Least privilege for the default GITHUB_TOKEN.
permissions:
  contents: read

jobs:
  ci:
    # Keep this job name unique across workflows if you mark it as a required check.
    name: ci
    runs-on: ubuntu-latest
    # Default is 360 minutes. A hung test should not eat your free allowance.
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v7

      - uses: actions/setup-node@v7
        with:
          node-version-file: .nvmrc
          cache: npm

      # Respect the lockfile. Same install everywhere.
      - run: npm ci

      # Same command you run locally. Logic lives in package.json, not YAML.
      - run: npm run ci

      - uses: actions/upload-artifact@v7
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        with:
          name: dist-${{ github.sha }}
          path: dist/
          retention-days: 7
```

### `example/.github/workflows/deploy.yml`

```yaml
name: Deploy

on:
  # Deploy only after CI succeeds on main.
  workflow_run:
    workflows: [CI]
    types: [completed]
    branches: [main]
  # Manual trigger: redeploy any SHA (this is your rollback button).
  workflow_dispatch:
    inputs:
      sha:
        description: Commit SHA to deploy (defaults to latest main)
        required: false

# Never run two deploys at once, and never cancel one halfway.
concurrency:
  group: deploy-production
  cancel-in-progress: false

permissions:
  contents: read
  # Uncomment when you switch to OIDC for cloud credentials:
  # id-token: write

jobs:
  deploy:
    name: deploy
    if: github.event_name == 'workflow_dispatch' || github.event.workflow_run.conclusion == 'success'
    runs-on: ubuntu-latest
    timeout-minutes: 15
    env:
      GIT_SHA: ${{ inputs.sha || github.event.workflow_run.head_sha || github.sha }}
    steps:
      - uses: actions/checkout@v7
        with:
          ref: ${{ env.GIT_SHA }}

      - uses: actions/setup-node@v7
        with:
          node-version-file: .nvmrc
          cache: npm

      - run: npm ci
      - run: npm run build
        env:
          GITHUB_SHA: ${{ env.GIT_SHA }}

      - name: Deploy
        run: ./scripts/deploy.sh
        env:
          DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}

      - name: Smoke check
        if: vars.SMOKE_URL != ''
        run: npm run smoke
        env:
          SMOKE_URL: ${{ vars.SMOKE_URL }}
```

Both workflows pass [`actionlint`](https://github.com/rhysd/actionlint).

## Setup checklist (one afternoon, not one sprint)

1. **Copy** [`example/`](example/) into its own GitHub repo (Actions only reads workflows at a repository root).
2. **Protect `main`**: Settings → Branches (or Rulesets) → require a pull request and require the `ci` status check to pass.
3. **Wire up a real deploy**: replace the body of `example/scripts/deploy.sh` with your platform's CLI. Keep the contract: deploy `$GIT_SHA`, exit non-zero on failure.
4. **Add secrets/vars**: `DEPLOY_TOKEN` as a repository secret if your platform needs one, and `SMOKE_URL` as a repository variable pointing at production.
5. **Rollback drill**: Actions → Deploy → Run workflow → paste the previous SHA. Do this once before you need it.

## Gotchas worth knowing (verified against GitHub docs at time of writing)

- **Plan limits on private repos.** On GitHub Free, environment secrets, environment protection rules (required reviewers, wait timers) and some branch protection features only apply to public repos. That's why this starter uses repository-level secrets and a manual `workflow_dispatch` instead of an approval-gated environment. Check your plan before designing around those features.
- **Minutes.** GitHub Free includes 2,000 Actions minutes/month for private repos on standard hosted runners. Public repos on standard runners are free. macOS runners cost far more per minute than Linux, so keep macOS jobs to what truly needs them.
- **`workflow_run` reads the workflow file from the default branch.** Changes to `deploy.yml` take effect once they're merged to `main`.
- **Unique job names** if you mark a check as required, otherwise you can get ambiguous status results and blocked PRs.
- **Self-hosted runners** are currently free per GitHub's billing docs (a per-minute charge announced in Dec 2025 was postponed). They still cost you a machine, patching, and on-call time.
- **Move to OIDC** for cloud deploys instead of long-lived access keys in secrets. Uncomment `id-token: write` and follow your cloud provider's GitHub OIDC guide.

## When to grow this

Add each of these when you feel the matching pain, not before:

- Staging environment → something passed tests but broke on real config
- Migration checks against a throwaway DB in CI → a migration failed or locked a table in prod
- Preview deploys per PR → non-engineers need to review changes before merge
- Approval gates → deploys carry real risk (needs a higher GitHub plan for private repos)
- Test sharding / parallel jobs → people stop waiting for CI

## License

MIT. Fork it, break it, and share what your first production failure taught you.
