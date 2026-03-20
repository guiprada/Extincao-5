@ECHO OFF
REM Headless simulation launcher -- Windows
REM Tries bundled luajit first, then system luajit, then lua5.4, then lua.
REM
REM Usage:
REM   run_headless.bat [max_updates]

SET SCRIPT=run_headless.lua
SET BUNDLED_LUAJIT=.\lua\luajit.exe
SET BUNDLED_LUA=.\lua\lua5.4.exe

IF EXIST "%BUNDLED_LUAJIT%" (
    "%BUNDLED_LUAJIT%" "%SCRIPT%" %*
    GOTO :EOF
)
IF EXIST "%BUNDLED_LUA%" (
    "%BUNDLED_LUA%" "%SCRIPT%" %*
    GOTO :EOF
)

WHERE luajit >NUL 2>&1
IF %ERRORLEVEL% == 0 (
    luajit "%SCRIPT%" %*
    GOTO :EOF
)

WHERE lua5.4 >NUL 2>&1
IF %ERRORLEVEL% == 0 (
    lua5.4 "%SCRIPT%" %*
    GOTO :EOF
)

WHERE lua >NUL 2>&1
IF %ERRORLEVEL% == 0 (
    lua "%SCRIPT%" %*
    GOTO :EOF
)

ECHO No Lua interpreter found.
ECHO Install luajit or lua5.4, or place a binary in .\lua\
EXIT /B 1
