@echo off
rem Starts the Strange Ranger tracker. Leave this window open while you use it.
cd /d "%~dp0..\.."
python tools\tracker\server.py
pause
