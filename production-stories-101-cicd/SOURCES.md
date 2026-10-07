# Sources (checked Oct 7, 2026)

1. GitHub Docs, GitHub Actions billing (free minutes per plan, per-minute rates for Linux/Windows/macOS, self-hosted usage free, cache/artifact allowances): https://docs.github.com/en/billing/concepts/product-billing/github-actions
2. GitHub Changelog, Update to GitHub Actions pricing (Dec 16, 2025: hosted price cut up to 39% from Jan 1, 2026; self-hosted platform charge postponed): https://github.blog/changelog/2025-12-16-coming-soon-simpler-pricing-and-a-better-experience-for-github-actions/
3. GitHub Docs, Deployments and environments (required reviewers, wait timers, environment secrets plan limits for private repos): https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments
4. GitHub Docs, Control workflow concurrency (`concurrency`, `cancel-in-progress`): https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency
5. GitHub Docs, Workflow syntax (`jobs.<job_id>.timeout-minutes`, default 360): https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
6. GitHub Docs, About protected branches (required status checks, unique job name tip): https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches
7. GitHub Docs, OpenID Connect in GitHub Actions (short-lived cloud credentials): https://docs.github.com/en/actions/concepts/security/openid-connect
8. actions/setup-node README (v7 usage, `cache` input, automatic npm caching when package manager is declared, `node-version-file`): https://github.com/actions/setup-node
9. actions/checkout and actions/upload-artifact READMEs (current major version v7): https://github.com/actions/checkout , https://github.com/actions/upload-artifact
10. actionlint (used to lint the companion workflows): https://github.com/rhysd/actionlint
