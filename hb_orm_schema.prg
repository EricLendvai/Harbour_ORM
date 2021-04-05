//Copyright (c) 2021 Eric Lendvai, MIT License

#include "hb_orm.ch"
#include "hb_vfp.ch"

#ifndef DONOTINCLUDE   //Will be defined by BuilLib.bat
#include "hb_orm_sqlconnect_class_definition.prg"
#endif

// RND Notes
// autoincrement fields are not null with no default.

//-----------------------------------------------------------------------------------------------------------------
method LoadSchema() class hb_orm_SQLConnect
local l_select := iif(used(),select(),0)
local l_SQLCommand
local l_SQLCommandFields  := ""
local l_SQLCommandIndexes := ""
local l_FieldType,l_FieldLen,l_FieldDec,l_FieldAllowNull,l_FieldAutoIncrement
local l_TableName,l_TableNameLast
local l_SchemaAndTableName,l_SchemaAndTableNameLast
local l_cIndexName,l_IndexDefinition,l_IndexExpression,l_IndexUnique,l_IndexType
local l_Schema_Fields  := {=>}
local l_Schema_Indexes := {=>}
local l_pos1,l_pos2,l_pos3,l_pos4
local l_LoadedCache

hb_HCaseMatch(l_Schema_Fields ,.f.)
hb_HCaseMatch(l_Schema_Indexes,.f.)
hb_HClear(::p_Schema)
hb_HCaseMatch(::p_Schema,.f.)

CloseAlias("hb_orm_sqlconnect_schema_fields")
CloseAlias("hb_orm_sqlconnect_schema_indexes")

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_SQLCommandFields  += [SELECT columns.table_name                 AS table_name,]
    l_SQLCommandFields  += [       columns.ordinal_position           AS field_position,]
    l_SQLCommandFields  += [       columns.column_name                AS field_name,]
    l_SQLCommandFields  += [       columns.data_type                  AS field_type,]
    l_SQLCommandFields  += [       columns.column_comment             AS field_comment,]
    l_SQLCommandFields  += [       columns.character_maximum_length   AS field_clength,]
    l_SQLCommandFields  += [       columns.numeric_precision          AS field_nlength,]
    l_SQLCommandFields  += [       columns.datetime_precision         AS field_tlength,]
    l_SQLCommandFields  += [       columns.numeric_scale              AS field_decimals,]
    l_SQLCommandFields  += [       (columns.is_nullable = 'YES')      AS field_nullable,]
    l_SQLCommandFields  += [       columns.column_default             AS field_default,]
    l_SQLCommandFields  += [       (columns.extra = 'auto_increment') AS field_identity_is,]
    l_SQLCommandFields  += [       upper(columns.table_name)          AS tag1]
    l_SQLCommandFields  += [ FROM information_schema.columns]
    l_SQLCommandFields  += [ WHERE columns.table_schema = ']+::p_Database+[']
    l_SQLCommandFields  += [ AND   lower(left(columns.table_name,11)) != 'schemacache']
    l_SQLCommandFields  += [ ORDER BY tag1,field_position]

    //Following fails to detect some removed fields. MySQL fails to remove previous table definitions.
    // SELECT tables.table_name                  AS table_name,
    //        columns.ordinal_position           AS field_position,
    //        columns.column_name                AS field_name,
    //        columns.data_type                  AS field_type,
    //        columns.column_comment             AS field_comment,
    //        columns.character_maximum_length   AS field_clength,
    //        columns.numeric_precision          AS field_nlength,
    //        columns.datetime_precision         AS field_tlength,
    //        columns.numeric_scale              AS field_decimals,
    //        (columns.is_nullable = 'YES')      AS field_nullable,
    //        columns.column_default             AS field_default,
    //        (columns.extra = 'auto_increment') AS field_identity_is,
    //        upper(tables.table_name)           AS tag1
    //  FROM information_schema.tables  AS tables
    //  JOIN information_schema.columns AS columns ON columns.TABLE_NAME = tables.TABLE_NAME
    //  WHERE tables.table_schema    = 'test004'
    //  AND   tables.table_type      = 'BASE TABLE'
    //  AND   lower(left(tables.table_name,11)) != 'schemacache'
    //  ORDER BY tag1,field_position


    //Getting rid of the join on information_schema.tables solved the refresh of fields being deleted.
    // SELECT columns.table_name                 AS table_name,
    //        columns.ordinal_position           AS field_position,
    //        columns.column_name                AS field_name,
    //        columns.data_type                  AS field_type,
    //        columns.column_comment             AS field_comment,
    //        columns.character_maximum_length   AS field_clength,
    //        columns.numeric_precision          AS field_nlength,
    //        columns.datetime_precision         AS field_tlength,
    //        columns.numeric_scale              AS field_decimals,
    //        (columns.is_nullable = 'YES')      AS field_nullable,
    //        columns.column_default             AS field_default,
    //        (columns.extra = 'auto_increment') AS field_identity_is,
    //        upper(columns.table_name)          AS tag1
    //  FROM information_schema.columns
    //  WHERE columns.table_schema = 'test004'
    //  AND   lower(left(columns.table_name,11)) != 'schemacache'
    //  ORDER BY tag1,field_position


    l_SQLCommandIndexes += [SELECT table_name,]
    l_SQLCommandIndexes += [       index_name,]
    l_SQLCommandIndexes += [       group_concat(column_name order by seq_in_index) AS index_columns,]
    l_SQLCommandIndexes += [       index_type,]
    l_SQLCommandIndexes += [       CASE non_unique]
    l_SQLCommandIndexes += [            WHEN 1 then 0]
    l_SQLCommandIndexes += [            ELSE 1]
    l_SQLCommandIndexes += [            END AS is_unique]
    l_SQLCommandIndexes += [ FROM information_schema.statistics]
    l_SQLCommandIndexes += [ WHERE table_schema NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')]
    l_SQLCommandIndexes += [ AND   index_schema = ']+::p_Database+[']
    l_SQLCommandIndexes += [ AND   lower(left(table_name,11)) != 'schemacache']
    l_SQLCommandIndexes += [ GROUP BY table_name,index_name]
    l_SQLCommandIndexes += [ ORDER BY index_schema,table_name,index_name;]


    if !::SQLExec(l_SQLCommandFields,"hb_orm_sqlconnect_schema_fields")
        ::p_ErrorMessage := [Failed SQL for hb_orm_sqlconnect_schema_fields.]
        // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQLCommandFields+[ -> ]+::p_ErrorMessage)
    elseif !::SQLExec(l_SQLCommandIndexes,"hb_orm_sqlconnect_schema_indexes")
        ::p_ErrorMessage := [Failed SQL for hb_orm_sqlconnect_schema_indexes.]
    else
        if used("hb_orm_sqlconnect_schema_fields") .and. used("hb_orm_sqlconnect_schema_indexes")
            select hb_orm_sqlconnect_schema_fields
            if Reccount() > 0
                l_TableNameLast := Trim(hb_orm_sqlconnect_schema_fields->table_name)
                hb_HClear(l_Schema_Fields)
                scan all
                    l_TableName := Trim(hb_orm_sqlconnect_schema_fields->table_name)
                    if !(l_TableName == l_TableNameLast)  // Method to for an exact not equal
                        ::p_Schema[l_TableNameLast] := {hb_hClone(l_Schema_Fields),NIL}    //{Table Fields, Table Indexes}
                        hb_HClear(l_Schema_Fields)
                        l_TableNameLast := l_TableName
                    endif

                    switch trim(field->field_type)
                    case "int"
                        l_FieldType          := "I"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "bigint"
                        l_FieldType          := "IB"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "decimal"
                        if left(field->field_comment,5) == "money"
                            l_FieldType      := "Y"
                            l_FieldLen       := 0
                            l_FieldDec       := 0
                        else
                            l_FieldType      := "N"
                            l_FieldLen       := field->field_nlength
                            l_FieldDec       := field->field_decimals
                        endif
                        exit
                    case "char"
                        l_FieldType          := "C"
                        l_FieldLen           := field->field_clength
                        l_FieldDec           := 0
                        exit
                    case "varchar"
                        l_FieldType          := "CV"
                        l_FieldLen           := field->field_clength
                        l_FieldDec           := 0
                        exit
                    case "binary"
                        l_FieldType          := "B"
                        l_FieldLen           := field->field_clength
                        l_FieldDec           := 0
                        exit
                    case "varbinary"
                        l_FieldType          := "BV"
                        l_FieldLen           := field->field_clength
                        l_FieldDec           := 0
                        exit
                    case "longtext"
                        l_FieldType          := "M"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "longblob"
                        l_FieldType          := "R"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "tinyint"  //Used as Boolean
                        l_FieldType          := "L"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "date"
                        l_FieldType          := "D"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "time"  //Time Only part of datetime     MySQL does not make the difference between with our without time zone  "TOZ" -> "TO"
                        if left(field->field_comment,13) == "with timezone"
                            l_FieldType      := "TOZ"
                        else
                            l_FieldType      := "TO"
                        endif
                        l_FieldLen           := 0
                        l_FieldDec           := field->field_tlength
                        exit
                    case "timestamp"
                        l_FieldType          := "DTZ"
                        l_FieldLen           := 0
                        l_FieldDec           := field->field_tlength
                        exit
                    case "datetime"
                        l_FieldType          := "DT"        // Same as "T"
                        l_FieldLen           := 0
                        l_FieldDec           := field->field_tlength
                        exit
                    // case "bit"   //bit mask
                    //     l_FieldType          := "BT"
                    //     l_FieldLen           := field->field_nlength
                    //     l_FieldDec           := 0
                    //     exit
                    otherwise
                        l_FieldType          := "?"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                    endswitch

                    l_FieldAllowNull     := (field->field_nullable == 1)
                    l_FieldAutoIncrement := (field->field_identity_is == 1)
                    //{"I",,,,.t.}

                    l_Schema_Fields[trim(field->field_Name)] := {,;
                                                                 l_FieldType,;
                                                                 l_FieldLen,;
                                                                 l_FieldDec,;
                                                                 iif(l_FieldAllowNull,"N","")+iif(l_FieldAutoIncrement,"+","")}

                endscan

                ::p_Schema[l_TableNameLast] := {hb_hClone(l_Schema_Fields),NIL}    //{Table Fields, Table Indexes}
                hb_HClear(l_Schema_Fields)



                //Since Indexes could only exists for an existing table we simply assign to a ::p_Schema[][HB_ORM_SCHEMA_INDEX] cell
                select hb_orm_sqlconnect_schema_indexes
                if Reccount() > 0
                    l_TableNameLast := Trim(hb_orm_sqlconnect_schema_indexes->table_name)
                    hb_HClear(l_Schema_Indexes)

                    scan all
                        l_TableName := Trim(hb_orm_sqlconnect_schema_indexes->table_name)
                        if !(l_TableName == l_TableNameLast)
                            if len(l_Schema_Indexes) > 0
                                ::p_Schema[l_TableNameLast][HB_ORM_SCHEMA_INDEX] := hb_hClone(l_Schema_Indexes)
                                hb_HClear(l_Schema_Indexes)
                            else
                                ::p_Schema[l_TableNameLast][HB_ORM_SCHEMA_INDEX] := NIL
                            endif
                            l_TableNameLast := l_TableName
                        endif

                        l_cIndexName := lower(trim(field->index_name))
                        if left(l_cIndexName,len(l_TableName)+1) == lower(l_TableName)+"_" .and. right(l_cIndexName,4) == "_idx"  // only record indexes maintained by hb_orm
                            l_cIndexName      := hb_orm_RootIndexName(l_TableName,l_cIndexName)

                            l_IndexExpression := trim(field->index_columns)
                            if !(lower(l_IndexExpression) == lower(::p_PKFN))   // No reason to record the index of the PRIMARY key
                                l_IndexUnique     := (field->is_unique == 1)
                                l_IndexType       := field->index_type
                                l_Schema_Indexes[l_cIndexName] := {,l_IndexExpression,l_IndexUnique,l_IndexType}
                            endif
                        endif

                    endscan

                    if len(l_Schema_Indexes) > 0
                        ::p_Schema[l_TableNameLast][HB_ORM_SCHEMA_INDEX] := hb_hClone(l_Schema_Indexes)
                        hb_HClear(l_Schema_Indexes)
                    else
                        ::p_Schema[l_TableNameLast][HB_ORM_SCHEMA_INDEX] := NIL
                    endif

                endif

            endif

            // scan all for lower(trim(field->table_name)) == l_TableName_lower
            // HB_ORM_OUTPUTDEBUGSTRING("[Harbour] "+lower(trim(field->field_Name)) )
            // HB_ORM_OUTPUTDEBUGSTRING("[Harbour] "+lower(trim(field->field_type)) )

        endif

    endif


case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_LoadedCache := .f.

    //Find out if there is cached schema
    TEXT TO VAR l_SQLCommand
SELECT pk
 FROM  hborm."SchemaCacheLog"
 WHERE cachedschema
 ORDER BY pk DESC
 LIMIT 1
    ENDTEXT

    if !(::PostgreSQLHBORMSchemaName == "hborm")
        l_SQLCommand := strtran(l_SQLCommand,"hborm",::FormatIdentifier(::PostgreSQLHBORMSchemaName))
    endif

    if ::SQLExec(l_SQLCommand,"SchemaCacheLogLast")
        if SchemaCacheLogLast->(reccount()) > 0

            l_SQLCommandFields  := [SELECT schema_name,]
            l_SQLCommandFields  += [       table_name,]
            l_SQLCommandFields  += [       field_position,]
            l_SQLCommandFields  += [       field_name,]
            l_SQLCommandFields  += [       field_type,]
            l_SQLCommandFields  += [       field_clength,]
            l_SQLCommandFields  += [       field_nlength,]
            l_SQLCommandFields  += [       field_tlength,]
            l_SQLCommandFields  += [       field_decimals,]
            l_SQLCommandFields  += [       field_nullable,]
            l_SQLCommandFields  += [       field_default,]
            l_SQLCommandFields  += [       field_identity_is,]
            l_SQLCommandFields  += [       tag1,]
            l_SQLCommandFields  += [       tag2]
            l_SQLCommandFields  += [ FROM ]+::FormatIdentifier(::PostgreSQLHBORMSchemaName)+[."SchemaCacheFields_]+trans(SchemaCacheLogLast->pk)+["]
            l_SQLCommandFields  += [ ORDER BY tag1,tag2,field_position]

            l_SQLCommandIndexes := [SELECT schema_name,]
            l_SQLCommandIndexes += [       table_name,]
            l_SQLCommandIndexes += [       index_name,]
            l_SQLCommandIndexes += [       index_definition,]
            l_SQLCommandIndexes += [       tag1,]
            l_SQLCommandIndexes += [       tag2]
            l_SQLCommandIndexes += [ FROM ]+::FormatIdentifier(::PostgreSQLHBORMSchemaName)+[."SchemaCacheIndexes_]+trans(SchemaCacheLogLast->pk)+["]
            l_SQLCommandIndexes += [ ORDER BY tag1,tag2,index_name]

            if ::SQLExec(l_SQLCommandFields,"hb_orm_sqlconnect_schema_fields") .and. ::SQLExec(l_SQLCommandIndexes,"hb_orm_sqlconnect_schema_indexes")
                l_LoadedCache := .t.
            else
                //Failed to get the file. It is probably missing
                CloseAlias("hb_orm_sqlconnect_schema_fields")
                CloseAlias("hb_orm_sqlconnect_schema_indexes")
                ::UpdateSchemaCache(.t.)
                //Try to load again, since called the UpdateSchemaCache(.t.) above
                if ::SQLExec(l_SQLCommandFields,"hb_orm_sqlconnect_schema_fields") .and. ::SQLExec(l_SQLCommandIndexes,"hb_orm_sqlconnect_schema_indexes")
                    l_LoadedCache := .t.
                endif
            endif
        endif
    endif

    if !l_LoadedCache
        //The following is WAY TO SLOW on Large catalogs. The joining on the "tables" is the main performance problem.
        // l_SQLCommandFields  := [SELECT tables.table_name                AS table_name,]
        // l_SQLCommandFields  += [       columns.ordinal_position         AS field_position,]
        // l_SQLCommandFields  += [       columns.column_name              AS field_name,]
        // l_SQLCommandFields  += [       columns.data_type                AS field_type,]
        // l_SQLCommandFields  += [       columns.character_maximum_length AS field_clength,]
        // l_SQLCommandFields  += [       columns.numeric_precision        AS field_nlength,]
        // l_SQLCommandFields  += [       columns.datetime_precision       AS field_tlength,]
        // l_SQLCommandFields  += [       columns.numeric_scale            AS field_decimals,]
        // l_SQLCommandFields  += [       (columns.is_nullable = 'YES')    AS field_nullable,]
        // l_SQLCommandFields  += [       columns.column_default           AS field_default,]
        // l_SQLCommandFields  += [       (columns.is_identity = 'YES')    AS field_identity_is,]
        // l_SQLCommandFields  += [       upper(tables.table_name)         AS tag1]
        // l_SQLCommandFields  += [ FROM information_schema.tables  AS tables]
        // l_SQLCommandFields  += [ JOIN information_schema.columns AS columns ON columns.TABLE_NAME = tables.TABLE_NAME]
        // l_SQLCommandFields  += [ WHERE tables.table_schema    = ']+::p_SchemaName+[']
        // l_SQLCommandFields  += [ AND   tables.table_type      = 'BASE TABLE']
        // l_SQLCommandFields  += [ AND   lower(left(tables.table_name,11)) != 'schemacache']
        // l_SQLCommandFields  += [ ORDER BY tag1,field_position]

        // l_SQLCommandFields  := [SELECT columns.table_name               AS table_name,]
        // l_SQLCommandFields  += [       columns.ordinal_position         AS field_position,]
        // l_SQLCommandFields  += [       columns.column_name              AS field_name,]
        // l_SQLCommandFields  += [       columns.data_type                AS field_type,]
        // l_SQLCommandFields  += [       columns.character_maximum_length AS field_clength,]
        // l_SQLCommandFields  += [       columns.numeric_precision        AS field_nlength,]
        // l_SQLCommandFields  += [       columns.datetime_precision       AS field_tlength,]
        // l_SQLCommandFields  += [       columns.numeric_scale            AS field_decimals,]
        // l_SQLCommandFields  += [       (columns.is_nullable = 'YES')    AS field_nullable,]
        // l_SQLCommandFields  += [       columns.column_default           AS field_default,]
        // l_SQLCommandFields  += [       (columns.is_identity = 'YES')    AS field_identity_is,]
        // l_SQLCommandFields  += [       upper(columns.table_name)        AS tag1]
        // l_SQLCommandFields  += [ FROM information_schema.columns]
        // l_SQLCommandFields  += [ WHERE columns.table_schema    = ']+::p_SchemaName+[']
        // l_SQLCommandFields  += [ AND   lower(left(columns.table_name,11)) != 'schemacache']  // This should not even be needed since the Schema* files are in a different postgreSQL schema folder.
        // l_SQLCommandFields  += [ ORDER BY tag1,field_position]

        // l_SQLCommandIndexes := [SELECT pg_indexes.tablename        AS table_name,]
        // l_SQLCommandIndexes += [       pg_indexes.indexname        AS index_name,]
        // l_SQLCommandIndexes += [       pg_indexes.indexdef         AS index_definition,]
        // l_SQLCommandIndexes += [       upper(pg_indexes.tablename) AS tag1]
        // l_SQLCommandIndexes += [ FROM pg_indexes]
        // l_SQLCommandIndexes += [ WHERE pg_indexes.schemaname = ']+::p_SchemaName+[']
        // l_SQLCommandIndexes += [ AND   lower(left(pg_indexes.tablename,11)) != 'schemacache']
        // l_SQLCommandIndexes += [ ORDER BY tag1,index_name]

        l_SQLCommandFields  := [SELECT columns.table_schema             AS schema_name,]
        l_SQLCommandFields  += [       columns.table_name               AS table_name,]
        l_SQLCommandFields  += [       columns.ordinal_position         AS field_position,]
        l_SQLCommandFields  += [       columns.column_name              AS field_name,]
        l_SQLCommandFields  += [       columns.data_type                AS field_type,]
        l_SQLCommandFields  += [       columns.character_maximum_length AS field_clength,]
        l_SQLCommandFields  += [       columns.numeric_precision        AS field_nlength,]
        l_SQLCommandFields  += [       columns.datetime_precision       AS field_tlength,]
        l_SQLCommandFields  += [       columns.numeric_scale            AS field_decimals,]
        l_SQLCommandFields  += [       (columns.is_nullable = 'YES')    AS field_nullable,]
        l_SQLCommandFields  += [       columns.column_default           AS field_default,]
        l_SQLCommandFields  += [       (columns.is_identity = 'YES')    AS field_identity_is,]
        l_SQLCommandFields  += [       upper(columns.table_schema)      AS tag1,]
        l_SQLCommandFields  += [       upper(columns.table_name)        AS tag2]
        l_SQLCommandFields  += [ FROM information_schema.columns]
        l_SQLCommandFields  += [ WHERE NOT (lower(left(columns.table_name,11)) = 'schemacache' OR lower(columns.table_schema) in ('information_schema','pg_catalog'))]
        l_SQLCommandFields  += [ ORDER BY tag1,tag2,field_position]


        l_SQLCommandIndexes := [SELECT pg_indexes.schemaname        AS schema_name,]
        l_SQLCommandIndexes += [       pg_indexes.tablename         AS table_name,]
        l_SQLCommandIndexes += [       pg_indexes.indexname         AS index_name,]
        l_SQLCommandIndexes += [       pg_indexes.indexdef          AS index_definition,]
        l_SQLCommandIndexes += [       upper(pg_indexes.schemaname) AS tag1,]
        l_SQLCommandIndexes += [       upper(pg_indexes.tablename)  AS tag2]
        l_SQLCommandIndexes += [ FROM pg_indexes]
        l_SQLCommandIndexes += [ WHERE NOT (lower(left(pg_indexes.tablename,11)) = 'schemacache' OR lower(pg_indexes.schemaname) in ('information_schema','pg_catalog'))]
        l_SQLCommandIndexes += [ ORDER BY tag1,tag2,index_name]

    endif

    if !l_LoadedCache .and. !::SQLExec(l_SQLCommandFields,"hb_orm_sqlconnect_schema_fields")
        ::p_ErrorMessage := [Failed SQL for hb_orm_sqlconnect_schema_fields.]
        // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQLCommandFields+[ -> ]+::p_ErrorMessage)

    elseif !l_LoadedCache .and. !::SQLExec(l_SQLCommandIndexes,"hb_orm_sqlconnect_schema_indexes")
        ::p_ErrorMessage := [Failed SQL for hb_orm_sqlconnect_schema_indexes.]

    else
        if used("hb_orm_sqlconnect_schema_fields") .and. used("hb_orm_sqlconnect_schema_indexes")

// select hb_orm_sqlconnect_schema_indexes
// ExportTableToHtmlFile("hb_orm_sqlconnect_schema_indexes","d:\SchemaIndexes.html","Cache",,,.t.)

            select hb_orm_sqlconnect_schema_fields

// if l_UsingCachedSchema
//     ExportTableToHtmlFile("hb_orm_sqlconnect_schema_fields","d:\310\SchemaFields_cache.html","Cache",,,.t.)
// else
//     ExportTableToHtmlFile("hb_orm_sqlconnect_schema_fields","d:\310\SchemaFields_live.html","No Cache",,,.t.)
// endif

// altd()

// set filter to field->table_name = "table003"
// ExportTableToHtmlFile("hb_orm_sqlconnect_schema_fields","PostgreSQL_information_schema.html","PostgreSQL Schema",,25)
// set filter to

            if Reccount() > 0
                l_SchemaAndTableNameLast := Trim(hb_orm_sqlconnect_schema_fields->schema_name)+"."+Trim(hb_orm_sqlconnect_schema_fields->table_name)
                hb_HClear(l_Schema_Fields)

                scan all
                    l_SchemaAndTableName := Trim(hb_orm_sqlconnect_schema_fields->schema_name)+"."+Trim(hb_orm_sqlconnect_schema_fields->table_name)
                    if !(l_SchemaAndTableName == l_SchemaAndTableNameLast)
                        ::p_Schema[l_SchemaAndTableNameLast] := {hb_hClone(l_Schema_Fields),NIL}    //{Table Fields (HB_ORM_SCHEMA_FIELD), Table Indexes (HB_ORM_SCHEMA_INDEX)}
                        hb_HClear(l_Schema_Fields)
                        l_SchemaAndTableNameLast := l_SchemaAndTableName
                    endif
                    switch trim(field->field_type)
                    case "integer"
                        l_FieldType          := "I"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "bigint"
                        l_FieldType          := "IB"    // Integer Big
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "numeric"
                        l_FieldType          := "N"
                        l_FieldLen           := field->field_nlength
                        l_FieldDec           := field->field_decimals
                        exit
                    case "character"
                        l_FieldType          := "C"
                        l_FieldLen           := field->field_clength
                        l_FieldDec           := 0
                        exit
                    case "character varying"
                        l_FieldType          := "CV"
                        l_FieldLen           := field->field_clength
                        l_FieldDec           := 0
                        exit
                    case "bit"
                        l_FieldType          := "B"
                        l_FieldLen           := field->field_clength
                        l_FieldDec           := 0
                        exit
                    case "bit varying"
                        l_FieldType          := "BV"
                        l_FieldLen           := field->field_clength
                        l_FieldDec           := 0
                        exit
                    case "text"
                        l_FieldType          := "M"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "bytea"  //Raw Binary
                        l_FieldType          := "R"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "boolean"
                        l_FieldType          := "L"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "date"
                        l_FieldType          := "D"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "time"                           //Time Only With Time Zone Conversion
                    case "time with time zone"            //Time Only With Time Zone Conversion
                        l_FieldType          := "TOZ"
                        l_FieldLen           := 0
                        l_FieldDec           := field->field_tlength
                        exit
                    case "time without time zone"         //Time Only Without Time Zone Conversion
                        l_FieldType          := "TO"
                        l_FieldLen           := 0
                        l_FieldDec           := field->field_tlength
                        exit
                    case "timestamp"                     //date and time With Time Zone Conversion
                    case "timestamp with time zone"      //date and time With Time Zone Conversion
                        l_FieldType          := "DTZ"
                        l_FieldLen           := 0
                        l_FieldDec           := field->field_tlength
                        exit
                    case "timestamp without time zone"   //date and time Without Time Zone Conversion
                        l_FieldType          := "DT"     //Is DBF equivalent for "T"
                        l_FieldLen           := 0
                        l_FieldDec           := field->field_tlength
                        exit
                    case "money"
                        l_FieldType          := "Y"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    otherwise
                        l_FieldType          := "?"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                    endswitch

                    l_FieldAllowNull     := (field->field_nullable == "1")
                    l_FieldAutoIncrement := (field->field_identity_is == "1")                    //{"I",,,,.t.}

                    l_Schema_Fields[trim(field->field_Name)] := {,l_FieldType,l_FieldLen,l_FieldDec,iif(l_FieldAllowNull,"N","")+iif(l_FieldAutoIncrement,"+","")}

                endscan

                ::p_Schema[l_SchemaAndTableNameLast] := {hb_hClone(l_Schema_Fields),NIL}    //{Table Fields (HB_ORM_SCHEMA_FIELD), Table Indexes (HB_ORM_SCHEMA_INDEX)}
                hb_HClear(l_Schema_Fields)

                //Since Indexes could only exists for an existing table we simply assign to a ::p_Schema[][HB_ORM_SCHEMA_INDEX] cell
                select hb_orm_sqlconnect_schema_indexes
                if Reccount() > 0
                    l_SchemaAndTableNameLast := Trim(hb_orm_sqlconnect_schema_indexes->schema_name)+"."+Trim(hb_orm_sqlconnect_schema_indexes->table_name)
                    hb_HClear(l_Schema_Indexes)

                    scan all
                        l_SchemaAndTableName := Trim(hb_orm_sqlconnect_schema_indexes->schema_name)+"."+Trim(hb_orm_sqlconnect_schema_indexes->table_name)
                        if !(l_SchemaAndTableName == l_SchemaAndTableNameLast)
                            if len(l_Schema_Indexes) > 0
                                ::p_Schema[l_SchemaAndTableNameLast][HB_ORM_SCHEMA_INDEX] := hb_hClone(l_Schema_Indexes)
                                hb_HClear(l_Schema_Indexes)
                            else
                                ::p_Schema[l_SchemaAndTableNameLast][HB_ORM_SCHEMA_INDEX] := NIL
                            endif
                            l_SchemaAndTableNameLast := l_SchemaAndTableName
                        endif

                        l_cIndexName := lower(trim(field->index_name))
                        if left(l_cIndexName,len(l_SchemaAndTableName)+1) == lower(strtran(l_SchemaAndTableName,".","_"))+"_" .and. right(l_cIndexName,4) == "_idx"
                            l_cIndexName      := hb_orm_RootIndexName(l_SchemaAndTableName,l_cIndexName)
                            
                            l_IndexDefinition := field->index_definition
                            l_pos1 := hb_ati(" USING ",l_IndexDefinition)
                            if l_pos1 > 0
                                l_pos2 := hb_at(" ",l_IndexDefinition,l_pos1+1)
                                l_pos3 := hb_at("(",l_IndexDefinition,l_pos1)
                                l_pos4 := hb_rat(")",l_IndexDefinition,l_pos1)
                                l_IndexExpression := substr(l_IndexDefinition,l_pos3+1,l_pos4-l_pos3-1)

                                if !(lower(l_IndexExpression) == lower(::p_PKFN))   // No reason to record the index of the PRIMARY key
                                    l_IndexUnique     := ("UNIQUE INDEX" $ l_IndexDefinition)
                                    l_IndexType       := upper(substr(l_IndexDefinition,l_pos2+1,l_pos3-l_pos2-2))
                                    l_Schema_Indexes[l_cIndexName] := {,l_IndexExpression,l_IndexUnique,l_IndexType}
                                endif

                            endif
                        endif

                    endscan
                    if len(l_Schema_Indexes) > 0
                        ::p_Schema[l_SchemaAndTableNameLast][HB_ORM_SCHEMA_INDEX] := hb_hClone(l_Schema_Indexes)
                        hb_HClear(l_Schema_Indexes)
                    else
                        ::p_Schema[l_SchemaAndTableNameLast][HB_ORM_SCHEMA_INDEX] := NIL
                    endif

                endif

            endif

            // scan all for lower(trim(field->table_name)) == l_SchemaAndTableName_lower
            // HB_ORM_OUTPUTDEBUGSTRING("[Harbour] "+lower(trim(field->field_Name)) )
            // HB_ORM_OUTPUTDEBUGSTRING("[Harbour] "+lower(trim(field->field_type)) )

        endif

    endif

endcase

CloseAlias("hb_orm_sqlconnect_schema_fields")
CloseAlias("hb_orm_sqlconnect_schema_indexes")

select (l_select)

// altd()

return NIL
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
method GenerateMigrateSchemaScript(par_hSchemaDefinition) class hb_orm_SQLConnect

local l_hTableDefinition,l_cTableName,l_aTableDefinition
local l_hFieldDefinition,l_cFieldName,l_aFieldDefinitions,l_aFieldDefinition
local l_hIndexDefinition,l_cIndexName,l_aIndexDefinitions,l_aIndexDefinition
local l_hFields,l_hIndexes
local l_iArrayPos
local l_aCurrentTableDefinition
local l_aCurrentFieldDefinition
local l_aCurrentIndexDefinition
local l_FieldType,       l_FieldLen,       l_FieldDec,       l_FieldAttributes,       l_FieldAllowNull,       l_FieldAutoIncrement
local l_CurrentFieldType,l_CurrentFieldLen,l_CurrentFieldDec,l_CurrentFieldAttributes,l_CurrentFieldAllowNull,l_CurrentFieldAutoIncrement
local l_MatchingFieldDefinition
local l_cCurrentSchemaName,l_cSchemaName
local l_SQLScript := ""
local l_SQLScriptFieldChanges,l_SQLScriptFieldChangesCycle1,l_SQLScriptFieldChangesCycle2
local l_cSchemaAndTableName
local l_FormattedTableName
local l_BackendType := ""
local l_iPos
local l_hListOfSchemaName := {=>}
local l_hSchemaName
local l_SQLScriptCreateSchemaName := ""

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cCurrentSchemaName := ""
    l_BackendType        := "M"
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cCurrentSchemaName := ::GetCurrentSchemaName()
    l_BackendType        := "P"
endcase

if ::UpdateSchemaCache()
    ::LoadSchema()
endif

for each l_hTableDefinition in par_hSchemaDefinition
    l_cSchemaAndTableName := l_hTableDefinition:__enumKey()
    l_aTableDefinition    := l_hTableDefinition:__enumValue()

    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_cSchemaName := ""
        l_cTableName  := l_cSchemaAndTableName
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        l_iPos := at(".",l_cSchemaAndTableName)
        if empty(l_iPos)
            l_cSchemaName         := l_cCurrentSchemaName
            l_cTableName          := l_cSchemaAndTableName
            l_cSchemaAndTableName := l_cSchemaName+"."+l_cTableName
        else
            l_cSchemaName := left(l_cSchemaAndTableName,l_iPos-1)
            l_cTableName  := substr(l_cSchemaAndTableName,l_iPos+1)
        endif
        l_hListOfSchemaName[l_cSchemaName] := NIL  //Will use the Hash as a Set of values
    endcase

    l_aCurrentTableDefinition := hb_HGetDef(::p_Schema,l_cSchemaAndTableName,NIL)

    l_hFields  := l_aTableDefinition[HB_ORM_SCHEMA_FIELD]
    l_hIndexes := l_aTableDefinition[HB_ORM_SCHEMA_INDEX]

    if hb_IsNIL(l_aCurrentTableDefinition)
        // Table does not exist in the current catalog
        hb_orm_SendToDebugView("Add Table: "+l_cSchemaAndTableName)
        l_SQLScript += ::AddTable(l_cSchemaName,l_cTableName,l_hFields,.f. /*par_lAlsoRemoveFields*/)
        
        // Add all the indexes
        if !hb_IsNIL(l_hIndexes)
            for each l_hIndexDefinition in l_hIndexes
                l_cIndexName        := lower(l_hIndexDefinition:__enumKey())
                l_aIndexDefinitions := l_hIndexDefinition:__enumValue()
                
                if ValType(l_aIndexDefinitions[1]) == "A"
                    l_iArrayPos        := len(l_aIndexDefinitions)
                    l_aIndexDefinition := l_aIndexDefinitions[l_iArrayPos]
                else
                    l_iArrayPos        := 1
                    l_aIndexDefinition := l_aIndexDefinitions
                endif
                do while l_iArrayPos > 0

                    if l_BackendType $ hb_DefaultValue(l_aIndexDefinition[HB_ORM_SCHEMA_INDEX_BACKEND_TYPES],"MP")
                        if !(lower(l_aIndexDefinition[HB_ORM_SCHEMA_INDEX_EXPRESSION]) == lower(::p_PKFN))   // Don't Create and index, since PRIMARY will already do so. This should not happen since no loaded in p_Schema to start with. But this method accepts any p_Schema hash arrays.
                            l_SQLScript += ::AddIndex(l_cSchemaName,l_cTableName,l_hFields,l_cIndexName,l_aIndexDefinition)  //Passing l_hFields to help with index expressions
                        endif
                    endif
                    
                    l_iArrayPos -= 1
                    if l_iArrayPos > 0
                        l_aIndexDefinition := l_aIndexDefinitions[l_iArrayPos]
                    endif
                enddo
                
            endfor
        endif

    else
        // Found the table in the current ::p_Schema, know lets test all the fields are also there and matching
        // Test Every Fields to see if structure must be updated.

        l_SQLScriptFieldChangesCycle1 := ""
        l_SQLScriptFieldChangesCycle2 := ""

        for each l_hFieldDefinition in l_hFields   //l_aTableDefinition[1]
            l_cFieldName              := l_hFieldDefinition:__enumKey()
            l_aFieldDefinitions       := l_hFieldDefinition:__enumValue()

            if ValType(l_aFieldDefinitions[1]) == "A"
                l_iArrayPos        := len(l_aFieldDefinitions)
                l_aFieldDefinition := l_aFieldDefinitions[l_iArrayPos]
            else
                l_iArrayPos        := 1
                l_aFieldDefinition := l_aFieldDefinitions
            endif
            do while l_iArrayPos > 0

                //Only process fields that are valid for all backends or at least the current backend
                if l_BackendType $ hb_DefaultValue(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_BACKEND_TYPES],"MP")
                    l_FieldType                 := iif(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE] == "T","DT",l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE])
                    l_FieldLen                  := iif(len(l_aFieldDefinition) < 2, 0 ,hb_defaultValue(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_LENGTH]        , 0 ))
                    l_FieldDec                  := iif(len(l_aFieldDefinition) < 3, 0 ,hb_defaultValue(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_DECIMALS]      , 0 ))
                    l_FieldAttributes           := iif(len(l_aFieldDefinition) < 4, "",hb_defaultValue(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_ATTRIBUTES]    , ""))
                    l_FieldAllowNull            := ("N" $ l_FieldAttributes)
                    l_FieldAutoIncrement        := ("+" $ l_FieldAttributes)

                    if lower(l_cFieldName) == lower(::p_PKFN)
                        l_FieldAutoIncrement := .t.
                    endif
                    if l_FieldAutoIncrement .and. empty(el_inlist(l_FieldType,"I","IB"))  //Only those fields types may be flagged as Auto-Increment
                        l_FieldAutoIncrement := .f.
                    endif
                    if l_FieldAutoIncrement .and. l_FieldAllowNull  //Auto-Increment fields may not be null (and not have a default)
                        l_FieldAllowNull := .f.
                    endif

                    l_FieldAttributes := iif(l_FieldAllowNull,"N","")+iif(l_FieldAutoIncrement,"+","")

                    l_aCurrentFieldDefinition := hb_HGetDef(::p_Schema[l_cSchemaAndTableName][HB_ORM_SCHEMA_FIELD],l_cFieldName,NIL)
                    if hb_IsNIL(l_aCurrentFieldDefinition)
                        //Missing Field
                        hb_orm_SendToDebugView("Table: "+l_cSchemaAndTableName+" Add Field: "+l_cFieldName)
                        l_SQLScriptFieldChangesCycle1 += ::AddField(l_cSchemaName,;
                                                                    l_cTableName,;
                                                                    l_cFieldName,;
                                                                    {,l_FieldType,l_FieldLen,l_FieldDec,l_FieldAttributes})
                    else
                        //Compare the field definition using arrays l_aCurrentFieldDefinition and l_aFieldDefinition

                        l_CurrentFieldType          := iif(l_aCurrentFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE] == "T","DT",l_aCurrentFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE])
                        l_CurrentFieldLen           := iif(len(l_aCurrentFieldDefinition) < 2, 0 ,hb_defaultValue(l_aCurrentFieldDefinition[HB_ORM_SCHEMA_FIELD_LENGTH]        , 0 ))
                        l_CurrentFieldDec           := iif(len(l_aCurrentFieldDefinition) < 3, 0 ,hb_defaultValue(l_aCurrentFieldDefinition[HB_ORM_SCHEMA_FIELD_DECIMALS]      , 0 ))
                        l_CurrentFieldAttributes    := iif(len(l_aCurrentFieldDefinition) < 4, "",hb_defaultValue(l_aCurrentFieldDefinition[HB_ORM_SCHEMA_FIELD_ATTRIBUTES]    , ""))
                        l_CurrentFieldAllowNull     := ("N" $ l_CurrentFieldAttributes)
                        l_CurrentFieldAutoIncrement := ("+" $ l_CurrentFieldAttributes)

                        if l_CurrentFieldAutoIncrement .and. empty(el_inlist(l_CurrentFieldType,"I","IB"))  //Only those fields types may be flagged as Auto-Increment
                            l_CurrentFieldAutoIncrement := .f.
                        endif
                        if l_CurrentFieldAutoIncrement .and. l_CurrentFieldAllowNull  //Auto-Increment fields may not be null (and not have a default)
                            l_CurrentFieldAllowNull := .f.
                        endif

                        l_CurrentFieldAttributes := iif(l_CurrentFieldAllowNull,"N","")+iif(l_CurrentFieldAutoIncrement,"+","")

                        l_MatchingFieldDefinition := .t.
                        do case
                        case !(l_FieldType == l_CurrentFieldType)   // Field Type is always defined.  !(==) is a method to deal with SET EXACT being OFF by default.
                            l_MatchingFieldDefinition := .f.
                        case !empty(el_inlist(l_FieldType,"I","IB","M","R","L","D","Y"))  //Field type with no length
                        case empty(el_inlist(l_FieldType,"TOZ","TO","DTZ","DT")) .and. l_FieldLen <> l_CurrentFieldLen   //Ignore Length matching for datetime and time fields
                            l_MatchingFieldDefinition := .f.
                        case !empty(el_inlist(l_FieldType,"C","CV","B","BV"))  //Field type with a length but no decimal
                        case l_FieldDec  <> l_CurrentFieldDec
                            l_MatchingFieldDefinition := .f.
                        endcase

                        if l_MatchingFieldDefinition  // Should still test on nullable and incremental
                            do case
                            // Test on AllowNull
                            case l_FieldAllowNull <> l_CurrentFieldAllowNull
                                l_MatchingFieldDefinition := .f.
                            // Test on AutoIncrement
                            case l_FieldAutoIncrement <> l_CurrentFieldAutoIncrement
                                l_MatchingFieldDefinition := .f.
                            endcase
                        endif

                        if !l_MatchingFieldDefinition
                            hb_orm_SendToDebugView("Table: "+l_cSchemaAndTableName+" Field: "+l_cFieldName+"  Mismatch")
                            l_SQLScriptFieldChanges := ::UpdateField(l_cSchemaName,;
                                                                    l_cTableName,;
                                                                    l_cFieldName,;
                                                                    {,l_FieldType,l_FieldLen,l_FieldDec,l_FieldAttributes},;
                                                                    {,l_CurrentFieldType,l_CurrentFieldLen,l_CurrentFieldDec,l_CurrentFieldAttributes})
                            l_SQLScriptFieldChangesCycle1 += l_SQLScriptFieldChanges[1]
                            l_SQLScriptFieldChangesCycle2 += l_SQLScriptFieldChanges[2]
                        endif

                    endif
                endif

                l_iArrayPos -= 1
                if l_iArrayPos > 0
                    l_aFieldDefinition := l_aFieldDefinitions[l_iArrayPos]
                endif
            enddo

        endfor

        if !empty(l_SQLScriptFieldChangesCycle1) .or. !empty(l_SQLScriptFieldChangesCycle2)
            do case
            case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
                l_FormattedTableName := ::FormatIdentifier(l_cTableName)
            case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
                l_FormattedTableName := ::FormatIdentifier(l_cSchemaAndTableName)
            endcase
            if !empty(l_SQLScriptFieldChangesCycle1)
                l_SQLScript += [ALTER TABLE ]+l_FormattedTableName+[ ]+substr(l_SQLScriptFieldChangesCycle1,2)+[;]+CRLF   //Drop the leading "," in l_SQLScriptFieldChangesCycle1
            endif
            if !empty(l_SQLScriptFieldChangesCycle2)
                l_SQLScript += [ALTER TABLE ]+l_FormattedTableName+[ ]+substr(l_SQLScriptFieldChangesCycle2,2)+[;]+CRLF   //Drop the leading "," in l_SQLScriptFieldChangesCycle2
            endif
        endif

        if !hb_IsNIL(l_hIndexes)
            for each l_hIndexDefinition in l_hIndexes
                l_cIndexName              := hb_orm_RootIndexName(l_cSchemaAndTableName,l_hIndexDefinition:__enumKey())
                l_aIndexDefinitions       := l_hIndexDefinition:__enumValue()

                if ValType(l_aIndexDefinitions[1]) == "A"
                    l_iArrayPos        := len(l_aIndexDefinitions)
                    l_aIndexDefinition := l_aIndexDefinitions[l_iArrayPos]
                else
                    l_iArrayPos        := 1
                    l_aIndexDefinition := l_aIndexDefinitions
                endif
                do while l_iArrayPos > 0
                    
                    if l_BackendType $ hb_DefaultValue(l_aIndexDefinition[HB_ORM_SCHEMA_INDEX_BACKEND_TYPES],"MP")
                        if !(lower(l_aIndexDefinition[HB_ORM_SCHEMA_INDEX_EXPRESSION]) == lower(::p_PKFN))   // Don't Create and index, since PRIMARY will already do so.
                            
                            if hb_IsNIL(::p_Schema[l_cSchemaAndTableName][HB_ORM_SCHEMA_INDEX])
                                l_aCurrentIndexDefinition := NIL
                            else
                                l_aCurrentIndexDefinition := hb_HGetDef(::p_Schema[l_cSchemaAndTableName][HB_ORM_SCHEMA_INDEX],l_cIndexName,NIL)
                            endif
                            if hb_IsNIL(l_aCurrentIndexDefinition)
                                //Missing Index
                                hb_orm_SendToDebugView("Table: "+l_cSchemaAndTableName+" Add Index: "+l_cIndexName)
                                l_SQLScript += ::AddIndex(l_cSchemaName,l_cTableName,l_hFields,l_cIndexName,l_aIndexDefinition)  //Passing l_hFields to help with index expressions
                            else
                                // _M_ Compare the index definition
                            endif

                        endif
                    endif

                    l_iArrayPos -= 1
                    if l_iArrayPos > 0
                        l_aIndexDefinition := l_aIndexDefinitions[l_iArrayPos]
                    endif
                enddo

            endfor
        endif

    endif
endfor

if !empty(l_SQLScript)
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_SQLScript := [USE ]+::FormatIdentifier(::GetDatabase())+[;]+CRLF+l_SQLScript

    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        //When you get a connection to PostgreSQL it is always to a particular database. To access a different database, you must get a new connection.

        for each l_hSchemaName in l_hListOfSchemaName
            l_SQLScriptCreateSchemaName += [CREATE SCHEMA IF NOT EXISTS ]+::FormatIdentifier(l_hSchemaName:__enumKey())+[;]+CRLF
        endfor

        if !empty(l_SQLScriptCreateSchemaName)
            l_SQLScript := l_SQLScriptCreateSchemaName+l_SQLScript
        endif
    endcase
endif

return l_SQLScript
//-----------------------------------------------------------------------------------------------------------------
method MigrateSchema(par_hSchemaDefinition) class hb_orm_SQLConnect
local l_SQLScript
local l_Result := 0   // 0 = Nothing Migrated, 1 = Migrated, -1 = Error Migrating
local l_LastError := ""
local aInstructions,cStatement
local nCounter := 0


l_SQLScript := ::GenerateMigrateSchemaScript(par_hSchemaDefinition)

if !empty(l_SQLScript)
    l_Result := 1
    aInstructions := hb_ATokens(l_SQLScript,.t.)
    for each cStatement in aInstructions
        if !empty(cStatement)
            nCounter++
            if ::SQLExec(cStatement)
                // hb_orm_SendToDebugView("Updated Table Structure.")
            else
// altd()
                l_LastError := ::GetSQLExecErrorMessage()
                hb_orm_SendToDebugView("Failed MigrateSchema on instruction "+Trans(nCounter)+".   Error Text="+l_LastError)
                l_Result := -1
                exit
            endif
        endif
    endfor
    ::UpdateSchemaCache()
    ::LoadSchema()
endif

::UpdateORMSchemaTableNumber()  // Will call this routine even if no tables where modified.

return {l_Result,l_SQLScript,l_LastError}
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
method AddTable(par_cSchemaName,par_cTableName,par_hStructure) class hb_orm_SQLConnect                 // Fix if needed a single file structure
local l_aField
local l_FieldName
local l_FieldStructures,l_FieldStructure
local l_SQLCommand := ""
local l_SQLFields := ""
local l_FieldType
local l_FieldDec
local l_FieldLen
local l_FieldAttributes
local l_FieldAllowNull
local l_FieldAutoIncrement
local l_NumberOfFieldDefinitionParameters
local l_Default
local l_SQLExtra := ""
local l_FormattedTableName
local l_BackendType := ""
local l_iArrayPos

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_FormattedTableName := ::FormatIdentifier(par_cTableName)
    l_BackendType        := "M"
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_FormattedTableName := ::FormatIdentifier(par_cSchemaName+"."+par_cTableName)
    l_BackendType        := "P"
endcase

// l_aStructure := {=>}
// l_aStructure["key"]        := {"I",,}
// l_aStructure["p_table001"] := {"I",,}
// l_aStructure["city"]       := {"C",50,0}

for each l_aField in par_hStructure
    l_FieldName          := l_aField:__enumKey()
    l_FieldStructures    := l_aField:__enumValue()

    if ValType(l_FieldStructures[1]) == "A"
        l_iArrayPos        := len(l_FieldStructures)
        l_FieldStructure   := l_FieldStructures[l_iArrayPos]
    else
        l_iArrayPos        := 1
        l_FieldStructure   := l_FieldStructures
    endif
    do while l_iArrayPos > 0

        if l_BackendType $ hb_DefaultValue(l_FieldStructure[HB_ORM_SCHEMA_FIELD_BACKEND_TYPES],"MP")
            l_NumberOfFieldDefinitionParameters := len(l_FieldStructure)
            l_FieldType          := l_FieldStructure[HB_ORM_SCHEMA_FIELD_TYPE]
            l_FieldLen           := iif(l_NumberOfFieldDefinitionParameters < 2, 0 ,hb_DefaultValue(l_FieldStructure[HB_ORM_SCHEMA_FIELD_LENGTH]        , 0 ))
            l_FieldDec           := iif(l_NumberOfFieldDefinitionParameters < 3, 0 ,hb_DefaultValue(l_FieldStructure[HB_ORM_SCHEMA_FIELD_DECIMALS]      , 0 ))
            l_FieldAttributes    := iif(l_NumberOfFieldDefinitionParameters < 4, "",hb_DefaultValue(l_FieldStructure[HB_ORM_SCHEMA_FIELD_ATTRIBUTES]    , ""))
            l_FieldAllowNull     := ("N" $ l_FieldAttributes)
            l_FieldAutoIncrement := ("+" $ l_FieldAttributes)

            if lower(l_FieldName) == lower(::p_PKFN)
                l_FieldAutoIncrement := .t.
            endif
            if l_FieldAutoIncrement .and. empty(el_inlist(l_FieldType,"I","IB"))  //Only those fields types may be flagged as Auto-Increment
                l_FieldAutoIncrement := .f.
            endif
            if l_FieldAutoIncrement .and. l_FieldAllowNull  //Auto-Increment fields may not be null (and not have a default)
                l_FieldAllowNull := .f.
            endif

            // l_FieldAttributes := iif(l_FieldAllowNull,"N","")+iif(l_FieldAutoIncrement,"+","")  Not needed since the AddTable will also deal with all the fields and not call AddField()

            if !empty(l_SQLFields)
                l_SQLFields += ","
            endif

            l_SQLFields += ::FormatIdentifier(l_FieldName) + [ ]

            do case
            case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
                do case
                case !empty(el_inlist(l_FieldType,"I","IB","N"))
                    do case
                    case l_FieldType == "I"
                        l_SQLFields += [INT]
                    case l_FieldType == "IB"
                        l_SQLFields += [BIGINT]
                    case l_FieldType == "N"
                        l_SQLFields += [DECIMAL(]+trans(l_FieldLen)+[,]+trans(l_FieldDec)+[)]
                        if l_FieldAutoIncrement
                            l_FieldAutoIncrement := .f.
                            hb_orm_SendToDebugView("May not make numeric field auto-increment. Table: "+par_cTableName+" - Field: "+l_FieldName)
                        endif
                    endcase

                    do case
                    // case lower(l_FieldName) == lower(::p_PKFN)
                    //     l_SQLFields += [ NOT NULL AUTO_INCREMENT]
                    //     l_SQLExtra  += [,PRIMARY KEY (]+::FormatIdentifier(l_FieldName)+[) USING BTREE]
                    //     // l_SQLFields += [ NOT NULL AUTO_INCREMENT]
                    case l_FieldAutoIncrement
                        l_SQLFields += [ NOT NULL AUTO_INCREMENT]
                        l_SQLExtra  += [,PRIMARY KEY (]+::FormatIdentifier(l_FieldName)+[) USING BTREE]
                    case l_FieldAllowNull
                        l_SQLFields += [ NULL]
                    otherwise
                        l_SQLFields += [ NOT NULL DEFAULT 0]
                    endcase

                case !empty(el_inlist(l_FieldType,"C","CV","B","BV","M","R"))
                    do case
                    case l_FieldType == "C"
                        l_SQLFields += [CHAR(]+trans(l_FieldLen)+[)]
                    case l_FieldType == "CV"
                        l_SQLFields += [VARCHAR]+iif(empty(l_FieldLen),[],[(]+trans(l_FieldLen)+[)])
                    case l_FieldType == "B"
                        l_SQLFields += [BINARY(]+trans(l_FieldLen)+[)]
                    case l_FieldType == "BV"
                        l_SQLFields += [VARBINARY]+iif(empty(l_FieldLen),[],[(]+trans(l_FieldLen)+[)])
                    case l_FieldType == "M"
                        l_SQLFields += [LONGTEXT]
                    case l_FieldType == "R"
                        l_SQLFields += [LONGBLOB]
                    endcase

                    if l_FieldAllowNull
                        l_SQLFields += [ NULL]
                    else
                        l_SQLFields += [ NOT NULL DEFAULT '']
                    endif

                case l_FieldType == "L"
                    l_SQLFields += [TINYINT(1)]
                    if l_FieldAllowNull
                        l_SQLFields += [ NULL]
                    else
                        l_SQLFields += [ NOT NULL DEFAULT 0]
                    endif
                    
                case !empty(el_inlist(l_FieldType,"D","TOZ","TO","DTZ","T","DT"))
                    do case
                    case l_FieldType == "D"
                        l_SQLFields += [DATE]
                        l_Default   := ['0000-00-00']
                    case l_FieldType == "TOZ"
                        if vfp_between(l_FieldDec,0,6)
                            l_SQLFields += [TIME(]+trans(l_FieldDec)+[) COMMENT 'with timezone']
                        else
                            l_SQLFields += [TIME COMMENT 'with timezone']
                        endif
                        l_Default   := ['00:00:00']
                    case l_FieldType == "TO"
                        if vfp_between(l_FieldDec,0,6)
                            l_SQLFields += [TIME(]+trans(l_FieldDec)+[)]
                        else
                            l_SQLFields += [TIME]
                        endif
                        l_Default   := ['00:00:00']
                    case l_FieldType == "DTZ"
                        if vfp_between(l_FieldDec,0,6)
                            l_SQLFields += [TIMESTAMP(]+trans(l_FieldDec)+[)]
                        else
                            l_SQLFields += [TIMESTAMP]
                        endif
                        l_Default   := ['0000-00-00 00:00:00']
                    case l_FieldType == "DT" .or. l_FieldType == "T"
                        if vfp_between(l_FieldDec,0,6)
                            l_SQLFields += [DATETIME(]+trans(l_FieldDec)+[)]
                        else
                            l_SQLFields += [DATETIME]
                        endif
                        l_Default   := ['0000-00-00 00:00:00']
                    endcase

                    if l_FieldAllowNull
                        l_SQLFields += [ NULL]
                    else
                        l_SQLFields += [ NOT NULL DEFAULT ]+l_Default
                    endif

                // case l_FieldType == "TS"
                //     l_SQLFields += [TIMESTAMP NOT NULL DEFAULT current_timestamp]
                    
                case l_FieldType == "Y"
                    l_SQLFields += [DECIMAL(13,4) COMMENT 'money']
                    if l_FieldAllowNull
                        l_SQLFields += [ NULL]
                    else
                        l_SQLFields += [ NOT NULL DEFAULT 0]
                    endif
                    
                otherwise
                    
                endcase

            case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
                do case
                case !empty(el_inlist(l_FieldType,"I","IB","N"))
                    do case
                    case l_FieldType == "I"
                        l_SQLFields += [integer]
                    case l_FieldType == "IB"
                        l_SQLFields += [bigint]
                    case l_FieldType == "N"
                        l_SQLFields += [numeric(]+trans(l_FieldLen)+[,]+trans(l_FieldDec)+[)]
                        if l_FieldAutoIncrement
                            l_FieldAutoIncrement := .f.
                            hb_orm_SendToDebugView("May not make numeric field auto-increment. Table: "+par_cTableName+" - Field: "+l_FieldName)
                        endif
                    endcase

                    do case
                    // case lower(l_FieldName) == lower(::p_PKFN)
                    //     l_SQLFields += [ NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 ), PRIMARY KEY (]+::FormatIdentifier(l_FieldName)+[)]
                    case l_FieldAutoIncrement
                        // l_SQLFields += [ NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 )]
                        l_SQLFields += [ NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 ), PRIMARY KEY (]+::FormatIdentifier(l_FieldName)+[)]
                    case l_FieldAllowNull
                    otherwise
                        l_SQLFields += [ NOT NULL DEFAULT 0]
                    endcase

                case !empty(el_inlist(l_FieldType,"C","CV","B","BV","M","R"))
                    do case
                    case l_FieldType == "C"
                        l_SQLFields += [character(]+trans(l_FieldLen)+[)]
                    case l_FieldType == "CV"
                        l_SQLFields += [character varying]+iif(empty(l_FieldLen),[],[(]+trans(l_FieldLen)+[)])
                    case l_FieldType == "B"
                        l_SQLFields += [bit(]+trans(l_FieldLen)+[)]
                    case l_FieldType == "BV"
                        l_SQLFields += [bit varying]+iif(empty(l_FieldLen),[],[(]+trans(l_FieldLen)+[)])
                    case l_FieldType == "M"
                        l_SQLFields += [text]
                    case l_FieldType == "R"
                        l_SQLFields += [bytea]
                    endcase

                    if !l_FieldAllowNull
                        l_SQLFields += [ NOT NULL DEFAULT '']
                    endif

                case l_FieldType == "L"
                    l_SQLFields += [boolean]
                    if !l_FieldAllowNull
                        l_SQLFields += [ NOT NULL DEFAULT FALSE]
                    endif
                    
                case !empty(el_inlist(l_FieldType,"D","TOZ","TO","DTZ","T","DT"))
                    do case
                    case l_FieldType == "D"
                        l_SQLFields += [date]
                    case l_FieldType == "TOZ"
                        if vfp_between(l_FieldDec,0,6)
                            l_SQLFields += [time(]+trans(l_FieldDec)+[) with time zone]
                        else
                            l_SQLFields += [time with time zone]
                        endif
                    case l_FieldType == "TO"
                        if vfp_between(l_FieldDec,0,6)
                            l_SQLFields += [time(]+trans(l_FieldDec)+[) without time zone]
                        else
                            l_SQLFields += [time without time zone]
                        endif
                    case l_FieldType == "DTZ"
                        if vfp_between(l_FieldDec,0,6)
                            l_SQLFields += [timestamp(]+trans(l_FieldDec)+[) with time zone]
                        else
                            l_SQLFields += [timestamp with time zone]
                        endif
                    case l_FieldType == "DT" .or. l_FieldType == "T"
                        if vfp_between(l_FieldDec,0,6)
                            l_SQLFields += [timestamp(]+trans(l_FieldDec)+[) without time zone]
                        else
                            l_SQLFields += [timestamp without time zone]
                        endif
                    endcase

                    if !l_FieldAllowNull
                        l_SQLFields += [ NOT NULL DEFAULT '-infinity']
                    endif

                case l_FieldType == "Y"
                    l_SQLFields += [money]
                    if !l_FieldAllowNull
                        l_SQLFields += [ NOT NULL DEFAULT 0]
                    endif
                    
                otherwise
                    
                endcase

            endcase
        endif

        l_iArrayPos -= 1
        if l_iArrayPos > 0
            l_FieldStructure := l_FieldStructures[l_iArrayPos]
        endif
    enddo

endfor

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_SQLCommand := [CREATE TABLE ]+l_FormattedTableName+[ (] + l_SQLFields + l_SQLExtra
    l_SQLCommand += [) ENGINE=InnoDB COLLATE='utf8_general_ci';]+CRLF

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_SQLCommand := [CREATE TABLE ]+l_FormattedTableName+[ (] + l_SQLFields
    l_SQLCommand += [);]+CRLF

endcase

return l_SQLCommand
//-----------------------------------------------------------------------------------------------------------------
method UpdateField(par_cSchemaName,par_cTableName,par_cFieldName,par_aFieldDefinition,par_aCurrentFieldDefinition) class hb_orm_SQLConnect
// Due to a bug in MySQL engine of the "ALTER TABLE" command cannot mix "CHANGE COLUMN" and "ALTER COLUMN" options. Therefore separating those in 2 Cycles
local l_SQLCommandCycle1 := ""
local l_SQLCommandCycle2 := ""
local l_FieldType,       l_FieldLen,       l_FieldDec,       l_FieldAttributes,       l_FieldAllowNull,       l_FieldAutoIncrement
local                                                        l_CurrentFieldAttributes,l_CurrentFieldAllowNull,l_CurrentFieldAutoIncrement
local l_FormattedFieldName := ::FormatIdentifier(par_cFieldName)
local l_Default

l_FieldType                 := par_aFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE]
l_FieldLen                  := par_aFieldDefinition[HB_ORM_SCHEMA_FIELD_LENGTH]
l_FieldDec                  := par_aFieldDefinition[HB_ORM_SCHEMA_FIELD_DECIMALS]
l_FieldAttributes           := par_aFieldDefinition[HB_ORM_SCHEMA_FIELD_ATTRIBUTES]
l_FieldAllowNull            := ("N" $ l_FieldAttributes)
l_FieldAutoIncrement        := ("+" $ l_FieldAttributes)

l_CurrentFieldAttributes    := par_aCurrentFieldDefinition[HB_ORM_SCHEMA_FIELD_ATTRIBUTES]
l_CurrentFieldAllowNull     := ("N" $ l_CurrentFieldAttributes)
l_CurrentFieldAutoIncrement := ("+" $ l_CurrentFieldAttributes)

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    // MySQL has issues of DROP DEFAULT before a field is set to allow NULL
    l_SQLCommandCycle2 += [,CHANGE COLUMN ]+l_FormattedFieldName+[ ]+l_FormattedFieldName+[ ]

    do case
    case !empty(el_inlist(l_FieldType,"I","IB","N"))
        do case
        case l_FieldType == "I"
            l_SQLCommandCycle2 += [INT]
        case l_FieldType == "IB"
            l_SQLCommandCycle2 += [BIGINT]
        case l_FieldType == "N"
            l_SQLCommandCycle2 += [DECIMAL(]+trans(l_FieldLen)+[,]+trans(l_FieldDec)+[)]
            if l_FieldAutoIncrement
                l_FieldAutoIncrement := .f.
                hb_orm_SendToDebugView("May not make numeric field auto-increment. Table: "+par_cTableName+" - Field: "+par_cFieldName)
            endif
        endcase

        do case
        case l_FieldAutoIncrement
            l_SQLCommandCycle2 += [ NOT NULL AUTO_INCREMENT]
            
            // if lower(par_cFieldName) == lower(::p_PKFN)
                l_SQLCommandCycle2 += [,ADD PRIMARY KEY (]+l_FormattedFieldName+[)]
            // endif
        case l_FieldAllowNull
            l_SQLCommandCycle2 += [ NULL]
            // if !l_CurrentFieldAllowNull     // Does not create a problem to always set this property
                l_SQLCommandCycle1 += [,ALTER COLUMN ]+l_FormattedFieldName+[ DROP DEFAULT]
            // endif
        otherwise
            //do not allow NULL
            l_SQLCommandCycle2 += [ NOT NULL]
            l_SQLCommandCycle1 += [,ALTER COLUMN ]+l_FormattedFieldName+[ SET DEFAULT 0]
        endcase
        
    case !empty(el_inlist(l_FieldType,"C","CV","B","BV","M","R"))
        do case
        case l_FieldType == "C"
            l_SQLCommandCycle2 += [CHAR(]+trans(l_FieldLen)+[)]
        case l_FieldType == "CV"
            l_SQLCommandCycle2 += [VARCHAR]+iif(empty(l_FieldLen),[],[(]+trans(l_FieldLen)+[)])
        case l_FieldType == "B"
            l_SQLCommandCycle2 += [BINARY(]+trans(l_FieldLen)+[)]
        case l_FieldType == "BV"
            l_SQLCommandCycle2 += [VARBINARY]+iif(empty(l_FieldLen),[],[(]+trans(l_FieldLen)+[)])
        case l_FieldType == "M"
            l_SQLCommandCycle2 += [LONGTEXT]
        case l_FieldType == "R"
            l_SQLCommandCycle2 += [LONGBLOB]
        endcase

        if l_FieldAllowNull
            l_SQLCommandCycle2 += [ NULL]
            l_SQLCommandCycle1 += [,ALTER COLUMN ]+l_FormattedFieldName+[ DROP DEFAULT]
        else
            l_SQLCommandCycle2 += [ NOT NULL]
            l_SQLCommandCycle1 += [,ALTER COLUMN ]+l_FormattedFieldName+[ SET DEFAULT '']
        endif

    case l_FieldType == "L"
        l_SQLCommandCycle2 += [TINYINT(1)]

        if l_FieldAllowNull
            l_SQLCommandCycle2 += [ NULL]
            l_SQLCommandCycle1 += [,ALTER COLUMN ]+l_FormattedFieldName+[ DROP DEFAULT]
        else
            l_SQLCommandCycle2 += [ NOT NULL]
            l_SQLCommandCycle1 += [,ALTER COLUMN ]+l_FormattedFieldName+[ SET DEFAULT 0]
        endif
        
    case !empty(el_inlist(l_FieldType,"D","TOZ","TO","DTZ","T","DT"))
        do case
        case l_FieldType == "D"
            l_SQLCommandCycle2 += [DATE]
            l_Default    := ['0000-00-00']
        case l_FieldType == "TOZ"
            if vfp_between(l_FieldDec,0,6)
                l_SQLCommandCycle2 += [TIME(]+trans(l_FieldDec)+[) COMMENT 'with timezone']
            else
                l_SQLCommandCycle2 += [TIME COMMENT 'with timezone']
            endif
            l_Default    := ['00:00:00']
        case l_FieldType == "TO"
            if vfp_between(l_FieldDec,0,6)
                l_SQLCommandCycle2 += [TIME(]+trans(l_FieldDec)+[)]
            else
                l_SQLCommandCycle2 += [TIME]
            endif
            l_Default    := ['00:00:00']
        case l_FieldType == "DTZ"
            if vfp_between(l_FieldDec,0,6)
                l_SQLCommandCycle2 += [TIMESTAMP(]+trans(l_FieldDec)+[)]
            else
                l_SQLCommandCycle2 += [TIMESTAMP]
            endif
            l_Default    := ['0000-00-00 00:00:00']
        case l_FieldType == "DT" .or. l_FieldType == "T"
            if vfp_between(l_FieldDec,0,6)
                l_SQLCommandCycle2 += [DATETIME(]+trans(l_FieldDec)+[)]
            else
                l_SQLCommandCycle2 += [DATETIME]
            endif
            l_Default    := ['0000-00-00 00:00:00']
        endcase

        if l_FieldAllowNull
            l_SQLCommandCycle2 += [ NULL]
            l_SQLCommandCycle1 += [,ALTER COLUMN ]+l_FormattedFieldName+[ DROP DEFAULT]
        else
            l_SQLCommandCycle2 += [ NOT NULL]
            l_SQLCommandCycle1 += [,ALTER COLUMN ]+l_FormattedFieldName+[ SET DEFAULT ]+l_Default
        endif

    case l_FieldType == "Y"
        l_SQLCommandCycle2 += [DECIMAL(13,4) COMMENT 'money']
        if l_FieldAllowNull
            l_SQLCommandCycle2 += [ NULL]
            l_SQLCommandCycle1 += [,ALTER COLUMN ]+l_FormattedFieldName+[ DROP DEFAULT]
        else
            l_SQLCommandCycle2 += [ NOT NULL]
            l_SQLCommandCycle1 += [,ALTER COLUMN ]+l_FormattedFieldName+[ SET DEFAULT 0]
        endif

    otherwise
        
    endcase


case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_SQLCommandCycle1 += [,ALTER COLUMN ]+l_FormattedFieldName+[ ]

    do case
    case !empty(el_inlist(l_FieldType,"I","IB","N"))
        do case
        case l_FieldType == "I"
            l_SQLCommandCycle1 += [TYPE integer]
        case l_FieldType == "IB"
            l_SQLCommandCycle1 += [TYPE bigint]
        case l_FieldType == "N"
            l_SQLCommandCycle1 += [TYPE numeric(]+trans(l_FieldLen)+[,]+trans(l_FieldDec)+[)]
            if l_FieldAutoIncrement
                l_FieldAutoIncrement := .f.
                hb_orm_SendToDebugView("May not make numeric field auto-increment. Table: "+par_cSchemaName+"."+par_cTableName+" - Field: "+par_cFieldName)
            endif
        endcase

        if l_FieldAutoIncrement .or. l_CurrentFieldAutoIncrement
            do case
            case l_FieldAutoIncrement = l_CurrentFieldAutoIncrement
            case l_FieldAutoIncrement // Make it Auto-Incremental
                l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ DROP DEFAULT]
                l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ SET NOT NULL]
                l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ ADD GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 )]
            otherwise    // Stop Auto-Incremental
                l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ DROP IDENTITY]
            endcase
        endif

        if !l_FieldAutoIncrement
            do case
            case l_FieldAllowNull = l_CurrentFieldAllowNull
            case l_FieldAllowNull
                //Was NOT NULL
                if !l_FieldAutoIncrement
                    l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ DROP DEFAULT]
                endif
                l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ DROP NOT NULL]
            otherwise    // Stop NULL
                if !l_FieldAutoIncrement
                    l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ SET DEFAULT 0]
                endif
                l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ SET NOT NULL]
            endcase
        endif

        // if lower(par_cFieldName) == lower(::p_PKFN) .or. l_FieldAutoIncrement
        if l_FieldAutoIncrement
            // Will always name the constraints in lower case
            l_SQLCommandCycle1 += [,ADD CONSTRAINT ]+lower(par_cTableName)+[_pkey PRIMARY KEY (]+::FormatIdentifier(par_cFieldName)+[)]
        endif

    case !empty(el_inlist(l_FieldType,"C","CV","B","BV","M","R"))
        do case
        case l_FieldType == "C"
            l_SQLCommandCycle1 += [TYPE character(]+trans(l_FieldLen)+[)]
        case l_FieldType == "CV"
            l_SQLCommandCycle1 += [TYPE character varying]+iif(empty(l_FieldLen),[],[(]+trans(l_FieldLen)+[)])
        case l_FieldType == "B"
            l_SQLCommandCycle1 += [TYPE bit(]+trans(l_FieldLen)+[)]
        case l_FieldType == "BV"
            l_SQLCommandCycle1 += [TYPE bit varying]+iif(empty(l_FieldLen),[],[(]+trans(l_FieldLen)+[)])
        case l_FieldType == "M"
            l_SQLCommandCycle1 += [TYPE text]
        case l_FieldType == "R"
            l_SQLCommandCycle1 += [TYPE bytea]
        endcase

        do case
        case l_FieldAllowNull = l_CurrentFieldAllowNull
        case l_FieldAllowNull
            //Was NOT NULL
            l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ DROP DEFAULT]
            l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ DROP NOT NULL]
        otherwise    // Stop NULL
            l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ SET DEFAULT '']
            l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ SET NOT NULL]
        endcase

    case l_FieldType == "L"
        l_SQLCommandCycle1 += [TYPE boolean]

        do case
        case l_FieldAllowNull = l_CurrentFieldAllowNull
        case l_FieldAllowNull
            //Was NOT NULL
            l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ DROP DEFAULT]
            l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ DROP NOT NULL]
        otherwise    // Stop NULL
            l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ SET DEFAULT FALSE]
            l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ SET NOT NULL]
        endcase

    case !empty(el_inlist(l_FieldType,"D","TOZ","TO","DTZ","T","DT"))
        do case
        case l_FieldType == "D"
            l_SQLCommandCycle1 += [TYPE date]
        case l_FieldType == "TOZ"
            if vfp_between(l_FieldDec,0,6)
                l_SQLCommandCycle1 += [TYPE time(]+trans(l_FieldDec)+[) with time zone]
            else
                l_SQLCommandCycle1 += [TYPE time with time zone]
            endif
        case l_FieldType == "TO"
            if vfp_between(l_FieldDec,0,6)
                l_SQLCommandCycle1 += [TYPE time(]+trans(l_FieldDec)+[) without time zone]
            else
                l_SQLCommandCycle1 += [TYPE time without time zone]
            endif
        case l_FieldType == "DTZ"
            if vfp_between(l_FieldDec,0,6)
                l_SQLCommandCycle1 += [TYPE timestamp(]+trans(l_FieldDec)+[) with time zone]
            else
                l_SQLCommandCycle1 += [TYPE timestamp with time zone]
            endif
        case l_FieldType == "DT" .or. l_FieldType == "T"
            if vfp_between(l_FieldDec,0,6)
                l_SQLCommandCycle1 += [TYPE timestamp(]+trans(l_FieldDec)+[) without time zone]
            else
                l_SQLCommandCycle1 += [TYPE timestamp without time zone]
            endif
        endcase

        do case
        case l_FieldAllowNull = l_CurrentFieldAllowNull
        case l_FieldAllowNull
            //Was NOT NULL
            l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ DROP DEFAULT]
            l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ DROP NOT NULL]
        otherwise    // Stop NULL
            l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ SET DEFAULT '-infinity']
            l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ SET NOT NULL]
        endcase

    case l_FieldType == "Y"
        l_SQLCommandCycle1 += [TYPE money]

        do case
        case l_FieldAllowNull = l_CurrentFieldAllowNull
        case l_FieldAllowNull
            //Was NOT NULL
            l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ DROP DEFAULT]
            l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ DROP NOT NULL]
        otherwise    // Stop NULL
            l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ SET DEFAULT 0]
            l_SQLCommandCycle1 += [,ALTER COLUMN ] + l_FormattedFieldName + [ SET NOT NULL]
        endcase

    otherwise
        
    endcase

endcase

return {l_SQLCommandCycle1,l_SQLCommandCycle2}
//-----------------------------------------------------------------------------------------------------------------
method AddField(par_cSchemaName,par_cTableName,par_cFieldName,par_aFieldDefinition) class hb_orm_SQLConnect
local l_SQLCommand := ""
local l_FieldType,l_FieldLen,l_FieldDec,l_FieldAttributes,l_FieldAllowNull,l_FieldAutoIncrement
local l_FormattedFieldName := ::FormatIdentifier(par_cFieldName)
local l_Default

l_FieldType          := par_aFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE]
l_FieldLen           := par_aFieldDefinition[HB_ORM_SCHEMA_FIELD_LENGTH]
l_FieldDec           := par_aFieldDefinition[HB_ORM_SCHEMA_FIELD_DECIMALS]
l_FieldAttributes    := par_aFieldDefinition[HB_ORM_SCHEMA_FIELD_ATTRIBUTES]
l_FieldAllowNull     := ("N" $ l_FieldAttributes)
l_FieldAutoIncrement := ("+" $ l_FieldAttributes)

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_SQLCommand += [,ADD COLUMN ]+l_FormattedFieldName+[ ]

    do case
    case !empty(el_inlist(l_FieldType,"I","IB","N"))
        do case
        case l_FieldType == "I"
            l_SQLCommand += [INT]
        case l_FieldType == "IB"
            l_SQLCommand += [BIGINT]
        case l_FieldType == "N"
            l_SQLCommand += [DECIMAL(]+trans(l_FieldLen)+[,]+trans(l_FieldDec)+[)]
            if l_FieldAutoIncrement
                l_FieldAutoIncrement := .f.
                hb_orm_SendToDebugView("May not make numeric field auto-increment. Table: "+par_cTableName+" - Field: "+par_cFieldName)
            endif
        endcase

        do case
        case l_FieldAutoIncrement
            l_SQLCommand += [ NOT NULL AUTO_INCREMENT]
            
            // if lower(par_cFieldName) == lower(::p_PKFN)
                l_SQLCommand += [ PRIMARY KEY]
            // endif
        case l_FieldAllowNull
            l_SQLCommand += [ NULL]
        otherwise
            l_SQLCommand += [ NOT NULL DEFAULT 0]
        endcase
        
    case !empty(el_inlist(l_FieldType,"C","CV","B","BV","M","R"))
        do case
        case l_FieldType == "C"
            l_SQLCommand += [CHAR(]+trans(l_FieldLen)+[)]
        case l_FieldType == "CV"
            l_SQLCommand += [VARCHAR]+iif(empty(l_FieldLen),[],[(]+trans(l_FieldLen)+[)])
        case l_FieldType == "B"
            l_SQLCommand += [BINARY(]+trans(l_FieldLen)+[)]
        case l_FieldType == "BV"
            l_SQLCommand += [VARBINARY]+iif(empty(l_FieldLen),[],[(]+trans(l_FieldLen)+[)])
        case l_FieldType == "M"
            l_SQLCommand += [LONGTEXT]
        case l_FieldType == "R"
            l_SQLCommand += [LONGBLOB]
        endcase

        if l_FieldAllowNull
            l_SQLCommand += [ NULL]
        else
            l_SQLCommand += [ NOT NULL DEFAULT '']
        endif

    case l_FieldType == "L"
        l_SQLCommand += [TINYINT(1)]

        if l_FieldAllowNull
            l_SQLCommand += [ NULL]
        else
            l_SQLCommand += [ NOT NULL DEFAULT 0]
        endif
        
    case !empty(el_inlist(l_FieldType,"D","TOZ","TO","DTZ","T","DT"))
        do case
        case l_FieldType == "D"
            l_SQLCommand += [DATE]
            l_Default    := ['0000-00-00']
        case l_FieldType == "TOZ"
            if vfp_between(l_FieldDec,0,6)
                l_SQLCommand += [TIME(]+trans(l_FieldDec)+[) COMMENT 'with timezone']
            else
                l_SQLCommand += [TIME COMMENT 'with timezone']
            endif
            l_Default    := ['00:00:00']
        case l_FieldType == "TO"
            if vfp_between(l_FieldDec,0,6)
                l_SQLCommand += [TIME(]+trans(l_FieldDec)+[)]
            else
                l_SQLCommand += [TIME]
            endif
            l_Default    := ['00:00:00']
        case l_FieldType == "DTZ"
            if vfp_between(l_FieldDec,0,6)
                l_SQLCommand += [TIMESTAMP(]+trans(l_FieldDec)+[)]
            else
                l_SQLCommand += [TIMESTAMP]
            endif
            l_Default    := ['0000-00-00 00:00:00']
        case l_FieldType == "DT" .or. l_FieldType == "T"
            if vfp_between(l_FieldDec,0,6)
                l_SQLCommand += [DATETIME(]+trans(l_FieldDec)+[)]
            else
                l_SQLCommand += [DATETIME]
            endif
            l_Default    := ['0000-00-00 00:00:00']
        endcase

        if l_FieldAllowNull
            l_SQLCommand += [ NULL]
        else
            l_SQLCommand += [ NOT NULL DEFAULT ]+l_Default
        endif
        
    case l_FieldType == "Y"
        l_SQLCommand += [DECIMAL(13,4) COMMENT 'money']

        if l_FieldAllowNull
            l_SQLCommand += [ NULL]
        else
            l_SQLCommand += [ NOT NULL DEFAULT 0]
        endif

    otherwise
        
    endcase

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_SQLCommand += [,ADD COLUMN ]+l_FormattedFieldName+[ ]

    do case
    case !empty(el_inlist(l_FieldType,"I","IB","N"))
        do case
        case l_FieldType == "I"
            l_SQLCommand += [integer]
        case l_FieldType == "IB"
            l_SQLCommand += [bigint]
        case l_FieldType == "N"
            l_SQLCommand += [numeric(]+trans(l_FieldLen)+[,]+trans(l_FieldDec)+[)]
            if l_FieldAutoIncrement
                l_FieldAutoIncrement := .f.
                hb_orm_SendToDebugView("May not make numeric field auto-increment. Table: "+par_cSchemaName+"."+par_cTableName+" - Field: "+par_cFieldName)
            endif
        endcase

        do case
        case l_FieldAutoIncrement
            l_SQLCommand += [ NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 )]
            
            // if lower(par_cFieldName) == lower(::p_PKFN)
                // Will always name the constraints in lower case
                // l_SQLCommand += [,ADD CONSTRAINT ]+lower(par_cTableName)+[_]+lower(par_cFieldName)+[ PRIMARY KEY (]+::FormatIdentifier(par_cFieldName)+[)]
                l_SQLCommand += [,ADD CONSTRAINT ]+lower(par_cTableName)+[_pkey PRIMARY KEY (]+::FormatIdentifier(par_cFieldName)+[)]
            // endif
        case l_FieldAllowNull
        otherwise
            l_SQLCommand += [ NOT NULL DEFAULT 0]
        endcase
        
    case !empty(el_inlist(l_FieldType,"C","CV","B","BV","M","R"))
        do case
        case l_FieldType == "C"
            l_SQLCommand += [character(]+trans(l_FieldLen)+[)]
        case l_FieldType == "CV"
            l_SQLCommand += [character varying]+iif(empty(l_FieldLen),[],[(]+trans(l_FieldLen)+[)])
        case l_FieldType == "B"
            l_SQLCommand += [bit(]+trans(l_FieldLen)+[)]
        case l_FieldType == "BV"
            l_SQLCommand += [bit varying]+iif(empty(l_FieldLen),[],[(]+trans(l_FieldLen)+[)])
        case l_FieldType == "M"
            l_SQLCommand += [text]
        case l_FieldType == "R"
            l_SQLCommand += [bytea]
        endcase

        if !l_FieldAllowNull
            l_SQLCommand += [ NOT NULL DEFAULT '']
        endif

    case l_FieldType == "L"
        l_SQLCommand += [boolean]

        if !l_FieldAllowNull
            l_SQLCommand += [ NOT NULL DEFAULT FALSE]
        endif
        
    case !empty(el_inlist(l_FieldType,"D","TOZ","TO","DTZ","T","DT"))
        do case
        case l_FieldType == "D"
            l_SQLCommand += [date]
        case l_FieldType == "TOZ"
            if vfp_between(l_FieldDec,0,6)
                l_SQLCommand += [time(]+trans(l_FieldDec)+[) with time zone]
            else
                l_SQLCommand += [time with time zone]
            endif
        case l_FieldType == "TO"
            if vfp_between(l_FieldDec,0,6)
                l_SQLCommand += [time(]+trans(l_FieldDec)+[) without time zone]
            else
                l_SQLCommand += [time without time zone]
            endif
        case l_FieldType == "DTZ"
            if vfp_between(l_FieldDec,0,6)
                l_SQLCommand += [timestamp(]+trans(l_FieldDec)+[) with time zone]
            else
                l_SQLCommand += [timestamp with time zone]
            endif
        case l_FieldType == "DT" .or. l_FieldType == "T"
            if vfp_between(l_FieldDec,0,6)
                l_SQLCommand += [timestamp(]+trans(l_FieldDec)+[) without time zone]
            else
                l_SQLCommand += [timestamp without time zone]
            endif
        endcase

        if !l_FieldAllowNull
            l_SQLCommand += [ NOT NULL DEFAULT '-infinity']
        endif
        
    case l_FieldType == "Y"
        l_SQLCommand += [money]

        if !l_FieldAllowNull
            l_SQLCommand += [ NOT NULL DEFAULT 0]
        endif
        
    otherwise
        
    endcase

    // par_FieldSQLautoinc     l_FieldAutoIncrement
    // par_FieldSQLAlNull      l_FieldAllowNull
    // par_FieldType           l_FieldType
    // par_FieldLen            l_FieldLen
    // par_FieldDec            l_FieldDec  
    // par_FieldType           l_FieldType
    // l_result                l_SQLCommand

endcase

return l_SQLCommand
//-----------------------------------------------------------------------------------------------------------------
method AddIndex(par_cSchemaName,par_cTableName,par_hFields,par_cIndexName,par_aIndexDefinition) class hb_orm_SQLConnect
local l_SQLCommand := ""
local l_cIndexNameOnFile
local l_IndexExpression
local l_IndexUnique
local l_IndexType
local l_FormattedTableName

// altd()

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cIndexNameOnFile   := lower(par_cTableName)+"_"+lower(par_cIndexName)+"_idx"
    l_FormattedTableName := ::FormatIdentifier(par_cTableName)
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cIndexNameOnFile   := lower(par_cSchemaName)+"_"+lower(par_cTableName)+"_"+lower(par_cIndexName)+"_idx"
    l_FormattedTableName := ::FormatIdentifier(par_cSchemaName+"."+par_cTableName)
endcase

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_IndexExpression := ::FixCasingInFieldExpression(par_hFields,par_aIndexDefinition[HB_ORM_SCHEMA_INDEX_EXPRESSION])
    l_IndexUnique     := par_aIndexDefinition[HB_ORM_SCHEMA_INDEX_UNIQUE]
    l_IndexType       := par_aIndexDefinition[HB_ORM_SCHEMA_INDEX_ALGORITHM]
    if empty(l_IndexType)
        l_IndexType := "BTREE"
    endif

    l_SQLCommand := [ALTER TABLE ]+l_FormattedTableName
	l_SQLCommand += [ ADD ]+iif(l_IndexUnique,"UNIQUE ","")+[INDEX `]+l_cIndexNameOnFile+[` (]+l_IndexExpression+[) USING ]+l_IndexType+[;]+CRLF
// altd()

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_IndexExpression := ::FixCasingInFieldExpression(par_hFields,par_aIndexDefinition[HB_ORM_SCHEMA_INDEX_EXPRESSION])
    l_IndexUnique     := par_aIndexDefinition[HB_ORM_SCHEMA_INDEX_UNIQUE]
    l_IndexType       := par_aIndexDefinition[HB_ORM_SCHEMA_INDEX_ALGORITHM]
    if empty(l_IndexType)
        l_IndexType := "BTREE"
    endif

    // Will create index named in lower cases.
    l_SQLCommand := [CREATE ]+iif(l_IndexUnique,"UNIQUE ","")+[INDEX ]+l_cIndexNameOnFile
    l_SQLCommand += [ ON ]+l_FormattedTableName+[ USING ]+l_IndexType
    l_SQLCommand += [ (]+l_IndexExpression+[);]+CRLF

endcase

return l_SQLCommand
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
method GenerateCurrentSchemaHarbourCode(par_cFileName) class hb_orm_SQLConnect

local l_hTableDefinition,l_aTableDefinition,l_cTableName
local l_hFields,l_hIndexes
local l_hFieldDefinition,l_cFieldName,l_aFieldDefinition
local l_hIndexDefinition,l_cIndexName,l_aIndexDefinition
local l_cSourceCode := ""
local l_cSourceCodeFields,l_cSourceCodeIndexes
local l_nMaxNameLength
local l_cIndent := space(3)
// local l_aListOfTablesToNoProcess := {"SchemaCacheLog"}
local l_cIndexExpression
local l_FieldType,l_FieldLen,l_FieldDec,l_FieldAttributes,l_FieldAllowNull,l_FieldAutoIncrement
local l_nLengthPostgreSQLHBORMSchemaName := Len(::PostgreSQLHBORMSchemaName)

::UpdateSchemaCache()
::LoadSchema()

for each l_hTableDefinition in ::p_Schema
    l_cTableName       := l_hTableDefinition:__enumKey()
    // if AScan( l_aListOfTablesToNoProcess, {|cName|lower(cName) == lower(l_cTableName) } ) > 0
    //     loop
    // endif

    // Do not export the ORM Support Files
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        if lower(left(l_cTableName,6)) == "schema"   // Not the best method to decide if a ORM support table.
            loop
        endif
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        if lower(left(l_cTableName,l_nLengthPostgreSQLHBORMSchemaName+1)) == lower(::PostgreSQLHBORMSchemaName)+"."
            loop
        endif
    endcase

    l_aTableDefinition := l_hTableDefinition:__enumValue()

    l_hFields          := l_aTableDefinition[HB_ORM_SCHEMA_FIELD]
    l_hIndexes         := l_aTableDefinition[HB_ORM_SCHEMA_INDEX]

    l_cSourceCode += iif(empty(l_cSourceCode),"{",",")
    l_cSourceCode += '"'+l_cTableName+'"'+"=>{;   /"+"/Field Definition"
    
    //Get Field Definitions
    l_cSourceCodeFields := ""
    
    l_nMaxNameLength := 0
    AEval(hb_HKeys(l_hFields),{|l_cFieldName|l_nMaxNameLength:=max(l_nMaxNameLength,len(l_cFieldName))})  //Get length of max FieldName length

    for each l_hFieldDefinition in l_hFields
        l_cFieldName       := l_hFieldDefinition:__enumKey()
        l_aFieldDefinition := l_hFieldDefinition:__enumValue()

        l_cSourceCodeFields += iif(empty(l_cSourceCodeFields) , CRLF+l_cIndent+"{" , ";"+CRLF+l_cIndent+"," )
        
        l_FieldType          := allt(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE])
        l_FieldLen           := hb_DefaultValue(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_LENGTH]        , 0 )
        l_FieldDec           := hb_DefaultValue(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_DECIMALS]      , 0 )
        l_FieldAttributes    := hb_DefaultValue(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_ATTRIBUTES]    , "")
        l_FieldAllowNull     := ("N" $ l_FieldAttributes)
        l_FieldAutoIncrement := ("+" $ l_FieldAttributes)

        if lower(l_cFieldName) == lower(::p_PKFN)
            l_FieldAutoIncrement := .t.
        endif
        if l_FieldAutoIncrement .and. empty(el_inlist(l_FieldType,"I","IB"))  //Only those fields types may be flagged as Auto-Increment
            l_FieldAutoIncrement := .f.
        endif
        if l_FieldAutoIncrement .and. l_FieldAllowNull  //Auto-Increment fields may not be null (and not have a default)
            l_FieldAllowNull := .f.
        endif

        l_FieldAttributes := iif(l_FieldAllowNull,"N","")+iif(l_FieldAutoIncrement,"+","")

        l_cSourceCodeFields += padr('"'+l_cFieldName+'"',l_nMaxNameLength+2)+"=>{"
        l_cSourceCodeFields += ","  // Null Value for the HB_ORM_SCHEMA_INDEX_BACKEND_TYPES 
        l_cSourceCodeFields += padl('"'+l_FieldType+'"',5)+","+;
                             str(l_FieldLen,4)+","+;
                             str(l_FieldDec,3)+","+;
                             iif(empty(l_FieldAttributes),"",'"'+l_FieldAttributes+'"')
        l_cSourceCodeFields += "}"

    endfor
    l_cSourceCodeFields += "}"

    l_cSourceCode += l_cSourceCodeFields+";"+CRLF+l_cIndent+",;   /"+"/Index Definition"

    //Get Index Definitions
    if hb_IsNIL(l_hIndexes)
        l_cSourceCode += CRLF+l_cIndent+"NIL};"+CRLF
    else
        l_cSourceCodeIndexes := ""
        l_nMaxNameLength := 0
        
        AEval(hb_HKeys(l_hIndexes),{|l_cIndexName|l_nMaxNameLength:=max(l_nMaxNameLength,len(l_cIndexName))})  //Get length of max FieldName length

        for each l_hIndexDefinition in l_hIndexes
            l_cIndexName       := l_hIndexDefinition:__enumKey()
            l_aIndexDefinition := l_hIndexDefinition:__enumValue()

// Temporarily while generating SDOL code
// l_cIndexName := strtran(l_cIndexName,"index_"+lower(l_cTableName)+"_","")

            l_cIndexExpression := l_aIndexDefinition[HB_ORM_SCHEMA_INDEX_EXPRESSION]
            l_cIndexExpression := strtran(l_cIndexExpression,["],[]) // remove PostgreSQL token delimiter. Will be added as needed when creating indexes.
            l_cIndexExpression := strtran(l_cIndexExpression,['],[]) // remove MySQL token delimiter. Will be added as needed when creating indexes.
            
            l_cSourceCodeIndexes += iif(empty(l_cSourceCodeIndexes) , CRLF+l_cIndent+"{" , ";"+CRLF+l_cIndent+",")

            l_cSourceCodeIndexes += padr('"'+l_cIndexName+'"',l_nMaxNameLength+2)+"=>{"
            l_cSourceCodeIndexes += "," // HB_ORM_SCHEMA_FIELD_BACKEND_TYPES
            l_cSourceCodeIndexes += '"'+l_cIndexExpression+'",'+;
                                  iif(l_aIndexDefinition[HB_ORM_SCHEMA_INDEX_UNIQUE],".t.",".f.")+","+;
                                  '"'+l_aIndexDefinition[HB_ORM_SCHEMA_INDEX_ALGORITHM]+'"'
            l_cSourceCodeIndexes += "}"

        endfor
        l_cSourceCode += l_cSourceCodeIndexes+"}};"+CRLF
    endif

endfor

if !empty(l_cSourceCode)
    l_cSourceCode += "}"
endif

hb_MemoWrit(par_cFileName,l_cSourceCode)

return NIL

//-----------------------------------------------------------------------------------------------------------------
method EnableSchemaChangeTracking() class hb_orm_SQLConnect
local l_SQLCommand
local l_Success := .f.

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_Success := .t.

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    // https://www.enterprisedb.com/postgres-tutorials/how-use-event-triggers-postgresql
    // ddl acronym = Data Definition Language
    // ddl statements: CREATE, ALTER, TRUNCATE, DROP
    // https://www.postgresql.org/docs/13/event-trigger-matrix.html

    TEXT TO VAR l_SQLCommand
CREATE SCHEMA IF NOT EXISTS hborm;

DROP EVENT TRIGGER IF EXISTS schema_log_ddl_info;
DROP EVENT TRIGGER IF EXISTS schema_log_ddl_drop_info;

CREATE TABLE IF NOT EXISTS hborm."SchemaCacheLog" (
  pk serial primary key,
  datetime timestamptz DEFAULT CURRENT_TIMESTAMP,
  action text,
  objectname text,
  objecttype text,
  cachedschema boolean DEFAULT false,  --If a related Schema Fields and Indexes Tables were created
  username character varying DEFAULT "current_user"(),
  address character varying DEFAULT "inet_client_addr"()
);

CREATE OR REPLACE FUNCTION hborm.schema_log_ddl()
  RETURNS event_trigger AS $$
DECLARE
  audit_query TEXT;
  r RECORD;
BEGIN
  IF tg_tag = 'DROP TABLE' OR tg_tag = 'DROP INDEX' THEN
    --Do nothing since the schema_log_ddl_drop will also be triggered
  ELSE
    FOR r IN SELECT * FROM pg_event_trigger_ddl_commands() LOOP
      IF position('SchemaCache' in r.object_identity) = 0 THEN
        IF r.object_type = 'sequence' THEN
          CONTINUE;
        END IF;
        BEGIN
          INSERT INTO hborm."SchemaCacheLog" (action,objectname,objecttype) VALUES (tg_tag,r.object_identity,r.object_type);
        EXCEPTION WHEN OTHERS THEN
          NULL;
        END;
      END IF;
      --Only the first object info will be recorded
      EXIT;
    END LOOP;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION hborm.schema_log_ddl_drop()
  RETURNS event_trigger AS $$
DECLARE
  audit_query TEXT;
  r RECORD;
BEGIN
  IF tg_tag = 'DROP TABLE' OR tg_tag = 'DROP INDEX' THEN
    FOR r IN SELECT * FROM pg_event_trigger_dropped_objects() LOOP
      IF position('SchemaCache' in r.object_identity) = 0 THEN
        IF r.object_type = 'sequence' THEN
          CONTINUE;
        END IF;
        BEGIN
          INSERT INTO hborm."SchemaCacheLog" (action,objectname,objecttype) VALUES (tg_tag,r.object_identity,r.object_type);
        EXCEPTION WHEN OTHERS THEN
          NULL;
        END;
      END IF;
      --Only the first object info will be recorded
      EXIT;
    END LOOP;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE EVENT TRIGGER schema_log_ddl_info      ON ddl_command_end EXECUTE PROCEDURE hborm.schema_log_ddl();
CREATE EVENT TRIGGER schema_log_ddl_drop_info ON sql_drop        EXECUTE PROCEDURE hborm.schema_log_ddl_drop();
    ENDTEXT

    if !(::PostgreSQLHBORMSchemaName == "hborm")
        l_SQLCommand := strtran(l_SQLCommand,"hborm",::FormatIdentifier(::PostgreSQLHBORMSchemaName))
    endif

    l_Success := ::SQLExec(l_SQLCommand)

endcase

return l_Success
//-----------------------------------------------------------------------------------------------------------------
method DisableSchemaChangeTracking() class hb_orm_SQLConnect
local l_SQLCommand
local l_Success := .f.

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_Success := .t.
    
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    TEXT TO VAR l_SQLCommand
DROP EVENT TRIGGER IF EXISTS schema_log_ddl_info;
DROP EVENT TRIGGER IF EXISTS schema_log_ddl_drop_info;

DROP FUNCTION IF EXISTS hborm.schema_log_ddl;
DROP FUNCTION IF EXISTS hborm.schema_log_ddl_drop;
    ENDTEXT

    if !(::PostgreSQLHBORMSchemaName == "hborm")
        l_SQLCommand := strtran(l_SQLCommand,"hborm",::FormatIdentifier(::PostgreSQLHBORMSchemaName))
    endif

    l_Success := ::SQLExec(l_SQLCommand)

endcase

return l_Success
//-----------------------------------------------------------------------------------------------------------------
method RemoveSchemaChangeTracking() class hb_orm_SQLConnect
local l_SQLCommand
local l_Success := .f.

::DisableSchemaChangeTracking()

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_Success := .t.
    
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_SQLCommand := [DROP TABLE IF EXISTS hborm."SchemaCacheLog";]
    
    if !(::PostgreSQLHBORMSchemaName == "hborm")
        l_SQLCommand := strtran(l_SQLCommand,"hborm",::FormatIdentifier(::PostgreSQLHBORMSchemaName))
    endif

    l_Success := ::SQLExec(l_SQLCommand)

endcase

return l_Success
//-----------------------------------------------------------------------------------------------------------------
method UpdateSchemaCache(par_Force) class hb_orm_SQLConnect   //returns .t. if cache was updated
local l_SQLCommand
local l_SQLCommandFields
local l_SQLCommandIndexes
local l_select := iif(used(),select(),0)
local l_CacheFullName
local l_result := .f.

hb_Default(@par_Force,.f.)

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL

    // altd()

    if par_Force
        //Add an Entry in SchemaCacheLog to notify to make a cache
        l_SQLCommand := [INSERT INTO ]+::FormatIdentifier(::PostgreSQLHBORMSchemaName)+[."SchemaCacheLog" (action) VALUES ('No Change');]
        ::SQLExec(l_SQLCommand)
    endif

    l_SQLCommand := [SELECT pk,]
    l_SQLCommand += [       cachedschema::integer]
    l_SQLCommand += [ FROM  ]+::FormatIdentifier(::PostgreSQLHBORMSchemaName)+[."SchemaCacheLog"]
    l_SQLCommand += [ ORDER BY pk DESC]
    l_SQLCommand += [ LIMIT 1]

    if ::SQLExec(l_SQLCommand,"SchemaCacheLogLast")
        if SchemaCacheLogLast->(reccount()) == 1
            if SchemaCacheLogLast->cachedschema == 0
hb_orm_SendToDebugView("Will create a new Schema Cache")
                l_CacheFullName := ::FormatIdentifier(::PostgreSQLHBORMSchemaName)+[."SchemaCacheFields_]+trans(SchemaCacheLogLast->pk)+["]
                l_SQLCommandFields := [DROP TABLE IF EXISTS ]+l_CacheFullName+[;]+CRLF
                l_SQLCommandFields += [CREATE TABLE ]+l_CacheFullName+[ AS]
                //The following is WAY TO SLOW on Large catalogs. The joining on the "tables" is the main performance problem.
                // l_SQLCommandFields += [ SELECT tables.table_name                AS table_name,]
                // l_SQLCommandFields += [        columns.ordinal_position         AS field_position,]
                // l_SQLCommandFields += [        columns.column_name              AS field_name,]
                // l_SQLCommandFields += [        columns.data_type                AS field_type,]
                // l_SQLCommandFields += [        columns.character_maximum_length AS field_clength,]
                // l_SQLCommandFields += [        columns.numeric_precision        AS field_nlength,]
                // l_SQLCommandFields += [        columns.datetime_precision       AS field_tlength,]
                // l_SQLCommandFields += [        columns.numeric_scale            AS field_decimals,]
                // l_SQLCommandFields += [        (columns.is_nullable = 'YES')    AS field_nullable,]
                // l_SQLCommandFields += [        columns.column_default           AS field_default,]
                // l_SQLCommandFields += [        (columns.is_identity = 'YES')    AS field_identity_is,]
                // l_SQLCommandFields += [        upper(tables.table_name)         AS tag1]
                // l_SQLCommandFields += [ FROM information_schema.tables  AS tables]
                // l_SQLCommandFields += [ JOIN information_schema.columns AS columns ON columns.TABLE_NAME = tables.TABLE_NAME]
                // l_SQLCommandFields += [ WHERE tables.table_schema    = ']+::p_SchemaName+[']
                // l_SQLCommandFields += [ AND   tables.table_type      = 'BASE TABLE']
                // l_SQLCommandFields += [ AND   lower(left(tables.table_name,11)) != 'schemacache']
                // l_SQLCommandFields += [ ORDER BY tag1,field_position]

                l_SQLCommandFields += [ SELECT columns.table_schema             AS schema_name,]
                l_SQLCommandFields += [        columns.table_name               AS table_name,]
                l_SQLCommandFields += [        columns.ordinal_position         AS field_position,]
                l_SQLCommandFields += [        columns.column_name              AS field_name,]
                l_SQLCommandFields += [        columns.data_type                AS field_type,]
                l_SQLCommandFields += [        columns.character_maximum_length AS field_clength,]
                l_SQLCommandFields += [        columns.numeric_precision        AS field_nlength,]
                l_SQLCommandFields += [        columns.datetime_precision       AS field_tlength,]
                l_SQLCommandFields += [        columns.numeric_scale            AS field_decimals,]
                l_SQLCommandFields += [        (columns.is_nullable = 'YES')    AS field_nullable,]
                l_SQLCommandFields += [        columns.column_default           AS field_default,]
                l_SQLCommandFields += [        (columns.is_identity = 'YES')    AS field_identity_is,]
                l_SQLCommandFields += [        upper(columns.table_schema)      AS tag1,]
                l_SQLCommandFields += [        upper(columns.table_name)        AS tag2]
                l_SQLCommandFields += [ FROM information_schema.columns]
                l_SQLCommandFields += [ WHERE NOT (lower(left(columns.table_name,11)) = 'schemacache' OR lower(columns.table_schema) in ('information_schema','pg_catalog'))]
                l_SQLCommandFields += [ ORDER BY tag1,tag2,field_position;]

                l_CacheFullName := ::FormatIdentifier(::PostgreSQLHBORMSchemaName)+[."SchemaCacheIndexes_]+trans(SchemaCacheLogLast->pk)+["]
                l_SQLCommandIndexes := [DROP TABLE IF EXISTS ]+l_CacheFullName+[;]+CRLF
                l_SQLCommandIndexes += [CREATE TABLE ]+l_CacheFullName+[ AS]
                l_SQLCommandIndexes += [ SELECT pg_indexes.schemaname      AS schema_name,]
                l_SQLCommandIndexes += [        pg_indexes.tablename       AS table_name,]
                l_SQLCommandIndexes += [        pg_indexes.indexname       AS index_name,]
                l_SQLCommandIndexes += [        pg_indexes.indexdef        AS index_definition,]
                l_SQLCommandIndexes += [       upper(pg_indexes.schemaname) AS tag1,]
                l_SQLCommandIndexes += [       upper(pg_indexes.tablename) AS tag2]
                l_SQLCommandIndexes += [ FROM pg_indexes]
                l_SQLCommandIndexes += [ WHERE NOT (lower(left(pg_indexes.tablename,11)) = 'schemacache' OR lower(pg_indexes.schemaname) in ('information_schema','pg_catalog'))]
                l_SQLCommandIndexes += [ ORDER BY tag1,index_name;]

                if ::SQLExec(l_SQLCommandFields) .and. ::SQLExec(l_SQLCommandIndexes)
                    l_SQLCommand := [UPDATE ]+::FormatIdentifier(::PostgreSQLHBORMSchemaName)+[."SchemaCacheLog"]
                    l_SQLCommand += [ SET cachedschema = TRUE]
                    l_SQLCommand += [ WHERE pk = ]+trans(SchemaCacheLogLast->pk)

                    if ::SQLExec(l_SQLCommand)
hb_orm_SendToDebugView("Done creating a new Schema Cache")
                        //Remove any previous cache
                        l_SQLCommand := [SELECT pk]
                        l_SQLCommand += [ FROM ]+::FormatIdentifier(::PostgreSQLHBORMSchemaName)+[."SchemaCacheLog"]
                        l_SQLCommand += [ WHERE cachedschema]
                        l_SQLCommand += [ AND pk < ]+trans(SchemaCacheLogLast->pk)
                        l_SQLCommand += [ ORDER BY pk]  // Oldest to newest

                        if ::SQLExec(l_SQLCommand,"SchemaCacheLogLast")
                            select SchemaCacheLogLast
                            scan all
                                if recno() == reccount()  // Since last record is the latest beside the one just added, will exit the scan
                                    exit
                                endif
                                l_SQLCommand := [UPDATE ]+::FormatIdentifier(::PostgreSQLHBORMSchemaName)+[."SchemaCacheLog"]
                                l_SQLCommand += [ SET cachedschema = FALSE]
                                l_SQLCommand += [ WHERE pk = ]+trans(SchemaCacheLogLast->pk)
                                
                                if ::SQLExec(l_SQLCommand)
                                    l_SQLCommand := [DROP TABLE ]+::FormatIdentifier(::PostgreSQLHBORMSchemaName)+[."SchemaCacheFields_]+trans(SchemaCacheLogLast->pk)+["]
                                    ::SQLExec(l_SQLCommand)
                                    l_SQLCommand := [DROP TABLE ]+::FormatIdentifier(::PostgreSQLHBORMSchemaName)+[."SchemaCacheIndexes_]+trans(SchemaCacheLogLast->pk)+["]
                                    ::SQLExec(l_SQLCommand)
                                endif
                            endscan

                        endif
                    endif
                endif
                // ::LoadSchema()
                l_result := .t.
            endif
        endif
    endif
    CloseAlias("SchemaCacheLogLast")
    select (l_select)

endcase

return l_result
//-----------------------------------------------------------------------------------------------------------------
method IsReservedWord(par_cIdentifier) class hb_orm_SQLConnect
local l_Result := .f.

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    // https://dev.mysql.com/doc/refman/8.0/en/keywords.html
    l_Result := AScan( ::ReservedWordsMySQL, {|cWord|cWord == upper(alltrim(par_cIdentifier)) } ) > 0

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    // https://www.postgresql.org/docs/13/sql-keywords-appendix.html
    l_Result := AScan( ::ReservedWordsPostgreSQL, {|cWord|cWord == upper(alltrim(par_cIdentifier)) } ) > 0

endcase

return l_Result
//-----------------------------------------------------------------------------------------------------------------
method FormatIdentifier(par_cName) class hb_orm_SQLConnect
local l_cFormattedIdentifier
local l_iPos
local l_cSchemaName,l_cTableName
do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    if ::MySQLEngineConvertIdentifierToLowerCase
        l_cFormattedIdentifier := "`"+lower(par_cName)+"`"
    else
        l_cFormattedIdentifier := "`"+par_cName+"`"
    endif
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    // Since a Schema name could be a prefix to the table name, detect its presence.
    l_iPos := at(".",par_cName)
    if l_iPos == 0  // no Schema name was specified
        do case
        case ::PostgreSQLIdentifierCasing == 0  // Case Insensitive (displayed as lower case) except reserved words always lower case
            if ::IsReservedWord(par_cName)
                l_cFormattedIdentifier := '"'+lower(par_cName)+'"'
            else
                l_cFormattedIdentifier := par_cName
            endif
        case ::PostgreSQLIdentifierCasing == 1
            l_cFormattedIdentifier := '"'+par_cName+'"'
        case ::PostgreSQLIdentifierCasing == 2  // convert to lower case
            l_cFormattedIdentifier := '"'+lower(par_cName)+'"'
        otherwise  // Should not happen
            l_cFormattedIdentifier := par_cName
        endcase
    else
        l_cSchemaName := left(par_cName,l_iPos-1)
        l_cTableName  := substr(par_cName,l_iPos+1)

        do case
        case ::PostgreSQLIdentifierCasing == 0  // Case Insensitive (displayed as lower case) except reserved words always lower case
            if ::IsReservedWord(l_cSchemaName)
                l_cFormattedIdentifier := '"'+lower(l_cSchemaName)+'".'
            else
                l_cFormattedIdentifier := l_cSchemaName+"."
            endif
            if ::IsReservedWord(l_cTableName)
                l_cFormattedIdentifier += '"'+lower(l_cTableName)+'"'
            else
                l_cFormattedIdentifier += l_cTableName
            endif
        case ::PostgreSQLIdentifierCasing == 1
            l_cFormattedIdentifier := '"'+l_cSchemaName+'"."'+l_cTableName+'"'
        case ::PostgreSQLIdentifierCasing == 2  // convert to lower case
            l_cFormattedIdentifier := '"'+lower(l_cSchemaName)+'"."'+lower(l_cTableName)+'"'
        otherwise  // Should not happen
            l_cFormattedIdentifier := '"'+l_cSchemaName+'"."'+l_cTableName+'"'
        endcase

    endif
endcase

return l_cFormattedIdentifier
//-----------------------------------------------------------------------------------------------------------------
method CaseTableName(par_cSchemaAndTableName) class hb_orm_SQLConnect
local l_SchemaAndTableName := allt(par_cSchemaAndTableName)
local l_HashPos
//Fix The Casing of Table and Field based on he actual on file tables.
l_HashPos := hb_hPos(::p_Schema,l_SchemaAndTableName)
if l_HashPos > 0
    l_SchemaAndTableName := hb_hKeyAt(::p_Schema,l_HashPos) 
else
    // Report Failed to find Table by returning empty.
    l_SchemaAndTableName := ""
endif
return l_SchemaAndTableName
//-----------------------------------------------------------------------------------------------------------------
method CaseFieldName(par_cSchemaAndTableName,par_cFieldName) class hb_orm_SQLConnect
local l_SchemaAndTableName := allt(par_cSchemaAndTableName)
local l_FieldName          := allt(par_cFieldName)
local l_HashPos
l_HashPos := hb_hPos(::p_Schema[l_SchemaAndTableName][HB_ORM_SCHEMA_FIELD],l_FieldName)
if l_HashPos > 0
    l_FieldName := hb_hKeyAt(::p_Schema[l_SchemaAndTableName][HB_ORM_SCHEMA_FIELD],l_HashPos)
else
    // Report Failed to find Field by returning empty.
    l_FieldName := ""
endif
return l_FieldName
//-----------------------------------------------------------------------------------------------------------------
// Following used to handle index expressions
method FixCasingInFieldExpression(par_hFields,par_expression) class hb_orm_SQLConnect
local l_result := ""
local l_FieldName
local l_Byte
local l_ByteIsToken
local l_FieldDetection := 0
local l_StreamBuffer        := ""
local l_FieldHashPos
local l_TokenCouldBeCasting := .f. //Used to handle situations like "::text"

// See https://www.postgresql.org/docs/13/indexes-expressional.html

// Meaning of "Token", same as "Identifier"
hb_HCaseMatch(par_hFields,.f.)

// Discover Tokens. Tokens may not have a following "(" or preceding "::"

for each l_Byte in @par_expression
    l_ByteIsToken := (l_Byte $ "0123456789_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    do case
    case l_FieldDetection == 0  // Not in <FieldName> pattern
        if l_ByteIsToken
            l_FieldDetection := 1
            l_StreamBuffer   := l_Byte
            l_FieldName      := l_Byte
        else
            l_result += l_Byte
            l_TokenCouldBeCasting := (l_Byte == ":")
        endif
    case l_FieldDetection == 1 // in <Field> possibly
        do case
        case l_ByteIsToken
            l_StreamBuffer += l_Byte
            l_FieldName    += l_Byte
        case l_byte == "(" // Meaning token is used as a function.
            l_FieldDetection := 0
            l_result              += l_StreamBuffer+l_Byte
            l_StreamBuffer        := ""
            l_TokenCouldBeCasting := .f.
        otherwise
            // It was a <Field> possibly
            l_FieldDetection := 0
            if l_TokenCouldBeCasting
                l_result              += l_FieldName + l_Byte
                l_FieldName           := ""
                l_StreamBuffer        := ""
                l_TokenCouldBeCasting := .f.
            else
                l_FieldHashPos := hb_hPos(par_hFields,l_FieldName)
                if l_FieldHashPos > 0  //Token is one of the fields
                    l_FieldName    := hb_hKeyAt(par_hFields,l_FieldHashPos) //Fix Token Casing   Many better method
                    l_result       += ::FormatIdentifier(l_FieldName)+l_Byte
                    l_FieldName    := ""
                    l_StreamBuffer := ""
                else
                    l_result       += l_FieldName + l_Byte   //Token is not a know field name for table par_cTableName
                    l_FieldName    := ""
                    l_StreamBuffer := ""
                endif
            endif
        endcase
    endcase
endfor
if !empty(l_FieldName)  //We were detecting a fieldname possibly
    if l_TokenCouldBeCasting
        l_result += l_FieldName
    else
        l_FieldHashPos := hb_hPos(par_hFields,l_FieldName)
        if l_FieldHashPos > 0  //Token is one of the fields
            l_FieldName := hb_hKeyAt(par_hFields,l_FieldHashPos) //Fix Token Casing   Many better method
            l_result    += ::FormatIdentifier(l_FieldName)
        else
            l_result += l_FieldName
        endif
    endif
endif

return l_result
//-----------------------------------------------------------------------------------------------------------------
method DeleteTable(par_cSchemaAndTableName) class hb_orm_SQLConnect
local l_result := .t.
local l_SQLCommand
local l_LastError
local l_cSchemaAndTableNameFixedCase

l_cSchemaAndTableNameFixedCase := ::CaseTableName(par_cSchemaAndTableName)
if empty(l_cSchemaAndTableNameFixedCase)
    hb_orm_SendToDebugView([Unable to delete field(s) in unknown table: "]+par_cSchemaAndTableName+["])
else
    l_SQLCommand := [DROP TABLE IF EXISTS ]+::FormatIdentifier(l_cSchemaAndTableNameFixedCase)+[;]
    if ::SQLExec(l_SQLCommand)
        hb_HDel(::p_Schema,l_cSchemaAndTableNameFixedCase)
    else
        l_result := .f.
        l_LastError := ::GetSQLExecErrorMessage()
        hb_orm_SendToDebugView([Failed Delete Table "]+par_cSchemaAndTableName+[".   Error Text=]+l_LastError)
    endif
endif

return l_result
//-----------------------------------------------------------------------------------------------------------------
method DeleteIndex(par_cSchemaAndTableName,par_cIndexName) class hb_orm_SQLConnect
local l_result := .t.
local l_cSchemaAndTableNameFixedCase
local l_LastError
local l_SQLCommand := ""
local l_HashPos

l_cSchemaAndTableNameFixedCase := ::CaseTableName(par_cSchemaAndTableName)
if empty(l_cSchemaAndTableNameFixedCase)
    hb_orm_SendToDebugView([Unable to delete index(s) in unknown table: "]+par_cSchemaAndTableName+["])

else
    //Test if the index is present. Only hb_orm indexes can be removed.
    l_HashPos := hb_hPos(::p_Schema[par_cSchemaAndTableName][HB_ORM_SCHEMA_INDEX],lower(par_cIndexName))
    if l_HashPos > 0
        
        do case
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
            l_SQLCommand  := [DROP INDEX `]+strtran(lower(par_cSchemaAndTableName),".","_")+"_"+lower(par_cIndexName)+"_idx"+[` ON ]+::FormatIdentifier(l_cSchemaAndTableNameFixedCase)+[;]

        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
            l_SQLCommand  := [DROP INDEX IF EXISTS ]+strtran(lower(par_cSchemaAndTableName),".","_")+"_"+lower(par_cIndexName)+"_idx"+[ CASCADE;]

        endcase

        if !empty(l_SQLCommand)
            if ::SQLExec(l_SQLCommand)
                hb_HDel(::p_Schema[par_cSchemaAndTableName][HB_ORM_SCHEMA_INDEX],lower(par_cIndexName))
            else
                l_result := .f.
                l_LastError := ::GetSQLExecErrorMessage()
                hb_orm_SendToDebugView([Failed Delete index "]+par_cIndexName+[" for table "]+par_cSchemaAndTableName+[".   Error Text=]+l_LastError)
            endif
        endif

    endif

endif

return l_result
//-----------------------------------------------------------------------------------------------------------------
method DeleteField(par_cSchemaAndTableName,par_xFieldNames) class hb_orm_SQLConnect
local l_result := .t.
local l_cSchemaAndTableNameFixedCase
local l_LastError
local l_aFieldNames,l_cFieldName,l_cFieldNameFixedCase
local l_SQLCommand
local l_SQLAlterTable
local l_SQLIfExist

// par_xFieldNames can be an array of field names or a single field name

l_cSchemaAndTableNameFixedCase := ::CaseTableName(par_cSchemaAndTableName)
if empty(l_cSchemaAndTableNameFixedCase)
    hb_orm_SendToDebugView([Unable to delete field(s) in unknown table: "]+par_cSchemaAndTableName+["])

else
    if ValType(par_xFieldNames) == "A"
        l_aFieldNames := par_xFieldNames
    elseif ValType(par_xFieldNames) == "C"
        l_aFieldNames := {par_xFieldNames}
    else
        l_aFieldNames := {}
    endif

    if len(l_aFieldNames) > 0

        l_SQLAlterTable := [ALTER TABLE ]+::FormatIdentifier(l_cSchemaAndTableNameFixedCase)

        do case
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
            l_SQLIfExist    := [ ]
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
            l_SQLIfExist    := [ IF EXISTS ]
        endcase

        l_SQLCommand := []
        for each l_cFieldName in l_aFieldNames
            l_cFieldNameFixedCase := ::CaseFieldName(l_cSchemaAndTableNameFixedCase,l_cFieldName)
            if empty(l_cFieldNameFixedCase)
                hb_orm_SendToDebugView([Unable to delete unknown field: "]+par_cSchemaAndTableName+[.]+l_cFieldName+["])
            else
                if !empty(l_SQLCommand)
                    l_SQLCommand += [,]
                endif
                l_SQLCommand += [ DROP COLUMN]+l_SQLIfExist+::FormatIdentifier(l_cFieldNameFixedCase)+[ CASCADE]
            endif
        endfor

        if !empty(l_SQLCommand)
            l_SQLCommand := l_SQLAlterTable + l_SQLCommand + [;]
            if ::SQLExec(l_SQLCommand)
                for each l_cFieldName in l_aFieldNames
                    l_cFieldNameFixedCase := ::CaseFieldName(l_cSchemaAndTableNameFixedCase,l_cFieldName)
                    if !empty(l_cFieldNameFixedCase)
                        hb_HDel(::p_Schema[l_cSchemaAndTableNameFixedCase][HB_ORM_SCHEMA_FIELD],l_cFieldNameFixedCase)
                    endif
                endfor
            else
                l_result := .f.
                l_LastError := ::GetSQLExecErrorMessage()
                hb_orm_SendToDebugView([Failed Delete Field(s) in "]+par_cSchemaAndTableName+[".   Error Text=]+l_LastError)
            endif
        endif

    endif

endif

return l_result
//-----------------------------------------------------------------------------------------------------------------
method TableExists(par_cSchemaAndTableName) class hb_orm_SQLConnect
local l_result
local l_SQLCommand
local l_iPos,l_cSchemaName,l_cTableName

l_iPos := at(".",par_cSchemaAndTableName)
if l_iPos == 0
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_cSchemaName := ""
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        l_cSchemaName := ::GetCurrentSchemaName()   // To search in the current Schema
    endcase
    l_cTableName  := par_cSchemaAndTableName
else
    l_cSchemaName := left(par_cSchemaAndTableName,l_iPos-1)
    l_cTableName  := substr(par_cSchemaAndTableName,l_iPos+1)
endif

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_SQLCommand  := [SELECT count(*) as count FROM information_schema.tables WHERE lower(table_schema) = ']+lower(::GetDatabase())+[' AND lower(table_name) = ']+lower(l_cTableName)+[';]
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_SQLCommand  := [SELECT count(*) AS count FROM information_schema.tables WHERE lower(table_schema) = ']+lower(l_cSchemaName)  +[' AND lower(table_name) = ']+lower(l_cTableName)+[';]
endcase

if ::SQLExec(l_SQLCommand,"TableExistsResult")
    l_result := (TableExistsResult->count > 0)
else
    l_result := .f.
    hb_orm_SendToDebugView([Failed TableExists "]+par_cSchemaAndTableName+[".   Error Text=]+::GetSQLExecErrorMessage())
endif

CloseAlias("TableExistsResult")

return l_result
//-----------------------------------------------------------------------------------------------------------------
method UpdateORMSupportSchema() class hb_orm_SQLConnect
local l_result := .f.   // return .t. if overall schema changed
local l_SQLScript,l_ErrorInfo   // can be removed later, only used during code testing
local l_PreviousSchemaName
local l_Schema := ;
    {"SchemaVersion"=>{;   //Field Definition
      {"pk"     =>{, "I",  0,  0,""};
      ,"name"   =>{{HB_ORM_SCHEMA_MYSQL_OBJECT     ,"CV",254,  0,},;
                   {HB_ORM_SCHEMA_POSTGRESQL_OBJECT, "M",  0,  0,}};
      ,"version"=>{, "I",  0,  0,}};
      ,;   //Index Definition
      NIL};
     ,"SchemaAutoTrimLog" => {;   //Field Definition
      {"pk"           =>{                                , "IB",  0,  0,"+"};
      ,"eventid"      =>{                                ,  "C",HB_ORM_MAX_EVENTID_SIZE,0,"N"};
      ,"datetime"     =>{                                ,"DTZ",  0,  0,};
      ,"ip"           =>{                                ,  "C", 43,  0,};
      ,"schemaname"   =>{HB_ORM_SCHEMA_POSTGRESQL_OBJECT ,  "M",  0,  0,};   /*{{Note: This field will only exists for PostgreSQL databases.}}*/
      ,"tablename"    =>{{HB_ORM_SCHEMA_MYSQL_OBJECT     , "CV",254,  0,},;  /*{{Note: Same field defined differently depending of backend server.}}*/
                         {HB_ORM_SCHEMA_POSTGRESQL_OBJECT,  "M",  0,  0,}};
      ,"recordpk"     =>{                                , "IB",  0,  0,};
      ,"fieldname"    =>{{HB_ORM_SCHEMA_MYSQL_OBJECT     , "CV",254,  0,},;
                         {HB_ORM_SCHEMA_POSTGRESQL_OBJECT,  "M",  0,  0,}};
      ,"fieldtype"    =>{                                ,  "C",  3,  0,};
      ,"fieldlen"     =>{                                ,  "I",  0,  0,};
      ,"fieldvaluer"  =>{                                ,  "R",  0,  0,"N"};
      ,"fieldvaluem"  =>{                                ,  "M",  0,  0,"N"}};
      ,;   //Index Definition
      NIL};
     ,"SchemaAndDataErrorLog" => {;   // _M_ Maybe add a user defined "errornumber" to make easier to search.
      {"pk"           =>{                                , "IB",  0,  0,"+"};
      ,"eventid"      =>{                                ,  "C",HB_ORM_MAX_EVENTID_SIZE,0,"N"};
      ,"datetime"     =>{                                ,"DTZ",  0,  0,};
      ,"ip"           =>{                                ,  "C", 43,  0,};
      ,"schemaname"   =>{HB_ORM_SCHEMA_POSTGRESQL_OBJECT ,  "M",  0,  0,"N"};
      ,"tablename"    =>{{HB_ORM_SCHEMA_MYSQL_OBJECT     , "CV",254,  0,"N"},;
                         {HB_ORM_SCHEMA_POSTGRESQL_OBJECT,  "M",  0,  0,"N"}};
      ,"recordpk"     =>{                                , "IB",  0,  0,"N"};
      ,"errormessage" =>{                                ,  "M",  0,  0,"N"};
      ,"appstack"     =>{                                ,  "M",  0,  0,"N"}};
      ,;   //Index Definition
      NIL};
     ,"SchemaTableNumber" => {;   // Used to get a single number for a table name, to be used with pg_advisory_lock()
      {"pk"           =>{                                ,  "I",  0,  0,"+"};   // Will never have more than 2**32 tables.
      ,"schemaname"   =>{HB_ORM_SCHEMA_POSTGRESQL_OBJECT ,  "M",  0,  0,};
      ,"tablename"    =>{{HB_ORM_SCHEMA_MYSQL_OBJECT     , "CV",254,  0,},;
                         {HB_ORM_SCHEMA_POSTGRESQL_OBJECT,  "M",  0,  0,}}};
      ,;   //Index Definition
      {"schemaname" =>{HB_ORM_SCHEMA_POSTGRESQL_OBJECT,"schemaname",.f.,"BTREE"};   /*{{Note: This index will only exists for PostgreSQL databases.}}*/
      ,"tablename"  =>{                               ,"tablename" ,.f.,"BTREE"}}};
    }

l_PreviousSchemaName := ::SetCurrentSchemaName(::PostgreSQLHBORMSchemaName)

if el_AUnpack(::MigrateSchema(l_Schema),,@l_SQLScript,@l_ErrorInfo) <> 0
    // altd()
    l_result = .t.  // Will assume the schema change worked.
endif

::SetCurrentSchemaName(l_PreviousSchemaName)

return l_result
//-----------------------------------------------------------------------------------------------------------------
method UpdateORMSchemaTableNumber() class hb_orm_SQLConnect
local l_SQLCommand

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    TEXT TO VAR l_SQLCommand
INSERT INTO schematablenumber (tablename)
WITH
ListOfTables AS (
	SELECT DISTINCT
           tables.table_name   as tablename
	 FROM information_schema.tables
	 WHERE tables.table_schema = '-DataBase-'
	 AND   NOT (lower(left(tables.table_name,11)) = 'schemacache')
)
SELECT AllTables.tablename
 FROM ListOfTables AS AllTables
 LEFT OUTER JOIN schematablenumber AS TablesOnFile ON AllTables.tablename = TablesOnFile.tablename
 WHERE TablesOnFile.tablename IS NULL
    ENDTEXT

    l_SQLCommand := strtran(l_SQLCommand,"-DataBase-",::GetDatabase())

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    TEXT TO VAR l_SQLCommand
WITH
ListOfTables AS (
	SELECT DISTINCT
           columns.table_schema::text as schemaname,
           columns.table_name::text   as tablename
	 FROM information_schema.columns
	 WHERE NOT (lower(left(columns.table_name,11)) = 'schemacache' OR lower(columns.table_schema) in ('information_schema','pg_catalog'))
),
ListOfMissingTablesInSchemaTableNumber AS (
    SELECT AllTables.schemaname,
           AllTables.tablename
	 FROM ListOfTables AS AllTables
	 LEFT OUTER JOIN hborm."SchemaTableNumber" AS TablesOnFile ON AllTables.schemaname = TablesOnFile.schemaname and AllTables.tablename = TablesOnFile.tablename
	 WHERE TablesOnFile.tablename IS NULL
)
INSERT INTO hborm."SchemaTableNumber" ("schemaname","tablename") SELECT schemaname,tablename FROM ListOfMissingTablesInSchemaTableNumber;
    ENDTEXT

    if !(::PostgreSQLHBORMSchemaName == "hborm")
        l_SQLCommand := strtran(l_SQLCommand,"hborm",::FormatIdentifier(::PostgreSQLHBORMSchemaName))
    endif

endcase

::SQLExec(l_SQLCommand)

return NIL
//-----------------------------------------------------------------------------------------------------------------
method GetSchemaDefinitionVersion(par_cSchemaDefinitionName) class hb_orm_SQLConnect                         // Since calling ::MigrateSchema() is cumulative with different hSchemaDefinition, each can be named and have a different version.
local l_Version := -1  //To report if failed to retrieve the version number.
local l_SQLCommand
local l_FormattedTableName

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    if ::TableExists("SchemaVersion")
        l_FormattedTableName := ::FormatIdentifier("SchemaVersion")

        l_SQLCommand := [SELECT pk,version]
        l_SQLCommand += [ FROM ]+l_FormattedTableName
        l_SQLCommand += [ WHERE lower(name) = ']+strtran(lower(par_cSchemaDefinitionName),"'","")+[';]
        if ::SQLExec(l_SQLCommand,"SchemaVersion")
            if !empty(SchemaVersion->(reccount()))
                l_Version := SchemaVersion->version
            endif
        else
            ::p_ErrorMessage := [Failed SQL on SchemaVersion (1).]
            hb_orm_SendToDebugView([Failed SQL on SchemaVersion (1).   Error Text=]+::GetSQLExecErrorMessage())
        endif
    endif

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    if ::TableExists(::PostgreSQLHBORMSchemaName+".SchemaVersion")
        l_FormattedTableName := ::FormatIdentifier(::PostgreSQLHBORMSchemaName+[.]+"SchemaVersion")

        l_SQLCommand := [SELECT pk,version]
        l_SQLCommand += [ FROM ]+l_FormattedTableName
        l_SQLCommand += [ WHERE lower(name) = ']+strtran(lower(par_cSchemaDefinitionName),"'","")+[';]

        if ::SQLExec(l_SQLCommand,"SchemaVersion")
            if !empty(SchemaVersion->(reccount()))
                l_Version := SchemaVersion->version
            endif
        else
            ::p_ErrorMessage := [Failed SQL on SchemaVersion (2).]
            hb_orm_SendToDebugView([Failed SQL on SchemaVersion (2).   Error Text=]+::GetSQLExecErrorMessage())
        endif
    endif
endcase


CloseAlias("SchemaVersion")

return l_Version
//-----------------------------------------------------------------------------------------------------------------
method SetSchemaDefinitionVersion(par_cSchemaDefinitionName,par_iVersion) class hb_orm_SQLConnect                         // Since calling ::MigrateSchema() is cumulative with different hSchemaDefinition, each can be named and have a different version.
local l_result := .f.
local l_SQLCommand := ""
local l_FormattedTableName

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_FormattedTableName := ::FormatIdentifier("SchemaVersion")

    l_SQLCommand := [SELECT pk,version]
    l_SQLCommand += [ FROM ]+l_FormattedTableName
    l_SQLCommand += [ WHERE lower(name) = ']+strtran(lower(par_cSchemaDefinitionName),"'","")+[';]

    if ::SQLExec(l_SQLCommand,"SchemaVersion")
        if empty(SchemaVersion->(reccount()))
            //Add an entry
            l_SQLCommand := [INSERT INTO ]+l_FormattedTableName+[ (]
            l_SQLCommand += [name,version]
            l_SQLCommand += [) VALUES (]
            l_SQLCommand += [']+strtran(par_cSchemaDefinitionName,"'","")+[',]+trans(par_iVersion)
            l_SQLCommand += [);]
        else
            //Update Version
            l_SQLCommand := [UPDATE ]+l_FormattedTableName+[ SET ]
            l_SQLCommand += [version=]+trans(par_iVersion)
            l_SQLCommand += [ WHERE pk=]+trans(SchemaVersion->pk)+[;]
        endif
        if ::SQLExec(l_SQLCommand)
            l_result := .t.
        else
            ::p_ErrorMessage := [Failed SQL on SchemaVersion (3).]
            hb_orm_SendToDebugView([Failed SQL on SchemaVersion (3).   Error Text=]+::GetSQLExecErrorMessage())
        endif
    else
        ::p_ErrorMessage := [Failed SQL on SchemaVersion (4).]
        hb_orm_SendToDebugView([Failed SQL on SchemaVersion (4).   Error Text=]+::GetSQLExecErrorMessage())
    endif

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_FormattedTableName := ::FormatIdentifier(::PostgreSQLHBORMSchemaName+[.]+"SchemaVersion")

    l_SQLCommand := [SELECT pk,version]
    l_SQLCommand += [ FROM ]+l_FormattedTableName
    l_SQLCommand += [ WHERE lower(name) = ']+strtran(lower(par_cSchemaDefinitionName),"'","")+[';]

    if ::SQLExec(l_SQLCommand,"SchemaVersion")
        if empty(SchemaVersion->(reccount()))
            //Add an entry
            l_SQLCommand := [INSERT INTO ]+l_FormattedTableName+[ (]
            l_SQLCommand += [name,version]
            l_SQLCommand += [) VALUES (]
            l_SQLCommand += [']+strtran(par_cSchemaDefinitionName,"'","")+[',]+trans(par_iVersion)
            l_SQLCommand += [);]
        else
            //Update Version
            l_SQLCommand := [UPDATE ]+l_FormattedTableName+[ SET ]
            l_SQLCommand += [version=]+trans(par_iVersion)
            l_SQLCommand += [ WHERE pk=]+trans(SchemaVersion->pk)+[;]
        endif
        if ::SQLExec(l_SQLCommand)
            l_result := .t.
        else
            ::p_ErrorMessage := [Failed SQL on SchemaVersion (5).]
            hb_orm_SendToDebugView([Failed SQL on SchemaVersion (5).   Error Text=]+::GetSQLExecErrorMessage())
        endif
    else
        ::p_ErrorMessage := [Failed SQL on SchemaVersion (6).]
        hb_orm_SendToDebugView([Failed SQL on SchemaVersion (6).   Error Text=]+::GetSQLExecErrorMessage())
    endif

endcase

CloseAlias("SchemaVersion")

//Cannot call the Table method from the data object. Not certain why not.
// l_o_data := hb_SQLData(self) 

return l_result
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
static function hb_orm_RootIndexName(par_cSchemaAndTableName,par_cIndexNameOnFile)
local l_cIndexName          := lower(par_cIndexNameOnFile)
local l_cSchemaAndTableName := strtran(par_cSchemaAndTableName,".","_")
if (left(l_cIndexName,len(l_cSchemaAndTableName)+1) == lower(l_cSchemaAndTableName)+"_") .and. right(l_cIndexName,4) == "_idx"
    l_cIndexName := substr(l_cIndexName,len(l_cSchemaAndTableName)+2,len(par_cIndexNameOnFile)-len(l_cSchemaAndTableName)-1-4)
endif
return l_cIndexName
//-----------------------------------------------------------------------------------------------------------------
