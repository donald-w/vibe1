#!/usr/bin/env bash
set -euo pipefail

REPO="donald-w/vibe1"
WORKFLOW_NAME="Deploy static site to Pages"

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh is not installed"
  exit 1
fi

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "ERROR: GITHUB_TOKEN is not set in the environment"
  exit 1
fi

echo "== Repo =="
echo "$REPO"
echo

echo "== Latest workflow runs =="
GH_TOKEN="$GITHUB_TOKEN" gh run list --repo "$REPO" --limit 5 || true
echo

LATEST_JSON=$(GH_TOKEN="$GITHUB_TOKEN" gh run list --repo "$REPO" --workflow "$WORKFLOW_NAME" --limit 1 --json databaseId,status,conclusion,displayTitle,workflowName,headBranch,url 2>/dev/null || echo '[]')

echo "== Latest Pages workflow JSON =="
echo "$LATEST_JSON"
echo

RUN_ID=$(printf '%s' "$LATEST_JSON" | python3 - <<'PY'
import json,sys
try:
    data=json.load(sys.stdin)
    print(data[0]["databaseId"] if data else "")
except Exception:
    print("")
PY
)

RUN_STATUS=$(printf '%s' "$LATEST_JSON" | python3 - <<'PY'
import json,sys
try:
    data=json.load(sys.stdin)
    print(data[0].get("status","") if data else "")
except Exception:
    print("")
PY
)

RUN_CONCLUSION=$(printf '%s' "$LATEST_JSON" | python3 - <<'PY'
import json,sys
try:
    data=json.load(sys.stdin)
    print(data[0].get("conclusion","") if data else "")
except Exception:
    print("")
PY
)

if [ -n "$RUN_ID" ]; then
  echo "== Latest Pages workflow summary =="
  echo "run_id=$RUN_ID"
  echo "status=$RUN_STATUS"
  echo "conclusion=$RUN_CONCLUSION"
  echo

  echo "== Run view =="
  GH_TOKEN="$GITHUB_TOKEN" gh run view "$RUN_ID" --repo "$REPO" || true
  echo

  if [ "$RUN_CONCLUSION" = "failure" ]; then
    echo "== Failure log excerpt =="
    GH_TOKEN="$GITHUB_TOKEN" gh run view "$RUN_ID" --repo "$REPO" --log 2>&1 | tail -120 || true
    echo
  fi
else
  echo "No Pages workflow run found."
  echo
fi

echo "== Pages API =="
PAGES_JSON=$(GH_TOKEN="$GITHUB_TOKEN" gh api "repos/$REPO/pages" 2>&1 || true)
echo "$PAGES_JSON"
echo

PAGES_URL=$(printf '%s' "$PAGES_JSON" | python3 - <<'PY'
import json,sys
text=sys.stdin.read()
try:
    data=json.loads(text)
    print(data.get("html_url", ""))
except Exception:
    print("")
PY
)

if [ -n "$PAGES_URL" ]; then
  echo "== Conclusion =="
  if [ "$RUN_CONCLUSION" = "success" ]; then
    echo "Pipeline ran successfully."
    echo "Live URL: $PAGES_URL"
  else
    echo "Pages site exists at: $PAGES_URL"
    echo "But latest workflow conclusion is: ${RUN_CONCLUSION:-unknown}"
  fi
else
  echo "== Conclusion =="
  if [ "$RUN_CONCLUSION" = "failure" ]; then
    echo "Pipeline ran and failed. See failure log excerpt above for the reason."
  elif [ "$RUN_STATUS" = "in_progress" ] || [ "$RUN_STATUS" = "queued" ]; then
    echo "Pipeline has started but has not finished yet."
  else
    echo "Could not confirm a live Pages site yet."
  fi
fi
