#include "hbapi.h"
#include "hbapirdd.h"
#include "hbapierr.h"
#include "hbapiitm.h"
// #include "hbvm.h"
// #include "hbset.h"

HB_FUNC( FIELDPUTALLOWNULL )
{
    AREAP pArea = ( AREAP ) hb_rddGetCurrentWorkAreaPointer();

    if( pArea )
    {
        HB_USHORT uiIndex = ( HB_FIELDNO ) hb_parni( 1 );

        if( uiIndex > 0 )
        {
            PHB_ITEM pItem = hb_param( 2, HB_IT_ANY );
            if( pItem /*&& ! HB_IS_NIL( pItem ) */)
            {
                if( SELF_PUTVALUE( pArea, uiIndex, pItem ) == HB_SUCCESS )
                    hb_itemReturn( pItem );
            }
        }
    }
}
