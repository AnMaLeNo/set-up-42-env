# 🛠️ Goinfre Auto-Setup Daemon

![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Automation](https://img.shields.io/badge/Automation-FF4F8B?style=for-the-badge&logo=github-actions&logoColor=white)

Un utilitaire système en ligne de commande (CLI) conçu pour contourner les restrictions strictes de quota de stockage dans les environnements à profils itinérants (comme l'infrastructure de l'École 42). 

## Le Problème
Dans les environnements avec un répertoire `$HOME` restreint (ex: 5 Go maximum), il est impossible d'installer des outils de développement lourds (toolchains de compilation, extensions VS Code) sans saturer instantanément l'espace alloué, ce qui bloque la session.

## La Solution
Ce script installe un daemon (processus en arrière-plan) qui redirige automatiquement et de manière transparente ces installations lourdes vers la partition locale et volatile de la machine physique (le `/goinfre`). 
À chaque nouvelle ouverture de session, le daemon restaure l'environnement de travail de manière asynchrone, offrant une persistance d'état malgré la volatilité du stockage local.

## Architecture & Mécanismes Intégrés

Aucun binaire tiers n'est requis. Le système repose entièrement sur des utilitaires natifs UNIX et génère sa propre infrastructure de provisionnement :

*   **Démarrage Automatisé (XDG Autostart) :** Génération de descripteurs `.desktop` dans `~/.config/autostart/`. Le gestionnaire de session graphique (X11/Wayland) lance les routines de restauration en arrière-plan dès le login.
*   **Polling d'Entrées/Sorties Sécurisé :** Les scripts attendent activement le montage de la partition locale (`~/goinfre`) avec un timeout de sécurité (60s) pour éviter tout interblocage (deadlock).
*   **Idempotence & Réconciliation d'état :** Le script compare un fichier manifeste (`~/.vscode_extensions_manifest`) avec l'état réel du système. Seules les dépendances manquantes sont réinstallées, minimisant l'impact réseau (I/O).

## Modules de Provisionnement

### 1. Module Rust (Toolchain)
Redirection de l'installation en surchargeant les variables d'environnement `RUSTUP_HOME` et `CARGO_HOME`. Les variables sont injectées proprement dans le `~/.zshrc` pour garantir la persistance inter-sessions.

### 2. Module VS Code (Extensions)
Le répertoire par défaut `~/.vscode/extensions` est remplacé par un lien symbolique pointant vers la partition locale. Une routine IPC (`code --list-extensions`) lit le manifeste de l'utilisateur et force l'installation en arrière-plan des extensions manquantes.

## Utilisation

**Prérequis :** Environnement Linux, Bash, `curl`, GNU Coreutils.

1. Clonez le dépôt et donnez les droits d'exécution au script de configuration[cite: 3] :
   ```bash
   chmod +x goinfre_auto_setup.sh