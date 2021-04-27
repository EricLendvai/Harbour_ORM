@echo off
::echo on
::echo EXEName = %EXEName%
::echo BuildMode = %BuildMode%
::echo HB_COMPILER = %HB_COMPILER%

if %EXEName%. == . goto MissingEnvironmentVariables
if %BuildMode%. == . goto MissingEnvironmentVariables
if %HB_COMPILER%. ==. goto MissingEnvironmentVariables

if not exist %EXEName%_windows.hbp (
    echo Invalid Workspace Folder. Missing file %EXEName%_windows.hbp
    goto End
)

if %BuildMode%. == debug.   goto GoodParameters
if %BuildMode%. == release. goto GoodParameters

echo You must set Environment Variable BuildMode as "debug" or "release"
goto End

:GoodParameters


if %HB_COMPILER% == msvc64 call "%ProgramFiles(x86)%\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat" x86_amd64

if %HB_COMPILER% == mingw64 set PATH=C:\Program Files\mingw-w64\x86_64-8.1.0-win32-seh-rt_v6-rev0\mingw64\bin;%PATH%

set HB_PATH=C:\Harbour

set PATH=%HB_PATH%\bin\win\%HB_COMPILER%;C:\HarbourTools;%PATH%

echo HB_PATH     = %HB_PATH%
echo HB_COMPILER = %HB_COMPILER%
echo PATH        = %PATH%

md build 2>nul
md build\win64 2>nul
md build\win64\%HB_COMPILER% 2>nul
md build\win64\%HB_COMPILER%\%BuildMode% 2>nul
md build\win64\%HB_COMPILER%\%BuildMode%\hbmk2 2>nul

del build\win64\%HB_COMPILER%\%BuildMode%\%EXEName%.exe 2>nul
if exist build\win64\%HB_COMPILER%\%BuildMode%\%EXEName%.exe (
    echo Could not delete previous version of %EXEName%.exe
    goto End
)

::  -b        = debug
::  -w3       = warn for variable declarations
::  -es2      = process warning as errors
::  -p        = Leave generated ppo files

if %BuildMode% == debug (
    copy ..\debugger_on.hbm ..\debugger.hbm
    rem Had to use -static since with -shared this would create linking issues when using this library in actual programs (hb_ntoc)
    hbmk2 %EXEName%_windows.hbp -b -p -w3 -dDONOTINCLUDE -static
) else (
    copy ..\debugger_off.hbm ..\debugger.hbm
    hbmk2 %EXEName%_windows.hbp -w3 -dDONOTINCLUDE -fullstatic
)

rem the following will output the current datetime
for /F "tokens=2" %%i in ('date /t') do set mydate=%%i
set mytime=%time%
echo Current time is %mydate% %mytime%

if not exist build\win64\%HB_COMPILER%\%BuildMode%\%EXEName%.exe (
    echo Failed To build %EXEName%.exe
) else (
    if errorlevel 0 (
        echo.
        echo No Errors
        echo.
        echo Ready            BuildMode = %BuildMode%          C Compiler = %HB_COMPILER%          EXE = %EXEName%
        if %BuildMode% == release (
            if %RunAfterCompile% == yes (
                echo -----------------------------------------------------------------------------------------------
                build\win64\%HB_COMPILER%\release\%EXEName%
                echo.
                echo -----------------------------------------------------------------------------------------------
            )
        )
    ) else (
        echo Compilation Error
        if errorlevel  1 echo Unknown platform
        if errorlevel  2 echo Unknown compiler
        if errorlevel  3 echo Failed Harbour detection
        if errorlevel  5 echo Failed stub creation
        if errorlevel  6 echo Failed in compilation (Harbour, C compiler, Resource compiler)
        if errorlevel  7 echo Failed in final assembly (linker or library manager)
        if errorlevel  8 echo Unsupported
        if errorlevel  9 echo Failed to create working directory
        if errorlevel 19 echo Help
        if errorlevel 10 echo Dependency missing or disabled
        if errorlevel 20 echo Plugin initialization
        if errorlevel 30 echo Too deep nesting
        if errorlevel 50 echo Stop requested
    )
)

goto End
:MissingEnvironmentVariables
echo Missing Environment Variables
:End