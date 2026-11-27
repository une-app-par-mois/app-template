#!/usr/bin/env bash
# Release locale, pour un projet qui a choisi « Lieu de la release : local » (CLAUDE.md,
# « Mode de CI ») : build sur le poste, empreintes SHA-256, release GitHub par gh.
# Différence avec release.yml : pas d'attestation de provenance (elle n'existe que sur
# GitHub Actions) ; la vérification par l'utilisateur repose sur SHA256SUMS.txt seul.
#
#   ./scripts/release-local.sh vX.Y.Z
#
# Prérequis : le tag vX.Y.Z est poussé sur origin et pointe sur le dernier commit de main,
# et ce commit a un statut « ci-local » vert (./scripts/ci-local.sh --publish sur main).
# Publier est une action extérieure : lancé par le porteur, ou par l'IA avec son accord.
set -euo pipefail

tag=${1:-}
if ! [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage : $0 vX.Y.Z" >&2
  exit 2
fi

racine=$(git rev-parse --show-toplevel)
url=$(git -C "$racine" remote get-url origin)
if [[ "$url" =~ ^(git@github\.com:|ssh://git@github\.com/|https://([^@/]+@)?github\.com/)([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)/?$ ]]; then
  depot=${BASH_REMATCH[3]%.git} # toujours origin, jamais upstream (fork)
else
  echo "❌ origin n'est pas un dépôt GitHub : $url" >&2
  exit 2
fi
if [ -z "$(git -C "$racine" ls-remote --tags origin "refs/tags/$tag")" ]; then
  echo "❌ Le tag $tag n'est pas poussé sur origin." >&2
  exit 3
fi
git -C "$racine" fetch --quiet origin main "refs/tags/$tag:refs/tags/$tag"
sha=$(git -C "$racine" rev-parse "$tag^{commit}")
if [ "$sha" != "$(git -C "$racine" rev-parse origin/main)" ]; then
  echo "❌ $tag ne pointe pas sur le dernier commit de main." >&2
  exit 1
fi
"$racine/scripts/ci-local.sh" --verify "$sha"

dossier=$(mktemp -d)
nettoyer() { git -C "$racine" worktree remove --force "$dossier" 2>/dev/null || rm -rf "$dossier"; }
trap nettoyer EXIT
git -C "$racine" worktree add --quiet --detach "$dossier" "$sha"
cd "$dossier"

./scripts/build.sh
cd dist
mapfile -t fichiers < <(find . -maxdepth 1 -type f ! -name SHA256SUMS.txt -printf '%f\n' | sort)
if [ "${#fichiers[@]}" -eq 0 ]; then
  echo "❌ dist/ ne contient aucun fichier à publier (les sous-dossiers sont ignorés)." >&2
  exit 1
fi
sha256sum -- "${fichiers[@]}" >SHA256SUMS.txt
cat SHA256SUMS.txt
gh release create "$tag" -R "$depot" --title "$tag" --generate-notes --verify-tag \
  -- "${fichiers[@]}" SHA256SUMS.txt
