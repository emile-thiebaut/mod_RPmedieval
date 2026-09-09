#!/bin/bash
# ============================================================================
#  SERVEUR RP MEDIEVAL - Mise a jour du pack de jeu (macOS et Linux)
# ----------------------------------------------------------------------------
#  Ce script est telecharge depuis GitHub par JOUER.command a chaque
#  lancement. Il installe le pack s'il est absent, le met a jour sinon.
#
#  Il ne lit que manifest.txt (format tabule), jamais du JSON : macOS n'a
#  ni jq ni python garantis, et on ne veut aucune dependance a installer.
# ============================================================================

set -u

DEPOT="${DEPOT:-https://raw.githubusercontent.com/emile-thiebaut/mod_RPmedieval/main}"

# REPARER=1 : on oublie ce qu'on croit savoir et on reinstalle tout. C'est la
# seule reponse a un dossier config/ ou scripts/ qu'un joueur a bricole.
REPARER="${REPARER:-0}"

# ------------------------------------------------------- ou vit Minecraft ici

if [ -d "$HOME/Library/Application Support/minecraft" ] || [ "$(uname)" = "Darwin" ]; then
    MINECRAFT="$HOME/Library/Application Support/minecraft"
else
    MINECRAFT="$HOME/.minecraft"
fi

INSTANCE="$MINECRAFT/versions/serveur_rp_medieval"
ETAT="$INSTANCE/.pack_etat"
RETIRES="$INSTANCE/mods_retires"
TRAVAIL="$(mktemp -d)"
trap 'rm -rf "$TRAVAIL"' EXIT

VERT='\033[0;32m'; JAUNE='\033[0;33m'; CYAN='\033[0;36m'; GRIS='\033[0;90m'; NEUTRE='\033[0m'

titre() {
    echo ""
    echo "============================================================"
    printf "   ${CYAN}%s${NEUTRE}\n" "$1"
    echo "============================================================"
    echo ""
}

empreinte() {
    [ -f "$1" ] || { echo ""; return; }
    shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1 | tr 'A-Z' 'a-z'
}

poids() {
    o=$1
    if [ "$o" -ge 1048576 ]; then echo "$((o / 1048576)) Mo"
    elif [ "$o" -ge 1024 ]; then echo "$((o / 1024)) Ko"
    else echo "$o o"; fi
}

# ------------------------------------------------------------- le manifeste

titre "SERVEUR RP MEDIEVAL - VERIFICATION DU PACK"
printf "${GRIS}  Lecture de la liste des fichiers du pack...${NEUTRE}\n"

# L'horodatage contourne le cache de 5 minutes du CDN de GitHub ; sur un
# depot local (file://) il n'y a pas de cache et le ? casse le chemin.
MANIFESTE="$TRAVAIL/manifest.txt"
URL_MANIFESTE="$DEPOT/manifest.txt"
case "$DEPOT" in http*) URL_MANIFESTE="$URL_MANIFESTE?t=$(date +%s)" ;; esac
if ! curl -fsSL "$URL_MANIFESTE" -o "$MANIFESTE"; then
    printf "${JAUNE}  [!] GitHub est injoignable. Le jeu va se lancer tel quel.${NEUTRE}\n"
    exit 0
fi

VERSION=$(awk -F'\t' '$1=="V"{print $2}' "$MANIFESTE")
SERVEUR=$(awk -F'\t' '$1=="S"{print $2}' "$MANIFESTE")
BASE=$(awk -F'\t' '$1=="B"{print $2}' "$MANIFESTE")

printf "${GRIS}  Version publiee : %s${NEUTRE}\n" "$VERSION"

if [ ! -d "$INSTANCE/mods" ]; then
    echo ""
    printf "${JAUNE}  Aucun pack installe sur cet ordinateur.${NEUTRE}\n"
    printf "${JAUNE}  Installation complete - comptez quelques minutes.${NEUTRE}\n"
fi
mkdir -p "$INSTANCE"

lire_etat() {
    [ -f "$ETAT" ] || { echo ""; return; }
    awk -F'\t' -v k="$1" '$1==k{print $2}' "$ETAT"
}

# Remplace (ou ajoute) une ligne "cle<TAB>valeur" dans le fichier d'etat.
poser_etat() {
    tmp="$TRAVAIL/etat_tmp"
    if [ -f "$ETAT" ]; then
        awk -F'\t' -v k="$1" '$1!=k' "$ETAT" > "$tmp"
    else
        : > "$tmp"
    fi
    printf '%s\t%s\n' "$1" "$2" >> "$tmp"
    mv -f "$tmp" "$ETAT"
}

# ------------------------------------------ ce qu'il y a a faire, et son poids

A_FAIRE="$TRAVAIL/a_faire"
: > "$A_FAIRE"
TOTAL=0

while IFS=$'\t' read -r type sha taille source cible extra; do
    case "$type" in
        F)
            if [ "$REPARER" = "1" ] || [ "$(empreinte "$INSTANCE/$cible")" != "$sha" ]; then
                printf 'F\t%s\t%s\t%s\t%s\n' "$sha" "$taille" "$source" "$cible" >> "$A_FAIRE"
                TOTAL=$((TOTAL + taille))
            fi
            ;;
        A)
            if [ "$REPARER" = "1" ] || [ "$(lire_etat "$source")" != "$sha" ] || [ ! -d "$INSTANCE/$cible" ]; then
                printf 'A\t%s\t%s\t%s\t%s\t%s\n' "$sha" "$taille" "$source" "$cible" "$extra" >> "$A_FAIRE"
                TOTAL=$((TOTAL + taille))
            fi
            ;;
    esac
done < "$MANIFESTE"

NB=$(wc -l < "$A_FAIRE" | tr -d ' ')

if [ "$NB" -eq 0 ]; then
    echo ""
    printf "${VERT}  [OK] Votre pack est deja a jour. Rien a telecharger.${NEUTRE}\n"
else
    echo ""
    printf "${JAUNE}  %s element(s) a telecharger - %s${NEUTRE}\n" "$NB" "$(poids $TOTAL)"
    echo ""

    N=0
    while IFS=$'\t' read -r type sha taille source cible extra; do
        N=$((N + 1))
        if [ "$type" = "F" ]; then
            printf "  [%s/%s] %s" "$N" "$NB" "$(basename "$cible")"
            mkdir -p "$(dirname "$INSTANCE/$cible")"
            if curl -fsSL "$BASE/$source" -o "$INSTANCE/$cible.part"; then
                mv -f "$INSTANCE/$cible.part" "$INSTANCE/$cible"
                printf "${VERT}   OK${NEUTRE}\n"
            else
                rm -f "$INSTANCE/$cible.part"
                printf "${JAUNE}   ECHEC${NEUTRE}\n"
            fi
        else
            printf "  [%s/%s] %s (dossier complet)" "$N" "$NB" "$cible"
            ZIP="$TRAVAIL/$(basename "$source")"
            if curl -fsSL "$BASE/$source" -o "$ZIP"; then
                [ "$extra" = "purge" ] && rm -rf "$INSTANCE/$cible"
                mkdir -p "$INSTANCE/$cible"
                unzip -oq "$ZIP" -d "$INSTANCE/$cible"
                poser_etat "$source" "$sha"
                printf "${VERT}   OK${NEUTRE}\n"
            else
                printf "${JAUNE}   ECHEC${NEUTRE}\n"
            fi
        fi
    done < "$A_FAIRE"
fi

# ------------------------------------------ retrait des mods hors du manifeste

if [ -d "$INSTANCE/mods" ]; then
    ATTENDUS="$TRAVAIL/attendus"
    awk -F'\t' '$1=="F" && $5 ~ /^mods\//{ n=$5; sub(/^mods\//,"",n); print n }' "$MANIFESTE" > "$ATTENDUS"
    PREMIER=1
    for jar in "$INSTANCE/mods"/*.jar; do
        [ -e "$jar" ] || continue
        nom="$(basename "$jar")"
        if ! grep -Fxq "$nom" "$ATTENDUS"; then
            if [ "$PREMIER" = "1" ]; then
                echo ""
                printf "${JAUNE}  Mods qui ne font plus partie du pack (ranges dans mods_retires) :${NEUTRE}\n"
                mkdir -p "$RETIRES"
                PREMIER=0
            fi
            printf "    - %s\n" "$nom"
            mv -f "$jar" "$RETIRES/$nom"
        fi
    done
fi

# --------------------------------------------------------- liste multijoueur

if [ -f "$INSTANCE/servers.dat" ] && [ ! -f "$MINECRAFT/servers.dat" ]; then
    cp -f "$INSTANCE/servers.dat" "$MINECRAFT/servers.dat" 2>/dev/null || true
fi

# ------------------------------------------------------------ etat sur disque

poser_etat "version" "$VERSION"
poser_etat "date" "$(date '+%Y-%m-%d %H:%M:%S')"

titre "PACK A JOUR - BON JEU !"
printf "${GRIS}  Adresse du serveur : %s${NEUTRE}\n" "$SERVEUR"
echo ""

[ "${SANS_LANCEMENT:-0}" = "1" ] && exit 0

# ------------------------------------------------------------------ lancement

if [ -d "/Applications/Minecraft.app" ]; then
    printf "${CYAN}  Ouverture du launcher Minecraft...${NEUTRE}\n"
    open -a "Minecraft" >/dev/null 2>&1 && exit 0
fi

for cand in "$HOME/Downloads/TLauncher.jar" "$HOME/Desktop/TLauncher.jar" \
            "$HOME/Downloads/1_TLauncher_Mac.jar" "$MINECRAFT/TLauncher.jar"; do
    if [ -f "$cand" ]; then
        printf "${CYAN}  Ouverture de TLauncher...${NEUTRE}\n"
        (java -jar "$cand" >/dev/null 2>&1 &) && exit 0
    fi
done

printf "${JAUNE}  Aucun launcher Minecraft detecte.${NEUTRE}\n"
printf "${JAUNE}  Ouvrez le votre et choisissez la version : serveur_rp_medieval${NEUTRE}\n"
echo ""
exit 0
