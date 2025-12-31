//Copyright (c) 2024 Eric Lendvai MIT License

#ifdef _WIN32
#include <windows.h>
#endif

#include <hbapi.h>
#include <hbapierr.h>

// #include <hbapicdp.h>
// #include <hbapirdd.h>

#include <hbapiitm.h>

//Ensure HARBOUR_ROOT is set in launch.json
#include <hbrddsql.h>

#include <sql.h>
#include <sqlext.h>

//=================================================================================================================

HB_FUNC( HB_ORM_OUTPUTDEBUGSTRING )   // For Windows Only
{
#ifdef _WIN32
    OutputDebugString( hb_parc(1) );
#endif
}
//=================================================================================================================

// Following code left for reference purpose
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
typedef struct
{
   void * hEnv;
   void * hConn;
} SDDCONN;

// Following function provided by Antonio Linares in the conversation: https://groups.google.com/g/harbour-users/c/tFe2EgBfJyk
HB_FUNC( HB_ORM_ODBCAPIGETHANDLE )
{
   SQLBASEAREAP pArea = ( SQLBASEAREAP ) hb_rddGetCurrentWorkAreaPointer();
   SQLDDCONNECTION * pConnection = pArea->pConnection;

   hb_storptr( ( ( SDDCONN * ) pConnection->pSDDConn )->hConn, 1 );
}
//=================================================================================================================
//Following 4 functions provided by David Field in the conversation: https://groups.google.com/g/harbour-users/c/tFe2EgBfJyk
HB_FUNC( HB_ORM_ODBC_SQLSETCONNECTIONATTRIBUTE ) /* hDbc, nOption, uOption */
{
#if ODBCVER >= 0x0300
   hb_retni( SQLSetConnectAttr( ( SQLHDBC )  hb_parptr( 1 ), 
                                ( SQLINTEGER ) hb_parnl( 2 ),
                                HB_ISCHAR( 3 ) ? ( SQLPOINTER ) hb_parc( 3 ) : ( SQLPOINTER ) ( HB_PTRUINT ) hb_parnint( 3 ),
                                HB_ISCHAR( 3 ) ? ( SQLINTEGER ) hb_parclen( 3 ) : ( SQLINTEGER ) SQL_IS_INTEGER ) );
#else
   hb_retni( SQLSetConnectOption( ( SQLHDBC ) hb_parptr( 1 ), 
                                  ( SQLUSMALLINT ) hb_parni( 2 ),
                                  ( SQLULEN ) HB_ISCHAR( 3 ) ? ( SQLULEN ) hb_parc( 3 ) : hb_parnl( 3 ) ) );
#endif
}
//=================================================================================================================
HB_FUNC( HB_ORM_ODBC_SQLGETCONNECTIONATTRIBUTE ) /* hDbc, nOption, @cOption */
{
#if ODBCVER >= 0x0300
   SQLPOINTER buffer[ 512 ];
   SQLINTEGER lLen = 0;
   buffer[ 0 ] = '\0';
   hb_retni( SQLGetConnectAttr( ( SQLHDBC ) hb_parptr( 1 ),
                                ( SQLINTEGER ) hb_parnl( 2 ),
                                ( SQLPOINTER ) buffer,
                                ( SQLINTEGER ) sizeof( buffer ),
                                ( SQLINTEGER * ) &lLen ) );
   hb_storclen( ( char * ) buffer, lLen, 3 );
#else
   char buffer[ 512 ];
   buffer[ 0 ] = '\0';
   hb_retni( SQLGetConnectOption( ( SQLHDBC ) hb_parptr( 1 ),
                                  ( SQLSMALLINT ) hb_parni( 2 ),
                                  ( SQLPOINTER ) buffer ) );
   hb_storc( buffer, 3 );
#endif
}
//=================================================================================================================
HB_FUNC( HB_ORM_ODBC_SQLCOMMIT ) /* hDbc */
{
   hb_retni( SQLEndTran(  SQL_HANDLE_DBC , ( SQLHDBC ) hb_parptr( 1 ), SQL_COMMIT ) );
}
//=================================================================================================================
HB_FUNC( HB_ORM_ODBC_SQLROLLBACK ) /* hDbc */
{
   hb_retni( SQLEndTran(  SQL_HANDLE_DBC , ( SQLHDBC ) hb_parptr( 1 ), SQL_ROLLBACK ) );
}
//=================================================================================================================
//=================================================================================================================
//=================================================================================================================
