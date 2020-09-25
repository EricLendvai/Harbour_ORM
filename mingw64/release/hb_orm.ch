#include "hb_vfp.ch"

#include "hbclass.ch"

#xtranslate CloseAlias(<cAlias>) => (select(<cAlias>))->(dbCloseArea())
#xtranslate GetTimeDeltaInMs(<DateTime1>,<DateTime2>) => (<DateTime2>-<DateTime1>)*(24*3600*1000)

#define HB_ORM_BACKENDTYPE_MARIADB     1
#define HB_ORM_BACKENDTYPE_MYSQL       2
#define HB_ORM_BACKENDTYPE_POSTGRESQL  3

#define HB_ORM_ENGINETYPE_MYSQL       1
#define HB_ORM_ENGINETYPE_POSTGRESQL  2

