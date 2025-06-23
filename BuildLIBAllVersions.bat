@echo off

r:
cd \Harbour_ORM
SET HB_EL_ROOT=R:\Harbour_EL
SET HARBOUR_ROOT=C:\Harbour
SET LIBName=hb_orm
SET BuildMode=release
SET HB_COMPILER=mingw64
SET SUCCESS=F
CALL BuildLib.bat
if %SUCCESS% == F (
    echo Failed To build Library %BuildMode%  %HB_COMPILER%
    pause
    goto exit
)

r:
cd \Harbour_ORM
SET HB_EL_ROOT=R:\Harbour_EL
SET HARBOUR_ROOT=C:\Harbour
SET LIBName=hb_orm
SET BuildMode=debug
SET HB_COMPILER=mingw64
SET SUCCESS=F
CALL BuildLib.bat
if %SUCCESS% == F (
    echo Failed To build Library %BuildMode%  %HB_COMPILER%
    pause
    goto exit
)

r:
cd \Harbour_ORM
SET HB_EL_ROOT=R:\Harbour_EL
SET HARBOUR_ROOT=C:\Harbour
SET LIBName=hb_orm
SET BuildMode=release
SET HB_COMPILER=msvc64
SET SUCCESS=F
CALL BuildLib.bat
if %SUCCESS% == F (
    echo Failed To build Library %BuildMode%  %HB_COMPILER%
    pause
    goto exit
)

r:
cd \Harbour_ORM
SET HB_EL_ROOT=R:\Harbour_EL
SET HARBOUR_ROOT=C:\Harbour
SET LIBName=hb_orm
SET BuildMode=debug
SET HB_COMPILER=msvc64
SET SUCCESS=F
CALL BuildLib.bat
if %SUCCESS% == F (
    echo Failed To build Library %BuildMode%  %HB_COMPILER%
    pause
    goto exit
)

r:
cd \Harbour_ORM
del *.ppo

:exit
