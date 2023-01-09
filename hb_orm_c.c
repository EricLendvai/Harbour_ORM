//Copyright (c) 2023 Eric Lendvai MIT License

#include "hbapi.h"
#include "hbapierr.h"
#include "hbapicdp.h"

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

// HB_BOOL xxhb_cdpUTF8ToU16NextChar( HB_UCHAR ucChar, int * n, HB_WCHAR * pwc )
// {

//    if( *n > 0 )
//    {
//       if( ( ucChar & 0xc0 ) != 0x80 )
//       {
//          *n = 0;
//          return HB_FALSE;
//       }
//       *pwc = ( *pwc << 6 ) | ( ucChar & 0x3f );
//       ( *n )--;
//       return HB_TRUE;
//    }


//    *n = 0;
//    *pwc = ucChar;
//    // *pwc &= 0x1f;

// return HB_TRUE;

   
//    if( ucChar >= 0xc0 )
//    {
//       if( ucChar < 0xe0 )
//       {
//          *pwc &= 0x1f;
//          *n = 1;
//       }
//       else if( ucChar < 0xf0 )
//       {
//          *pwc &= 0x0f;
//          *n = 2;
//       }
//       else if( ucChar < 0xf8 )
//       {
//          *pwc &= 0x07;
//          *n = 3;
//       }
//       else if( ucChar < 0xfc )
//       {
//          *pwc &= 0x03;
//          *n = 4;
//       }
//       else if( ucChar < 0xfe )
//       {
//          *pwc &= 0x01;
//          *n = 5;
//       }
//    }
//    return HB_TRUE;
// }


//hb_UTF8FastPeek(cText,nByteToStartFrom,@nUTF8Value,@nNumberOfBytesOfTheCharacter)
//Alternate method from hb_UTF8Peek. The second parameter is a byte position, not a UTF8 position. 
//hb_UTF8Peek can be very slow since it has to process a string from the beginning. This new function allow you to skip from a previous position.
//nUTF8Value is used to return the integer value of the UTF8 character, and nNumberOfBytesOfTheCharacter will receive the number of bytes the character is made out off.
// Returns True is valid, False if invalid position.
HB_FUNC( HB_UTF8FASTPEEK )
{
   HB_BOOL lResult = HB_FALSE;

   if (HB_ISCHAR(1) && HB_ISNUM(2) && HB_ISNUM(3) && HB_ISNUM(4) && HB_ISBYREF(3) && HB_ISBYREF(4))
   {
      PHB_ITEM pText      = hb_param(1, HB_IT_STRING);
      int nLengthOfText    = hb_itemGetCLen(pText) ;
      int nByteToStartFrom = hb_parni(2);  // 1 based since coming from Harbour Language

      if ((nByteToStartFrom >= 1) && (nByteToStartFrom <= nLengthOfText))
      {
         HB_WCHAR wc = (HB_WCHAR) 0;
         int n = 0;
         int nNumberOfBytesOfTheCharacter = 0;

         // const char * szText = hb_itemGetCPtr( pText );   // This will not work under Linux and seems to fail on long strings in Windows.
         const char * szText = hb_parc( 1 );

         nByteToStartFrom--;  // C is 0 based for string and array positions.

         do
         {
            if( hb_cdpUTF8ToU16NextChar( ( HB_UCHAR ) szText[ nByteToStartFrom ], &n, &wc ) )
            {
               ++nByteToStartFrom;
               if ((nNumberOfBytesOfTheCharacter == 0) && (n > 0))
                  nNumberOfBytesOfTheCharacter = n+1;
            }
            if( n == 0 )
               break;
               // return wc;
         }
         while( nByteToStartFrom < nLengthOfText );

         hb_storni(wc,3);
         hb_storni(nNumberOfBytesOfTheCharacter,4);
         
         lResult = HB_TRUE;
      }
      
      hb_retl(lResult);

   } else {
      hb_errRT_BASE_SubstR( EG_ARG, 3012, NULL, HB_ERR_FUNCNAME, HB_ERR_ARGS_BASEPARAMS );
   }
}
//=================================================================================================================
