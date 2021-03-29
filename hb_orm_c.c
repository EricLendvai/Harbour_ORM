//Copyright (c) 2021 Eric Lendvai MIT License

#include "hbapi.h"

#ifdef _WIN32
#include <windows.h>
#endif

HB_FUNC( HB_ORM_OUTPUTDEBUGSTRING )   // For Windows Only
{
#ifdef _WIN32
    OutputDebugString( hb_parc(1) );
#endif
}

//=================================================================================================================

