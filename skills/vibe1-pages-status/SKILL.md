---
name: vibe1-pages-status
description: Check whether the GitHub Pages deployment pipeline for the `donald-w/vibe1` repository ran, whether it succeeded, what URL it deployed to, and if it failed, identify the exact failure reason from GitHub Actions and Pages API output. Use when asked to verify the Pages pipeline status for vibe1, confirm the live URL, or explain why the deployment did not happen.
---

# vibe1 Pages Status

Check the GitHub Pages deployment for `donald-w/vibe1` using the bundled script:

```bash
bash skills/vibe1-pages-status/scripts/check_vibe1_pages.sh
```

The script reports:

- latest workflow runs for the Pages workflow
- whether the newest run is queued, in progress, succeeded, or failed
- if failed, the relevant job/log output and the most likely reason
- GitHub Pages API state, including the live URL and HTTPS/custom-domain state when available
- a basic smoke test that fetches the live `index.html` after publication is confirmed

## Decision rule

Conclude the pipeline **ran successfully** only if both are true:

1. the latest `Deploy static site to Pages` workflow run completed successfully
2. the Pages API returns a site object with a URL

If the workflow failed, prefer the explicit GitHub error from logs over guessing.

## Notes

- This skill is repo-specific to `donald-w/vibe1`.
- It expects `gh` to be installed and `GITHUB_TOKEN` to already be available in the environment.
- If `gh api repos/donald-w/vibe1/pages` returns 404/Not Found, Pages is not fully enabled for the repo yet.
