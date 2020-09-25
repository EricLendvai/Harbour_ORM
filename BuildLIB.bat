@echo off
::echo on
::echo LIBName = %LIBName%
::echo BuildMode = %BuildMode%
::echo HB_COMPILER = %HB_COMPILER%

if %LIBName%. == . goto MissingEnvironmentVariables
if %BuildMode%. == . goto MissingEnvironmentVariables
if %HB_COMPILER%. ==. goto MissingEnvironmentVariables

if not exist %LIBName%.hbp (
	echo Invalid Workspace Folder. Missing file %LIBName%.hbp
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

md %HB_COMPILER% 2>nul
md %HB_COMPILER%\%BuildMode% 2>nul
md %HB_COMPILER%\%BuildMode%\hbmk2 2>nul

del %HB_COMPILER%\%BuildMode%\*.a 2>nul
del %HB_COMPILER%\%BuildMode%\*.lib 2>nul

::  -b        = debug
::  -w3       = warn for variable declarations
::  -es2      = process warning as errors
::  -p        = Leave generated ppo files

:: since this is a library will also fail on warnings.

if %BuildMode% == debug (
	copy debugger_on.hbm debugger.hbm
rem hbmk2 %LIBName%.hbp -b -p -w3 -es2
    hbmk2 %LIBName%.hbp -b -p -w3
) else (
	copy debugger_off.hbm debugger.hbm
    copy *.ch %HB_COMPILER%\%BuildMode%\
    del %HB_COMPILER%\%BuildMode%\*.ppo
rem	hbmk2 %LIBName%.hbp -w3 -es2
	hbmk2 %LIBName%.hbp -w3
)

set SUCCESS=F
if exist %HB_COMPILER%\%BuildMode%\lib%LIBName%.a (set SUCCESS=T)
if exist %HB_COMPILER%\%BuildMode%\%LIBName%.lib  (set SUCCESS=T)

if %SUCCESS% == F (
	echo Failed To build Library
) else (
	if errorlevel 0 (
rem     since debug and release have different .hbx file, localize it
        copy %LIBName%.hbx %HB_COMPILER%\%BuildMode%\ >nul
        del %LIBName%.hbx >nul

		echo.
		echo No Errors
		echo.
		echo Ready          BuildMode = %BuildMode%          C Compiler = %HB_COMPILER%
        if %BuildMode% == release (
rem            echo -----------------------------------------------------------------------------------------------
rem            echo.
rem            echo -----------------------------------------------------------------------------------------------
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