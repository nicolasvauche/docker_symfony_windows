# docker_symfony

## Description

Environnement Docker pour créer et exécuter un projet Symfony avec FrankenPHP et
PHP sous Windows. Compose Watch synchronise les sources vers Linux, tandis que
les dépendances et le cache restent côté Linux pour éviter les E/S lentes entre
Windows et Docker. Les extensions SQLite, PostgreSQL et MongoDB sont incluses,
sans services de base de données supplémentaires.

## Prérequis

Docker Desktop démarré en mode conteneurs Linux, avec le moteur WSL2,
et Docker Compose 2.32 ou plus récent (la version locale 5.6.1 convient).
Aucun PHP ni Composer n'est nécessaire sur Windows.

## Installation

```powershell
cd C:\Users\VAUCHE\Dev\_docker\docker_symfony
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

Exécutez les commandes ci-dessous depuis `docker_symfony`. Gardez
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

### Versions

Configuration préparée le 10 novembre 2026 : Symfony **8.1.x** (stable publiée :
8.1.11), PHP **8.5.12**, FrankenPHP **1.13.5**, Debian Trixie et Composer 2.
L'initialisation résout le dernier correctif Symfony 8.1 disponible, puis
`app/composer.lock` conserve les versions exactes. Aucun service de base de données
n'est créé.

### Bases de données et extensions

SQLite fonctionne immédiatement via `pdo_sqlite` et `sqlite3`. Par défaut,
`DATABASE_URL=sqlite:////app/var/data/app.db`. Le volume `app_data` conserve le fichier
quand vous arrêtez ou reconstruisez le service.

PostgreSQL : extensions `pdo_pgsql` et `pgsql`. MongoDB : extension `mongodb`
stable, sans ODM ni bibliothèque PHP MongoDB ajoutés automatiquement.
Extensions usuelles ajoutées : `intl`, `mbstring`, `zip`, `bcmath`, `gd`,
DOM/XML et cURL. OPcache est intégré à PHP 8.5.

Pour personnaliser le port ou DATABASE_URL, copiez `.env.example` vers `.env`
à la racine de **docker_symfony**, puis relancez `start`. Ce `.env` configure Compose ;
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
.\dev.ps1 check
```

`check` vérifie les versions, les exigences Composer et les extensions de bases.
Testez également une modification de contrôleur ou de template avec Watch actif :
elle doit apparaître après synchronisation, sans copie de `var/cache` vers Windows.

Les versions de PHP et FrankenPHP sont explicitement fixées dans le Dockerfile.
Pour une future mise à jour, vérifiez les versions et le tag officiel, modifiez
`FRANKENPHP_IMAGE`, puis exécutez `docker compose build --pull php` et relancez `start`.
Symfony reste volontairement sur la branche stable 8.1, sans préversion 8.2.
Conservez `composer.lock` et `symfony.lock` dans Git.

La configuration est destinée au développement local, avec HTTP lié uniquement
à `127.0.0.1`, le profiler et les erreurs de développement. Ce n'est pas une
configuration de production.

Validation sur cette machine : syntaxe Compose et PowerShell vérifiable sans
moteur. Le build, la disponibilité effective du tag d'image, l'installation des
extensions et les temps de réponse doivent être vérifiés une fois Docker Desktop
démarré et Docker Hub accessible.

Références officielles :

- https://symfony.com/releases
- https://www.php.net/downloads.php
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

Pour proposer une modification :

1. Décrivez le problème ou le comportement attendu et les étapes pour le reproduire.
2. Préparez une branche avec des modifications ciblées et mettez à jour la documentation concernée.
3. Vérifiez la configuration avec `docker compose config --quiet`, puis testez le démarrage et les commandes concernées avec Docker Desktop.
4. Si la modification touche les volumes ou Watch, vérifiez la synchronisation des sources et l'absence de synchronisation de `var/` et `vendor/`.
5. Ouvrez une pull request en précisant les changements, les vérifications effectuées et les éventuelles limites.

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
