#!/usr/bin/env bash
# Scripts d'installation npm : aucun ne tourne (.npmrc ignore-scripts=true). Un paquet piégé
# s'exécute à l'installation, avant tout contrôle ; un paquet honnête peut y envoyer une
# télémétrie (leçon de pixel-atelier : @scarf/scarf à chaque npm ci).
# Échoue si :
# - .npmrc ne fixe pas ignore-scripts=true (dernière valeur, comme npm), ou si npm, qui fait
#   passer l'environnement (npm_config_ignore_scripts) avant .npmrc, ne le voit pas à true ;
# - package.json déclare prepare, pre* ou post* : ignore-scripts les saute sans prévenir,
#   les renommer et les lancer explicitement (les hooks : ./scripts/setup-hooks.sh) ;
# - package.json a des dépendances sans package-lock.json (version 2 ou plus) ;
# - un paquet à script d'installation (nom@version) n'est pas dans
#   scripts/scripts-installation-revus.txt. Revoir un paquet : vérifier qu'il marche sans
#   son script, puis l'ajouter à la liste avec la raison.
# Sans package.json : rien à vérifier. Utilisé par ci-local.sh et security.yml.
set -euo pipefail

[ -f package.json ] || exit 0
echec=0
probleme() { echo "❌ $1" >&2; echec=1; }

valeur=$(grep -E '^[[:space:]]*ignore-scripts[[:space:]]*=' .npmrc 2>/dev/null | tail -1 |
  sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*$//' || true)
[ "$valeur" = "true" ] || probleme ".npmrc doit fixer ignore-scripts=true."
if command -v npm >/dev/null 2>&1 && [ "$(npm config get ignore-scripts 2>/dev/null)" != "true" ]; then
  probleme "npm ne voit pas ignore-scripts=true (variable npm_config_ignore_scripts ?)."
fi

cycle=$(jq -r '.scripts // {} | keys[] | select(test("^(pre|post)") or . == "prepare" or . == "install")' package.json)
[ -z "$cycle" ] || probleme "scripts de cycle de vie sautés par ignore-scripts : $(echo $cycle) (les renommer)."

if [ "$(jq '(.dependencies // {}) + (.devDependencies // {}) + (.optionalDependencies // {}) | length' package.json)" = 0 ]; then
  exit "$echec"
fi
if ! jq -e '.packages | type == "object"' package-lock.json >/dev/null 2>&1; then
  probleme "package-lock.json absent ou sans « packages » (lockfileVersion 2 ou plus)."
  exit 1
fi
revus=scripts/scripts-installation-revus.txt
while IFS= read -r paquet; do
  # Comparaison littérale du premier champ (une version peut contenir « + »).
  if ! awk -v p="$paquet" '$1 == p { trouve = 1 } END { exit !trouve }' "$revus" 2>/dev/null; then
    probleme "$paquet a un script d'installation non revu ($revus)."
  fi
done < <(jq -r '.packages | to_entries[]
  | select(.value.hasInstallScript == true and (.value.link // false) == false)
  | ((.value.name // (.key | split("node_modules/") | last | if . == "" then "(racine)" else . end))
     + "@" + (.value.version // "sans-version"))' package-lock.json | sort -u)
exit "$echec"
