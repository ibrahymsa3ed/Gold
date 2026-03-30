#!/usr/bin/env bash
set -euo pipefail

# Usage (single monorepo push):
#   GITHUB_REPO=git@github.com:ibrahymsa3ed/Gold.git ./scripts/deploy.sh "feat: update"
# or
#   GITHUB_REPO=https://<TOKEN>@github.com/ibrahymsa3ed/Gold.git ./scripts/deploy.sh "feat: update"

COMMIT_MSG="${1:-chore: update project}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_URL="${GITHUB_REPO:-}"
STRIP_NESTED_GIT="${STRIP_NESTED_GIT:-0}"

push_repo() {
  local dir="$1"
  local remote_url="$2"

  cd "${dir}"
  if [[ ! -d .git ]]; then
    git init
    git branch -M main
  fi
  if ! git remote get-url origin >/dev/null 2>&1; then
    git remote add origin "${remote_url}"
  fi

  git add .
  if git diff --cached --quiet; then
    echo "No changes in ${dir}, skipping commit."
    return
  fi

  git commit -m "${COMMIT_MSG}"
  git push -u origin main
}

if [[ -z "${REPO_URL}" ]]; then
  echo "ERROR: GITHUB_REPO is required."
  exit 1
fi

for nested in "scraper-service/.git" "main-backend/.git" "flutter-app/.git"; do
  if [[ -d "${ROOT_DIR}/${nested}" ]]; then
    if [[ "${STRIP_NESTED_GIT}" != "1" ]]; then
      echo "ERROR: nested git repo detected at ${nested}."
      echo "Set STRIP_NESTED_GIT=1 to remove nested .git directories for monorepo push."
      exit 1
    fi
    rm -rf "${ROOT_DIR}/${nested}"
    echo "Removed ${nested} for monorepo deployment."
  fi
done

push_repo "${ROOT_DIR}" "${REPO_URL}"
echo "Monorepo push completed."
