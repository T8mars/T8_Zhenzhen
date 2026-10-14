@echo off
setlocal
cd /d "%~dp0emulator"
start "" "%~dp0emulator\fceux64.exe" -pal 0 -no8lim 0 -turbo 0 "%~dp0game\t8-zhenzhen-v7.nes"
endlocal
