# docker_symfony

## Description

Environnement Docker pour créer et exécuter un projet Symfony avec FrankenPHP et
PHP sous Windows. Compose Watch synchronise les sources vers Linux, tandis que
les dépendances et le cache restent côté Linux pour éviter les E/S lentes entre
Windows et Docker. Les extensions SQLite, PostgreSQL et MongoDB sont incluses,
sans services de base de données supplémentaires.

> [!WARNING]
> **Cet environnement est réservé au développement local. Ne l'utilisez pas tel quel en production.**
> Le mode debug, l'affichage des erreurs PHP, les dépendances de développement et
> Compose Watch sont activés. Un déploiement en production nécessite une configuration
> dédiée, notamment pour la sécurité, les secrets, HTTPS et les dépendances installées.

## Prérequis

Docker Desktop démarré en mode conteneurs Linux, avec le moteur WSL2,
et Docker Compose 2.32 ou plus récent (la version locale 5.6.1 convient).
Aucun PHP ni Composer n'est nécessaire sur Windows.
Une connexion Internet est nécessaire à la création du projet pour consulter les
versions officielles et télécharger les images et dépendances.

## Récupérer le projet et préparer Git

### Commencer un nouveau projet Symfony

**Téléchargez l'archive ZIP de ce dépôt, ne le clonez pas.** Extrayez-la dans le
dossier de votre nouveau projet. Vous disposez ainsi du squelette Docker sans
reprendre l'historique Git du dépôt d'origine.

Depuis ce dossier, créez votre propre dépôt Git :

```powershell
git init
git branch -M main
```

Effectuez ensuite l'installation décrite dans la section suivante. Avant le premier
commit, adaptez le `.gitignore` à votre application :

- Retirez les règles `/app/*` et `!/app/.gitkeep` afin de versionner le code Symfony.
  Le fichier `app/.gitignore` généré par Symfony continuera d'exclure ses dépendances,
  son cache et ses secrets locaux.
- Retirez la règle `/compose.override.yaml` afin de conserver les versions choisies
  pour votre application et de pouvoir reconstruire son environnement.
- Conservez les exclusions des fichiers `.env` locaux et de votre IDE. Vérifiez
  qu'aucun secret ni fichier généré indésirable n'est ajouté au commit.

Une fois l'application créée et les exclusions adaptées :

```powershell
git add .
git diff --cached --stat
git diff --cached
git commit -m "chore: initialize Symfony project"
```

Créez également un dépôt distant vide sur votre hébergeur Git, puis associez-le
à votre dépôt local et publiez votre branche :

```powershell
# Remplacez cette valeur par l'URL de votre propre dépôt.
git remote add origin "URL_DE_VOTRE_DEPOT"
git push -u origin main
```

## Installation

Ouvrez PowerShell dans le dossier extrait contenant `dev.ps1` et `compose.yaml`
(depuis l'Explorateur Windows, ouvrez un terminal dans ce dossier), puis exécutez :

```powershell
# Facultatif : si vous souhaitez personnaliser les versions, le nom ou le port,
# copiez le modèle une seule fois et modifiez .env avant de lancer init.
# Ne remplacez pas un fichier .env existant.
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
.\dev.ps1 init
.\dev.ps1 start
```

Ouvrez http://localhost:8000. Laissez le terminal ouvert : il exécute Compose Watch.
`init` crée une application Symfony web complète dans `app/`. Pour une base minimale :
`.\dev.ps1 init skeleton`. L'initialisation refuse un dossier `app/` déjà rempli.
Elle télécharge les dépendances dans Linux et n'exporte vers Windows que les sources.
Si PowerShell bloque les scripts, utilisez ponctuellement
`powershell -ExecutionPolicy Bypass -File .\dev.ps1 init` (et pareil pour `start`).

Une installation interrompue peut laisser un projet dans `app/` : inspectez-le avant
de relancer `init`. Si `composer.lock` existe, essayez directement `start`.

## Commandes Symfony

Exécutez les commandes ci-dessous depuis le dossier de votre projet. Gardez
`.\dev.ps1 start` actif dans un premier terminal et utilisez un deuxième terminal
PowerShell pour les commandes Symfony. Le préfixe `.\dev.ps1 console` remplace
`php bin/console` et lance le service CLI temporaire `tools`.

### Maker : génération de code

```powershell
.\dev.ps1 console make:controller
.\dev.ps1 console make:controller HomeController
.\dev.ps1 console make:entity
.\dev.ps1 console make:form
.\dev.ps1 console make:migration
```

Ces commandes nécessitent MakerBundle, inclus dans l'installation `webapp`.
Les commandes d'entités et de migrations nécessitent également Doctrine et une
connexion à la base configurée.

Le service ponctuel `tools` monte les sources Windows pour que les fichiers créés
par Maker et les migrations reviennent dans votre éditeur. Ses dépendances sont
copiées depuis l'image dans un volume anonyme Linux, supprimé après la commande ;
son cache reste en mémoire Linux. Les commandes CLI peuvent donc être moins rapides
que le serveur HTTP, sans affecter les requêtes web. La base SQLite est partagée.

**N'utilisez pas `docker compose exec` pour générer
du code ou modifier les dépendances** : Watch est à sens unique, Windows vers Linux,
et les fichiers créés ainsi dans le serveur ne reviennent pas dans votre éditeur.

### Doctrine : migrations de base de données

```powershell
.\dev.ps1 console doctrine:migrations:status
.\dev.ps1 console doctrine:migrations:migrate
```

`status` affiche l'état des migrations ; `migrate` applique les migrations en attente
à la base configurée. Pour générer une migration, utilisez `make:migration` dans
la section Maker ci-dessus.

### Diagnostic et aide Symfony

```powershell
.\dev.ps1 console about
.\dev.ps1 console debug:router
.\dev.ps1 console debug:container
.\dev.ps1 console list
.\dev.ps1 console help make:entity
.\dev.ps1 check
```

`list` affiche les commandes disponibles dans votre projet et `help` détaille une
commande. `check` vérifie l'environnement du serveur web, notamment les extensions PHP.
Pour examiner directement le conteneur web démarré, les commandes de lecture peuvent
aussi s'exécuter avec `docker compose exec php php bin/console about`.

### Cache du serveur web : celui utilisé par vos pages

Exécutez ces commandes dans le service `php` déjà démarré :

```powershell
docker compose exec php php bin/console cache:clear
docker compose exec php php bin/console cache:warmup
```

`cache:clear` vide le cache Symfony du serveur et effectue normalement son
préchauffage. `cache:warmup` permet de demander explicitement ce préchauffage.
Ce cache est stocké dans le tmpfs Linux `/app/var/cache` du serveur web ; il n'est
jamais synchronisé vers Windows.

### Cache du conteneur CLI : temporaire et indépendant

```powershell
.\dev.ps1 console cache:clear
.\dev.ps1 console cache:warmup
```

**Ces commandes ne modifient pas le cache du serveur web.** Chaque appel à
`.\dev.ps1 console` crée un nouveau conteneur `tools`, avec son propre tmpfs
`/app/var/cache`, puis le supprime à la fin de la commande. Vider ou préchauffer ce
cache n'a donc pas d'effet durable, même pour la commande CLI suivante.
Pour résoudre un problème de cache sur vos pages, utilisez la section serveur web.

### Composer : gestion des dépendances

Pour ajouter une dépendance, arrêtez d'abord Watch avec Ctrl+C pour éviter une
reconstruction pendant que Composer modifie ses fichiers, puis :

```powershell
.\dev.ps1 composer require mongodb/mongodb
.\dev.ps1 start
```

Le script reconstruit l'image après Composer. Les changements des manifestes faits
directement dans l'éditeur sont également suivis par les règles `rebuild` de Watch.
Pour l'autocomplétion de l'IDE, vous pouvez exporter ponctuellement les dépendances :
`docker compose cp php:/app/vendor ./app/vendor`. Cette copie est ignorée par
Docker et Watch ; réexportez-la après une modification des dépendances si nécessaire.

## Commandes conteneurs

```powershell
.\dev.ps1 start
.\dev.ps1 logs
.\dev.ps1 stop
```

`start` exécute `docker compose up --build --watch`. Vous pouvez aussi utiliser
cette commande directement : conservez `--watch` pour synchroniser les sources.
`logs` suit les journaux du serveur ; `stop` arrête les services sans supprimer les données.

## Informations techniques complémentaires

### Plusieurs projets sur la même machine

Docker Compose utilise par défaut le nom du dossier comme nom de projet. Les
conteneurs, réseaux, volumes et images de cette configuration sont propres à ce
nom ; l'image d'initialisation utilise également ce préfixe.

Donnez à chaque projet un nom de dossier distinct, par exemple `cours-blog` et
`cours-boutique`. Si deux dossiers portent le même nom, même dans des emplacements
différents, définissez un `COMPOSE_PROJECT_NAME` différent dans chacun de leurs
fichiers `.env` **avant l'initialisation**.

Pour exécuter plusieurs projets simultanément, leurs ports HTTP doivent aussi
être différents. Copiez `.env.example` vers `.env` et adaptez, par exemple :

```dotenv
COMPOSE_PROJECT_NAME=cours-boutique
HTTP_PORT=8001
```

Ce projet sera accessible sur `http://localhost:8001`, tandis qu'un autre peut
rester sur le port 8000. Utilisez des noms Compose en minuscules, avec des chiffres,
des tirets ou des underscores, commençant par une lettre ou un chiffre.
Conservez le nom choisi : le modifier après l'installation désigne un autre
ensemble de conteneurs, d'images et de volumes, sans déplacer les anciennes données.

### Versions

Avant `./dev.ps1 init`, vous pouvez choisir les versions dans le fichier `.env`
à la racine du projet. `.env.example` est un modèle : il n'est pas lu automatiquement.
Sans `.env`, les versions utilisent toutes le comportement `stable` par défaut.

```dotenv
PHP_VERSION=stable
FRANKENPHP_VERSION=stable
SYMFONY_VERSION=stable
COMPOSER_VERSION=stable
```

Chaque variable accepte **`stable` ou une version exacte `X.Y.Z`**. Vous pouvez
mélanger les deux modes, par exemple :

```dotenv
PHP_VERSION=8.5.12
FRANKENPHP_VERSION=stable
SYMFONY_VERSION=7.4.23
COMPOSER_VERSION=stable
```

**Il est recommandé de laisser `FRANKENPHP_VERSION=stable`** et de choisir
principalement les versions de PHP et Symfony selon les besoins du projet ou du
cours. Fixer une version exacte de FrankenPHP reste utile pour reproduire un
environnement précis, analyser une régression ou utiliser une combinaison particulière
disponible. Le choix `stable` est résolu à l'initialisation, pas à chaque démarrage.

La dernière version stable de FrankenPHP n'est toutefois **pas une garantie de
compatibilité avec toutes les anciennes versions de PHP et Symfony** :

- **FrankenPHP et PHP** : une image officielle doit exister pour les versions exactes
  sélectionnées et la variante Debian Trixie utilisée ici. Toutes les anciennes
  branches PHP et tous leurs correctifs ne sont pas nécessairement disponibles
  avec la dernière release de FrankenPHP. Consultez les
  [images et tags officiels](https://frankenphp.dev/docs/docker/).
- **Symfony et PHP** : la version de Symfony, ses dépendances et les extensions
  doivent être compatibles avec le PHP choisi. Composer vérifie les contraintes
  déclarées ; les tests de votre application restent nécessaires pour valider son
  fonctionnement réel.
- **Mode d'exécution** : ce squelette utilise le mode classique de FrankenPHP.
  Il n'impose pas les exigences supplémentaires de l'intégration en mode worker.
  Si vous activez ce mode ultérieurement, vérifiez les conditions propres à votre
  version de Symfony dans la [documentation d'intégration](https://frankenphp.dev/docs/symfony/).

Le script ne recherche pas automatiquement une ancienne version de FrankenPHP
pour compenser une image manquante : l'installation s'arrête explicitement.

Une variable absente vaut `stable`. Une valeur vide, `latest`, `8.5`, `8.5.*`,
`^8.5.0`, un préfixe `v` ou une préversion est refusée avant le build.
Les valeurs sont lues par Docker Compose, qui gère les guillemets et les commentaires
du `.env`. Une variable définie dans votre terminal est prioritaire sur le `.env`.

Pour chaque valeur `stable`, le script consulte la source officielle correspondante :

- la dernière version stable de PHP publiée sur php.net ;
- la dernière release stable de FrankenPHP publiée sur GitHub ;
- la dernière version stable de Symfony annoncée par symfony.com ;
- la dernière version stable de Composer publiée sur getcomposer.org.

Les versions alpha, bêta et RC sont exclues. Le script construit un tag FrankenPHP
avec les versions exactes de FrankenPHP et PHP, sur Debian Trixie, et sélectionne
le binaire Composer officiel avec sa version exacte et sa somme SHA-256. Une version
explicite est conservée sans interroger l'API des dernières releases pour ce composant.
L'installation vérifie les versions
réelles de PHP, FrankenPHP, Composer et du framework Symfony avant de valider le projet.

Si une API nécessaire est inaccessible, si son format change, si une version
demandée n'existe pas ou si l'image combinant PHP et FrankenPHP n'est pas disponible,
`init` échoue : il ne revient pas
silencieusement à une ancienne version compatible. Vous pouvez réessayer une fois
les services accessibles et les images publiées. La sélection correspond aux
versions annoncées au moment de la consultation, pas aux éventuelles publications
survenues pendant le téléchargement ou la compilation. Les combinaisons doivent
être compatibles : Composer vérifie les exigences PHP de Symfony et de ses
dépendances. Une version ancienne peut également être refusée par les contrôles
de sécurité de Composer ; ces contrôles ne sont pas désactivés.

`SYMFONY_VERSION` fixe précisément `symfony/framework-bundle` dans `composer.json`
avant l'installation, même pour un ancien correctif. Les autres composants sont
résolus dans la branche majeure/mineure correspondante avec des versions compatibles :
ils n'ont pas tous nécessairement le même numéro de correctif. `composer.lock`
conserve leurs versions exactes. Le squelette utilisé correspond à cette branche.

Le build initial utilise `--pull --no-cache` pour actualiser les images, les paquets
APT et les extensions. Les extensions livrées avec PHP suivent sa version ; MongoDB
utilise le canal PECL stable. Les paquets système suivent les dépôts Debian Trixie.
Caddy et les autres composants intégrés suivent l'image officielle FrankenPHP :
leurs versions ne sont pas mises à jour indépendamment. Docker Desktop et Compose
restent des prérequis à mettre à jour sur votre machine.

Les versions sélectionnées sont enregistrées localement dans `compose.override.yaml`,
chargé automatiquement par Docker Compose. Ce fichier est ignoré par Git dans le
squelette ; conservez-le avec un projet existant pour pouvoir le reconstruire.
N'utilisez pas ce nom pour une configuration personnelle : `init` refuse de remplacer
un fichier qu'il n'a pas généré. Ne supprimez pas ce fichier tant que vous utilisez
l'application associée.

Les démarrages suivants ne recherchent pas de nouvelles versions et ne modifient
pas `composer.lock`. Un projet existant ne change donc pas automatiquement de
version majeure. Modifier les variables de version dans `.env` après `init` ne
met pas à niveau l'application ni son image. Chaque nouveau projet applique les
choix de son `.env` et résout les dernières versions pour les valeurs `stable`.
Aucun service de base de données n'est créé.

### Bases de données et extensions

SQLite fonctionne immédiatement via `pdo_sqlite` et `sqlite3`. Par défaut,
`DATABASE_URL=sqlite:////app/var/data/app.db`. Le volume `app_data` conserve le fichier
quand vous arrêtez ou reconstruisez le service.

PostgreSQL : extensions `pdo_pgsql` et `pgsql`. MongoDB : extension `mongodb`
stable, sans ODM ni bibliothèque PHP MongoDB ajoutés automatiquement.
Extensions usuelles ajoutées : `intl`, `mbstring`, `zip`, `bcmath`, `gd`,
DOM/XML et cURL. OPcache est intégré à PHP 8.5.

Pour personnaliser le port ou DATABASE_URL, copiez `.env.example` vers `.env`
à la racine de votre projet, à côté de `compose.yaml`, puis relancez `start`. Ce `.env` configure Compose ;
`app/.env` et `app/.env.local` configurent Symfony. Le `DATABASE_URL` défini par
Compose est prioritaire sur les fichiers dotenv Symfony.

Pour un futur PostgreSQL dont le port est publié sur Windows : utilisez
`host.docker.internal` comme hôte. Pour des services sur un réseau Docker partagé,
on ajoutera ce réseau et leurs noms DNS lors de leur création. Le dossier PostgreSQL
existant n'a pas été modifié.

`stop` conserve les données. **`docker compose down -v` supprime les volumes,
donc notamment la base SQLite et les logs.**

### Vérification et mises à jour

```powershell
docker compose config --quiet
.\tests\versions.Tests.ps1
.\dev.ps1 check
```

`check` vérifie les versions, les exigences Composer et les extensions de bases.
Le script `tests/versions.Tests.ps1` vérifie sans réseau les valeurs par défaut,
les versions exactes sans appel aux API, les choix mixtes, le filtrage des variables,
le passage à de futures versions majeures et le rejet des valeurs invalides,
des préversions ou d'une résolution impossible.
Testez également une modification de contrôleur ou de template avec Watch actif :
elle doit apparaître après synchronisation, sans copie de `var/cache` vers Windows.

Pour une nouvelle application, utilisez `./dev.ps1 init` avec un dossier `app/`
vide : les préférences du `.env` seront appliquées. Pour un projet existant,
les mises à niveau restent une opération explicite à préparer et à tester ;
`start` reconstruit avec les versions sélectionnées et installe `composer.lock`.
Conservez `composer.lock`, `symfony.lock` et `compose.override.yaml` avec ce projet.
Un build Docker direct doit recevoir les arguments `FRANKENPHP_IMAGE` et
`COMPOSER_VERSION` ; le chemin pris en charge est `init`, puis `start` ou Compose,
qui charge le fichier de versions généré.

La configuration est destinée au développement local, avec HTTP lié uniquement
à `127.0.0.1`, le profiler et les erreurs de développement. Ce n'est pas une
configuration de production.

Validation effectuée le 10 novembre 2026, depuis une archive du squelette extraite
dans deux dossiers vierges, avec Windows PowerShell et Docker Desktop :

- Création de deux applications complètes avec `dev.ps1 init` et lancement simultané
  avec `dev.ps1 start`, sur deux ports distincts.
- Génération de contrôleurs avec Maker et retour des fichiers dans les dossiers Windows.
- Réponses HTTP 200 et synchronisation des modifications PHP et Twig, sans recréation
  du conteneur et sans modification de l'autre application.
- Vérification des versions et extensions avec `dev.ps1 check`.
- Bases SQLite distinctes, conservation des données à l'arrêt et cache CLI indépendant
  du cache web ; aucun fichier de cache Symfony synchronisé vers Windows.
- Arrêt d'un projet sans interrompre l'autre ; noms d'images, réseaux et volumes distincts.

Les tests hors ligne du résolveur et la validation Compose passent également.
Les préférences de version ont aussi été vérifiées : lecture du `.env` (guillemets,
commentaires et priorité des variables du terminal), installation complète de
Symfony 7.4.23 demandé explicitement, installation de la stable résolue 8.1.11,
rejet d'une version inexistante et conservation du projet 7.4.23 après passage
des préférences à `stable`. Le test PHP `tests/prepare-symfony.Tests.php` couvre
la conservation des objets JSON vides et le verrouillage exact du framework.
Ces contrôles valident le fonctionnement observé sur cette machine ; ils ne constituent
pas un benchmark ni une garantie sur toutes les configurations des postes étudiants.

Références officielles :

- https://symfony.com/releases
- https://symfony.com/releases.json
- https://www.php.net/downloads.php
- https://www.php.net/releases/index.php?json
- https://getcomposer.org/versions
- https://github.com/php/frankenphp/releases/latest
- https://frankenphp.dev/docs/docker/
- https://docs.docker.com/compose/how-tos/file-watch/

### Pourquoi cela évite les E/S lentes Windows/Linux

Le service HTTP **ne monte aucun dossier Windows**. L'image contient les sources
et `vendor/`, et Watch copie uniquement les fichiers sources modifiés vers `/app`.
`vendor/`, `var/`, `.git/` et `node_modules/` sont exclus de la synchronisation.

- `var/cache` est en mémoire Linux (tmpfs), perdu à la recréation du conteneur.
- `var/log` et `var/data` sont des volumes Docker Linux persistants.
- `vendor` est dans l'image : une modification des fichiers Composer reconstruit
  l'image et remplace les dépendances, sans conserver un ancien volume vendor.
- OPcache vérifie les modifications à chaque requête ; aucun redémarrage PHP
  n'est nécessaire pour une modification PHP ordinaire.
- FrankenPHP utilise le mode classique en développement ; Xdebug n'est pas installé.

Le premier chargement après recréation reste plus lent : Symfony reconstruit son
cache. Watch a également un court délai de copie après une sauvegarde. Cette
architecture retire les accès réseau au système de fichiers Windows du chemin
des requêtes ; elle ne garantit pas un temps de réponse pour du code applicatif
ou des requêtes de base de données encore inconnus.

Ne remplacez pas cette configuration par `./app:/app` dans le service `php` : ce
serait réintroduire le problème. WSL2 reste une alternative si le projet entier
réside dans `/home/...`, mais n'est pas nécessaire pour cette organisation.

## Auteur

[Nicolas Vauché](https://nicolasvauche.fr)

## Contribution

Vous pouvez proposer une correction, une amélioration ou signaler un problème
via les issues et les pull requests du dépôt.

### Contribuer au squelette Docker

Pour contribuer à ce projet, **créez un fork, puis clonez votre fork**. Travaillez
sur une branche dédiée et ouvrez une pull request vers le dépôt d'origine.
Conservez les exclusions de `app/` et de `compose.override.yaml` : les applications
créées pour tester le squelette ne doivent pas faire partie de votre contribution.

Vos commits doivent respecter [Conventional Commits](https://www.conventionalcommits.org/fr/v1.0.0/).
Les règles et exemples sont détaillés ci-dessous dans [Format des commits](#format-des-commits).

Pour proposer une modification :

1. Décrivez le problème ou le comportement attendu et les étapes pour le reproduire.
2. Créez un fork du dépôt, clonez votre fork et préparez une branche avec des modifications ciblées. Mettez à jour la documentation concernée.
3. Vérifiez la configuration avec `docker compose config --quiet`, puis testez le démarrage et les commandes concernées avec Docker Desktop.
4. Si la modification touche les volumes ou Watch, vérifiez la synchronisation des sources et l'absence de synchronisation de `var/` et `vendor/`.
5. Créez des commits au format Conventional Commits, puis poussez votre branche vers votre fork.
6. Ouvrez une pull request vers le dépôt d'origine en précisant les changements, les vérifications effectuées et les éventuelles limites.

### Publication automatique des releases

Le workflow `.github/workflows/release.yml` publie automatiquement une release
GitHub lorsque vous poussez un tag stable au format `vMAJEUR.MINEUR.CORRECTIF`,
par exemple `v1.0.2`. Le titre reprend le tag et GitHub génère les notes de release.
Les tags de préversion comme `v1.1.0-rc.1` sont ignorés.

Commitez et poussez d'abord le workflow et les modifications à publier. Le commit
visé par le tag doit contenir le workflow. Depuis votre branche de publication :

```powershell
git status
git push origin main
git tag -a v1.0.2 -m "Release v1.0.2"
git push origin v1.0.2
```

Adaptez le numéro à chaque nouvelle version. Suivez l'exécution dans l'onglet
**Actions**, puis retrouvez la publication dans **Releases**. Aucun jeton personnel
n'est nécessaire : le workflow utilise `GITHUB_TOKEN` avec la permission
`contents: write`. GitHub Actions doit être autorisé sur le dépôt.

Une release déjà existante, même à l'état de brouillon, est laissée intacte lors
d'une nouvelle exécution. Le workflow ne crée pas les tags et ne calcule pas le
prochain numéro de version. Il ne publie pas rétroactivement les tags déjà poussés.

Les notes générées par GitHub reposent notamment sur les pull requests fusionnées
et les contributeurs ; ce n'est pas un changelog calculé à partir des types
Conventional Commits. Vous pouvez compléter les notes après publication.
Les archives ZIP et tar.gz du code sont fournies automatiquement par GitHub.

### Format des commits

Respectez la spécification [Conventional Commits 1.0.0](https://www.conventionalcommits.org/fr/v1.0.0/) :

```text
type(scope optionnel): description
```

Utilisez `feat` pour une fonctionnalité, `fix` pour une correction et, selon la
nature du changement, `docs`, `test`, `refactor`, `build`, `ci` ou `chore`.
Le scope est facultatif ; lorsqu'il est présent, il précise la partie concernée.

```text
feat(docker): ajouter une extension PHP
fix(watch): corriger la synchronisation des sources
docs: préciser les commandes de cache
test: vérifier le rejet des préversions
```

Signalez une rupture de compatibilité avec `!` avant les deux-points ou un pied
de message `BREAKING CHANGE:`, et expliquez les adaptations nécessaires :

```text
feat(config)!: modifier le format du fichier de versions

BREAKING CHANGE: régénérez le fichier de versions avant de reconstruire l'image.
```

Conservez le vouvoiement dans la documentation et les messages destinés à l'utilisateur.
Les contributions à ce dépôt sont proposées sous la même licence GPLv3.

## Licence

Copyright © 2026 Nicolas Vauché.

Ce dépôt est distribué sous la **GNU General Public License version 3 uniquement**
(`GPL-3.0-only`). Consultez le texte intégral dans [LICENSE](LICENSE).

Cette licence autorise l'utilisation, la modification et la redistribution, y compris
à des fins commerciales. Lors de la distribution d'une version modifiée couverte
par la GPLv3, vous devez conserver cette licence et fournir le code source
correspondant selon ses conditions. Elle n'impose pas de publier les modifications
qui restent privées. Le logiciel est fourni sans garantie, dans les limites prévues
par la licence.

Les composants tiers conservent leurs licences respectives. Le simple fait d'exécuter
une application indépendante dans cet environnement ne la place pas automatiquement
sous GPLv3.

Référence : [GNU GPLv3 et sa FAQ](https://www.gnu.org/licenses/gpl-faq.html).
