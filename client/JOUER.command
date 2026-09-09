#!/bin/bash
# ==========================================================================
#  SERVEUR RP MEDIEVAL - macOS
#  Double-cliquez sur ce fichier pour jouer.
#
#  Ce fichier ne change jamais : gardez-le sur votre bureau. Il va chercher
#  la mise a jour du pack sur GitHub a chaque lancement, puis ouvre le jeu.
#
#  Si macOS repond "permission denied", ouvrez le Terminal et tapez :
#      chmod +x ~/Desktop/JOUER.command
# ==========================================================================

cd "$(dirname "$0")" 2>/dev/null || true
clear

echo ""
echo "  Serveur RP Medieval - preparation en cours..."
echo ""

URL="https://raw.githubusercontent.com/emile-thiebaut/mod_RPmedieval/main/client/mise_a_jour.sh"
SCRIPT="$(mktemp -t rp_medieval)"

if curl -fsSL "$URL?t=$(date +%s)" -o "$SCRIPT"; then
    bash "$SCRIPT"
    CODE=$?
    rm -f "$SCRIPT"
    if [ "$CODE" -ne 0 ]; then
        echo ""
        echo "  [!] La mise a jour s'est interrompue. Le message ci-dessus dit pourquoi."
        echo "      Si le probleme revient, envoyez une capture d'ecran sur Discord."
        echo ""
        read -r -p "  Appuyez sur Entree pour fermer..."
        exit 1
    fi
else
    rm -f "$SCRIPT"
    echo ""
    echo "  [!] Impossible de contacter GitHub."
    echo "      Verifiez votre connexion Internet, puis relancez ce fichier."
    echo ""
    echo "      Si vous avez deja le pack installe, vous pouvez jouer quand meme :"
    echo "      ouvrez votre launcher et choisissez la version serveur_rp_medieval."
    echo ""
    read -r -p "  Appuyez sur Entree pour fermer..."
    exit 1
fi

sleep 3
exit 0
