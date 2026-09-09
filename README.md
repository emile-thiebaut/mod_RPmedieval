# Serveur RP Medieval - pack de jeu

Version publiee : **2026.09.09-56b7bb99** (59 mods)

## Pour jouer

**Windows** - telechargez [JOUER.bat](client/JOUER.bat) sur votre bureau,
puis double-cliquez dessus.

**macOS** - ouvrez le Terminal, collez cette ligne, tapez Entree :

    curl -fsSL https://raw.githubusercontent.com/emile-thiebaut/mod_RPmedieval/main/client/mise_a_jour.sh | bash

(ou telechargez [JOUER.command](client/JOUER.command), puis
`chmod +x ~/Downloads/JOUER.command` et double-cliquez.)

Le meme fichier installe le pack la premiere fois et le met a jour ensuite.
Il n'y a jamais rien d'autre a retelecharger.

## Ce que contient ce depot

| Chemin | Role |
| :--- | :--- |
| `manifest.json` / `manifest.txt` | la liste des fichiers et leurs empreintes |
| `client/` | les scripts que lancent les joueurs |
| `pack/mods/` | les mods, un fichier chacun |
| `pack/*.zip` | config, scripts CraftTweaker, packs de textures |
| `pack/base/` | le profil Forge 1.12.2 et la liste multijoueur |

Publie par `outils/publier_le_pack.py` depuis le depot de travail.
Ne rien modifier ici a la main : la prochaine publication ecraserait tout.
