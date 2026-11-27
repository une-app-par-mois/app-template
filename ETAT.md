# État du projet

Mis à jour à la fin de chaque ticket. **100 lignes au plus** : on remplace, on n'empile pas ; l'historique vit dans les PR et `PROMPTS.md`.

Dernière mise à jour : [AAAA-MM-JJ]

## En cours

[Jalon et branche de groupe ; ticket en cours et son état, ou « aucun ».]

## Prochaines étapes

Mise en route d'une nouvelle app (à retirer une fois faites) :

1. Supprimer `.github/workflows/modele.yml` et `scripts/tests-modele.sh` (tests du modèle seulement).
2. Remplir `docs/CADRAGE.md` (fonctionnalités, glossaire, données, zones sensibles, mode et lieu de la CI, lieu de la release), puis le faire valider ; reporter ces choix dans `CLAUDE.md`. CI locale : supprimer `ci.yml` et `security.yml` ; release locale : supprimer `release.yml`.
3. Charte et maquettes dans `design/`, validées avant le code.
4. Compléter `CLAUDE.md` (contexte, commandes), `scripts/test.sh`, `scripts/build.sh`, la mise en place de la stack dans les workflows et `.github/dependabot.yml`.
5. Activer les hooks : `./scripts/setup-hooks.sh` (gitleaks requis sur le poste).
6. Protéger `main` dans les réglages GitHub : PR obligatoire, travaux de la CI obligatoires (CI locale : statut `ci-local`, si l'offre GitHub le permet pour un dépôt privé).
7. Écrire les premiers tickets dans `docs/tickets/`.

## Points d'attention

- [Pièges rencontrés, décisions en attente du porteur.]

## Non vérifié

- [Ce qui n'a pas pu être vérifié et comment le faire.]
