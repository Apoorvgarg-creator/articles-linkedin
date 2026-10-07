# minimal-startup-pipeline

Minimal Node starter for Production Stories 101, Issue #1. No runtime dependencies. Tests use Node's built-in runner.

## Setup

Node 22 or newer. `nvm use` reads `.nvmrc`.

```bash
npm ci
npm test
npm run ci    # lint, then test, then build
npm start     # http://localhost:3000
curl localhost:3000/healthz
```

`npm test` runs `test/app.test.js` with Node's test runner. `npm run ci` is the same command the CI workflow runs: lint, then test, then build. The build copies `src/` to `dist/` and writes the commit SHA (or `local`) to `dist/VERSION`.

Smoke-check a server that is already running:

```bash
SMOKE_URL=http://localhost:3000 npm run smoke
```

`npm run smoke` exits non-zero when `SMOKE_URL` is unset or `/healthz` does not return `{ "ok": true }`.

## Workflows

These files live in `.github/workflows/`. GitHub Actions only runs workflows from the repository root, so copy this `example/` directory into its own repo (or move the workflows up) before relying on them.

**`ci.yml`** runs on pull requests and on pushes to `main`. It checks out the repo, installs the Node version from `.nvmrc` (with the npm cache), runs `npm ci`, then `npm run ci`. A push to `main` also uploads `dist/` as `dist-<sha>` (kept 7 days). A new push to the same ref cancels the in-progress run. The job times out after 10 minutes. The token is limited to `contents: read`.

**`deploy.yml`** runs after the CI workflow completes successfully on `main`, and when someone starts it by hand (`workflow_dispatch`) with an optional commit SHA. That manual SHA is the rollback button. The job checks out that SHA, runs `npm ci` and `npm run build` (stamping `GITHUB_SHA` into `dist/VERSION`), then `./scripts/deploy.sh`. Deploys share one concurrency group and are not cancelled mid-run. The job times out after 15 minutes.

`scripts/deploy.sh` is a placeholder. It requires `GIT_SHA` and prints that it deployed that SHA. It does not call a hosting platform. `DEPLOY_TOKEN` is only passed through from the `DEPLOY_TOKEN` repository secret; this starter does not define one. Add the secret when you replace the script with a real deploy.

If the repository variable `SMOKE_URL` is set, the workflow runs `npm run smoke` against it after deploy. Leave the variable unset and the smoke step is skipped.
