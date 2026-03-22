@ECHO OFF
REM Batch simulation launcher -- Windows
REM Runs run_batch.lua with whatever Lua interpreter is available.
REM
REM Usage:
REM   run_batch.bat [batch_file.lua]

SET SCRIPT=run_batch.lua
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
