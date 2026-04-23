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

# --- Menu Principal ---
clear
echo -e "${GREEN}==========================================${NC}"
echo -e "${BLUE}  Goinfre Auto-Setup (Édition Entreprise) ${NC}"
echo -e "${GREEN}==========================================${NC}"
echo "Que veux-tu configurer aujourd'hui ?"
echo ""
echo "  1) Rust & Cargo (Installation automatique dans le goinfre)"
echo "  2) (Exemple) Node.js & NVM"
echo "  3) (Exemple) Docker sans sudo"
echo "  q) Quitter"
echo ""

read -p "Fais ton choix [1-3, q] : " choix

case $choix in
    1) setup_rust ;;
    2) echo "Fonctionnalité en cours de développement..." ;;
    3) echo "Fonctionnalité en cours de développement..." ;;
    q|Q) echo "À bientôt !" ; exit 0 ;;
    *) echo "Choix invalide." ;;
esac