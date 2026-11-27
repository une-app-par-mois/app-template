#!/usr/bin/env bash
# CI locale : les contrôles de ci.yml et security.yml lancés sur le poste, pour un projet
# qui a choisi « Lieu de la CI : local » (CLAUDE.md, « Mode de CI »), sans GitHub Actions.
# Ils tournent sur le commit HEAD exact, dans un worktree temporaire : les fichiers non
# commités ne comptent jamais. scripts/test.sh doit donc installer ses dépendances.
#
#   ./scripts/ci-local.sh                  lance les contrôles
#   ./scripts/ci-local.sh --publish        les lance, puis dépose le statut de commit « ci-local »
#   ./scripts/ci-local.sh --verify <sha>   code 0 seulement si le dernier statut « ci-local »
#                                          de <sha> est un succès (vérifié avant chaque fusion)
#
# Le statut est déposé par `gh api` (aucune minute de GitHub Actions). C'est une discipline,
# pas une preuve : quiconque détient le jeton gh peut en déposer un.
# Prérequis du poste : git, gh, jq, gitleaks, semgrep ; npm ou pip-audit selon la stack.
set -euo pipefail

CONTEXTE="ci-local"
usage() {
  echo "usage : $0 [--publish | --verify <sha de 40 caractères>]" >&2
  exit 2
}

publier=0
verifier_sha=""
while [ $# -gt 0 ]; do
  case "$1" in
    --publish) publier=1 ;;
    --verify)
      [ $# -ge 2 ] || usage
      verifier_sha=$2
      shift
      ;;
    *) usage ;;
  esac
  shift
done
[ -z "$verifier_sha" ] || [[ "$verifier_sha" =~ ^[0-9a-f]{40}$ ]] || usage
[ "$publier" = 0 ] || [ -z "$verifier_sha" ] || usage

racine=$(git rev-parse --show-toplevel)
# Toujours le dépôt de origin, jamais un autre remote (upstream d'un fork, par exemple).
url=$(git -C "$racine" remote get-url origin)
if [[ "$url" =~ ^(git@github\.com:|https://github\.com/)([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)$ ]]; then
  depot=${BASH_REMATCH[2]%.git}
else
  echo "❌ origin n'est pas un dépôt GitHub : $url" >&2
  exit 2
fi

if [ -n "$verifier_sha" ]; then
  etat=$(gh api "repos/$depot/commits/$verifier_sha/statuses" \
    --jq "[.[] | select(.context == \"$CONTEXTE\")][0].state // \"absent\"")
  echo "$CONTEXTE sur $verifier_sha : $etat"
  [ "$etat" = "success" ]
  exit
fi

sha=$(git -C "$racine" rev-parse HEAD)
if [ -n "$(git -C "$racine" status --porcelain)" ]; then
  echo "⚠️  Modifications non commitées : elles ne sont pas testées (seul HEAD l'est)." >&2
fi
if [ "$publier" = 1 ] && [ -z "$(git -C "$racine" branch -r --contains "$sha" --list 'origin/*')" ]; then
  echo "❌ $sha n'est pas poussé : un statut exige le commit sur GitHub." >&2
  exit 2
fi

dossier=$(mktemp -d)
nettoyer() { git -C "$racine" worktree remove --force "$dossier" 2>/dev/null || rm -rf "$dossier"; }
trap nettoyer EXIT
git -C "$racine" worktree add --quiet --detach "$dossier" "$sha"
cd "$dossier"

bilan=()
bloquants_en_echec=0
etape() { # etape <libellé> <commande...> : lance la commande, note le résultat
  local libelle=$1
  shift
  echo
  echo "▶ $libelle"
  if "$@"; then
    bilan+=("ok     $libelle")
  else
    bilan+=("ÉCHEC  $libelle")
    bloquants_en_echec=$((bloquants_en_echec + 1))
  fi
}

etape "Tests (scripts/test.sh)" ./scripts/test.sh
etape "Secrets dans tout l'historique (gitleaks)" gitleaks git --redact .
etape "Analyse statique (Semgrep)" semgrep scan --config p/default --config p/owasp-top-ten \
  --metrics=off --error
if [ -f package-lock.json ]; then
  etape "Dépendances Node (npm audit, niveau élevé)" npm audit --audit-level=high
fi
if [ -f requirements.txt ]; then
  etape "Dépendances Python (pip-audit)" pip-audit -r requirements.txt
fi
if [ ! -f package-lock.json ] && [ ! -f requirements.txt ]; then
  bilan+=("info   Ni package-lock.json ni requirements.txt : ajouter l'audit adapté à la stack")
fi

etat=success
description="tous les contrôles bloquants passent"
if [ "$bloquants_en_echec" -gt 0 ]; then
  etat=failure
  description="$bloquants_en_echec contrôle(s) bloquant(s) en échec"
fi

echo
echo "$CONTEXTE sur $sha"
printf '%s\n' "${bilan[@]}"
echo "Verdict : $etat"

if [ "$publier" = 1 ]; then
  gh api "repos/$depot/statuses/$sha" -f state="$etat" -f context="$CONTEXTE" \
    -f description="$description" >/dev/null
  echo "Statut « $CONTEXTE : $etat » déposé sur $sha."
fi
[ "$etat" = success ]
