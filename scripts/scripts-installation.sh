#!/usr/bin/env bash
# Scripts d'installation npm : aucun ne tourne (.npmrc ignore-scripts=true). Un paquet piégé
# s'exécute à l'installation, avant tout contrôle ; un paquet honnête peut y envoyer une
# télémétrie (leçon de pixel-atelier : @scarf/scarf à chaque npm ci).
# Échoue si .npmrc ne fixe pas ignore-scripts=true (dernière valeur, comme npm), si
# package-lock.json manque ou est trop ancien, ou si un paquet à script d'installation
# (nom@version) n'est pas dans scripts/scripts-installation-revus.txt. Revoir un paquet :
# vérifier qu'il marche sans son script, puis l'ajouter à la liste avec la raison.
# Sans package.json : rien à vérifier. Utilisé par ci-local.sh et security.yml.
set -euo pipefail

[ -f package.json ] || exit 0
echec=0
valeur=$(grep -E '^[[:space:]]*ignore-scripts[[:space:]]*=' .npmrc 2>/dev/null | tail -1 |
  sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*$//' || true)
if [ "$valeur" != "true" ]; then
  echo "❌ .npmrc doit fixer ignore-scripts=true." >&2
  echec=1
fi
if ! jq -e '.packages | type == "object"' package-lock.json >/dev/null 2>&1; then
  echo "❌ package-lock.json absent ou sans « packages » (lockfileVersion 2 ou plus)." >&2
  exit 1
fi
revus=scripts/scripts-installation-revus.txt
while IFS= read -r paquet; do
  if ! grep -qE "^${paquet//./\\.}([[:space:]]|$)" "$revus" 2>/dev/null; then
    echo "❌ $paquet a un script d'installation non revu ($revus)." >&2
    echec=1
  fi
done < <(jq -r '.packages | to_entries[] | select(.value.hasInstallScript == true)
  | ((.key | split("node_modules/") | last | if . == "" then "(racine)" else . end)
     + "@" + (.value.version // "?"))' package-lock.json | sort -u)
exit "$echec"
