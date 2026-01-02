#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 <branch-to-delete> [--evidence]"
  echo "Example: $0 work/pr1b-showcase-ui-polish --evidence"
}

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

BRANCH="$1"
EVIDENCE="false"
if [[ "${2:-}" == "--evidence" ]]; then
  EVIDENCE="true"
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "ERROR: not inside a git repository."
  exit 1
fi
cd "$REPO_ROOT"

if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  echo "ERROR: refusing to delete protected branch: $BRANCH"
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: working tree is not clean. Commit/stash first."
  git status -sb
  exit 1
fi

echo "==> Repo: $REPO_ROOT"
echo "==> Target branch to delete: $BRANCH"

echo "==> Switching to main..."
git switch main >/dev/null 2>&1 || git checkout main
echo "==> Pulling latest (ff-only)..."
git pull --ff-only

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "==> Deleting local branch: $BRANCH"
  git branch -d "$BRANCH" || {
    echo "ERROR: local branch '$BRANCH' not fully merged."
    exit 1
  }
else
  echo "==> Local branch not found, skip: $BRANCH"
fi

if git ls-remote --heads origin "$BRANCH" | grep -q "$BRANCH"; then
  echo "==> Deleting remote branch: origin/$BRANCH"
  git push origin --delete "$BRANCH"
else
  echo "==> Remote branch not found, skip: origin/$BRANCH"
fi

if [[ -x "scripts/closeout.sh" ]]; then
  echo "==> Running scripts/closeout.sh"
  bash scripts/closeout.sh
else
  echo "==> closeout.sh not found/executable, skip"
fi

if [[ "$EVIDENCE" == "true" ]]; then
  if [[ -x "scripts/evidence_pack.sh" ]]; then
    ts="$(date +%Y%m%d_%H%M%S)"
    out="artifacts/evidence_${ts}.txt"
    mkdir -p artifacts
    echo "==> Writing evidence pack to: $out"
    bash scripts/evidence_pack.sh | tee "$out" >/dev/null
    echo "==> Evidence saved."
  else
    echo "==> evidence_pack.sh not found/executable, skip"
  fi
fi

echo "==> Done."
git status -sb
