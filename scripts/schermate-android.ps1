# Sul PC Windows: compila l'app per l'emulatore Android con le opzioni di prova e fotografa ogni schermata in dist\schermate-android.
# L'emulatore deve essere acceso (adb devices). Ogni argomento e' "nome:opzioni" (--dart-define separate da virgola):
#
#   powershell -File scripts\schermate-android.ps1 home: calendario:PROVA_SCHEDA=1 rioni:PROVA_RIONI=true
#
# Le schermate per Google Play non possono superare il rapporto 2:1: si ritagliano barra di stato e barra di navigazione.

param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Voci)
$ErrorActionPreference = 'Stop'
$flutter = 'C:\Tools\flutter\bin\flutter.bat'
$adb = 'C:\Tools\android-sdk\platform-tools\adb.exe'
$id = 'it.uggiateconronago.palio'
$attesa = if ($env:ATTESA) { [int]$env:ATTESA } else { 10 }
Set-Location (Split-Path $PSScriptRoot -Parent)
$uscita = 'dist\schermate-android'
New-Item -ItemType Directory -Force $uscita | Out-Null

# barra di stato fissa: 9:41, batteria piena, segnale pieno
& $adb shell settings put global sysui_demo_allowed 1 | Out-Null
& $adb shell am broadcast -a com.android.systemui.demo -e command enter | Out-Null
& $adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941 | Out-Null
& $adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false | Out-Null
& $adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 -e mobile show -e level 4 | Out-Null
& $adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false | Out-Null

foreach ($voce in $Voci) {
  $nome, $opzioni = $voce -split ':', 2
  $definizioni = @("--dart-define=SCHERMATA=$nome")
  if ($opzioni) { foreach ($c in $opzioni -split ',') { if ($c) { $definizioni += "--dart-define=$c" } } }
  Write-Host "=== $nome $definizioni"
  & $flutter build apk --release --target-platform android-x64 @definizioni *> "$env:TEMP\schermata-$nome.log"
  if ($LASTEXITCODE -ne 0) { Write-Host "!! build non riuscita, vedi $env:TEMP\schermata-$nome.log"; continue }
  & $adb install -r build\app\outputs\flutter-apk\app-release.apk | Out-Null
  # niente richiesta del permesso per le notifiche sopra la schermata
  & $adb shell pm grant $id android.permission.POST_NOTIFICATIONS 2>$null
  & $adb shell am force-stop $id
  & $adb shell monkey -p $id -c android.intent.category.LAUNCHER 1 | Out-Null
  Start-Sleep $attesa
  $png = "$uscita\$nome.png"
  & $adb shell screencap -p /sdcard/schermata.png
  & $adb pull /sdcard/schermata.png $png | Out-Null
  Write-Host "fatta: $png"
}
