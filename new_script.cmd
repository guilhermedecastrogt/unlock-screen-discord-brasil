@echo off
chcp 65001 >nul
title EXPERIMENTO DISCORD
setlocal enabledelayedexpansion

echo Bypassing...

taskkill /F /IM Discord.exe >nul 2>&1
taskkill /F /IM DiscordPTB.exe >nul 2>&1
taskkill /F /IM DiscordCanary.exe >nul 2>&1

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 1 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /t REG_SZ /d "181.39.25.196:8118" /f >nul

set "DISCORD_DIR="
set "APP_NAME="
set "PROCESS_BASE="

if exist "%LOCALAPPDATA%\Discord\Update.exe" (
    set "DISCORD_DIR=%LOCALAPPDATA%\Discord"
    set "APP_NAME=Discord.exe"
    set "PROCESS_BASE=Discord"
) else if exist "%LOCALAPPDATA%\DiscordCanary\Update.exe" (
    set "DISCORD_DIR=%LOCALAPPDATA%\DiscordCanary"
    set "APP_NAME=DiscordCanary.exe"
    set "PROCESS_BASE=DiscordCanary"
) else if exist "%LOCALAPPDATA%\DiscordPTB\Update.exe" (
    set "DISCORD_DIR=%LOCALAPPDATA%\DiscordPTB"
    set "APP_NAME=DiscordPTB.exe"
    set "PROCESS_BASE=DiscordPTB"
)

if defined DISCORD_DIR (
    start "" "!DISCORD_DIR!\Update.exe" --processStart !APP_NAME!
) else (
    goto FINALIZAR
)

:VERIFICACAO
timeout /t 1 /nobreak >nul

for /f "usebackq tokens=*" %%A in (`powershell -NoProfile -Command "$p = Get-Process -Name '!PROCESS_BASE!' -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -and $_.MainWindowTitle -notmatch 'Update|Updater' }; if ($p) { 'READY' } else { 'WAIT' }"`) do set "STATUS=%%A"

if not "!STATUS!"=="READY" (
    goto VERIFICACAO
)

:FINALIZAR
timeout /t 1 /nobreak >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f >nul

powershell -NoProfile -Command "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null; $found = Get-StartApps | Where-Object { $_.Name -match '!PROCESS_BASE!' -or $_.AppID -match '!PROCESS_BASE!' } | Select-Object -First 1; $appId = if ($found) { $found.AppID } else { 'com.squirrel.!PROCESS_BASE!.!PROCESS_BASE!' }; $tmpl = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02); $t = $tmpl.GetElementsByTagName('text'); $t.Item(0).AppendChild($tmpl.CreateTextNode('Bypass Concluído^!')) | Out-Null; $t.Item(1).AppendChild($tmpl.CreateTextNode('Será necessário aplicar o bypass novamente após fechar o Discord para reativar as funções.')) | Out-Null; $toast = [Windows.UI.Notifications.ToastNotification]::new($tmpl); [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast);"

endlocal