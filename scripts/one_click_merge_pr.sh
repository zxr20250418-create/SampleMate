#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 <pr-number> <branch-name> [--evidence] [--skip-build]"
  echo "Example: $0 8 work/pr1d-compact-text-toggle --evidence"
}

if [[ $# -lt 2 ]]; then
  usage
  exit 2
fi

PR="$1"
BRANCH="$2"
EVIDENCE="false"
SKIP_BUILD="false"
for arg in "${@:3}"; do
  case "$arg" in
    --evidence) EVIDENCE="true" ;;
    --skip-build) SKIP_BUILD="true" ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "ERROR: not inside a git repository."
  exit 1
fi
cd "$REPO_ROOT"

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh not found. Install: brew install gh"
  exit 1
fi

# Require clean working tree
if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: working tree is not clean. Commit/stash first."
  git status -sb
  exit 1
fi

echo "==> Repo: $REPO_ROOT"
echo "==> PR: #$PR"
echo "==> Branch: $BRANCH"

# Ensure auth
echo "==> Checking gh auth..."
gh auth status >/dev/null 2>&1 || { echo "ERROR: gh not authenticated. Run: gh auth login"; exit 1; }

# Fetch latest
echo "==> Fetching origin..."
git fetch -p origin

# Ensure local branch exists tracking remote
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "==> Local branch exists: $BRANCH"
else
  if git ls-remote --heads origin "$BRANCH" | grep -q "$BRANCH"; then
    echo "==> Creating local branch from origin/$BRANCH"
    git switch -c "$BRANCH" "origin/$BRANCH" >/dev/null
  else
    echo "ERROR: remote branch origin/$BRANCH not found."
    exit 1
  fi
fi

# Checkout the branch for file scanning/build
echo "==> Switching to branch: $BRANCH"
git switch "$BRANCH" >/dev/null

# Unicode/Bidi scan for files changed in PR
echo "==> Scanning PR files for bidi/hidden unicode..."
PR_FILES="$(gh pr view "$PR" --json files --jq '.files[].path' 2>/dev/null || true)"
if [[ -z "$PR_FILES" ]]; then
  echo "WARN: Could not fetch PR file list. Skipping scan."
else
  python3 - <<PY
from pathlib import Path
import sys

files = """$PR_FILES""".splitlines()
bidi_ranges = list(range(0x202A,0x202F+1)) + list(range(0x2066,0x206A+1))
zero_width = {0x200B,0x200C,0x200D,0xFEFF}

bad_total = 0
for f in files:
    p = Path(f)
    if not p.exists():
        continue
    s = p.read_text(encoding="utf-8", errors="replace")
    bad = [ord(ch) for ch in s if ord(ch) in bidi_ranges or ord(ch) in zero_width]
    if bad:
        bad_total += len(bad)
        uniq = sorted({hex(x) for x in bad})
        print(f"FOUND hidden/bidi unicode in {f}: count={len(bad)} uniq={uniq}")
if bad_total:
    print("ERROR: Hidden/Bidi unicode found. Please remove these characters before merging.")
    sys.exit(1)
print("OK: no hidden/bidi unicode found in PR files.")
PY
fi

# Optional local build (kept short output)
if [[ "$SKIP_BUILD" == "false" ]]; then
  if [[ -x "scripts/build_ios.sh" ]]; then
    echo "==> Local build (short log)..."
    SCHEME_IOS=SampleMate bash scripts/build_ios.sh | tail -n 80
  else
    echo "WARN: scripts/build_ios.sh not found/executable. Skipping local build."
  fi
fi

# Wait for CI checks then merge
echo "==> Waiting for PR checks to complete..."
gh pr checks "$PR" --watch

echo "==> Merging PR #$PR (merge commit) and deleting remote branch..."
gh pr merge "$PR" --merge --delete-branch

# Sync main
echo "==> Syncing main..."
git switch main >/dev/null 2>&1 || git checkout main
git pull --ff-only

# Cleanup (local/remote branch, closeout, evidence)
echo "==> Running one-click cleanup..."
if [[ "$EVIDENCE" == "true" ]]; then
  scripts/one_click_cleanup.sh "$BRANCH" --evidence
else
  scripts/one_click_cleanup.sh "$BRANCH"
fi

echo "==> Done."
