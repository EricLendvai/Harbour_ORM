//Copyright (c) 2023 Eric Lendvai MIT License

#include "hbapi.h"
#include "hbapierr.h"
#include "hbapicdp.h"

#ifdef _WIN32
#include <windows.h>
#endif

HB_WCHAR hb_orm_cdpUTF8StringPeek( const char * pSrc, HB_SIZE nLen, HB_SIZE nPos );
HB_BOOL hb_orm_cdpUTF8ToU16NextChar( HB_UCHAR ucChar, int * n, HB_WCHAR * pwc );

HB_FUNC( HB_ORM_OUTPUTDEBUGSTRING )   // For Windows Only
{
#ifdef _WIN32
    OutputDebugString( hb_parc(1) );
#endif
}

//=================================================================================================================

//------------------------------------------------------------------------------------------------------------------

HB_FUNC( HB_ORM_UTF8PEEK )
{
	const char * szString = hb_parc( 1 );

	if( szString && HB_ISNUM( 2 ) )
	{
		HB_SIZE nPos = hb_parns( 2 );
		HB_SIZE nLen = hb_parclen( 1 );

		if( nPos > 0 && nPos <= nLen )
			hb_retnint( hb_orm_cdpUTF8StringPeek( szString, nLen, nPos - 1 ) );
		else
			hb_retni( 0 );
	}
	else
		hb_errRT_BASE_SubstR( EG_ARG, 3012, NULL, HB_ERR_FUNCNAME, HB_ERR_ARGS_BASEPARAMS );
}

//------------------------------------------------------------------------------------------------------------------

HB_WCHAR hb_orm_cdpUTF8StringPeek( const char * pSrc, HB_SIZE nLen, HB_SIZE nPos )
{
   if( nLen )
   {
      HB_SIZE nPos2;
      HB_WCHAR wc = 0;
      int n = 0;

      for( nPos2 = 0; nPos2 < nLen && nPos; )
      {
         if( hb_orm_cdpUTF8ToU16NextChar( ( HB_UCHAR ) pSrc[ nPos2 ], &n, &wc ) )
            ++nPos2;
         if( n == 0 )
            --nPos;
      }

      if( nPos2 < nLen )
      {
         n = 0;
         do
         {
            if( hb_orm_cdpUTF8ToU16NextChar( ( HB_UCHAR ) pSrc[ nPos2 ], &n, &wc ) )
               ++nPos2;
            if( n == 0 )
               return wc;
         }
         while( nPos2 < nLen );
      }
   }

   return 0;
}


//------------------------------------------------------------------------------------------------------------------

HB_BOOL hb_orm_cdpUTF8ToU16NextChar( HB_UCHAR ucChar, int * n, HB_WCHAR * pwc )
{
   if( *n > 0 )
   {
      if( ( ucChar & 0xc0 ) != 0x80 )
      {
         *n = 0;
         return HB_FALSE;
      }
      *pwc = ( *pwc << 6 ) | ( ucChar & 0x3f );
      ( *n )--;
      return HB_TRUE;
   }

   *n = 0;
   *pwc = ucChar;
   if( ucChar >= 0xc0 )
   {
      if( ucChar < 0xe0 )
      {
         *pwc &= 0x1f;
         *n = 1;
      }
      else if( ucChar < 0xf0 )
      {
         *pwc &= 0x0f;
         *n = 2;
      }
      else if( ucChar < 0xf8 )
      {
         *pwc &= 0x07;
         *n = 3;
      }
      else if( ucChar < 0xfc )
      {
         *pwc &= 0x03;
         *n = 4;
      }
      else if( ucChar < 0xfe )
      {
         *pwc &= 0x01;
         *n = 5;
      }
   }
   return HB_TRUE;
}
//------------------------------------------------------------------------------------------------------------------
