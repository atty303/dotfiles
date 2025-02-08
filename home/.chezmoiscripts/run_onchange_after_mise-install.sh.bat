@ 2>/dev/null # 2>nul & echo off & goto BOF
:
mise install
exit

:BOF
setlocal
@echo off
mise install
endlocal
exit /B %errorlevel%
