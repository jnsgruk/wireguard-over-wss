@setlocal enableextensions enabledelayedexpansion
@ECHO OFF
REM This file should be run as Administrator
REM Folder where wireguard.exe, wstunnel.exe and wireguard conf file located
SET WIREG_LOCATION=c:\wgwss
SET LOCAL_UDP_PORT=59194
SET REMOTE_UDP_PORT=59194
REM URL to connect websocket tunnel to
SET WEBSOCKET_URL=wss://example.com
REM Mostly wg0 interface ip
SET WIREG_LOCAL_IP=10.10.1.1
REM Config filename without extension (.conf)
SET WIREG_CONFIG=solnwg

start /b %WIREG_LOCATION%\wstunnel.exe client --http-upgrade-path-prefix wstunnel -L "udp://127.0.0.1:%LOCAL_UDP_PORT%:127.0.0.1:%REMOTE_UDP_PORT%" %WEBSOCKET_URL%
echo "Connecting ...."
REM give it couple of seconds to establish tunnel
timeout 3 /NOBREAK
%WIREG_LOCATION%\wireguard.exe /installtunnelservice %WIREG_LOCATION%\%WIREG_CONFIG%.conf
ping -n 2 %WIREG_LOCAL_IP% | find "TTL" >nul
if not errorlevel 1 goto connected
if errorlevel 1 goto disconnected
:connected
cls
set /p DUMMY=Hit ENTER to disconnect...
goto disconnect
:disconnected
echo "Could not connect in time, please try again..."
:disconnect
%WIREG_LOCATION%\wireguard.exe /uninstalltunnelservice %WIREG_CONFIG%
REM kill wstunnel
taskkill -f -im wstunnel* >nul
echo "Disconnected.."
