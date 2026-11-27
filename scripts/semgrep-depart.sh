#!/usr/bin/env bash
# Commit de départ de Semgrep, lu dans .semgrep-baseline (code hérité avec beaucoup d'alertes :
# seules les alertes nouvelles depuis ce commit bloquent). Utilisé par ci-local.sh et security.yml.
# Affiche le sha s'il est valide, rien s'il n'y a pas de fichier ; sinon code 1 et la raison.
# Modifier .semgrep-baseline affaiblit un contrôle : relecture du porteur (CLAUDE.md).
set -euo pipefail

[ -f .semgrep-baseline ] || exit 0
depart=$(tr -d '[:space:]' <.semgrep-baseline)
if ! [[ "$depart" =~ ^[0-9a-f]{40}$ ]]; then
  echo "❌ .semgrep-baseline doit contenir un sha complet (40 caractères)." >&2
  exit 1
fi
if [ "$depart" = "$(git rev-parse HEAD)" ]; then
  echo "❌ .semgrep-baseline désigne HEAD lui-même : aucune alerte ne bloquerait." >&2
  exit 1
fi
if ! git merge-base --is-ancestor "$depart" HEAD 2>/dev/null; then
  echo "❌ .semgrep-baseline n'est pas un ancêtre de HEAD (après un --squash : le commit de fusion)." >&2
  exit 1
fi
echo "$depart"
