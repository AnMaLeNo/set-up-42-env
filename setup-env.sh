#!/bin/bash

# --- Couleurs pour rendre le terminal plus joli ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Fonction pour configurer Rust dans le goinfre ---
setup_rust() {
    echo -e "${BLUE}▶ Configuration de l'auto-installeur Rust...${NC}"

    # 1. Création du script d'auto-installation
    # On utilise $HOME au lieu de /home/amonot pour que ça marche pour n'importe quel utilisateur !
    cat << 'EOF' > "$HOME/.setup_rust_goinfre.sh"
#!/bin/bash
GOINFRE_DIR="$HOME/goinfre"
export RUSTUP_HOME="$GOINFRE_DIR/.rustup"
export CARGO_HOME="$GOINFRE_DIR/.cargo"

MAX_WAIT=60
WAIT_TIME=0
while [ ! -d "$GOINFRE_DIR" ]; do
    sleep 2
    WAIT_TIME=$((WAIT_TIME + 2))
    [ $WAIT_TIME -ge $MAX_WAIT ] && exit 1
done

if [ ! -d "$CARGO_HOME" ]; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y -q --no-modify-path
    # Exécution explicite du binaire cargo localisé dans le goinfre
    "$GOINFRE_DIR/.cargo/bin/rustup" component add rust-src
fi
EOF
    chmod +x "$HOME/.setup_rust_goinfre.sh"

    # 2. Création de l'entrée Autostart pour GNOME
    mkdir -p "$HOME/.config/autostart"
    cat << EOF > "$HOME/.config/autostart/rust-installer.desktop"
[Desktop Entry]
Type=Application
Exec=$HOME/.setup_rust_goinfre.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Rust Auto Installer (Goinfre)
Comment=Installe Rust automatiquement dans le goinfre
EOF

    # 3. Ajout des variables dans .zshrc (seulement si elles n'y sont pas déjà !)
    if ! grep -q "RUSTUP_HOME=" "$HOME/.zshrc"; then
        echo -e "\n# --- RUST IN GOINFRE ---" >> "$HOME/.zshrc"
        echo 'export RUSTUP_HOME="$HOME/goinfre/.rustup"' >> "$HOME/.zshrc"
        echo 'export CARGO_HOME="$HOME/goinfre/.cargo"' >> "$HOME/.zshrc"
        echo 'export PATH="$HOME/goinfre/.cargo/bin:$PATH"' >> "$HOME/.zshrc"
    fi

    echo -e "${GREEN}✅ Terminé ! Rust s'installera silencieusement à la prochaine connexion.${NC}"
}

setup_vscode_extensions() {
    echo -e "${BLUE}▶ Déploiement de l'infrastructure d'extensions VS Code...${NC}"

    local GOINFRE_EXT_DIR="$HOME/goinfre/.vscode-extensions"
    local LOCAL_EXT_DIR="$HOME/.vscode/extensions"
    local MANIFEST="$HOME/.vscode_extensions_manifest"
    local AUTOSTART_SCRIPT="$HOME/.setup_vscode_goinfre.sh"
    local DESKTOP_FILE="$HOME/.config/autostart/vscode-ext-installer.desktop"

    # 1. Évaluation de l'état et Routage I/O (Symlink)
    if [ ! -L "$LOCAL_EXT_DIR" ]; then
        echo "Initialisation du routage symbolique vers la partition goinfre..."
        mkdir -p "$GOINFRE_EXT_DIR"
        
        # Sauvegarde de l'existant en cas de répertoire standard (prévention de perte de données)
        if [ -d "$LOCAL_EXT_DIR" ]; then
            mv "$LOCAL_EXT_DIR" "${LOCAL_EXT_DIR}_backup_$(date +%s)"
        fi
        
        mkdir -p "$HOME/.vscode"
        ln -sf "$GOINFRE_EXT_DIR" "$LOCAL_EXT_DIR"
    else
        echo "Routage symbolique détecté. Saut de l'initialisation du système de fichiers."
    fi

    # 2. Gestion du Manifeste (Saisie et Déduplication)
    touch "$MANIFEST"
    echo -e "\nSaisissez les identifiants techniques des extensions à provisionner."
    echo "Syntaxe requise : <publisher>.<name> (séparés par un espace)."
    read -p "> " ext_input

    if [ -n "$ext_input" ]; then
        for ext in $ext_input; do
            # Expression régulière (grep) pour garantir l'unicité stricte de l'entrée
            if ! grep -q "^${ext}$" "$MANIFEST"; then
                echo "$ext" >> "$MANIFEST"
                echo "-> Ajout de l'entrée au manifeste : $ext"
            else
                echo "-> Entrée ignorée (déjà existante) : $ext"
            fi
        done
    fi

    # 3. Génération du Daemon d'Installation (Exécution au Login)
	rm -f "$AUTOSTART_SCRIPT"
	cat << 'EOF' > "$AUTOSTART_SCRIPT"
#!/bin/bash
MANIFEST="$HOME/.vscode_extensions_manifest"
LOG_FILE="$HOME/goinfre/vscode_setup.log"

# Attente active de la disponibilité du point de montage goinfre
MAX_WAIT=60
WAIT_TIME=0
while [ ! -d "$HOME/goinfre" ]; do
    sleep 2
    WAIT_TIME=$((WAIT_TIME + 2))
    [ $WAIT_TIME -ge $MAX_WAIT ] && exit 1
done

TARGET="$HOME/goinfre/.vscode-extensions"
LINK="$HOME/.vscode/extensions"

# 1. Fix critique (ENOENT)
mkdir -p "$TARGET"
mkdir -p "$HOME/.vscode"

# 2. Si c'est un dossier → backup
if [ -d "$LINK" ] && [ ! -L "$LINK" ]; then
    mv "$LINK" "${LINK}_backup_$(date +%s)"
fi

# 3. Si mauvais lien ou absent → corriger
if [ ! -L "$LINK" ] || [ "$(readlink "$LINK")" != "$TARGET" ]; then
    ln -sf "$TARGET" "$LINK"
fi

# Vérification de la disponibilité de l'exécutable dans le tableau d'environnement $PATH
if ! command -v code &> /dev/null; then
    echo "$(date) - ERREUR : Processus 'code' introuvable dans le \$PATH." >> "$LOG_FILE"
    exit 1
fi

# Parsing du manifeste et exécution conditionnelle de l'installation
if [ -f "$MANIFEST" ]; then
    # Extraction du cache des extensions installées pour minimiser les appels IPC
    INSTALLED_CACHE=$(code --list-extensions | tr '[:upper:]' '[:lower:]')
    
    while IFS= read -r ext; do
        [ -z "$ext" ] && continue
        EXT_LOWER=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
        
        if ! echo "$INSTALLED_CACHE" | grep -q "^${EXT_LOWER}$"; then
            echo "$(date) - Provisionnement : $ext" >> "$LOG_FILE"
            code --install-extension "$ext" --force >> "$LOG_FILE" 2>&1
        fi
    done < "$MANIFEST"
fi
EOF
        chmod +x "$AUTOSTART_SCRIPT"
    

    # 4. Enregistrement du Daemon auprès du gestionnaire de session (X11/Wayland)
    if [ ! -f "$DESKTOP_FILE" ]; then
        mkdir -p "$HOME/.config/autostart"
        cat << EOF > "$DESKTOP_FILE"
[Desktop Entry]
Type=Application
Exec=$AUTOSTART_SCRIPT
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=VS Code Extension Provisioner
Comment=Synchronisation non-interactive de l'état des extensions VS Code
EOF
    fi

    echo -e "${GREEN}✅ Séquence d'écriture terminée.${NC} L'état du manifeste sera réconcilié lors de la prochaine allocation de session."
}

# --- Menu Principal ---
clear
echo -e "${GREEN}==========================================${NC}"
echo -e "${BLUE}  Goinfre Auto-Setup (Édition Entreprise) ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo "Que veux-tu configurer aujourd'hui ?"
echo ""
echo "  1) Rust & Cargo (Installation automatique dans le goinfre)"
echo "  2) Setup VScode extensions"
echo "  3) (Exemple) Docker sans sudo"
echo "  q) Quitter"
echo ""

read -p "Fais ton choix [1-3, q] : " choix

case $choix in
    1) setup_rust ;;
    2) setup_vscode_extensions ;; # Appel de la nouvelle procédure
    3) echo "Fonctionnalité en cours de développement..." ;;
    q|Q) echo "Fin du processus." ; exit 0 ;;
    *) echo "Instruction non reconnue." ;;
esac
