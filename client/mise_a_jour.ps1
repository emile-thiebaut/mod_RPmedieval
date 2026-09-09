# ============================================================================
#  SERVEUR RP MEDIEVAL - Mise a jour du pack de jeu (Windows)
# ----------------------------------------------------------------------------
#  Ce script est telecharge depuis GitHub par JOUER.bat a chaque lancement.
#  Il installe le pack s'il est absent, le met a jour s'il est deja la.
#
#  ATTENTION : ASCII pur, aucun accent. Un seul caractere accentue casse
#  l'execution sur les machines dont la console n'est pas en UTF-8.
# ============================================================================

param(
    [string]$Depot = 'https://raw.githubusercontent.com/emile-thiebaut/mod_RPmedieval/main',
    [switch]$SansLancement
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Minecraft   = Join-Path $env:APPDATA '.minecraft'
$Instance    = Join-Path $Minecraft 'versions\serveur_rp_medieval'
$FichierEtat = Join-Path $Instance '.pack_etat.json'
$Retires     = Join-Path $Instance 'mods_retires'

# ---------------------------------------------------------------- utilitaires

function Titre($texte) {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host "   $texte" -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host ''
}

function NouveauClient {
    $c = New-Object System.Net.WebClient
    $c.Headers.Add('User-Agent', 'ServeurRPMedieval-MiseAJour')
    return $c
}

function Empreinte($chemin) {
    if (-not (Test-Path -LiteralPath $chemin)) { return '' }
    return (Get-FileHash -LiteralPath $chemin -Algorithm SHA256).Hash.ToLower()
}

function Telecharger($url, $cible) {
    $dossier = Split-Path -Parent $cible
    if ($dossier -and -not (Test-Path -LiteralPath $dossier)) {
        New-Item -ItemType Directory -Path $dossier -Force | Out-Null
    }
    $partiel = "$cible.part"
    $client = NouveauClient
    try {
        $client.DownloadFile($url, $partiel)
    } finally {
        $client.Dispose()
    }
    Move-Item -LiteralPath $partiel -Destination $cible -Force
}

function Poids($octets) {
    if ($octets -ge 1048576) { return ('{0:N1} Mo' -f ($octets / 1048576)) }
    if ($octets -ge 1024)    { return ('{0:N0} Ko' -f ($octets / 1024)) }
    return "$octets o"
}

# --------------------------------------------------------------- le manifeste

Titre 'SERVEUR RP MEDIEVAL - VERIFICATION DU PACK'

Write-Host '  Lecture de la liste des fichiers du pack...' -ForegroundColor Gray

# L'horodatage contourne le cache de 5 minutes du CDN de GitHub.
$urlManifeste = "$Depot/manifest.json?t=" + [DateTime]::UtcNow.Ticks
$client = NouveauClient
try {
    $brut = $client.DownloadString($urlManifeste)
} finally {
    $client.Dispose()
}
$manifeste = $brut | ConvertFrom-Json

Write-Host ('  Version publiee : ' + $manifeste.version) -ForegroundColor Gray

# ------------------------------------------------------------------ etat local

$etat = @{}
if (Test-Path -LiteralPath $FichierEtat) {
    try {
        $lu = Get-Content -LiteralPath $FichierEtat -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($p in $lu.PSObject.Properties) { $etat[$p.Name] = $p.Value }
    } catch { $etat = @{} }
}

if (-not (Test-Path -LiteralPath (Join-Path $Instance 'mods'))) {
    Write-Host ''
    Write-Host '  Aucun pack installe sur cet ordinateur.' -ForegroundColor Yellow
    Write-Host '  Installation complete - comptez quelques minutes.' -ForegroundColor Yellow
}
if (-not (Test-Path -LiteralPath $Instance)) {
    New-Item -ItemType Directory -Path $Instance -Force | Out-Null
}

$base = $manifeste.base.TrimEnd('/')

# ---------------------------------------------- fichiers unitaires (mods, jar)

$aFaire = @()
foreach ($f in $manifeste.fichiers) {
    $cible = Join-Path $Instance ($f.chemin -replace '/', '\')
    if ((Empreinte $cible) -ne $f.sha256) {
        $aFaire += [PSCustomObject]@{ Entree = $f; Cible = $cible }
    }
}

# ------------------------------------------------------ archives (config, ...)

$archivesAFaire = @()
foreach ($a in $manifeste.archives) {
    $cible = Join-Path $Instance ($a.cible -replace '/', '\')
    $connu = $etat[$a.source]
    if ($connu -ne $a.sha256 -or -not (Test-Path -LiteralPath $cible)) {
        $archivesAFaire += $a
    }
}

$total = 0
foreach ($t in $aFaire)         { $total += $t.Entree.taille }
foreach ($a in $archivesAFaire) { $total += $a.taille }

if ($aFaire.Count -eq 0 -and $archivesAFaire.Count -eq 0) {
    Write-Host ''
    Write-Host '  [OK] Votre pack est deja a jour. Rien a telecharger.' -ForegroundColor Green
} else {
    Write-Host ''
    Write-Host ('  ' + ($aFaire.Count + $archivesAFaire.Count) + ' element(s) a telecharger - ' + (Poids $total)) -ForegroundColor Yellow
    Write-Host ''

    $n = 0
    $sur = $aFaire.Count + $archivesAFaire.Count

    foreach ($t in $aFaire) {
        $n++
        $nom = Split-Path -Leaf $t.Cible
        Write-Host ('  [' + $n + '/' + $sur + '] ' + $nom) -NoNewline
        Telecharger ($base + '/' + $t.Entree.source) $t.Cible
        Write-Host '   OK' -ForegroundColor Green
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    foreach ($a in $archivesAFaire) {
        $n++
        Write-Host ('  [' + $n + '/' + $sur + '] ' + $a.cible + ' (dossier complet)') -NoNewline
        $zip = Join-Path $env:TEMP ('rp_' + [IO.Path]::GetFileName($a.source))
        Telecharger ($base + '/' + $a.source) $zip
        $cible = Join-Path $Instance ($a.cible -replace '/', '\')
        if ($a.purge -and (Test-Path -LiteralPath $cible)) {
            Remove-Item -LiteralPath $cible -Recurse -Force
        }
        if (-not (Test-Path -LiteralPath $cible)) {
            New-Item -ItemType Directory -Path $cible -Force | Out-Null
        }
        # ExtractToDirectory refuse d'ecraser un fichier existant : on extrait
        # donc entree par entree, en ecrasement force.
        $archive = [IO.Compression.ZipFile]::OpenRead($zip)
        try {
            foreach ($e in $archive.Entries) {
                $dest = Join-Path $cible ($e.FullName -replace '/', '\')
                if ($e.FullName.EndsWith('/')) {
                    if (-not (Test-Path -LiteralPath $dest)) {
                        New-Item -ItemType Directory -Path $dest -Force | Out-Null
                    }
                    continue
                }
                $parent = Split-Path -Parent $dest
                if (-not (Test-Path -LiteralPath $parent)) {
                    New-Item -ItemType Directory -Path $parent -Force | Out-Null
                }
                [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $dest, $true)
            }
        } finally {
            $archive.Dispose()
        }
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        $etat[$a.source] = $a.sha256
        Write-Host '   OK' -ForegroundColor Green
    }
}

# ------------------------------------------- retrait des mods hors du manifeste

$attendus = @{}
foreach ($f in $manifeste.fichiers) {
    if ($f.chemin -like 'mods/*') { $attendus[(Split-Path -Leaf $f.chemin)] = $true }
}

$dossierMods = Join-Path $Instance 'mods'
if (Test-Path -LiteralPath $dossierMods) {
    $intrus = Get-ChildItem -LiteralPath $dossierMods -File -Filter '*.jar' |
              Where-Object { -not $attendus.ContainsKey($_.Name) }
    if ($intrus) {
        if (-not (Test-Path -LiteralPath $Retires)) {
            New-Item -ItemType Directory -Path $Retires -Force | Out-Null
        }
        Write-Host ''
        Write-Host '  Mods qui ne font plus partie du pack (ranges dans mods_retires) :' -ForegroundColor Yellow
        foreach ($i in $intrus) {
            Write-Host ('    - ' + $i.Name) -ForegroundColor DarkYellow
            Move-Item -LiteralPath $i.FullName -Destination (Join-Path $Retires $i.Name) -Force -ErrorAction SilentlyContinue
        }
    }
}

# ----------------------------------------------------------- liste multijoueur

$serveursPack   = Join-Path $Instance 'servers.dat'
$serveursGlobal = Join-Path $Minecraft 'servers.dat'
if ((Test-Path -LiteralPath $serveursPack) -and -not (Test-Path -LiteralPath $serveursGlobal)) {
    Copy-Item -LiteralPath $serveursPack -Destination $serveursGlobal -Force -ErrorAction SilentlyContinue
}

# --------------------------------------- profil pour le launcher Mojang officiel

$profils = Join-Path $Minecraft 'launcher_profiles.json'
if (Test-Path -LiteralPath $profils) {
    try {
        $json = Get-Content -LiteralPath $profils -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($json.profiles) {
            $date = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            $profil = [PSCustomObject]@{
                name          = 'Serveur RP Medieval (1.12.2)'
                type          = 'custom'
                created       = $date
                lastUsed      = $date
                lastVersionId = 'serveur_rp_medieval'
                gameDir       = $Instance
                icon          = 'Lectern'
            }
            $json.profiles | Add-Member -Name 'serveur_rp_medieval' -Value $profil -MemberType NoteProperty -Force
            $json | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $profils -Encoding UTF8
        }
    } catch { }
}

# --------------------------------------------------------------- etat sur disque

$etat['version'] = $manifeste.version
$etat['date'] = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
($etat | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $FichierEtat -Encoding UTF8

Titre 'PACK A JOUR - BON JEU !'
Write-Host ('  Adresse du serveur : ' + $manifeste.serveur) -ForegroundColor Gray
Write-Host ''

if ($SansLancement) { exit 0 }

# -------------------------------------------------------------------- lancement

$launchers = @(
    (Join-Path $Minecraft 'TLauncher.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\launcher\Minecraft.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Minecraft Launcher\MinecraftLauncher.exe'),
    (Join-Path $env:ProgramFiles 'Minecraft Launcher\MinecraftLauncher.exe')
)

foreach ($l in $launchers) {
    if ($l -and (Test-Path -LiteralPath $l)) {
        Write-Host '  Ouverture de votre launcher Minecraft...' -ForegroundColor Cyan
        Start-Process -FilePath $l | Out-Null
        exit 0
    }
}

Write-Host '  Aucun launcher Minecraft detecte sur cet ordinateur.' -ForegroundColor Yellow
Write-Host '  Ouvrez le votre et choisissez la version : serveur_rp_medieval' -ForegroundColor Yellow
Write-Host ''
exit 0
