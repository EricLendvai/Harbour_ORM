//Copyright (c) 2024 Eric Lendvai MIT License

#ifndef HB_ORM_BUILDVERSION
#define HB_ORM_BUILDVERSION "4.8"

#define HB_ORM_TRIGGERVERSION 2

#include "hb_el.ch"
#include "hbclass.ch"

#xtranslate CloseAlias(<cAlias>) => (select(<cAlias>))->(dbCloseArea())
#xtranslate GetTimeDeltaInMs(<DateTime1>,<DateTime2>) => (<DateTime2>-<DateTime1>)*(24*3600*1000)

#define HB_ORM_BACKENDTYPE_MARIADB     1
#define HB_ORM_BACKENDTYPE_MYSQL       2
#define HB_ORM_BACKENDTYPE_POSTGRESQL  3
#define HB_ORM_BACKENDTYPE_MSSQL       4

#define HB_ORM_ENGINETYPE_MYSQL       1
#define HB_ORM_ENGINETYPE_POSTGRESQL  2
#define HB_ORM_ENGINETYPE_MSSQL       3

#define HB_ORM_POSTGRESQL_CASE_INSENSITIVE  0
#define HB_ORM_POSTGRESQL_CASE_SENSITIVE    1
#define HB_ORM_POSTGRESQL_CASE_ALL_LOWER    2

#define HB_ORM_SCHEMA_FIELD "Fields"
#define HB_ORM_SCHEMA_INDEX "Indexes"

#define HB_ORM_SCHEMA_FIELD_USEDAS         "UsedAs"
#define HB_ORM_SCHEMA_FIELD_TYPE           "Type"
#define HB_ORM_SCHEMA_FIELD_ENUMNAME       "Enumeration"
#define HB_ORM_SCHEMA_FIELD_LENGTH         "Length"
#define HB_ORM_SCHEMA_FIELD_DECIMALS       "Scale"
#define HB_ORM_SCHEMA_FIELD_DEFAULT        "Default"
#define HB_ORM_SCHEMA_FIELD_NULLABLE       "Nullable"
#define HB_ORM_SCHEMA_FIELD_AUTOINCREMENT  "AutoIncrement"
#define HB_ORM_SCHEMA_FIELD_ARRAY          "Array"

#define HB_ORM_SCHEMA_INDEX_EXPRESSION      "Expression"
#define HB_ORM_SCHEMA_INDEX_UNIQUE          "Unique"
#define HB_ORM_SCHEMA_INDEX_ALGORITHM       "Algorithm"

#define HB_ORM_SCHEMA_MYSQL_OBJECT      "M"
#define HB_ORM_SCHEMA_POSTGRESQL_OBJECT "P"

#define PRIMARY_KEY_INFO_NAME 1
#define PRIMARY_KEY_INFO_TYPE 2


#define HB_ORM_MAX_EVENTID_SIZE 50

#define HB_ORM_GETFIELDINFO_NAMESPACE_NAME      "NameSpace"
#define HB_ORM_GETFIELDINFO_TABLENAME           "TableName"
#define HB_ORM_GETFIELDINFO_FIELDNAME           "FieldName"
#define HB_ORM_GETFIELDINFO_FIELDTYPE           "FieldType"
#define HB_ORM_GETFIELDINFO_FIELDLENGTH         "FieldLen"
#define HB_ORM_GETFIELDINFO_FIELDDECIMALS       "FieldDec"
#define HB_ORM_GETFIELDINFO_FIELDNULLABLE       "FieldNullable"
#define HB_ORM_GETFIELDINFO_FIELDAUTOINCREMENT  "FieldAutoIncrement"
#define HB_ORM_GETFIELDINFO_FIELDARRAY          "FieldArray"
#define HB_ORM_GETFIELDINFO_FIELDDEFAULT        "FieldDefault"

#define COMBINE_ACTION_UNION     1
#define COMBINE_ACTION_EXCEPT    2
#define COMBINE_ACTION_INTERSECT 3

#define POSTGRESQL_MAX_FOREIGN_KEY_NAME_LENGTH 63   //A PostgreSQL limitation, unless recompiled otherwise
#define POSTGRESQL_MAX_INDEX_NAME_LENGTH 63         //A PostgreSQL limitation, unless recompiled otherwise

#endif /* HB_ORM_BUILDVERSION */
