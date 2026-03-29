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

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is not installed"
  exit 1
fi

echo "== Repo =="
echo "$REPO"
echo

echo "== Latest workflow runs =="
GH_TOKEN="$GITHUB_TOKEN" gh run list --repo "$REPO" --limit 5 || true
echo

LATEST_JSON=$(GH_TOKEN="$GITHUB_TOKEN" gh run list --repo "$REPO" --workflow "$WORKFLOW_NAME" --limit 5 --json databaseId,status,conclusion,displayTitle,workflowName,headBranch,url,createdAt,updatedAt 2>/dev/null || echo '[]')

echo "== Latest Pages workflow JSON =="
echo "$LATEST_JSON"
echo

readarray -t RUN_FIELDS < <(python3 - <<'PY' "$LATEST_JSON"
import json, sys
raw = sys.argv[1]
try:
    data = json.loads(raw)
except Exception:
    data = []
latest = data[0] if data else {}
success = next((r for r in data if r.get("conclusion") == "success"), {})
print(latest.get("databaseId", ""))
print(latest.get("status", ""))
print(latest.get("conclusion", ""))
print(latest.get("createdAt", ""))
print(latest.get("updatedAt", ""))
print(success.get("databaseId", ""))
print(success.get("updatedAt", ""))
PY
)

RUN_ID="${RUN_FIELDS[0]:-}"
RUN_STATUS="${RUN_FIELDS[1]:-}"
RUN_CONCLUSION="${RUN_FIELDS[2]:-}"
RUN_CREATED_AT="${RUN_FIELDS[3]:-}"
RUN_UPDATED_AT="${RUN_FIELDS[4]:-}"
LAST_SUCCESS_RUN_ID="${RUN_FIELDS[5]:-}"
LAST_SUCCESS_UPDATED_AT="${RUN_FIELDS[6]:-}"

human_age() {
  python3 - <<'PY' "$1"
from datetime import datetime, timezone
import sys
iso = sys.argv[1]
if not iso:
    print("unknown")
    raise SystemExit
try:
    dt = datetime.fromisoformat(iso.replace('Z', '+00:00'))
    now = datetime.now(timezone.utc)
    seconds = int(max(0, (now - dt).total_seconds()))
    if seconds < 60:
        print(f"{seconds}s ago")
    elif seconds < 3600:
        print(f"{seconds // 60}min ago")
    elif seconds < 86400:
        print(f"{seconds // 3600}h ago")
    else:
        print(f"{seconds // 86400}d ago")
except Exception:
    print("unknown")
PY
}

LAST_SUCCESS_AGE="$(human_age "$LAST_SUCCESS_UPDATED_AT")"

if [ -n "$RUN_ID" ]; then
  echo "== Latest Pages workflow summary =="
  echo "run_id=$RUN_ID"
  echo "status=$RUN_STATUS"
  echo "conclusion=$RUN_CONCLUSION"
  echo "created_at=$RUN_CREATED_AT"
  echo "updated_at=$RUN_UPDATED_AT"
  echo

  if [ -n "$LAST_SUCCESS_RUN_ID" ]; then
    echo "last_success_run_id=$LAST_SUCCESS_RUN_ID"
    echo "last_success_published=$LAST_SUCCESS_UPDATED_AT"
    echo "last_success_age=$LAST_SUCCESS_AGE"
    echo
  fi

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

PAGES_URL=$(python3 - <<'PY' "$PAGES_JSON"
import json, sys
raw = sys.argv[1]
try:
    data = json.loads(raw)
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
    if [ -n "$LAST_SUCCESS_RUN_ID" ]; then
      echo "Last successful publish: $LAST_SUCCESS_AGE"
    fi
  else
    echo "Pages site exists at: $PAGES_URL"
    echo "But latest workflow conclusion is: ${RUN_CONCLUSION:-unknown}"
    if [ -n "$LAST_SUCCESS_RUN_ID" ]; then
      echo "Last successful publish: $LAST_SUCCESS_AGE"
    fi
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
