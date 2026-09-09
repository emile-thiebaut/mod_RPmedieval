@echo off
:: ==========================================================================
::  SERVEUR RP MEDIEVAL - Windows
::  Double-cliquez sur ce fichier pour jouer.
::
::  Ce fichier ne change jamais : gardez-le sur votre bureau. Il va chercher
::  la mise a jour du pack sur GitHub a chaque lancement, puis ouvre le jeu.
:: ==========================================================================
setlocal
title Serveur RP Medieval
cls

echo.
echo   Serveur RP Medieval - preparation en cours...
echo.

set "SCRIPT=%TEMP%\rp_medieval_mise_a_jour.ps1"
set "URL=https://raw.githubusercontent.com/emile-thiebaut/mod_RPmedieval/main/client/mise_a_jour.ps1"

if exist "%SCRIPT%" del /q "%SCRIPT%" >nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
  "$c=New-Object System.Net.WebClient;" ^
  "$c.Headers.Add('User-Agent','ServeurRPMedieval');" ^
  "try { $c.DownloadFile('%URL%?t='+[DateTime]::UtcNow.Ticks,'%SCRIPT%') } catch {}" >nul 2>&1

if not exist "%SCRIPT%" goto :HORS_LIGNE

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
if errorlevel 1 goto :ECHEC

timeout /t 3 >nul
exit /b 0

:HORS_LIGNE
echo.
echo   [!] Impossible de contacter GitHub.
echo       Verifiez votre connexion Internet, puis relancez ce fichier.
echo.
echo       Si vous avez deja le pack installe, vous pouvez jouer quand meme :
echo       ouvrez votre launcher et choisissez la version serveur_rp_medieval.
echo.
pause
exit /b 1

:ECHEC
echo.
echo   [!] La mise a jour s'est interrompue. Le message ci-dessus dit pourquoi.
echo       Si le probleme revient, envoyez une capture d'ecran sur Discord.
echo.
pause
exit /b 1
