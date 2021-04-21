//Copyright (c) 2021 Eric Lendvai MIT License

#ifndef HB_ORM_CH_
#define HB_ORM_CH_

#include "hb_vfp.ch"
#include "hbclass.ch"

#xtranslate CloseAlias(<cAlias>) => (select(<cAlias>))->(dbCloseArea())
#xtranslate GetTimeDeltaInMs(<DateTime1>,<DateTime2>) => (<DateTime2>-<DateTime1>)*(24*3600*1000)

#define HB_ORM_BACKENDTYPE_MARIADB     1
#define HB_ORM_BACKENDTYPE_MYSQL       2
#define HB_ORM_BACKENDTYPE_POSTGRESQL  3

#define HB_ORM_ENGINETYPE_MYSQL       1
#define HB_ORM_ENGINETYPE_POSTGRESQL  2

#define HB_ORM_POSTGRESQL_CASE_INSENSITIVE     0
#define HB_ORM_POSTGRESQL_CASE_SENSITIVE       1
#define HB_ORM_POSTGRESQL_CASE_ALL_LOWER       2

#define HB_ORM_SCHEMA_FIELD 1
#define HB_ORM_SCHEMA_INDEX 2

#define HB_ORM_SCHEMA_FIELD_BACKEND_TYPES  1
#define HB_ORM_SCHEMA_FIELD_TYPE           2
#define HB_ORM_SCHEMA_FIELD_LENGTH         3
#define HB_ORM_SCHEMA_FIELD_DECIMALS       4
#define HB_ORM_SCHEMA_FIELD_ATTRIBUTES     5

#define HB_ORM_SCHEMA_INDEX_BACKEND_TYPES   1
#define HB_ORM_SCHEMA_INDEX_EXPRESSION      2
#define HB_ORM_SCHEMA_INDEX_UNIQUE          3
#define HB_ORM_SCHEMA_INDEX_ALGORITHM       4

#define HB_ORM_SCHEMA_MYSQL_OBJECT      "M"
#define HB_ORM_SCHEMA_POSTGRESQL_OBJECT "P"

#define HB_ORM_MAX_EVENTID_SIZE 50

#endif /* HB_ORM_CH_ */
