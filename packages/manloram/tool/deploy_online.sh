#!/usr/bin/env bash
# Builds ManLoram against the hosted Supabase project and publishes it to
# https://shayan-dnsh.github.io/manloram/ (the shayan-dnsh/manloram repo,
# which holds only the built game).
#
# Usage: SUPABASE_URL=https://<ref>.supabase.co SUPABASE_KEY=sb_publishable_... \
#          packages/manloram/tool/deploy_online.sh
# Push new migrations first with `supabase db push`.
set -euo pipefail

: "${SUPABASE_URL:?Set SUPABASE_URL to the hosted project URL}"
: "${SUPABASE_KEY:?Set SUPABASE_KEY to its publishable key}"
repo="${MANLORAM_REPO:-shayan-dnsh/manloram}"
package_dir="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

(cd "$package_dir" && flutter build web \
  --base-href "/${repo#*/}/" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_KEY="$SUPABASE_KEY" \
  -o "$work/site")
cp "$work/site/index.html" "$work/site/404.html"
touch "$work/site/.nojekyll"

git -c credential.helper= -c "credential.helper=!gh auth git-credential" \
  clone --quiet --depth 1 "https://github.com/$repo.git" "$work/repo"
rsync -a --delete --exclude .git --exclude README.md "$work/site/" "$work/repo/"
cd "$work/repo"
git add -A
if git diff --cached --quiet; then
  echo "Nothing changed; the live game is already up to date."
  exit 0
fi
git commit --quiet -m "Publish the ManLoram web build"
git -c credential.helper= -c "credential.helper=!gh auth git-credential" \
  push --quiet origin HEAD
echo "Published. Live in about a minute: https://${repo%%/*}.github.io/${repo#*/}/"
