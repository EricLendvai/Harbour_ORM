//Copyright (c) 2023 Eric Lendvai, MIT License

#include "hb_orm.ch"
#include "hb_vfp.ch"

#ifndef DONOTINCLUDE   //Will be defined by BuilLib.bat
#include "hb_orm_sqlconnect_class_definition.prg"
#endif

// RND Notes
// autoincrement fields are not null with no default.

//-----------------------------------------------------------------------------------------------------------------
method LoadSchema() class hb_orm_SQLConnect
local l_nSelect := iif(used(),select(),0)
local l_cSQLCommand
local l_cSQLCommandFields  := ""
local l_cSQLCommandIndexes := ""
local l_cFieldType,l_nFieldLen,l_nFieldDec,l_lFieldAllowNull,l_lFieldAutoIncrement,l_lFieldArray,l_cFieldComment,l_cFieldDefault
local l_cTableName,l_cTableNameLast
local l_cSchemaAndTableName,l_cSchemaAndTableNameLast
local l_cIndexName,l_cIndexDefinition,l_cIndexExpression,l_lIndexUnique,l_cIndexType
local l_hSchemaFields  := {=>}
local l_hSchemaIndexes := {=>}
local l_nPos1,l_nPos2,l_nPos3,l_nPos4
local l_lLoadedCache
local l_cFieldCommentType
local l_nFieldCommentLength

hb_orm_SendToDebugView("In LoadSchema")

hb_HCaseMatch(l_hSchemaFields ,.f.)
hb_HCaseMatch(l_hSchemaIndexes,.f.)
hb_HClear(::p_Schema)
hb_HCaseMatch(::p_Schema,.f.)

CloseAlias("hb_orm_sqlconnect_schema_fields")
CloseAlias("hb_orm_sqlconnect_schema_indexes")

::p_SchemaCacheLogLastPk := 0

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cSQLCommandFields  += [SELECT columns.table_name                 AS table_name,]
    l_cSQLCommandFields  +=        [columns.ordinal_position           AS field_position,]
    l_cSQLCommandFields  +=        [columns.column_name                AS field_name,]
    l_cSQLCommandFields  +=        [columns.data_type                  AS field_type,]
    l_cSQLCommandFields  +=        [columns.column_comment             AS field_comment,]
    l_cSQLCommandFields  +=        [columns.character_maximum_length   AS field_clength,]
    l_cSQLCommandFields  +=        [columns.numeric_precision          AS field_nlength,]
    l_cSQLCommandFields  +=        [columns.datetime_precision         AS field_tlength,]
    l_cSQLCommandFields  +=        [columns.numeric_scale              AS field_decimals,]
    l_cSQLCommandFields  +=        [(columns.is_nullable = 'YES')      AS field_nullable,]
    l_cSQLCommandFields  +=        [FALSE                              AS field_array,]
    l_cSQLCommandFields  +=        [columns.column_default             AS field_default,]
    l_cSQLCommandFields  +=        [(columns.extra = 'auto_increment') AS field_auto_increment,]
    l_cSQLCommandFields  +=        [upper(columns.table_name)          AS tag1]
    l_cSQLCommandFields  += [ FROM information_schema.columns]
    l_cSQLCommandFields  += [ WHERE columns.table_schema = ']+::p_Database+[']
    l_cSQLCommandFields  += [ AND   lower(left(columns.table_name,11)) != 'schemacache']
    l_cSQLCommandFields  += [ ORDER BY tag1,field_position]

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
    //        (columns.extra = 'auto_increment') AS field_auto_increment,
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
    //        (columns.extra = 'auto_increment') AS field_auto_increment,
    //        upper(columns.table_name)          AS tag1
    //  FROM information_schema.columns
    //  WHERE columns.table_schema = 'test004'
    //  AND   lower(left(columns.table_name,11)) != 'schemacache'
    //  ORDER BY tag1,field_position


    l_cSQLCommandIndexes += [SELECT table_name,]
    l_cSQLCommandIndexes +=        [index_name,]
    l_cSQLCommandIndexes +=        [group_concat(column_name order by seq_in_index) AS index_columns,]
    l_cSQLCommandIndexes +=        [index_type,]
    l_cSQLCommandIndexes +=        [CASE non_unique]
    l_cSQLCommandIndexes +=        [     WHEN 1 then 0]
    l_cSQLCommandIndexes +=        [     ELSE 1]
    l_cSQLCommandIndexes +=        [     END AS is_unique]
    l_cSQLCommandIndexes += [ FROM information_schema.statistics]
    l_cSQLCommandIndexes += [ WHERE table_schema NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')]
    l_cSQLCommandIndexes += [ AND   index_schema = ']+::p_Database+[']
    l_cSQLCommandIndexes += [ AND   lower(left(table_name,11)) != 'schemacache']
    l_cSQLCommandIndexes += [ GROUP BY table_name,index_name]
    l_cSQLCommandIndexes += [ ORDER BY index_schema,table_name,index_name;]


    if !::SQLExec(l_cSQLCommandFields,"hb_orm_sqlconnect_schema_fields")
        ::p_ErrorMessage := [Failed SQL for hb_orm_sqlconnect_schema_fields.]
        // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_cSQLCommandFields+[ -> ]+::p_ErrorMessage)
    elseif !::SQLExec(l_cSQLCommandIndexes,"hb_orm_sqlconnect_schema_indexes")
        ::p_ErrorMessage := [Failed SQL for hb_orm_sqlconnect_schema_indexes.]
    else
        if used("hb_orm_sqlconnect_schema_fields") .and. used("hb_orm_sqlconnect_schema_indexes")
            select hb_orm_sqlconnect_schema_fields
            if Reccount() > 0
                l_cTableNameLast := Trim(hb_orm_sqlconnect_schema_fields->table_name)
                hb_HClear(l_hSchemaFields)
                scan all
                    l_cTableName := Trim(hb_orm_sqlconnect_schema_fields->table_name)
                    if !(l_cTableName == l_cTableNameLast)  // Method to for an exact not equal
// if upper(l_cTableNameLast) == upper("table003")
//     altd()
// endif
                        ::p_Schema[l_cTableNameLast] := {hb_hClone(l_hSchemaFields),NIL}    //{Table Fields, Table Indexes}
                        hb_HClear(l_hSchemaFields)
                        l_cTableNameLast := l_cTableName
                    endif

// if upper(field->field_Name) == upper("VarChar52")
//     altd()
// endif

// if upper(field->field_Name) == upper("boolean") .and. upper(l_cTableName) == upper("table003")
//     altd()
// endif

                    //Parse the comment field to see if recorded the field type and its length
                    l_cFieldCommentType   := ""
                    l_nFieldCommentLength := 0
                    l_cFieldComment := nvl(field->field_comment,"")

                    l_cFieldComment := upper(MemoLine(l_cFieldComment,1000,1))  // Extract first line of comment, max 1000 char length
                    if !empty(l_cFieldComment) 
                        l_nPos1 := at("|",l_cFieldComment)
                        l_nPos2 := at("TYPE=",l_cFieldComment)
                        l_nPos3 := at("LENGTH=",l_cFieldComment)
                        if l_nPos1 > 0 .and. l_nPos2 > 0 .and. l_nPos3 > 0
                            l_cFieldCommentType   := Alltrim(substr(l_cFieldComment,l_nPos2+len("TYPE="),l_nPos1-(l_nPos2+len("TYPE="))))
                            l_nFieldCommentLength := Val(substr(l_cFieldComment,l_nPos3+len("LENGTH=")))
                        elseif l_nPos2 > 0
                            l_cFieldCommentType   := Alltrim(substr(l_cFieldComment,l_nPos2+len("TYPE=")))
                            l_nFieldCommentLength := 0
                        endif
                    endif

                    switch trim(field->field_type)
                    case "int"
                        l_cFieldType          := "I"
                        l_nFieldLen           := 0
                        l_nFieldDec           := 0
                        exit
                    case "bigint"
                        l_cFieldType          := "IB"
                        l_nFieldLen           := 0
                        l_nFieldDec           := 0
                        exit
                    case "smallint"
                        l_cFieldType          := "IS"
                        l_nFieldLen           := 0
                        l_nFieldDec           := 0
                        exit
                    case "decimal"
                        if l_cFieldCommentType == "Y"
                            l_cFieldType      := "Y"
                            l_nFieldLen       := 0
                            l_nFieldDec       := 0
                        else
                            l_cFieldType      := "N"
                            l_nFieldLen       := field->field_nlength
                            l_nFieldDec       := field->field_decimals
                        endif
                        exit
                    case "char"
                        if l_cFieldCommentType == "UUI"
                            l_cFieldType      := "UUI"
                            l_nFieldLen       := 0
                            l_nFieldDec       := 0
                        else
                            l_cFieldType          := "C"
                            l_nFieldLen           := field->field_clength
                            l_nFieldDec           := 0
                        endif
                        exit
                    case "varchar"
                        if l_cFieldCommentType == "UUI"     // Left this test since this was a previous implementation method
                            l_cFieldType      := "UUI"
                            l_nFieldLen       := 0
                            l_nFieldDec       := 0
                        else
                            l_cFieldType          := "CV"
                            l_nFieldLen           := field->field_clength
                            l_nFieldDec           := 0
                        endif
                        exit
                    case "binary"
                        l_cFieldType          := "B"
                        l_nFieldLen           := field->field_clength
                        l_nFieldDec           := 0
                        exit
                    case "varbinary"
                        l_cFieldType          := "BV"
                        l_nFieldLen           := field->field_clength
                        l_nFieldDec           := 0
                        exit
                    case "longtext"
                        if l_cFieldCommentType == "JS"
                            l_cFieldType      := "JS"
                            l_nFieldLen       := 0
                            l_nFieldDec       := 0
                        else
                            l_cFieldType          := "M"
                            l_nFieldLen           := 0
                            l_nFieldDec           := 0
                        endif
                        exit
                    case "longblob"
                        l_cFieldType          := "R"
                        l_nFieldLen           := 0
                        l_nFieldDec           := 0
                        exit
                    case "tinyint"  //Used as Boolean
                        l_cFieldType          := "L"
                        l_nFieldLen           := 0
                        l_nFieldDec           := 0
                        exit
                    case "date"
                        l_cFieldType          := "D"
                        l_nFieldLen           := 0
                        l_nFieldDec           := 0
                        exit
                    case "time"  //Time Only part of datetime     MySQL does not make the difference between with our without time zone  "TOZ" -> "TO"
                        if l_cFieldCommentType == "TOZ"
                            l_cFieldType      := "TOZ"
                        else
                            l_cFieldType      := "TO"
                        endif
                        l_nFieldLen           := 0
                        l_nFieldDec           := field->field_tlength
                        exit
                    case "timestamp"
                        l_cFieldType          := "DTZ"
                        l_nFieldLen           := 0
                        l_nFieldDec           := field->field_tlength
                        exit
                    case "datetime"
                        l_cFieldType          := "DT"        // Same as "T"
                        l_nFieldLen           := 0
                        l_nFieldDec           := field->field_tlength
                        exit
                    // case "bit"   //bit mask
                    //     l_cFieldType          := "BT"
                    //     l_nFieldLen           := field->field_nlength
                    //     l_nFieldDec           := 0
                    //     exit
                    otherwise
                        l_cFieldType          := "?"
                        l_nFieldLen           := 0
                        l_nFieldDec           := 0
                    endswitch

                    l_lFieldAllowNull     := (field->field_nullable == 1)
                    l_lFieldAutoIncrement := (field->field_auto_increment == 1)
                    l_lFieldArray         := .f.

                    // l_cFieldDefault       := field->field_default
                    // if !hb_IsNIL(l_cFieldDefault)
                        l_cFieldDefault := ::SanitizeFieldDefaultFromDefaultBehavior(::p_SQLEngineType,l_cFieldType,iif(l_lFieldAllowNull,"N","")+iif(l_lFieldAutoIncrement,"+","")+iif(l_lFieldArray,"A",""),field->field_default)
                    // endif

                    l_hSchemaFields[trim(field->field_Name)] := {,;
                                                                 l_cFieldType,;
                                                                 l_nFieldLen,;
                                                                 l_nFieldDec,;
                                                                 iif(l_lFieldAllowNull,"N","")+iif(l_lFieldAutoIncrement,"+","")+iif(l_lFieldArray,"A",""),;
                                                                 l_cFieldDefault}

                endscan

// if upper(l_cTableNameLast) == upper("table003")
//     altd()
// endif
                ::p_Schema[l_cTableNameLast] := {hb_hClone(l_hSchemaFields),NIL}    //{Table Fields, Table Indexes}
                hb_HClear(l_hSchemaFields)

                //Since Indexes could only exists for an existing table we simply assign to a ::p_Schema[][HB_ORM_SCHEMA_INDEX] cell
                select hb_orm_sqlconnect_schema_indexes
                if Reccount() > 0
                    l_cTableNameLast := Trim(hb_orm_sqlconnect_schema_indexes->table_name)
                    hb_HClear(l_hSchemaIndexes)

                    scan all
                        l_cTableName := Trim(hb_orm_sqlconnect_schema_indexes->table_name)

                        //Test that the index is for a real table, not a view or other type of objects. Since we used "tables.table_type = 'BASE TABLE'" earlier we need to check if we loaded that table in the p_schema
                        if hb_HHasKey(::p_Schema,l_cTableName)

                            if !(l_cTableName == l_cTableNameLast)
                                if len(l_hSchemaIndexes) > 0
                                    ::p_Schema[l_cTableNameLast][HB_ORM_SCHEMA_INDEX] := hb_hClone(l_hSchemaIndexes)
                                    hb_HClear(l_hSchemaIndexes)
                                else
                                    ::p_Schema[l_cTableNameLast][HB_ORM_SCHEMA_INDEX] := NIL
                                endif
                                l_cTableNameLast := l_cTableName
                            endif

                            l_cIndexName := lower(trim(field->index_name))
                            if left(l_cIndexName,len(l_cTableName)+1) == lower(l_cTableName)+"_" .and. right(l_cIndexName,4) == "_idx"  // only record indexes maintained by hb_orm
                                l_cIndexName      := hb_orm_RootIndexName(l_cTableName,l_cIndexName)

                                l_cIndexExpression := trim(field->index_columns)
                                if !(lower(l_cIndexExpression) == lower(::p_PrimaryKeyFieldName))   // No reason to record the index of the PRIMARY key
                                    l_lIndexUnique     := (field->is_unique == 1)
                                    l_cIndexType       := field->index_type
                                    l_hSchemaIndexes[l_cIndexName] := {,l_cIndexExpression,l_lIndexUnique,l_cIndexType}
                                endif
                            endif
                        endif
                    endscan

                    if len(l_hSchemaIndexes) > 0
                        ::p_Schema[l_cTableNameLast][HB_ORM_SCHEMA_INDEX] := hb_hClone(l_hSchemaIndexes)
                        hb_HClear(l_hSchemaIndexes)
                    else
                        ::p_Schema[l_cTableNameLast][HB_ORM_SCHEMA_INDEX] := NIL
                    endif

                endif

            endif

            // scan all for lower(trim(field->table_name)) == l_cTableName_lower
            // HB_ORM_OUTPUTDEBUGSTRING("[Harbour] "+lower(trim(field->field_Name)) )
            // HB_ORM_OUTPUTDEBUGSTRING("[Harbour] "+lower(trim(field->field_type)) )

        endif

    endif


case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_lLoadedCache := .f.

    //Find out if there is cached schema
    TEXT TO VAR l_cSQLCommand
SELECT pk
 FROM  hborm."SchemaCacheLog"
 WHERE cachedschema
 ORDER BY pk DESC
 LIMIT 1
    ENDTEXT

    if ::PostgreSQLIdentifierCasing != HB_ORM_POSTGRESQL_CASE_SENSITIVE
        l_cSQLCommand := Strtran(l_cSQLCommand,"SchemaCacheLog","schemacachelog")
    endif

    if !(::PostgreSQLHBORMSchemaName == "hborm")
        l_cSQLCommand := strtran(l_cSQLCommand,"hborm",::FormatIdentifier(::PostgreSQLHBORMSchemaName))
    endif

    if ::SQLExec(l_cSQLCommand,"SchemaCacheLogLast")
        if SchemaCacheLogLast->(reccount()) > 0

            l_cSQLCommandFields  := [SELECT schema_name,]
            l_cSQLCommandFields  +=        [table_name,]
            l_cSQLCommandFields  +=        [field_position,]
            l_cSQLCommandFields  +=        [field_name,]
            l_cSQLCommandFields  +=        [field_type,]
            l_cSQLCommandFields  +=        [field_clength,]
            l_cSQLCommandFields  +=        [field_nlength,]
            l_cSQLCommandFields  +=        [field_tlength,]
            l_cSQLCommandFields  +=        [field_decimals,]
            l_cSQLCommandFields  +=        [field_nullable,]
            l_cSQLCommandFields  +=        [field_array,]
            l_cSQLCommandFields  +=        [field_default,]
            l_cSQLCommandFields  +=        [field_auto_increment,]
            l_cSQLCommandFields  +=        [field_comment,]
            l_cSQLCommandFields  +=        [tag1,]
            l_cSQLCommandFields  +=        [tag2]
            // l_cSQLCommandFields  += [ FROM ]+::FormatIdentifier(::PostgreSQLHBORMSchemaName)+::FixCasingOfSchemaCacheTables([."SchemaCacheFields_])+trans(SchemaCacheLogLast->pk)+["]
            l_cSQLCommandFields  += [ FROM ]+::FormatIdentifier(::PostgreSQLHBORMSchemaName)+::FixCasingOfSchemaCacheTables([."SchemaCacheFields_])+[p_SchemaCacheLogLastPk]+["]
            l_cSQLCommandFields  += [ ORDER BY tag1,tag2,field_position]


            l_cSQLCommandIndexes := [SELECT schema_name,]
            l_cSQLCommandIndexes +=        [table_name,]
            l_cSQLCommandIndexes +=        [index_name,]
            l_cSQLCommandIndexes +=        [index_definition,]
            l_cSQLCommandIndexes +=        [tag1,]
            l_cSQLCommandIndexes +=        [tag2]
            // l_cSQLCommandIndexes += [ FROM ]+::FormatIdentifier(::PostgreSQLHBORMSchemaName)+::FixCasingOfSchemaCacheTables([."SchemaCacheIndexes_])+trans(SchemaCacheLogLast->pk)+["]
            l_cSQLCommandIndexes += [ FROM ]+::FormatIdentifier(::PostgreSQLHBORMSchemaName)+::FixCasingOfSchemaCacheTables([."SchemaCacheIndexes_])+[p_SchemaCacheLogLastPk]+["]
            l_cSQLCommandIndexes += [ ORDER BY tag1,tag2,index_name]

            if       ::SQLExec(strtran(l_cSQLCommandFields ,"p_SchemaCacheLogLastPk",trans(SchemaCacheLogLast->pk)),"hb_orm_sqlconnect_schema_fields") ;
               .and. ::SQLExec(strtran(l_cSQLCommandIndexes,"p_SchemaCacheLogLastPk",trans(SchemaCacheLogLast->pk)),"hb_orm_sqlconnect_schema_indexes")
                l_lLoadedCache := .t.
                ::p_SchemaCacheLogLastPk := SchemaCacheLogLast->pk
            else
                CloseAlias("hb_orm_sqlconnect_schema_fields")
                CloseAlias("hb_orm_sqlconnect_schema_indexes")
                ::EnableSchemaChangeTracking()
                ::UpdateSchemaCache(.t.)

                if ::SQLExec(l_cSQLCommand,"SchemaCacheLogLast")
                    if       ::SQLExec(strtran(l_cSQLCommandFields ,"p_SchemaCacheLogLastPk",trans(SchemaCacheLogLast->pk)),"hb_orm_sqlconnect_schema_fields") ;
                       .and. ::SQLExec(strtran(l_cSQLCommandIndexes,"p_SchemaCacheLogLastPk",trans(SchemaCacheLogLast->pk)),"hb_orm_sqlconnect_schema_indexes")
                        l_lLoadedCache := .t.
                        ::p_SchemaCacheLogLastPk := SchemaCacheLogLast->pk
                    endif
                endif
            endif

            if !l_lLoadedCache
                CloseAlias("hb_orm_sqlconnect_schema_fields")
                CloseAlias("hb_orm_sqlconnect_schema_indexes")
            endif

        endif
    endif

    // Will no longer support loading directly, due to performance since can not "SET enable_nestloop = false"
    // if !l_lLoadedCache
    //     // Load from Live information_schema
    //     l_cSQLCommandFields  := [SELECT columns.table_schema             AS schema_name,]
    //     l_cSQLCommandFields  +=        [columns.table_name               AS table_name,]
    //     l_cSQLCommandFields  +=        [columns.ordinal_position         AS field_position,]
    //     l_cSQLCommandFields  +=        [columns.column_name              AS field_name,]
    //     l_cSQLCommandFields  +=        [columns.data_type                AS field_type,]
    //     l_cSQLCommandFields  +=        [columns.character_maximum_length AS field_clength,]
    //     l_cSQLCommandFields  +=        [columns.numeric_precision        AS field_nlength,]
    //     l_cSQLCommandFields  +=        [columns.datetime_precision       AS field_tlength,]
    //     l_cSQLCommandFields  +=        [columns.numeric_scale            AS field_decimals,]
    //     l_cSQLCommandFields  +=        [(columns.is_nullable = 'YES')    AS field_nullable,]
    //     //_M_
    //     l_cSQLCommandFields  +=        [columns.column_default           AS field_default,]
    //     l_cSQLCommandFields  +=        [(columns.is_identity = 'YES')    AS field_auto_increment,]
    //     l_cSQLCommandFields  +=        [pgd.description                  AS field_comment,]
    //     l_cSQLCommandFields  +=        [upper(columns.table_schema)      AS tag1,]
    //     l_cSQLCommandFields  +=        [upper(columns.table_name)        AS tag2]
    //     l_cSQLCommandFields  +=  [ FROM information_schema.columns]
    //     l_cSQLCommandFields  +=  [ INNER JOIN pg_catalog.pg_statio_all_tables as st ON columns.table_schema = st.schemaname and columns.table_name = st.relname]
    //     l_cSQLCommandFields  +=  [ INNER JOIN information_schema.tables             ON columns.table_schema = tables.table_schema AND columns.table_name = tables.table_name]
    //     l_cSQLCommandFields  +=  [ LEFT JOIN pg_catalog.pg_description pgd          ON pgd.objoid=st.relid and pgd.objsubid=columns.ordinal_position]
    //     l_cSQLCommandFields  +=  [ WHERE NOT (lower(left(columns.table_name,11)) = 'schemacache' OR lower(columns.table_schema) in ('information_schema','pg_catalog'))]
    //     l_cSQLCommandFields  +=  [ AND   tables.table_type = 'BASE TABLE']
    //     l_cSQLCommandFields  +=  [ ORDER BY tag1,tag2,field_position]


    //     l_cSQLCommandIndexes := [SELECT pg_indexes.schemaname        AS schema_name,]
    //     l_cSQLCommandIndexes +=        [pg_indexes.tablename         AS table_name,]
    //     l_cSQLCommandIndexes +=        [pg_indexes.indexname         AS index_name,]
    //     l_cSQLCommandIndexes +=        [pg_indexes.indexdef          AS index_definition,]
    //     l_cSQLCommandIndexes +=        [upper(pg_indexes.schemaname) AS tag1,]
    //     l_cSQLCommandIndexes +=        [upper(pg_indexes.tablename)  AS tag2]
    //     l_cSQLCommandIndexes += [ FROM pg_indexes]
    //     l_cSQLCommandIndexes += [ WHERE NOT (lower(left(pg_indexes.tablename,11)) = 'schemacache' OR lower(pg_indexes.schemaname) in ('information_schema','pg_catalog'))]
    //     l_cSQLCommandIndexes += [ ORDER BY tag1,tag2,index_name]

    // endif

    // if !l_lLoadedCache .and. !::SQLExec(l_cSQLCommandFields,"hb_orm_sqlconnect_schema_fields")
    //     ::p_ErrorMessage := [Failed SQL for hb_orm_sqlconnect_schema_fields.]
    //     // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_cSQLCommandFields+[ -> ]+::p_ErrorMessage)

    // elseif !l_lLoadedCache .and. !::SQLExec(l_cSQLCommandIndexes,"hb_orm_sqlconnect_schema_indexes")
    //     ::p_ErrorMessage := [Failed SQL for hb_orm_sqlconnect_schema_indexes.]

    if !(used("hb_orm_sqlconnect_schema_fields") .and. used("hb_orm_sqlconnect_schema_indexes"))
        ::p_ErrorMessage := [Failed load cached PostgreSQL schema.]
    else
        

// select hb_orm_sqlconnect_schema_indexes
// ExportTableToHtmlFile("hb_orm_sqlconnect_schema_indexes","d:\SchemaIndexes.html","Cache",,,.t.)

            select hb_orm_sqlconnect_schema_fields

// if l_UsingCachedSchema
//     ExportTableToHtmlFile("hb_orm_sqlconnect_schema_fields","d:\SchemaFields_cache.html","Cache",,,.t.)
// else
//     ExportTableToHtmlFile("hb_orm_sqlconnect_schema_fields","d:\SchemaFields_live.html","No Cache",,,.t.)
// endif

// altd()

// set filter to field->table_name = "table003"
// ExportTableToHtmlFile("hb_orm_sqlconnect_schema_fields","PostgreSQL_information_schema.html","PostgreSQL Schema",,25)
// set filter to

        if Reccount() > 0
            l_cSchemaAndTableNameLast := Trim(hb_orm_sqlconnect_schema_fields->schema_name)+"."+Trim(hb_orm_sqlconnect_schema_fields->table_name)
            hb_HClear(l_hSchemaFields)

            scan all
                l_cSchemaAndTableName := Trim(hb_orm_sqlconnect_schema_fields->schema_name)+"."+Trim(hb_orm_sqlconnect_schema_fields->table_name)
                if !(l_cSchemaAndTableName == l_cSchemaAndTableNameLast)
                    ::p_Schema[l_cSchemaAndTableNameLast] := {hb_hClone(l_hSchemaFields),NIL}    //{Table Fields (HB_ORM_SCHEMA_FIELD), Table Indexes (HB_ORM_SCHEMA_INDEX)}
                    hb_HClear(l_hSchemaFields)
                    l_cSchemaAndTableNameLast := l_cSchemaAndTableName
                endif

// if upper(field->field_Name) == upper("DateTime")
//     altd()
// endif

// "set001"."alltypes"
// if upper(l_cSchemaAndTableName) == upper("set001.alltypes") .and. upper(field->field_Name) == upper("nvalue")
//     altd()
// endif

                //Parse the comment field to see if recorded the field type and its length
                l_cFieldCommentType   := ""
                l_nFieldCommentLength := 0
                l_cFieldComment := nvl(field->field_comment,"")

                // if upper(trim(field->field_Name)) == "BINARY10"
                //     altd()
                // endif

                l_cFieldComment := upper(MemoLine(l_cFieldComment,1000,1))  // Extract first line of comment, max 1000 char length.   example:  Type=BV|Length=5  or Type=TOZ
                if !empty(l_cFieldComment) 
                    l_nPos1 := at("|",l_cFieldComment)
                    l_nPos2 := at("TYPE=",l_cFieldComment)
                    l_nPos3 := at("LENGTH=",l_cFieldComment)
                    if l_nPos1 > 0 .and. l_nPos2 > 0 .and. l_nPos3 > 0
                        l_cFieldCommentType   := Alltrim(substr(l_cFieldComment,l_nPos2+len("TYPE="),l_nPos1-(l_nPos2+len("TYPE="))))
                        l_nFieldCommentLength := Val(substr(l_cFieldComment,l_nPos3+len("LENGTH=")))
                    elseif l_nPos2 > 0
                        l_cFieldCommentType   := Alltrim(substr(l_cFieldComment,l_nPos2+len("TYPE=")))
                        l_nFieldCommentLength := 0
                    endif
                endif


                switch trim(field->field_type)
                case "integer"
                    l_cFieldType          := "I"      //  (4 bytes)
                    l_nFieldLen           := 0
                    l_nFieldDec           := 0
                    exit
                case "bigint"
                    l_cFieldType          := "IB"    // Integer Big (8 bytes)
                    l_nFieldLen           := 0
                    l_nFieldDec           := 0
                    exit
                case "smallint"
                    l_cFieldType          := "IS"    // Integer Small (2 bytes)
                    l_nFieldLen           := 0
                    l_nFieldDec           := 0
                    exit
                case "numeric"
                    l_cFieldType          := "N"
                    l_nFieldLen           := field->field_nlength
                    l_nFieldDec           := field->field_decimals
                    exit
                case "character"
                    l_cFieldType          := "C"
                    l_nFieldLen           := field->field_clength
                    l_nFieldDec           := 0
                    exit
                case "character varying"
                    l_cFieldType          := "CV"
                    l_nFieldLen           := field->field_clength
                    l_nFieldDec           := 0
                    exit
                case "text"
                    l_cFieldType          := "M"
                    l_nFieldLen           := 0
                    l_nFieldDec           := 0
                    exit
                case "bytea"  // Raw Binary
                    do case
                    case l_cFieldCommentType == "B"  .and. l_nFieldCommentLength > 0    // Binary fixed length
                        l_cFieldType          := "B"
                        l_nFieldLen           := l_nFieldCommentLength
                        l_nFieldDec           := 0
                    case l_cFieldCommentType == "BV" .and. l_nFieldCommentLength > 0    // Binary variable length
                        l_cFieldType          := "BV"
                        l_nFieldLen           := l_nFieldCommentLength
                        l_nFieldDec           := 0
                    otherwise 
                        l_cFieldType          := "R"
                        l_nFieldLen           := 0
                        l_nFieldDec           := 0
                    endcase
                    exit
                case "boolean"
                    l_cFieldType          := "L"
                    l_nFieldLen           := 0
                    l_nFieldDec           := 0
                    exit
                case "date"
                    l_cFieldType          := "D"
                    l_nFieldLen           := 0
                    l_nFieldDec           := 0
                    exit
                case "time"                           //Time Only With Time Zone Conversion
                case "time with time zone"            //Time Only With Time Zone Conversion
                    l_cFieldType          := "TOZ"
                    l_nFieldLen           := 0
                    l_nFieldDec           := field->field_tlength
                    exit
                case "time without time zone"         //Time Only Without Time Zone Conversion
                    l_cFieldType          := "TO"
                    l_nFieldLen           := 0
                    l_nFieldDec           := field->field_tlength
                    exit
                case "timestamp"                     //date and time With Time Zone Conversion
                case "timestamp with time zone"      //date and time With Time Zone Conversion
                    l_cFieldType          := "DTZ"
                    l_nFieldLen           := 0
                    l_nFieldDec           := field->field_tlength
                    exit
                case "timestamp without time zone"   //date and time Without Time Zone Conversion
                    l_cFieldType          := "DT"     //Is DBF equivalent for "T"
                    l_nFieldLen           := 0
                    l_nFieldDec           := field->field_tlength
                    exit
                case "money"
                    l_cFieldType          := "Y"
                    l_nFieldLen           := 0
                    l_nFieldDec           := 0
                    exit
                case "uuid"
                    l_cFieldType      := "UUI"
                    l_nFieldLen       := 0
                    l_nFieldDec       := 0
                    exit
                case "json"
                    l_cFieldType      := "JS"
                    l_nFieldLen       := 0
                    l_nFieldDec       := 0
                    exit
                otherwise
                    l_cFieldType          := "?"
                    l_nFieldLen           := 0
                    l_nFieldDec           := 0
                endswitch

                l_lFieldAllowNull     := field->field_nullable
                l_lFieldAutoIncrement := field->field_auto_increment                    //{"I",,,,.t.}
                l_lFieldArray         := field->field_array

                // l_cFieldDefault       := field->field_default
                // if !hb_IsNIL(l_cFieldDefault)

// if "'1'::numeric" $ nvl(field->field_default,"")
//     altd()
// endif

                    l_cFieldDefault := ::SanitizeFieldDefaultFromDefaultBehavior(::p_SQLEngineType,l_cFieldType,iif(l_lFieldAllowNull,"N","")+iif(l_lFieldAutoIncrement,"+","")+iif(l_lFieldArray,"A",""),field->field_default)
                // endif

                l_hSchemaFields[trim(field->field_Name)] := {,;
                                                                l_cFieldType,;
                                                                l_nFieldLen,;
                                                                l_nFieldDec,;
                                                                iif(l_lFieldAllowNull,"N","")+iif(l_lFieldAutoIncrement,"+","")+iif(l_lFieldArray,"A",""),;
                                                                l_cFieldDefault}

            endscan

            ::p_Schema[l_cSchemaAndTableNameLast] := {hb_hClone(l_hSchemaFields),NIL}    //{Table Fields (HB_ORM_SCHEMA_FIELD), Table Indexes (HB_ORM_SCHEMA_INDEX)}
            hb_HClear(l_hSchemaFields)

            //Since Indexes could only exists for an existing table we simply assign to a ::p_Schema[][HB_ORM_SCHEMA_INDEX] cell
            select hb_orm_sqlconnect_schema_indexes
            if Reccount() > 0
                l_cSchemaAndTableNameLast := Trim(hb_orm_sqlconnect_schema_indexes->schema_name)+"."+Trim(hb_orm_sqlconnect_schema_indexes->table_name)
                hb_HClear(l_hSchemaIndexes)

                scan all
                    l_cSchemaAndTableName := Trim(hb_orm_sqlconnect_schema_indexes->schema_name)+"."+Trim(hb_orm_sqlconnect_schema_indexes->table_name)

                    //Test that the index is for a real table, not a view or other type of objects. Since we used "tables.table_type = 'BASE TABLE'" earlier we need to check if we loaded that table in the p_schema
                    if hb_HHasKey(::p_Schema,l_cSchemaAndTableName)

                        if !(l_cSchemaAndTableName == l_cSchemaAndTableNameLast)
                            if len(l_hSchemaIndexes) > 0
                                ::p_Schema[l_cSchemaAndTableNameLast][HB_ORM_SCHEMA_INDEX] := hb_hClone(l_hSchemaIndexes)
                                hb_HClear(l_hSchemaIndexes)
                            else
                                ::p_Schema[l_cSchemaAndTableNameLast][HB_ORM_SCHEMA_INDEX] := NIL
                            endif
                            l_cSchemaAndTableNameLast := l_cSchemaAndTableName
                        endif

                        l_cIndexName := lower(trim(field->index_name))
                        if left(l_cIndexName,len(l_cSchemaAndTableName)+1) == lower(strtran(l_cSchemaAndTableName,".","_"))+"_" .and. right(l_cIndexName,4) == "_idx"
                            l_cIndexName      := hb_orm_RootIndexName(l_cSchemaAndTableName,l_cIndexName)
                            
                            l_cIndexDefinition := field->index_definition
                            l_nPos1 := hb_ati(" USING ",l_cIndexDefinition)
                            if l_nPos1 > 0
                                l_nPos2 := hb_at(" ",l_cIndexDefinition,l_nPos1+1)
                                l_nPos3 := hb_at("(",l_cIndexDefinition,l_nPos1)
                                l_nPos4 := hb_rat(")",l_cIndexDefinition,l_nPos1)
                                l_cIndexExpression := substr(l_cIndexDefinition,l_nPos3+1,l_nPos4-l_nPos3-1)

                                if !(lower(l_cIndexExpression) == lower(::p_PrimaryKeyFieldName))   // No reason to record the index of the PRIMARY key
                                    l_lIndexUnique     := ("UNIQUE INDEX" $ l_cIndexDefinition)
                                    l_cIndexType       := upper(substr(l_cIndexDefinition,l_nPos2+1,l_nPos3-l_nPos2-2))
                                    l_hSchemaIndexes[l_cIndexName] := {,l_cIndexExpression,l_lIndexUnique,l_cIndexType}
                                endif

                            endif
                        endif
                    endif
                endscan
                if len(l_hSchemaIndexes) > 0
                    ::p_Schema[l_cSchemaAndTableNameLast][HB_ORM_SCHEMA_INDEX] := hb_hClone(l_hSchemaIndexes)
                    hb_HClear(l_hSchemaIndexes)
                else
                    ::p_Schema[l_cSchemaAndTableNameLast][HB_ORM_SCHEMA_INDEX] := NIL
                endif

            endif

        endif

        // scan all for lower(trim(field->table_name)) == l_cSchemaAndTableName_lower
        // HB_ORM_OUTPUTDEBUGSTRING("[Harbour] "+lower(trim(field->field_Name)) )
        // HB_ORM_OUTPUTDEBUGSTRING("[Harbour] "+lower(trim(field->field_type)) )

    endif

endcase

CloseAlias("hb_orm_sqlconnect_schema_fields")
CloseAlias("hb_orm_sqlconnect_schema_indexes")

select (l_nSelect)

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
local l_cFieldType,       l_lFieldArray,       l_nFieldLen,       l_nFieldDec,       l_cFieldAttributes,       l_lFieldAllowNull,       l_lFieldAutoIncrement,       l_cFieldDefault
local l_cCurrentFieldType,l_lCurrentFieldArray,l_nCurrentFieldLen,l_nCurrentFieldDec,l_cCurrentFieldAttributes,l_lCurrentFieldAllowNull,l_lCurrentFieldAutoIncrement,l_cCurrentFieldDefault
local l_lMatchingFieldDefinition
local l_cCurrentSchemaName,l_cSchemaName
local l_cSQLScriptPreUpdate := ""
local l_cSQLScript := ""
local l_cSQLScriptPostUpdate := ""
local l_cSQLScriptFieldChanges,l_cSQLScriptFieldChangesCycle1,l_cSQLScriptFieldChangesCycle2
local l_cSchemaAndTableName
local l_cFormattedTableName
local l_cBackendType := ""
local l_nPos
local l_hListOfSchemaName := {=>}
local l_hSchemaName
local l_cSQLScriptCreateSchemaName := ""

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cCurrentSchemaName := ""
    l_cBackendType        := "M"
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cCurrentSchemaName := ::GetCurrentSchemaName()
    l_cBackendType        := "P"
endcase

// if ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
//     altd()
// endif

if ::UpdateSchemaCache()
    ::LoadSchema()
endif

// if ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
//     altd()
// endif

for each l_hTableDefinition in par_hSchemaDefinition
    l_cSchemaAndTableName := l_hTableDefinition:__enumKey()
    l_aTableDefinition    := l_hTableDefinition:__enumValue()

// if "TABLE003" $ upper(l_cSchemaAndTableName)
//     altd()
// endif

    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_cSchemaName := ""
        l_cTableName  := l_cSchemaAndTableName
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        l_nPos := at(".",l_cSchemaAndTableName)
        if empty(l_nPos)
            l_cSchemaName         := l_cCurrentSchemaName
            l_cTableName          := l_cSchemaAndTableName
            l_cSchemaAndTableName := l_cSchemaName+"."+l_cTableName
        else
            l_cSchemaName := left(l_cSchemaAndTableName,l_nPos-1)
            l_cTableName  := substr(l_cSchemaAndTableName,l_nPos+1)
        endif
        l_hListOfSchemaName[l_cSchemaName] := NIL  //Will use the Hash as a Set of values
    endcase

    l_aCurrentTableDefinition := hb_HGetDef(::p_Schema,l_cSchemaAndTableName,NIL)

    l_hFields  := l_aTableDefinition[HB_ORM_SCHEMA_FIELD]
    l_hIndexes := l_aTableDefinition[HB_ORM_SCHEMA_INDEX]

    if hb_IsNIL(l_aCurrentTableDefinition)
        // Table does not exist in the current catalog
        hb_orm_SendToDebugView("Add Table: "+l_cSchemaAndTableName)
        l_cSQLScript += ::AddTable(l_cSchemaName,l_cTableName,l_hFields,.f. /*par_lAlsoRemoveFields*/)
        
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

                    if l_cBackendType $ hb_DefaultValue(l_aIndexDefinition[HB_ORM_SCHEMA_INDEX_BACKEND_TYPES],"MP")
                        if !(lower(l_aIndexDefinition[HB_ORM_SCHEMA_INDEX_EXPRESSION]) == lower(::p_PrimaryKeyFieldName))   // Don't Create and index, since PRIMARY will already do so. This should not happen since no loaded in p_Schema to start with. But this method accepts any p_Schema hash arrays.
                            l_cSQLScript += ::AddIndex(l_cSchemaName,l_cTableName,l_hFields,l_cIndexName,l_aIndexDefinition)  //Passing l_hFields to help with index expressions
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
        // Found the table in the current ::p_Schema, now lets test all the fields are also there and matching
        // Test Every Fields to see if structure must be updated.

        l_cSQLScriptFieldChangesCycle1 := ""
        l_cSQLScriptFieldChangesCycle2 := ""

        for each l_hFieldDefinition in l_hFields   //l_aTableDefinition[1]
            l_cFieldName              := l_hFieldDefinition:__enumKey()

// if upper(l_cFieldName) == upper("logical1")
//     altd()
// endif


// if upper("table003") $ upper(l_cSchemaAndTableName) .and. upper(l_cFieldName) == upper("boolean")
//     altd()
// endif

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
                if l_cBackendType $ hb_DefaultValue(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_BACKEND_TYPES],"MP")
                    l_cFieldType                 := iif(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE] == "T","DT",l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE])
                    l_nFieldLen                  := iif(len(l_aFieldDefinition) < 2, 0 ,hb_defaultValue(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_LENGTH]        , 0 ))
                    l_nFieldDec                  := iif(len(l_aFieldDefinition) < 3, 0 ,hb_defaultValue(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_DECIMALS]      , 0 ))
                    l_cFieldAttributes           := iif(len(l_aFieldDefinition) < 4, "",hb_defaultValue(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_ATTRIBUTES]    , ""))
                    l_cFieldDefault              := iif(len(l_aFieldDefinition) >= HB_ORM_SCHEMA_FIELD_DEFAULT,hb_DefaultValue(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_DEFAULT],""),"")
                    l_lFieldAllowNull            := ("N" $ l_cFieldAttributes)
                    l_lFieldAutoIncrement        := ("+" $ l_cFieldAttributes)
                    l_lFieldArray                := ("A" $ l_cFieldAttributes)

                    if lower(l_cFieldName) == lower(::p_PrimaryKeyFieldName)
                        l_lFieldAutoIncrement := .t.
                    endif
                    if l_lFieldAutoIncrement .and. empty(el_inlist(l_cFieldType,"I","IB","IS"))  //Only those fields types may be flagged as Auto-Increment
                        l_lFieldAutoIncrement := .f.
                    endif
                    if l_lFieldAutoIncrement .and. l_lFieldAllowNull  //Auto-Increment fields may not be null (and not have a default)
                        l_lFieldAllowNull := .f.
                    endif

                    //To ensure we only have the supported flags
                    l_cFieldAttributes := iif(l_lFieldAllowNull,"N","")+iif(l_lFieldAutoIncrement,"+","")+iif(l_lFieldArray,"A","")

                    l_aCurrentFieldDefinition := hb_HGetDef(::p_Schema[l_cSchemaAndTableName][HB_ORM_SCHEMA_FIELD],l_cFieldName,NIL)
                    if hb_IsNIL(l_aCurrentFieldDefinition)
                        //Missing Field
                        hb_orm_SendToDebugView("Table: "+l_cSchemaAndTableName+" Add Field: "+l_cFieldName)

                        l_cSQLScriptFieldChanges := ::AddField(l_cSchemaName,;
                                                              l_cTableName,;
                                                              l_cFieldName,;
                                                              {,l_cFieldType,l_nFieldLen,l_nFieldDec,l_cFieldAttributes,l_cFieldDefault})
                        l_cSQLScriptPreUpdate          += l_cSQLScriptFieldChanges[1]  // Allways blank for now MYSQL+POSTGRESQL
                        l_cSQLScriptFieldChangesCycle1 += l_cSQLScriptFieldChanges[2]
                        l_cSQLScriptFieldChangesCycle2 += l_cSQLScriptFieldChanges[3]  // Allways blank for now MYSQL+POSTGRESQL
                        l_cSQLScriptPostUpdate         += l_cSQLScriptFieldChanges[4]


                    else
                        //Compare the field definition using arrays l_aCurrentFieldDefinition and l_aFieldDefinition

                        l_cCurrentFieldType          := iif(l_aCurrentFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE] == "T","DT",l_aCurrentFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE])
                        l_nCurrentFieldLen           := iif(len(l_aCurrentFieldDefinition) < 2, 0 ,hb_defaultValue(l_aCurrentFieldDefinition[HB_ORM_SCHEMA_FIELD_LENGTH]        , 0 ))
                        l_nCurrentFieldDec           := iif(len(l_aCurrentFieldDefinition) < 3, 0 ,hb_defaultValue(l_aCurrentFieldDefinition[HB_ORM_SCHEMA_FIELD_DECIMALS]      , 0 ))
                        l_cCurrentFieldAttributes    := iif(len(l_aCurrentFieldDefinition) < 4, "",hb_defaultValue(l_aCurrentFieldDefinition[HB_ORM_SCHEMA_FIELD_ATTRIBUTES]    , ""))
                        l_cCurrentFieldDefault       := iif(len(l_aCurrentFieldDefinition) >= HB_ORM_SCHEMA_FIELD_DEFAULT,hb_DefaultValue(l_aCurrentFieldDefinition[HB_ORM_SCHEMA_FIELD_DEFAULT],""),"")
                        l_lCurrentFieldAllowNull     := ("N" $ l_cCurrentFieldAttributes)
                        l_lCurrentFieldAutoIncrement := ("+" $ l_cCurrentFieldAttributes)
                        l_lCurrentFieldArray         := ("A" $ l_cCurrentFieldAttributes)

                        if l_lCurrentFieldAutoIncrement .and. empty(el_inlist(l_cCurrentFieldType,"I","IB","IS"))  //Only those fields types may be flagged as Auto-Increment
                            l_lCurrentFieldAutoIncrement := .f.
                        endif
                        if l_lCurrentFieldAutoIncrement .and. l_lCurrentFieldAllowNull  //Auto-Increment fields may not be null (and not have a default)
                            l_lCurrentFieldAllowNull := .f.
                        endif

                        l_cCurrentFieldAttributes := iif(l_lCurrentFieldAllowNull,"N","")+iif(l_lCurrentFieldAutoIncrement,"+","")+iif(l_lCurrentFieldArray,"A","")

// if l_cFieldName == "VarChar52"
//     altd()
// endif

// if upper(l_cFieldName) == upper("json1_without_null") //.and. upper(l_cTableName) == upper("table003")
//     altd()
// endif

                        l_cFieldDefault := ::NormalizeFieldDefaultForCurrentEngineType(l_cFieldDefault,l_cFieldType,l_nFieldDec)

                        l_lMatchingFieldDefinition := .t.
                        do case
                        case !(l_cFieldType == l_cCurrentFieldType)   // Field Type is always defined.  !(==) is a method to deal with SET EXACT being OFF by default.
                            l_lMatchingFieldDefinition := .f.
                        case l_lFieldArray != l_lCurrentFieldArray
                            l_lMatchingFieldDefinition := .t.
                        case !empty(el_inlist(l_cFieldType,"I","IB","IS","M","R","L","D","Y","UUI","JS"))  //Field type with no length
                        case empty(el_inlist(l_cFieldType,"TOZ","TO","DTZ","DT")) .and. l_nFieldLen <> l_nCurrentFieldLen   //Ignore Length matching for datetime and time fields
                            l_lMatchingFieldDefinition := .f.
                        case !empty(el_inlist(l_cFieldType,"C","CV","B","BV"))  //Field type with a length but no decimal
                        case l_nFieldDec  <> l_nCurrentFieldDec
                            l_lMatchingFieldDefinition := .f.
                        endcase

                        if l_lMatchingFieldDefinition  // Should still test on nullable and incremental
                            // do case
                            // // Test on AllowNull
                            // case l_lFieldAllowNull <> l_lCurrentFieldAllowNull
                            //     l_lMatchingFieldDefinition := .f.
                            // // Test on AutoIncrement
                            // case l_lFieldAutoIncrement <> l_lCurrentFieldAutoIncrement
                            //     l_lMatchingFieldDefinition := .f.
                            // // Test on Array Setting
                            // case l_lFieldArray <> l_lCurrentFieldArray
                            //     l_lMatchingFieldDefinition := .f.
                            // endcase
                            do case
                            case !(l_cFieldAttributes == l_cCurrentFieldAttributes)
                                l_lMatchingFieldDefinition := .f.
                            case !(l_cFieldDefault == l_cCurrentFieldDefault)
                                l_lMatchingFieldDefinition := .f.
                            endcase
                        endif


// if upper(l_cFieldName) == upper("json1_without_null") //.and. upper(l_cSchemaName) == upper("set001") .and. upper(l_cTableName) == upper("table003")
//     altd()
// endif

                        if !l_lMatchingFieldDefinition
                            hb_orm_SendToDebugView("Table: "+l_cSchemaAndTableName+" Field: "+l_cFieldName+"  Mismatch")
                            l_cSQLScriptFieldChanges := ::UpdateField(l_cSchemaName,;
                                                                    l_cTableName,;
                                                                    l_cFieldName,;
                                                                    {,l_cFieldType       ,l_nFieldLen       ,l_nFieldDec       ,l_cFieldAttributes       ,l_cFieldDefault},;
                                                                    {,l_cCurrentFieldType,l_nCurrentFieldLen,l_nCurrentFieldDec,l_cCurrentFieldAttributes,l_cCurrentFieldDefault})
                            l_cSQLScriptPreUpdate          += l_cSQLScriptFieldChanges[1]
                            l_cSQLScriptFieldChangesCycle1 += l_cSQLScriptFieldChanges[2]
                            l_cSQLScriptFieldChangesCycle2 += l_cSQLScriptFieldChanges[3]
                            l_cSQLScriptPostUpdate         += l_cSQLScriptFieldChanges[4]
                        endif

                    endif
                endif

                l_iArrayPos -= 1
                if l_iArrayPos > 0
                    l_aFieldDefinition := l_aFieldDefinitions[l_iArrayPos]
                endif
            enddo

        endfor

        if !empty(l_cSQLScriptFieldChangesCycle1) .or. !empty(l_cSQLScriptFieldChangesCycle2)
            do case
            case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
                l_cFormattedTableName := ::FormatIdentifier(l_cTableName)
            case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
                l_cFormattedTableName := ::FormatIdentifier(l_cSchemaAndTableName)
            endcase
            if !empty(l_cSQLScriptFieldChangesCycle1)
                l_cSQLScript += [ALTER TABLE ]+l_cFormattedTableName+[ ]+substr(l_cSQLScriptFieldChangesCycle1,2)+[;]+CRLF   //Drop the leading "," in l_cSQLScriptFieldChangesCycle1
            endif
            if !empty(l_cSQLScriptFieldChangesCycle2)
                l_cSQLScript += [ALTER TABLE ]+l_cFormattedTableName+[ ]+substr(l_cSQLScriptFieldChangesCycle2,2)+[;]+CRLF   //Drop the leading "," in l_cSQLScriptFieldChangesCycle2
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
                    
                    if l_cBackendType $ hb_DefaultValue(l_aIndexDefinition[HB_ORM_SCHEMA_INDEX_BACKEND_TYPES],"MP")
                        if !(lower(l_aIndexDefinition[HB_ORM_SCHEMA_INDEX_EXPRESSION]) == lower(::p_PrimaryKeyFieldName))   // Don't Create and index, since PRIMARY will already do so.
                            
                            if hb_IsNIL(::p_Schema[l_cSchemaAndTableName][HB_ORM_SCHEMA_INDEX])
                                l_aCurrentIndexDefinition := NIL
                            else
                                l_aCurrentIndexDefinition := hb_HGetDef(::p_Schema[l_cSchemaAndTableName][HB_ORM_SCHEMA_INDEX],l_cIndexName,NIL)
                            endif
                            if hb_IsNIL(l_aCurrentIndexDefinition)
                                //Missing Index
                                hb_orm_SendToDebugView("Table: "+l_cSchemaAndTableName+" Add Index: "+l_cIndexName)
                                l_cSQLScript += ::AddIndex(l_cSchemaName,l_cTableName,l_hFields,l_cIndexName,l_aIndexDefinition)  //Passing l_hFields to help with index expressions
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

if !empty(l_cSQLScript)
    if !empty(l_cSQLScriptPreUpdate)
        l_cSQLScript := l_cSQLScriptPreUpdate+CRLF+l_cSQLScript
    endif
    if !empty(l_cSQLScriptPostUpdate)
        l_cSQLScript += l_cSQLScriptPostUpdate
    endif

    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_cSQLScript := [USE ]+::FormatIdentifier(::GetDatabase())+[;]+CRLF+l_cSQLScript

    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        //When you get a connection to PostgreSQL it is always to a particular database. To access a different database, you must get a new connection.

        for each l_hSchemaName in l_hListOfSchemaName
            l_cSQLScriptCreateSchemaName += [CREATE SCHEMA IF NOT EXISTS ]+::FormatIdentifier(l_hSchemaName:__enumKey())+[;]+CRLF
        endfor

        if !empty(l_cSQLScriptCreateSchemaName)
            l_cSQLScript := l_cSQLScriptCreateSchemaName+l_cSQLScript
        endif
    endcase
endif

return l_cSQLScript
//-----------------------------------------------------------------------------------------------------------------
method MigrateSchema(par_hSchemaDefinition) class hb_orm_SQLConnect
local l_cSQLScript
local l_nResult := 0   // 0 = Nothing Migrated, 1 = Migrated, -1 = Error Migrating
local l_cLastError := ""
local l_aInstructions
local l_cStatement
local l_nCounter := 0

l_cSQLScript := ::GenerateMigrateSchemaScript(par_hSchemaDefinition)

if !empty(l_cSQLScript)
    l_nResult := 1
    l_aInstructions := hb_ATokens(l_cSQLScript,.t.)
    for each l_cStatement in l_aInstructions
        if !empty(l_cStatement)
            l_nCounter++
            if ::SQLExec(l_cStatement)
                // hb_orm_SendToDebugView("Updated Table Structure.")
            else
                l_cLastError := ::GetSQLExecErrorMessage()
                hb_orm_SendToDebugView("Failed MigrateSchema on instruction "+Trans(l_nCounter)+".   Error Text="+l_cLastError)
                l_nResult := -1
                exit
            endif
        endif
    endfor
    ::UpdateSchemaCache()
    ::LoadSchema()
endif

::UpdateORMSchemaTableNumber()  // Will call this routine even if no tables where modified.

return {l_nResult,l_cSQLScript,l_cLastError}
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
method AddTable(par_cSchemaName,par_cTableName,par_hStructure) class hb_orm_SQLConnect                 // Fix if needed a single file structure
local l_aField
local l_cFieldName
local l_aFieldStructures,l_aFieldStructure
local l_cSQLCommand := ""
local l_cSQLFields := ""
local l_cFieldType
local l_nFieldDec
local l_nFieldLen
local l_cFieldAttributes
local l_lFieldAllowNull
local l_lFieldAutoIncrement
local l_lFieldArray
local l_cFieldDefault
local l_nNumberOfFieldDefinitionParameters
local l_cDefaultString := ""
local l_cSQLExtra := ""
local l_cFormattedTableName
local l_cFormattedFieldName
local l_cBackendType := ""
local l_iArrayPos
local l_cAdditionalSQLCommand :=""
local l_cFieldTypeSuffix

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cFormattedTableName := ::FormatIdentifier(par_cTableName)
    l_cBackendType        := "M"
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cFormattedTableName := ::FormatIdentifier(par_cSchemaName+"."+par_cTableName)
    l_cBackendType        := "P"
endcase

// l_aStructure := {=>}
// l_aStructure["key"]        := {"I",,}
// l_aStructure["p_table001"] := {"I",,}
// l_aStructure["city"]       := {"C",50,0}

for each l_aField in par_hStructure
    l_cFieldName          := l_aField:__enumKey()
    l_aFieldStructures    := l_aField:__enumValue()

    if ValType(l_aFieldStructures[1]) == "A"
        l_iArrayPos        := len(l_aFieldStructures)
        l_aFieldStructure   := l_aFieldStructures[l_iArrayPos]
    else
        l_iArrayPos        := 1
        l_aFieldStructure   := l_aFieldStructures
    endif
    do while l_iArrayPos > 0

        if l_cBackendType $ hb_DefaultValue(l_aFieldStructure[HB_ORM_SCHEMA_FIELD_BACKEND_TYPES],"MP")
            l_nNumberOfFieldDefinitionParameters := len(l_aFieldStructure)
            l_cFieldType          := l_aFieldStructure[HB_ORM_SCHEMA_FIELD_TYPE]
            l_nFieldLen           := iif(l_nNumberOfFieldDefinitionParameters < 2, 0 ,hb_DefaultValue(l_aFieldStructure[HB_ORM_SCHEMA_FIELD_LENGTH]        , 0 ))
            l_nFieldDec           := iif(l_nNumberOfFieldDefinitionParameters < 3, 0 ,hb_DefaultValue(l_aFieldStructure[HB_ORM_SCHEMA_FIELD_DECIMALS]      , 0 ))
            l_cFieldAttributes    := iif(l_nNumberOfFieldDefinitionParameters < 4, "",hb_DefaultValue(l_aFieldStructure[HB_ORM_SCHEMA_FIELD_ATTRIBUTES]    , ""))
            l_cFieldDefault       := iif(len(l_aFieldStructure) >= HB_ORM_SCHEMA_FIELD_DEFAULT,hb_DefaultValue(l_aFieldStructure[HB_ORM_SCHEMA_FIELD_DEFAULT],""),"")
            l_lFieldAllowNull     := ("N" $ l_cFieldAttributes)
            l_lFieldAutoIncrement := ("+" $ l_cFieldAttributes)
            l_lFieldArray         := ("A" $ l_cFieldAttributes)

            if lower(l_cFieldName) == lower(::p_PrimaryKeyFieldName)
                l_lFieldAutoIncrement := .t.
            endif
            if l_lFieldAutoIncrement .and. empty(el_inlist(l_cFieldType,"I","IB","IS"))  //Only those fields types may be flagged as Auto-Increment
                l_lFieldAutoIncrement := .f.
            endif
            if l_lFieldAutoIncrement .and. l_lFieldAllowNull  //Auto-Increment fields may not be null (and not have a default)
                l_lFieldAllowNull := .f.
            endif

            l_cFieldDefault := ::NormalizeFieldDefaultForCurrentEngineType(l_cFieldDefault,l_cFieldType,l_nFieldDec)

            // l_cFieldAttributes := iif(l_lFieldAllowNull,"N","")+iif(l_lFieldAutoIncrement,"+","")  Not needed since the AddTable will also deal with all the fields and not call AddField()

            if !empty(l_cSQLFields)
                l_cSQLFields += ","
            endif

            l_cFormattedFieldName := ::FormatIdentifier(l_cFieldName)
            l_cSQLFields += l_cFormattedFieldName + [ ]

            do case
            case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
                do case
                case !empty(el_inlist(l_cFieldType,"I","IB","IS","N"))
                    do case
                    case l_cFieldType == "I"
                        l_cSQLFields += [INT]
                    case l_cFieldType == "IB"
                        l_cSQLFields += [BIGINT]
                    case l_cFieldType == "IS"
                        l_cSQLFields += [SMALLINT]
                    case l_cFieldType == "N"
                        l_cSQLFields += [DECIMAL(]+trans(l_nFieldLen)+[,]+trans(l_nFieldDec)+[)]
                        if l_lFieldAutoIncrement
                            l_lFieldAutoIncrement := .f.
                            hb_orm_SendToDebugView("May not make numeric field auto-increment. Table: "+par_cTableName+" - Field: "+l_cFieldName)
                        endif
                    endcase

                    if l_lFieldAutoIncrement
                        l_cSQLFields += [ NOT NULL AUTO_INCREMENT]
                        l_cSQLExtra  += [,PRIMARY KEY (]+l_cFormattedFieldName+[) USING BTREE]
                    else
                        l_cDefaultString := "0"
                    endif

                case !empty(el_inlist(l_cFieldType,"C","CV","B","BV","M","R"))
                    do case
                    case l_cFieldType == "C"
                        l_cSQLFields += [CHAR(]+trans(l_nFieldLen)+[)]
                    case l_cFieldType == "CV"
                        l_cSQLFields += [VARCHAR]+iif(empty(l_nFieldLen),[],[(]+trans(l_nFieldLen)+[)])
                    case l_cFieldType == "B"
                        l_cSQLFields += [BINARY(]+trans(l_nFieldLen)+[)]
                    case l_cFieldType == "BV"
                        l_cSQLFields += [VARBINARY]+iif(empty(l_nFieldLen),[],[(]+trans(l_nFieldLen)+[)])
                    case l_cFieldType == "M"
                        l_cSQLFields += [LONGTEXT]
                    case l_cFieldType == "R"
                        l_cSQLFields += [LONGBLOB]
                    endcase

                    l_cDefaultString := "''"

                case l_cFieldType == "L"
                    l_cSQLFields += [TINYINT(1)]
                    l_cDefaultString := "0"
                    
                case !empty(el_inlist(l_cFieldType,"D","TOZ","TO","DTZ","T","DT"))
                    do case
                    case l_cFieldType == "D"
                        l_cSQLFields += [DATE]
                        l_cDefaultString   := ['0000-00-00']
                    case l_cFieldType == "TOZ"
                        if vfp_between(l_nFieldDec,0,6)
                            l_cSQLFields += [TIME(]+trans(l_nFieldDec)+[) COMMENT 'Type=TOZ']
                        else
                            l_cSQLFields += [TIME COMMENT 'Type=TOZ']
                        endif
                        l_cDefaultString   := ['00:00:00']
                    case l_cFieldType == "TO"
                        if vfp_between(l_nFieldDec,0,6)
                            l_cSQLFields += [TIME(]+trans(l_nFieldDec)+[)]
                        else
                            l_cSQLFields += [TIME]
                        endif
                        l_cDefaultString   := ['00:00:00']
                    case l_cFieldType == "DTZ"
                        if vfp_between(l_nFieldDec,0,6)
                            l_cSQLFields += [TIMESTAMP(]+trans(l_nFieldDec)+[)]
                        else
                            l_cSQLFields += [TIMESTAMP]
                        endif
                        l_cDefaultString   := ['0000-00-00 00:00:00']
                    case l_cFieldType == "DT" .or. l_cFieldType == "T"
                        if vfp_between(l_nFieldDec,0,6)
                            l_cSQLFields += [DATETIME(]+trans(l_nFieldDec)+[)]
                        else
                            l_cSQLFields += [DATETIME]
                        endif
                        l_cDefaultString   := ['0000-00-00 00:00:00']
                    endcase

                // case l_cFieldType == "TS"
                //     l_cSQLFields += [TIMESTAMP NOT NULL DEFAULT current_timestamp]
                    
                case l_cFieldType == "Y"
                    l_cSQLFields += [DECIMAL(13,4) COMMENT 'Type=Y']
                    l_cDefaultString := "0"

                case l_cFieldType == "UUI"
                    l_cSQLFields += [CHAR(36) COMMENT 'Type=UUI']
                    l_cDefaultString := "'00000000-0000-0000-0000-000000000000'"

                case l_cFieldType == "JS"
                    l_cSQLFields += [LONGTEXT COMMENT 'Type=JS']
                    l_cDefaultString := "'{}'"
                    
                otherwise
                    
                endcase

                if !empty(l_cDefaultString)
                    if l_lFieldAllowNull
                        if empty(l_cFieldDefault)
                            l_cSQLFields += [ NULL]
                        else
                            l_cSQLFields += [ NULL DEFAULT ]+l_cFieldDefault
                        endif
                    else
                        if empty(l_cFieldDefault)
                            l_cSQLFields += [ NOT NULL DEFAULT ]+l_cDefaultString
                        else
                            l_cSQLFields += [ NOT NULL DEFAULT ]+l_cFieldDefault
                        endif
                    endif
                endif

            case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
                l_cFieldTypeSuffix := iif(l_lFieldArray,"[]","")

                do case
                case !empty(el_inlist(l_cFieldType,"I","IB","IS","N"))
                    do case
                    case l_cFieldType == "I"
                        l_cSQLFields += [integer]+l_cFieldTypeSuffix
                    case l_cFieldType == "IB"
                        l_cSQLFields += [bigint]+l_cFieldTypeSuffix
                    case l_cFieldType == "IS"
                        l_cSQLFields += [smallint]+l_cFieldTypeSuffix
                    case l_cFieldType == "N"
                        l_cSQLFields += [numeric(]+trans(l_nFieldLen)+[,]+trans(l_nFieldDec)+[)]+l_cFieldTypeSuffix
                        if l_lFieldAutoIncrement
                            l_lFieldAutoIncrement := .f.
                            hb_orm_SendToDebugView("May not make numeric field auto-increment. Table: "+par_cTableName+" - Field: "+l_cFieldName)
                        endif
                    endcase

                    if l_lFieldAutoIncrement
                        l_cSQLFields += [ NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 ), PRIMARY KEY (]+l_cFormattedFieldName+[)]
                    else
                        l_cDefaultString := "0"
                    endif


                case !empty(el_inlist(l_cFieldType,"C","CV","B","BV","M","R"))
                    do case
                    case l_cFieldType == "C"
                        l_cSQLFields += [character(]+trans(l_nFieldLen)+[)]+l_cFieldTypeSuffix
                    case l_cFieldType == "CV"
                        l_cSQLFields += [character varying]+iif(empty(l_nFieldLen),[],[(]+trans(l_nFieldLen)+[)])+l_cFieldTypeSuffix
                    case l_cFieldType == "B"
                        l_cSQLFields += [bytea]+l_cFieldTypeSuffix
                        l_cAdditionalSQLCommand += [COMMENT ON COLUMN ]+l_cFormattedTableName+"."+l_cFormattedFieldName+[ IS 'Type=B|Length=]+trans(l_nFieldLen)+[';]+CRLF
                    case l_cFieldType == "BV"
                        l_cSQLFields += [bytea]+l_cFieldTypeSuffix
                        l_cAdditionalSQLCommand += [COMMENT ON COLUMN ]+l_cFormattedTableName+"."+l_cFormattedFieldName+[ IS 'Type=BV|Length=]+trans(l_nFieldLen)+[';]+CRLF
                    case l_cFieldType == "M"
                        l_cSQLFields += [text]+l_cFieldTypeSuffix
                    case l_cFieldType == "R"
                        l_cSQLFields += [bytea]+l_cFieldTypeSuffix
                        
                    endcase

                    l_cDefaultString := "''"

                case l_cFieldType == "L"
                    l_cSQLFields += [boolean]+l_cFieldTypeSuffix

                    l_cDefaultString := "FALSE"
                    
                case !empty(el_inlist(l_cFieldType,"D","TOZ","TO","DTZ","T","DT"))
                    do case
                    case l_cFieldType == "D"
                        l_cSQLFields += [date]+l_cFieldTypeSuffix
                    case l_cFieldType == "TOZ"
                        if vfp_between(l_nFieldDec,0,6)
                            l_cSQLFields += [time(]+trans(l_nFieldDec)+[) with time zone]+l_cFieldTypeSuffix
                        else
                            l_cSQLFields += [time with time zone]+l_cFieldTypeSuffix
                        endif
                    case l_cFieldType == "TO"
                        if vfp_between(l_nFieldDec,0,6)
                            l_cSQLFields += [time(]+trans(l_nFieldDec)+[) without time zone]+l_cFieldTypeSuffix
                        else
                            l_cSQLFields += [time without time zone]+l_cFieldTypeSuffix
                        endif
                    case l_cFieldType == "DTZ"
                        if vfp_between(l_nFieldDec,0,6)
                            l_cSQLFields += [timestamp(]+trans(l_nFieldDec)+[) with time zone]+l_cFieldTypeSuffix
                        else
                            l_cSQLFields += [timestamp with time zone]+l_cFieldTypeSuffix
                        endif
                    case l_cFieldType == "DT" .or. l_cFieldType == "T"
                        if vfp_between(l_nFieldDec,0,6)
                            l_cSQLFields += [timestamp(]+trans(l_nFieldDec)+[) without time zone]+l_cFieldTypeSuffix
                        else
                            l_cSQLFields += [timestamp without time zone]+l_cFieldTypeSuffix
                        endif
                    endcase

                    l_cDefaultString := "'-infinity'"

                case l_cFieldType == "Y"
                    l_cSQLFields += [money]+l_cFieldTypeSuffix

                    l_cDefaultString := "0"
                    
                case l_cFieldType == "UUI"
                    l_cSQLFields += [uuid]+l_cFieldTypeSuffix

                    l_cDefaultString := "'00000000-0000-0000-0000-000000000000'::uuid"

                case l_cFieldType == "JS"
                    l_cSQLFields += [json]+l_cFieldTypeSuffix

                    l_cDefaultString := "'{}'::json"
                    
                otherwise
                    
                endcase

                if !empty(l_cDefaultString)
                    if l_lFieldAllowNull
                        if empty(l_cFieldDefault)
                            // l_cSQLFields += []
                        else
                            l_cSQLFields += [ DEFAULT ]+l_cFieldDefault
                        endif
                    else
                        if empty(l_cFieldDefault)
                            l_cSQLFields += [ NOT NULL DEFAULT ]+l_cDefaultString
                        else
                            l_cSQLFields += [ NOT NULL DEFAULT ]+l_cFieldDefault
                        endif
                    endif
                endif

            endcase
        endif

        l_iArrayPos -= 1
        if l_iArrayPos > 0
            l_aFieldStructure := l_aFieldStructures[l_iArrayPos]
        endif

    enddo

endfor

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cSQLCommand := [CREATE TABLE ]+l_cFormattedTableName+[ (] + l_cSQLFields + l_cSQLExtra
    l_cSQLCommand += [) ENGINE=InnoDB COLLATE='utf8_general_ci';]+CRLF

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cSQLCommand := [CREATE TABLE ]+l_cFormattedTableName+[ (] + l_cSQLFields
    l_cSQLCommand += [);]+CRLF

endcase

return l_cSQLCommand+l_cAdditionalSQLCommand
//-----------------------------------------------------------------------------------------------------------------
method UpdateField(par_cSchemaName,par_cTableName,par_cFieldName,par_aFieldDefinition,par_aCurrentFieldDefinition) class hb_orm_SQLConnect
// Due to a bug in MySQL engine of the "ALTER TABLE" command cannot mix "CHANGE COLUMN" and "ALTER COLUMN" options. Therefore separating those in 2 Cycles
local l_cSQLCommandPreUpdate := ""
local l_cSQLCommandCycle1    := ""
local l_cSQLCommandCycle2    := ""
local l_cFieldType,       l_nFieldLen,       l_nFieldDec,       l_cFieldAttributes,       l_lFieldAllowNull,       l_lFieldAutoIncrement,       l_lFieldArray       ,l_cFieldDefault
local                                                           l_cCurrentFieldAttributes,l_lCurrentFieldAllowNull,l_lCurrentFieldAutoIncrement,l_lCurrentFieldArray,l_cCurrentFieldDefault
local l_cFormattedFieldName := ::FormatIdentifier(par_cFieldName)
local l_cFormattedTableName
local l_cAdditionalSQLCommands := ""
local l_cFieldTypeSuffix
local l_cDefaultString := ""

l_cFieldType                 := par_aFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE]
l_nFieldLen                  := par_aFieldDefinition[HB_ORM_SCHEMA_FIELD_LENGTH]
l_nFieldDec                  := par_aFieldDefinition[HB_ORM_SCHEMA_FIELD_DECIMALS]
l_cFieldAttributes           := par_aFieldDefinition[HB_ORM_SCHEMA_FIELD_ATTRIBUTES]
l_cFieldDefault              := iif(len(par_aFieldDefinition) >= HB_ORM_SCHEMA_FIELD_DEFAULT,hb_DefaultValue(par_aFieldDefinition[HB_ORM_SCHEMA_FIELD_DEFAULT],""),"")
l_lFieldAllowNull            := ("N" $ l_cFieldAttributes)
l_lFieldAutoIncrement        := ("+" $ l_cFieldAttributes)
l_lFieldArray                := ("A" $ l_cFieldAttributes)

l_cCurrentFieldAttributes    := par_aCurrentFieldDefinition[HB_ORM_SCHEMA_FIELD_ATTRIBUTES]
l_cCurrentFieldDefault       := iif(len(par_aCurrentFieldDefinition) >= HB_ORM_SCHEMA_FIELD_DEFAULT,hb_DefaultValue(par_aCurrentFieldDefinition[HB_ORM_SCHEMA_FIELD_DEFAULT],""),"")
l_lCurrentFieldAllowNull     := ("N" $ l_cCurrentFieldAttributes)
l_lCurrentFieldAutoIncrement := ("+" $ l_cCurrentFieldAttributes)
l_lCurrentFieldArray         := ("A" $ l_cCurrentFieldAttributes)

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cFormattedTableName := ::FormatIdentifier(par_cTableName)

    // MySQL has issues of DROP DEFAULT before a field is set to allow NULL
    l_cSQLCommandCycle2 += [,CHANGE COLUMN ]+l_cFormattedFieldName+[ ]+l_cFormattedFieldName+[ ]

    do case
    case !empty(el_inlist(l_cFieldType,"I","IB","IS","N"))
        do case
        case l_cFieldType == "I"
            l_cSQLCommandCycle2 += [INT]
        case l_cFieldType == "IB"
            l_cSQLCommandCycle2 += [BIGINT]
        case l_cFieldType == "IS"
            l_cSQLCommandCycle2 += [SMALLINT]
        case l_cFieldType == "N"
            l_cSQLCommandCycle2 += [DECIMAL(]+trans(l_nFieldLen)+[,]+trans(l_nFieldDec)+[)]
            if l_lFieldAutoIncrement
                l_lFieldAutoIncrement := .f.
                hb_orm_SendToDebugView("May not make numeric field auto-increment. Table: "+par_cTableName+" - Field: "+par_cFieldName)
            endif
        endcase

        if l_lFieldAutoIncrement
            l_cSQLCommandCycle2 += [ NOT NULL AUTO_INCREMENT]
            l_cSQLCommandCycle2 += [,ADD PRIMARY KEY (]+l_cFormattedFieldName+[)]
        else
            if l_lFieldAllowNull
            else
                //do not allow NULL
                l_cSQLCommandPreUpdate += [UPDATE ]+l_cFormattedTableName+[ SET ]+l_cFormattedFieldName+[ = 0  WHERE ]+l_cFormattedFieldName+[ IS NULL;]
            endif

            l_cDefaultString := "0"

        endif


    case !empty(el_inlist(l_cFieldType,"C","CV","B","BV","M","R"))
        do case
        case l_cFieldType == "C"
            l_cSQLCommandCycle2 += [CHAR(]+trans(l_nFieldLen)+[)]
        case l_cFieldType == "CV"
            l_cSQLCommandCycle2 += [VARCHAR]+iif(empty(l_nFieldLen),[],[(]+trans(l_nFieldLen)+[)])
        case l_cFieldType == "B"
            l_cSQLCommandCycle2 += [BINARY(]+trans(l_nFieldLen)+[)]
        case l_cFieldType == "BV"
            l_cSQLCommandCycle2 += [VARBINARY]+iif(empty(l_nFieldLen),[],[(]+trans(l_nFieldLen)+[)])
        case l_cFieldType == "M"
            l_cSQLCommandCycle2 += [LONGTEXT]
        case l_cFieldType == "R"
            l_cSQLCommandCycle2 += [LONGBLOB]
        endcase

        l_cDefaultString := "''"


    case l_cFieldType == "L"
        l_cSQLCommandCycle2 += [TINYINT(1)]
        l_cDefaultString := "0"
        
    case !empty(el_inlist(l_cFieldType,"D","TOZ","TO","DTZ","T","DT"))
        do case
        case l_cFieldType == "D"
            l_cSQLCommandCycle2 += [DATE]
            l_cDefaultString := ['0000-00-00']
        case l_cFieldType == "TOZ"
            if vfp_between(l_nFieldDec,0,6)
                l_cSQLCommandCycle2 += [TIME(]+trans(l_nFieldDec)+[) COMMENT 'Type=TOZ']
            else
                l_cSQLCommandCycle2 += [TIME COMMENT 'Type=TOZ']
            endif
            l_cDefaultString := ['00:00:00']
        case l_cFieldType == "TO"
            if vfp_between(l_nFieldDec,0,6)
                l_cSQLCommandCycle2 += [TIME(]+trans(l_nFieldDec)+[)]
            else
                l_cSQLCommandCycle2 += [TIME]
            endif
            l_cDefaultString := ['00:00:00']
        case l_cFieldType == "DTZ"
            if vfp_between(l_nFieldDec,0,6)
                l_cSQLCommandCycle2 += [TIMESTAMP(]+trans(l_nFieldDec)+[)]
            else
                l_cSQLCommandCycle2 += [TIMESTAMP]
            endif
            l_cDefaultString := ['0000-00-00 00:00:00']
        case l_cFieldType == "DT" .or. l_cFieldType == "T"
            if vfp_between(l_nFieldDec,0,6)
                l_cSQLCommandCycle2 += [DATETIME(]+trans(l_nFieldDec)+[)]
            else
                l_cSQLCommandCycle2 += [DATETIME]
            endif
            l_cDefaultString := ['0000-00-00 00:00:00']
        endcase

    case l_cFieldType == "Y"
        l_cSQLCommandCycle2 += [DECIMAL(13,4) COMMENT 'Type=Y']
        l_cDefaultString := "0"

    case l_cFieldType == "UUI"
        l_cSQLCommandCycle2 += [CHAR(36) COMMENT 'Type=UUI']
        l_cDefaultString := "'00000000-0000-0000-0000-000000000000'"

    case l_cFieldType == "JS"
        l_cSQLCommandCycle2 += [LONGTEXT COMMENT 'Type=JS']
        l_cDefaultString := "'{}'"

    otherwise
    
    endcase

    if !empty(l_cDefaultString)
        if l_lFieldAllowNull
            l_cSQLCommandCycle2 += [ NULL]
            if empty(l_cFieldDefault)
                l_cSQLCommandCycle1 += [,ALTER COLUMN ]+l_cFormattedFieldName+[ DROP DEFAULT]
            else
                l_cSQLCommandCycle2 += [ DEFAULT ]+l_cFieldDefault
            endif
        else
            l_cSQLCommandCycle2 += [ NOT NULL]
            if empty(l_cFieldDefault)
                l_cSQLCommandCycle2 += [ DEFAULT ]+l_cDefaultString
            else
                l_cSQLCommandCycle2 += [ DEFAULT ]+l_cFieldDefault
            endif
        endif
    endif

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cFormattedTableName := ::FormatIdentifier(par_cSchemaName+"."+par_cTableName)

    l_cSQLCommandCycle1 += [,ALTER COLUMN ]+l_cFormattedFieldName+[ ]

    l_cFieldTypeSuffix := iif(l_lFieldArray,"[]","")

    do case
    case !empty(el_inlist(l_cFieldType,"I","IB","IS","N"))
        do case
        case l_cFieldType == "I"
            l_cSQLCommandCycle1 += [TYPE integer]+l_cFieldTypeSuffix
        case l_cFieldType == "IB"
            l_cSQLCommandCycle1 += [TYPE bigint]+l_cFieldTypeSuffix
        case l_cFieldType == "IS"
            l_cSQLCommandCycle1 += [TYPE smallint]+l_cFieldTypeSuffix
        case l_cFieldType == "N"
            l_cSQLCommandCycle1 += [TYPE numeric(]+trans(l_nFieldLen)+[,]+trans(l_nFieldDec)+[)]+l_cFieldTypeSuffix
            if l_lFieldAutoIncrement
                l_lFieldAutoIncrement := .f.
                hb_orm_SendToDebugView("May not make numeric field auto-increment. Table: "+par_cSchemaName+"."+par_cTableName+" - Field: "+par_cFieldName)
            endif
        endcase

        if l_lFieldAutoIncrement .or. l_lCurrentFieldAutoIncrement
            do case
            case l_lFieldAutoIncrement = l_lCurrentFieldAutoIncrement
            case l_lFieldAutoIncrement // Make it Auto-Incremental
                l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ DROP DEFAULT]
                l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ SET NOT NULL]
                l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ ADD GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 )]
            otherwise    // Stop Auto-Incremental
                l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ DROP IDENTITY]
            endcase
        endif

        if l_lFieldAutoIncrement
            // Will always name the constraints in lower case
            l_cSQLCommandCycle1 += [,ADD CONSTRAINT ]+lower(par_cTableName)+[_pkey PRIMARY KEY (]+::FormatIdentifier(par_cFieldName)+[)]
        else
            do case
            case l_lFieldAllowNull = l_lCurrentFieldAllowNull
            case l_lFieldAllowNull
                // //Was NOT NULL
            otherwise    // Stop NULL
                l_cSQLCommandPreUpdate += [UPDATE ]+l_cFormattedTableName+[ SET ]+l_cFormattedFieldName+[ = 0  WHERE ]+l_cFormattedFieldName+[ IS NULL;]
            endcase

            l_cDefaultString := "0"

        endif

    case !empty(el_inlist(l_cFieldType,"C","CV","B","BV","M","R"))
        do case
        case l_cFieldType == "C"
            l_cSQLCommandCycle1 += [TYPE character(]+trans(l_nFieldLen)+[)]+l_cFieldTypeSuffix
        case l_cFieldType == "CV"
            l_cSQLCommandCycle1 += [TYPE character varying]+iif(empty(l_nFieldLen),[],[(]+trans(l_nFieldLen)+[)])+l_cFieldTypeSuffix
        case l_cFieldType == "B"
            l_cSQLCommandCycle1 += [TYPE bytea]+l_cFieldTypeSuffix
            l_cAdditionalSQLCommands += [COMMENT ON COLUMN ]+l_cFormattedTableName+"."+l_cFormattedFieldName+[ IS 'Type=B|Length=]+trans(l_nFieldLen)+[';]+CRLF
        case l_cFieldType == "BV"
            l_cSQLCommandCycle1 += [TYPE bytea]+l_cFieldTypeSuffix
            l_cAdditionalSQLCommands += [COMMENT ON COLUMN ]+l_cFormattedTableName+"."+l_cFormattedFieldName+[ IS 'Type=BV|Length=]+trans(l_nFieldLen)+[';]+CRLF
        case l_cFieldType == "M"
            l_cSQLCommandCycle1 += [TYPE text]+l_cFieldTypeSuffix
        case l_cFieldType == "R"
            l_cSQLCommandCycle1 += [TYPE bytea]+l_cFieldTypeSuffix
        endcase
        l_cDefaultString := "''"

    case l_cFieldType == "L"
        l_cSQLCommandCycle1 += [TYPE boolean]+l_cFieldTypeSuffix
        l_cDefaultString := "FALSE"

    case !empty(el_inlist(l_cFieldType,"D","TOZ","TO","DTZ","T","DT"))
        do case
        case l_cFieldType == "D"
            l_cSQLCommandCycle1 += [TYPE date]+l_cFieldTypeSuffix
        case l_cFieldType == "TOZ"
            if vfp_between(l_nFieldDec,0,6)
                l_cSQLCommandCycle1 += [TYPE time(]+trans(l_nFieldDec)+[) with time zone]+l_cFieldTypeSuffix
            else
                l_cSQLCommandCycle1 += [TYPE time with time zone]+l_cFieldTypeSuffix
            endif
        case l_cFieldType == "TO"
            if vfp_between(l_nFieldDec,0,6)
                l_cSQLCommandCycle1 += [TYPE time(]+trans(l_nFieldDec)+[) without time zone]+l_cFieldTypeSuffix
            else
                l_cSQLCommandCycle1 += [TYPE time without time zone]+l_cFieldTypeSuffix
            endif
        case l_cFieldType == "DTZ"
            if vfp_between(l_nFieldDec,0,6)
                l_cSQLCommandCycle1 += [TYPE timestamp(]+trans(l_nFieldDec)+[) with time zone]+l_cFieldTypeSuffix
            else
                l_cSQLCommandCycle1 += [TYPE timestamp with time zone]+l_cFieldTypeSuffix
            endif
        case l_cFieldType == "DT" .or. l_cFieldType == "T"
            if vfp_between(l_nFieldDec,0,6)
                l_cSQLCommandCycle1 += [TYPE timestamp(]+trans(l_nFieldDec)+[) without time zone]+l_cFieldTypeSuffix
            else
                l_cSQLCommandCycle1 += [TYPE timestamp without time zone]+l_cFieldTypeSuffix
            endif
        endcase
        l_cDefaultString := "'-infinity'"


    case l_cFieldType == "Y"
        l_cSQLCommandCycle1 += [TYPE money]+l_cFieldTypeSuffix
        l_cDefaultString := "0"

    case l_cFieldType == "UUI"
        l_cSQLCommandCycle1 += [TYPE uuid]+l_cFieldTypeSuffix
        l_cDefaultString := "'00000000-0000-0000-0000-000000000000'::uuid"

    case l_cFieldType == "JS"
        l_cSQLCommandCycle1 += [TYPE json]+l_cFieldTypeSuffix
        l_cDefaultString := "'{}'::json"

    otherwise
        
    endcase

    if !empty(l_cDefaultString)
        do case
        case l_lFieldAllowNull = l_lCurrentFieldAllowNull
            if !(l_cFieldDefault == l_cCurrentFieldDefault)
                if empty(l_cFieldDefault)
                    l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ DROP DEFAULT]
                else
                    l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ SET DEFAULT ]+l_cFieldDefault
                endif
            endif

        case l_lFieldAllowNull
            //Was NOT NULL
            if empty(l_cFieldDefault)
                l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ DROP DEFAULT]
            else
                l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ SET DEFAULT ]+l_cFieldDefault
            endif
            l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ DROP NOT NULL]

        otherwise    // Stop NULL
            if empty(l_cFieldDefault)
                l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ SET DEFAULT ]+l_cDefaultString
            else
                l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ SET DEFAULT ]+l_cFieldDefault
            endif
            l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ SET NOT NULL]

        endcase
    endif

endcase

return {l_cSQLCommandPreUpdate,l_cSQLCommandCycle1,l_cSQLCommandCycle2,l_cAdditionalSQLCommands}
//-----------------------------------------------------------------------------------------------------------------
method AddField(par_cSchemaName,par_cTableName,par_cFieldName,par_aFieldDefinition) class hb_orm_SQLConnect
local l_cSQLCommand := ""
local l_cAdditionalSQLCommands := ""
local l_cFieldType,l_lFieldArray,l_nFieldLen,l_nFieldDec,l_cFieldAttributes,l_lFieldAllowNull,l_lFieldAutoIncrement,l_cFieldDefault
local l_cFieldTypeSuffix
local l_cFormattedTableName
local l_cFormattedFieldName := ::FormatIdentifier(par_cFieldName)
local l_cDefaultString := ""

l_cFieldType          := par_aFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE]
l_nFieldLen           := par_aFieldDefinition[HB_ORM_SCHEMA_FIELD_LENGTH]
l_nFieldDec           := par_aFieldDefinition[HB_ORM_SCHEMA_FIELD_DECIMALS]
l_cFieldAttributes    := par_aFieldDefinition[HB_ORM_SCHEMA_FIELD_ATTRIBUTES]
l_cFieldDefault       := iif(len(par_aFieldDefinition) >= HB_ORM_SCHEMA_FIELD_DEFAULT,hb_DefaultValue(par_aFieldDefinition[HB_ORM_SCHEMA_FIELD_DEFAULT],""),"")
l_lFieldAllowNull     := ("N" $ l_cFieldAttributes)
l_lFieldAutoIncrement := ("+" $ l_cFieldAttributes)
l_lFieldArray         := ("A" $ l_cFieldAttributes)

l_cFieldDefault := ::NormalizeFieldDefaultForCurrentEngineType(l_cFieldDefault,l_cFieldType,l_nFieldDec)

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cFormattedTableName := ::FormatIdentifier(par_cTableName)
    
    l_cSQLCommand += [,ADD COLUMN ]+l_cFormattedFieldName+[ ]

    do case
    case !empty(el_inlist(l_cFieldType,"I","IB","IS","N"))
        do case
        case l_cFieldType == "I"
            l_cSQLCommand += [INT]
        case l_cFieldType == "IB"
            l_cSQLCommand += [BIGINT]
        case l_cFieldType == "IS"
            l_cSQLCommand += [SMALLINT]
        case l_cFieldType == "N"
            l_cSQLCommand += [DECIMAL(]+trans(l_nFieldLen)+[,]+trans(l_nFieldDec)+[)]
            if l_lFieldAutoIncrement
                l_lFieldAutoIncrement := .f.
                hb_orm_SendToDebugView("May not make numeric field auto-increment. Table: "+par_cTableName+" - Field: "+par_cFieldName)
            endif
        endcase

        if l_lFieldAutoIncrement
            l_cSQLCommand += [ NOT NULL AUTO_INCREMENT]
            l_cSQLCommand += [ PRIMARY KEY]

        else
            l_cDefaultString := "0"
        endif
        
    case !empty(el_inlist(l_cFieldType,"C","CV","B","BV","M","R"))
        do case
        case l_cFieldType == "C"
            l_cSQLCommand += [CHAR(]+trans(l_nFieldLen)+[)]
        case l_cFieldType == "CV"
            l_cSQLCommand += [VARCHAR]+iif(empty(l_nFieldLen),[],[(]+trans(l_nFieldLen)+[)])
        case l_cFieldType == "B"
            l_cSQLCommand += [BINARY(]+trans(l_nFieldLen)+[)]
        case l_cFieldType == "BV"
            l_cSQLCommand += [VARBINARY]+iif(empty(l_nFieldLen),[],[(]+trans(l_nFieldLen)+[)])
        case l_cFieldType == "M"
            l_cSQLCommand += [LONGTEXT]
        case l_cFieldType == "R"
            l_cSQLCommand += [LONGBLOB]
        endcase
        l_cDefaultString := "''"

    case l_cFieldType == "L"
        l_cSQLCommand += [TINYINT(1)]
        l_cDefaultString := "0"
        
    case !empty(el_inlist(l_cFieldType,"D","TOZ","TO","DTZ","T","DT"))
        do case
        case l_cFieldType == "D"
            l_cSQLCommand += [DATE]
            l_cDefaultString    := ['0000-00-00']
        case l_cFieldType == "TOZ"
            if vfp_between(l_nFieldDec,0,6)
                l_cSQLCommand += [TIME(]+trans(l_nFieldDec)+[) COMMENT 'Type=TOZ']
            else
                l_cSQLCommand += [TIME COMMENT 'Type=TOZ']
            endif
            l_cDefaultString    := ['00:00:00']
        case l_cFieldType == "TO"
            if vfp_between(l_nFieldDec,0,6)
                l_cSQLCommand += [TIME(]+trans(l_nFieldDec)+[)]
            else
                l_cSQLCommand += [TIME]
            endif
            l_cDefaultString    := ['00:00:00']
        case l_cFieldType == "DTZ"
            if vfp_between(l_nFieldDec,0,6)
                l_cSQLCommand += [TIMESTAMP(]+trans(l_nFieldDec)+[)]
            else
                l_cSQLCommand += [TIMESTAMP]
            endif
            l_cDefaultString    := ['0000-00-00 00:00:00']
        case l_cFieldType == "DT" .or. l_cFieldType == "T"
            if vfp_between(l_nFieldDec,0,6)
                l_cSQLCommand += [DATETIME(]+trans(l_nFieldDec)+[)]
            else
                l_cSQLCommand += [DATETIME]
            endif
            l_cDefaultString    := ['0000-00-00 00:00:00']
        endcase

    case l_cFieldType == "Y"
        l_cSQLCommand += [DECIMAL(13,4) COMMENT 'Type=Y']
        l_cDefaultString := "0"

    case l_cFieldType == "UUI"
        l_cSQLCommand += [CHAR(36) COMMENT 'Type=UUI']
        l_cDefaultString := "'00000000-0000-0000-0000-000000000000'"

    case l_cFieldType == "JS"
        l_cSQLCommand += [LONGTEXT COMMENT 'Type=JS']
        l_cDefaultString := "'{}'"

    otherwise
        
    endcase

    if !empty(l_cDefaultString)
        if l_lFieldAllowNull
            if empty(l_cFieldDefault)
                l_cSQLCommand += [ NULL]
            else
                l_cSQLCommand += [ NULL DEFAULT ]+l_cFieldDefault
            endif
        else
            if empty(l_cFieldDefault)
                l_cSQLCommand += [ NOT NULL DEFAULT ]+l_cDefaultString
            else
                l_cSQLCommand += [ NOT NULL DEFAULT ]+l_cFieldDefault
            endif
        endif
    endif

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL

    //_M_  How to deal with default values for not null and array types?

    l_cFormattedTableName := ::FormatIdentifier(par_cSchemaName+"."+par_cTableName)

    l_cSQLCommand += [,ADD COLUMN ]+l_cFormattedFieldName+[ ]

    l_cFieldTypeSuffix := iif(l_lFieldArray,"[]","")

    do case
    case !empty(el_inlist(l_cFieldType,"I","IB","IS","N"))
        do case
        case l_cFieldType == "I"
            l_cSQLCommand += [integer]+l_cFieldTypeSuffix
        case l_cFieldType == "IB"
            l_cSQLCommand += [bigint]+l_cFieldTypeSuffix
        case l_cFieldType == "IS"
            l_cSQLCommand += [smallint]+l_cFieldTypeSuffix
        case l_cFieldType == "N"
            l_cSQLCommand += [numeric(]+trans(l_nFieldLen)+[,]+trans(l_nFieldDec)+[)]+l_cFieldTypeSuffix
            if l_lFieldAutoIncrement
                l_lFieldAutoIncrement := .f.
                hb_orm_SendToDebugView("May not make numeric field auto-increment. Table: "+par_cSchemaName+"."+par_cTableName+" - Field: "+par_cFieldName)
            endif
        endcase

        if l_lFieldAutoIncrement
            l_cSQLCommand += [ NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 )]
            l_cSQLCommand += [,ADD CONSTRAINT ]+lower(par_cTableName)+[_pkey PRIMARY KEY (]+::FormatIdentifier(par_cFieldName)+[)]
        else
            l_cDefaultString := "0"
        endif
        
    case !empty(el_inlist(l_cFieldType,"C","CV","M","B","BV","R"))
        do case
        case l_cFieldType == "C"
            l_cSQLCommand += [character(]+trans(l_nFieldLen)+[)]+l_cFieldTypeSuffix
        case l_cFieldType == "CV"
            l_cSQLCommand += [character varying]+iif(empty(l_nFieldLen),[],[(]+trans(l_nFieldLen)+[)])+l_cFieldTypeSuffix
        case l_cFieldType == "M"
            l_cSQLCommand += [text]+l_cFieldTypeSuffix
        case l_cFieldType == "B"
            l_cSQLCommand += [bytea]+l_cFieldTypeSuffix
            l_cAdditionalSQLCommands += [COMMENT ON COLUMN ]+l_cFormattedTableName+"."+l_cFormattedFieldName+[ IS 'Type=B|Length=]+trans(l_nFieldLen)+[';]+CRLF
        case l_cFieldType == "BV"
            l_cSQLCommand += [bytea]+l_cFieldTypeSuffix
            l_cAdditionalSQLCommands += [COMMENT ON COLUMN ]+l_cFormattedTableName+"."+l_cFormattedFieldName+[ IS 'Type=BV|Length=]+trans(l_nFieldLen)+[';]+CRLF
        case l_cFieldType == "R"
            l_cSQLCommand += [bytea]+l_cFieldTypeSuffix
        endcase
        l_cDefaultString := "''"

    case l_cFieldType == "L"
        l_cSQLCommand += [boolean]+l_cFieldTypeSuffix
        l_cDefaultString := "FALSE"

    case !empty(el_inlist(l_cFieldType,"D","TOZ","TO","DTZ","T","DT"))
        do case
        case l_cFieldType == "D"
            l_cSQLCommand += [date]+l_cFieldTypeSuffix
        case l_cFieldType == "TOZ"
            if vfp_between(l_nFieldDec,0,6)
                l_cSQLCommand += [time(]+trans(l_nFieldDec)+[) with time zone]+l_cFieldTypeSuffix
            else
                l_cSQLCommand += [time with time zone]+l_cFieldTypeSuffix
            endif
        case l_cFieldType == "TO"
            if vfp_between(l_nFieldDec,0,6)
                l_cSQLCommand += [time(]+trans(l_nFieldDec)+[) without time zone]+l_cFieldTypeSuffix
            else
                l_cSQLCommand += [time without time zone]+l_cFieldTypeSuffix
            endif
        case l_cFieldType == "DTZ"
            if vfp_between(l_nFieldDec,0,6)
                l_cSQLCommand += [timestamp(]+trans(l_nFieldDec)+[) with time zone]+l_cFieldTypeSuffix
            else
                l_cSQLCommand += [timestamp with time zone]+l_cFieldTypeSuffix
            endif
        case l_cFieldType == "DT" .or. l_cFieldType == "T"
            if vfp_between(l_nFieldDec,0,6)
                l_cSQLCommand += [timestamp(]+trans(l_nFieldDec)+[) without time zone]+l_cFieldTypeSuffix
            else
                l_cSQLCommand += [timestamp without time zone]+l_cFieldTypeSuffix
            endif
        endcase
        l_cDefaultString := "'-infinity'"
        
    case l_cFieldType == "Y"
        l_cSQLCommand += [money]+l_cFieldTypeSuffix
        l_cDefaultString := "0"
        
    case l_cFieldType == "UUI"
        l_cSQLCommand += [uuid]+l_cFieldTypeSuffix
        l_cDefaultString := "'00000000-0000-0000-0000-000000000000'::uuid"

    case l_cFieldType == "JS"
        l_cSQLCommand += [json]+l_cFieldTypeSuffix
        l_cDefaultString := "'{}'::json"

    otherwise
        
    endcase

    if !empty(l_cDefaultString)
        if l_lFieldAllowNull
            if empty(l_cFieldDefault)
            else
                l_cSQLCommand += [ DEFAULT ]+l_cFieldDefault
            endif
        else
            if empty(l_cFieldDefault)
                l_cSQLCommand += [ NOT NULL DEFAULT ]+l_cDefaultString
            else
                l_cSQLCommand += [ NOT NULL DEFAULT ]+l_cFieldDefault
            endif
        endif
    endif

endcase

return {"",l_cSQLCommand,"",l_cAdditionalSQLCommands}
// return l_cSQLCommand
//-----------------------------------------------------------------------------------------------------------------
method AddIndex(par_cSchemaName,par_cTableName,par_hFields,par_cIndexName,par_aIndexDefinition) class hb_orm_SQLConnect
local l_cSQLCommand := ""
local l_cIndexNameOnFile
local l_cIndexExpression
local l_lIndexUnique
local l_cIndexType
local l_cFormattedTableName

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cIndexNameOnFile   := lower(par_cTableName)+"_"+lower(par_cIndexName)+"_idx"
    l_cFormattedTableName := ::FormatIdentifier(par_cTableName)
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cIndexNameOnFile   := lower(par_cSchemaName)+"_"+lower(par_cTableName)+"_"+lower(par_cIndexName)+"_idx"
    l_cFormattedTableName := ::FormatIdentifier(par_cSchemaName+"."+par_cTableName)
endcase

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cIndexExpression := ::FixCasingInFieldExpression(par_hFields,par_aIndexDefinition[HB_ORM_SCHEMA_INDEX_EXPRESSION])
    l_lIndexUnique     := par_aIndexDefinition[HB_ORM_SCHEMA_INDEX_UNIQUE]
    l_cIndexType       := par_aIndexDefinition[HB_ORM_SCHEMA_INDEX_ALGORITHM]
    if empty(l_cIndexType)
        l_cIndexType := "BTREE"
    endif

    l_cSQLCommand := [ALTER TABLE ]+l_cFormattedTableName
	l_cSQLCommand += [ ADD ]+iif(l_lIndexUnique,"UNIQUE ","")+[INDEX `]+l_cIndexNameOnFile+[` (]+l_cIndexExpression+[) USING ]+l_cIndexType+[;]+CRLF
// altd()

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cIndexExpression := ::FixCasingInFieldExpression(par_hFields,par_aIndexDefinition[HB_ORM_SCHEMA_INDEX_EXPRESSION])
    l_lIndexUnique     := par_aIndexDefinition[HB_ORM_SCHEMA_INDEX_UNIQUE]
    l_cIndexType       := par_aIndexDefinition[HB_ORM_SCHEMA_INDEX_ALGORITHM]
    if empty(l_cIndexType)
        l_cIndexType := "BTREE"
    endif

    // Will create index named in lower cases.
    l_cSQLCommand := [CREATE ]+iif(l_lIndexUnique,"UNIQUE ","")+[INDEX ]+l_cIndexNameOnFile
    l_cSQLCommand += [ ON ]+l_cFormattedTableName+[ USING ]+l_cIndexType
    l_cSQLCommand += [ (]+l_cIndexExpression+[);]+CRLF

endcase

return l_cSQLCommand
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
local l_cFieldType,l_nFieldLen,l_nFieldDec,l_cFieldAttributes,l_lFieldAllowNull,l_lFieldAutoIncrement,l_lFieldArray,l_cFieldDefault
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
        
        l_cFieldType          := allt(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE])
        l_nFieldLen           := hb_DefaultValue(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_LENGTH]        , 0 )
        l_nFieldDec           := hb_DefaultValue(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_DECIMALS]      , 0 )
        l_cFieldAttributes    := hb_DefaultValue(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_ATTRIBUTES]    , "")
        l_cFieldDefault       := iif(len(l_aFieldDefinition) >= HB_ORM_SCHEMA_FIELD_DEFAULT,hb_DefaultValue(l_aFieldDefinition[HB_ORM_SCHEMA_FIELD_DEFAULT],""),"")
        l_lFieldAllowNull     := ("N" $ l_cFieldAttributes)
        l_lFieldAutoIncrement := ("+" $ l_cFieldAttributes)
        l_lFieldArray         := ("A" $ l_cFieldAttributes)

        if lower(l_cFieldName) == lower(::p_PrimaryKeyFieldName)
            l_lFieldAutoIncrement := .t.
        endif
        if l_lFieldAutoIncrement .and. empty(el_inlist(l_cFieldType,"I","IB","IS"))  //Only those fields types may be flagged as Auto-Increment
            l_lFieldAutoIncrement := .f.
        endif
        if l_lFieldAutoIncrement .and. l_lFieldAllowNull  //Auto-Increment fields may not be null (and not have a default)
            l_lFieldAllowNull := .f.
        endif

        l_cFieldAttributes := iif(l_lFieldAllowNull,"N","")+iif(l_lFieldAutoIncrement,"+","")+iif(l_lFieldArray,"A","")

        l_cSourceCodeFields += padr('"'+l_cFieldName+'"',l_nMaxNameLength+2)+"=>{"
        l_cSourceCodeFields += ","  // Null Value for the HB_ORM_SCHEMA_INDEX_BACKEND_TYPES 
        l_cSourceCodeFields += padl('"'+l_cFieldType+'"',5)+","+;
                             str(l_nFieldLen,4)+","+;
                             str(l_nFieldDec,3)+","+;
                             iif(empty(l_cFieldAttributes),"",'"'+l_cFieldAttributes+'"')
        if !empty(l_cFieldDefault)
            l_cSourceCodeFields += ',"'+strtran(l_cFieldDefault,["],["+'"'+"])+'"'
        endif
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
        
        AEval(hb_HKeys(l_hIndexes),{|l_cIndexName|l_nMaxNameLength:=max(l_nMaxNameLength,len(l_cIndexName))})  //Get length of max IndexName length

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
local l_cSQLCommand
local l_Success := .f.

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_Success := .t.

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    // https://www.enterprisedb.com/postgres-tutorials/how-use-event-triggers-postgresql
    // ddl acronym = Data Definition Language
    // ddl statements: CREATE, ALTER, TRUNCATE, DROP
    // https://www.postgresql.org/docs/13/event-trigger-matrix.html

    // UPDATED   #define HB_ORM_TRIGGERVERSION to a new number in case the code below is changed.

    TEXT TO VAR l_cSQLCommand
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
  IF tg_tag = 'DROP TABLE' OR tg_tag = 'DROP INDEX' OR tg_tag = 'DROP SCHEMA' THEN
    --Do nothing since the schema_log_ddl_drop will also be triggered
  ELSE
    FOR r IN SELECT * FROM pg_event_trigger_ddl_commands() LOOP
      IF position('SchemaCache' in r.object_identity) = 0 THEN
        IF r.object_type = 'sequence' OR r.object_type = 'function' THEN
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
  IF tg_tag = 'DROP TABLE' OR tg_tag = 'DROP INDEX' OR tg_tag = 'DROP SCHEMA' THEN
    FOR r IN SELECT * FROM pg_event_trigger_dropped_objects() LOOP
      IF position('SchemaCache' in r.object_identity) = 0 THEN
        IF r.object_type = 'sequence' OR r.object_type = 'function' THEN
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

    if ::PostgreSQLIdentifierCasing != HB_ORM_POSTGRESQL_CASE_SENSITIVE
        l_cSQLCommand := Strtran(l_cSQLCommand,"SchemaCacheLog","schemacachelog")
        l_cSQLCommand := Strtran(l_cSQLCommand,"SchemaCache"   ,"schemacache")
    endif

    if !(::PostgreSQLHBORMSchemaName == "hborm")
        l_cSQLCommand := strtran(l_cSQLCommand,"hborm",::FormatIdentifier(::PostgreSQLHBORMSchemaName))
    endif

    l_Success := ::SQLExec(l_cSQLCommand)

endcase

return l_Success
//-----------------------------------------------------------------------------------------------------------------
method DisableSchemaChangeTracking() class hb_orm_SQLConnect
local l_cSQLCommand
local l_Success := .f.

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_Success := .t.
    
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    TEXT TO VAR l_cSQLCommand
DROP EVENT TRIGGER IF EXISTS schema_log_ddl_info;
DROP EVENT TRIGGER IF EXISTS schema_log_ddl_drop_info;

DROP FUNCTION IF EXISTS hborm.schema_log_ddl;
DROP FUNCTION IF EXISTS hborm.schema_log_ddl_drop;
    ENDTEXT

    if !(::PostgreSQLHBORMSchemaName == "hborm")
        l_cSQLCommand := strtran(l_cSQLCommand,"hborm",::FormatIdentifier(::PostgreSQLHBORMSchemaName))
    endif

    l_Success := ::SQLExec(l_cSQLCommand)

endcase

return l_Success
//-----------------------------------------------------------------------------------------------------------------
method RemoveSchemaChangeTracking() class hb_orm_SQLConnect
local l_cSQLCommand
local l_Success := .f.

::DisableSchemaChangeTracking()

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_Success := .t.
    
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cSQLCommand := [DROP TABLE IF EXISTS hborm.]+::FixCasingOfSchemaCacheTables(["SchemaCacheLog"])+[;]
    
    if !(::PostgreSQLHBORMSchemaName == "hborm")
        l_cSQLCommand := strtran(l_cSQLCommand,"hborm",::FormatIdentifier(::PostgreSQLHBORMSchemaName))
    endif

    l_Success := ::SQLExec(l_cSQLCommand)

endcase

return l_Success
//-----------------------------------------------------------------------------------------------------------------
method UpdateSchemaCache(par_lForce) class hb_orm_SQLConnect   //returns .t. if cache was updated
local l_cSQLCommand
// local l_cSQLCommandFields
// local l_cSQLCommandIndexes
local l_nSelect := iif(used(),select(),0)
// local l_CacheFullName
local l_CacheFullNameField
local l_CacheFullNameIndex
local l_lResult := .f.
local l_HBORMSchemaName := ::FormatIdentifier(::PostgreSQLHBORMSchemaName)

hb_Default(@par_lForce,.f.)

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    // altd()

    if par_lForce
        //Add an Entry in SchemaCacheLog to notify to make a cache
        l_cSQLCommand := [INSERT INTO ]+l_HBORMSchemaName+::FixCasingOfSchemaCacheTables([."SchemaCacheLog"])+[ (action) VALUES ('No Change');]
        ::SQLExec(l_cSQLCommand)
    endif

    l_cSQLCommand := [SELECT pk,]
    l_cSQLCommand += [       cachedschema::integer]
    l_cSQLCommand += [ FROM  ]+l_HBORMSchemaName+::FixCasingOfSchemaCacheTables([."SchemaCacheLog"])
    l_cSQLCommand += [ ORDER BY pk DESC]
    l_cSQLCommand += [ LIMIT 1]

    if ::SQLExec(l_cSQLCommand,"SchemaCacheLogLast")
        if SchemaCacheLogLast->(reccount()) == 1
            if SchemaCacheLogLast->cachedschema == 0   //Meaning the last schema change log was not cached  (0 = false)
//hb_orm_SendToDebugView("Will create a new Schema Cache")


l_CacheFullNameField := l_HBORMSchemaName+::FixCasingOfSchemaCacheTables([."SchemaCacheFields_])+trans(SchemaCacheLogLast->pk)+["]
l_CacheFullNameIndex := l_HBORMSchemaName+::FixCasingOfSchemaCacheTables([."SchemaCacheIndexes_])+trans(SchemaCacheLogLast->pk)+["]

//====================================
l_cSQLCommand := [DROP FUNCTION IF EXISTS ]+l_HBORMSchemaName+[.hb_orm_update_schema_cache;]+CRLF
//====================================
l_cSQLCommand += [CREATE OR REPLACE FUNCTION ]+l_HBORMSchemaName+[.hb_orm_update_schema_cache(par_cache_full_name_field text,par_cache_full_name_index text) RETURNS boolean]
l_cSQLCommand += [ LANGUAGE plpgsql VOLATILE SECURITY DEFINER AS $BODY$]+CRLF
l_cSQLCommand += [DECLARE]+CRLF
l_cSQLCommand += [   v_SQLCommand text;]+CRLF
l_cSQLCommand += [   v_lReturn boolean := TRUE;]+CRLF
l_cSQLCommand += [BEGIN]+CRLF
l_cSQLCommand += [SET enable_nestloop = false;]+CRLF //    -- See  https://github.com/yugabyte/yugabyte-db/issues/9938
// -------------------------------------------------------------------------------------
l_cSQLCommand += [EXECUTE format('DROP TABLE IF EXISTS %s', par_cache_full_name_field);]+CRLF

l_cSQLCommand += [v_SQLCommand := $$]+CRLF
l_cSQLCommand += [SELECT columns.table_schema::text        AS schema_name,]+CRLF
l_cSQLCommand += [       columns.table_name::text          AS table_name,]+CRLF
l_cSQLCommand += [       columns.ordinal_position::integer AS field_position,]+CRLF
l_cSQLCommand += [       columns.column_name::text         AS field_name,]+CRLF
l_cSQLCommand += [      CASE]+CRLF
l_cSQLCommand += [         WHEN columns.data_type = 'ARRAY' THEN element_types.data_type::text]+CRLF
l_cSQLCommand += [        ELSE columns.data_type::text]+CRLF
l_cSQLCommand += [      END AS field_type,]+CRLF
l_cSQLCommand += [         CASE]+CRLF
l_cSQLCommand += [         WHEN columns.data_type = 'ARRAY' THEN true]+CRLF
l_cSQLCommand += [        ELSE false]+CRLF
l_cSQLCommand += [      END AS field_array,]+CRLF
l_cSQLCommand += [       columns.character_maximum_length::integer AS field_clength,]+CRLF
l_cSQLCommand += [       columns.numeric_precision::integer        AS field_nlength,]+CRLF
l_cSQLCommand += [       columns.datetime_precision::integer       AS field_tlength,]+CRLF
l_cSQLCommand += [       columns.numeric_scale::integer            AS field_decimals,]+CRLF
l_cSQLCommand += [       (columns.is_nullable = 'YES')    AS field_nullable,]+CRLF
l_cSQLCommand += [       columns.column_default::text     AS field_default,]+CRLF
l_cSQLCommand += [       (columns.is_identity = 'YES')    AS field_auto_increment,]+CRLF
l_cSQLCommand += [       pgd.description                  AS field_comment,]+CRLF
l_cSQLCommand += [       upper(columns.table_schema)      AS tag1,]+CRLF
l_cSQLCommand += [       upper(columns.table_name)        AS tag2]+CRLF
l_cSQLCommand += [ FROM information_schema.columns]+CRLF
l_cSQLCommand += [ INNER JOIN pg_catalog.pg_statio_all_tables as st ON columns.table_schema = st.schemaname and columns.table_name = st.relname]+CRLF
l_cSQLCommand += [ INNER JOIN information_schema.tables             ON columns.table_schema = tables.table_schema AND columns.table_name = tables.table_name]+CRLF
l_cSQLCommand += [ LEFT JOIN pg_catalog.pg_description pgd          ON pgd.objoid=st.relid and pgd.objsubid=columns.ordinal_position]+CRLF
l_cSQLCommand += [ LEFT  JOIN information_schema.element_types ON ((columns.table_catalog, columns.table_schema, columns.table_name, 'TABLE', columns.dtd_identifier) = (element_types.object_catalog, element_types.object_schema, element_types.object_name, element_types.object_type, element_types.collection_type_identifier))]+CRLF
l_cSQLCommand += [ WHERE NOT (lower(left(columns.table_name,11)) = 'schemacache' OR lower(columns.table_schema) in ('information_schema','pg_catalog'))]+CRLF
l_cSQLCommand += [ AND   tables.table_type = 'BASE TABLE']+CRLF
l_cSQLCommand += [ ORDER BY tag1,tag2,field_position;]+CRLF
l_cSQLCommand += [$$;]+CRLF
l_cSQLCommand += [v_SQLCommand := CONCAT('CREATE TABLE ',par_cache_full_name_field,' AS ',v_SQLCommand);]+CRLF
l_cSQLCommand += [EXECUTE v_SQLCommand;]+CRLF
// -------------------------------------------------------------------------------------
l_cSQLCommand += [EXECUTE format('DROP TABLE IF EXISTS %s', par_cache_full_name_index);]+CRLF
// -------------------------------------------------------------------------------------
l_cSQLCommand += [v_SQLCommand := $$]+CRLF
l_cSQLCommand += [SELECT pg_indexes.schemaname      AS schema_name,]+CRLF
l_cSQLCommand += [       pg_indexes.tablename       AS table_name,]+CRLF
l_cSQLCommand += [       pg_indexes.indexname       AS index_name,]+CRLF
l_cSQLCommand += [       pg_indexes.indexdef        AS index_definition,]+CRLF
l_cSQLCommand += [       upper(pg_indexes.schemaname) AS tag1,]+CRLF
l_cSQLCommand += [       upper(pg_indexes.tablename) AS tag2]+CRLF
l_cSQLCommand += [ FROM pg_indexes]+CRLF
l_cSQLCommand += [ WHERE NOT (lower(left(pg_indexes.tablename,11)) = 'schemacache' OR lower(pg_indexes.schemaname) in ('information_schema','pg_catalog'))]+CRLF
l_cSQLCommand += [ ORDER BY tag1,index_name;]+CRLF
l_cSQLCommand += [$$;]+CRLF
l_cSQLCommand += [v_SQLCommand := CONCAT('CREATE TABLE ',par_cache_full_name_index,' AS ',v_SQLCommand);]+CRLF
l_cSQLCommand += [EXECUTE v_SQLCommand;]+CRLF
// -------------------------------------------------------------------------------------
l_cSQLCommand += [SET enable_nestloop = true;]+CRLF
// l_cSQLCommand += [RAISE NOTICE '%',v_SQLCommand;]
l_cSQLCommand += [RETURN v_lReturn;]+CRLF
l_cSQLCommand += [END]+CRLF
l_cSQLCommand += [$BODY$;]+CRLF
//====================================
l_cSQLCommand += [SELECT ]+l_HBORMSchemaName+[.hb_orm_update_schema_cache(']+l_CacheFullNameField+[',']+l_CacheFullNameIndex+[');]+CRLF
//====================================
l_cSQLCommand += [DROP FUNCTION IF EXISTS ]+l_HBORMSchemaName+[.hb_orm_update_schema_cache;]+CRLF
//====================================

// -------------------------------------------------------------------------------------






                // l_CacheFullName := ::FormatIdentifier(::PostgreSQLHBORMSchemaName)+::FixCasingOfSchemaCacheTables([."SchemaCacheFields_])+trans(SchemaCacheLogLast->pk)+["]
                // l_cSQLCommandFields := [DROP TABLE IF EXISTS ]+l_CacheFullName+[;]+CRLF
                // l_cSQLCommandFields += [CREATE TABLE ]+l_CacheFullName+[ AS ]

                // l_cSQLCommandFields += [SELECT columns.table_schema              AS schema_name,]
                // l_cSQLCommandFields +=         [columns.table_name               AS table_name,]
                // l_cSQLCommandFields +=         [columns.ordinal_position         AS field_position,]
                // l_cSQLCommandFields +=         [columns.column_name              AS field_name,]
                // l_cSQLCommandFields +=         [columns.data_type                AS field_type,]
                // //_M_ is array 
                // l_cSQLCommandFields +=         [columns.character_maximum_length AS field_clength,]
                // l_cSQLCommandFields +=         [columns.numeric_precision        AS field_nlength,]
                // l_cSQLCommandFields +=         [columns.datetime_precision       AS field_tlength,]
                // l_cSQLCommandFields +=         [columns.numeric_scale            AS field_decimals,]
                // l_cSQLCommandFields +=         [(columns.is_nullable = 'YES')    AS field_nullable,]
                // l_cSQLCommandFields +=         [columns.column_default           AS field_default,]
                // l_cSQLCommandFields +=         [(columns.is_identity = 'YES')    AS field_auto_increment,]
                // l_cSQLCommandFields +=         [pgd.description                  AS field_comment,]
                // l_cSQLCommandFields +=         [upper(columns.table_schema)      AS tag1,]
                // l_cSQLCommandFields +=         [upper(columns.table_name)        AS tag2]
                // l_cSQLCommandFields += [ FROM information_schema.columns]
                // l_cSQLCommandFields += [ INNER JOIN pg_catalog.pg_statio_all_tables as st ON columns.table_schema = st.schemaname and columns.table_name = st.relname]
                // l_cSQLCommandFields += [ INNER JOIN information_schema.tables             ON columns.table_schema = tables.table_schema AND columns.table_name = tables.table_name]
                // l_cSQLCommandFields += [ LEFT JOIN pg_catalog.pg_description pgd          ON pgd.objoid=st.relid and pgd.objsubid=columns.ordinal_position]
                // l_cSQLCommandFields += [ WHERE NOT (lower(left(columns.table_name,11)) = 'schemacache' OR lower(columns.table_schema) in ('information_schema','pg_catalog'))]
                // l_cSQLCommandFields += [ AND   tables.table_type = 'BASE TABLE']
                // l_cSQLCommandFields += [ ORDER BY tag1,tag2,field_position;]

                // l_CacheFullName := ::FormatIdentifier(::PostgreSQLHBORMSchemaName)+::FixCasingOfSchemaCacheTables([."SchemaCacheIndexes_])+trans(SchemaCacheLogLast->pk)+["]
                
                // l_cSQLCommandIndexes := [DROP TABLE IF EXISTS ]+l_CacheFullName+[;]+CRLF
                // l_cSQLCommandIndexes += [CREATE TABLE ]+l_CacheFullName+[ AS ]
                // l_cSQLCommandIndexes += [SELECT pg_indexes.schemaname      AS schema_name,]
                // l_cSQLCommandIndexes +=         [pg_indexes.tablename       AS table_name,]
                // l_cSQLCommandIndexes +=         [pg_indexes.indexname       AS index_name,]
                // l_cSQLCommandIndexes +=         [pg_indexes.indexdef        AS index_definition,]
                // l_cSQLCommandIndexes +=         [upper(pg_indexes.schemaname) AS tag1,]
                // l_cSQLCommandIndexes +=         [upper(pg_indexes.tablename) AS tag2]
                // l_cSQLCommandIndexes += [ FROM pg_indexes]
                // l_cSQLCommandIndexes += [ WHERE NOT (lower(left(pg_indexes.tablename,11)) = 'schemacache' OR lower(pg_indexes.schemaname) in ('information_schema','pg_catalog'))]
                // l_cSQLCommandIndexes += [ ORDER BY tag1,index_name;]

                // if ::SQLExec(l_cSQLCommandFields) .and. ::SQLExec(l_cSQLCommandIndexes)

// ALTD()
                if ::SQLExec(l_cSQLCommand)


                    l_cSQLCommand := [UPDATE ]+l_HBORMSchemaName+::FixCasingOfSchemaCacheTables([."SchemaCacheLog"])
                    l_cSQLCommand += [ SET cachedschema = TRUE]
                    l_cSQLCommand += [ WHERE pk = ]+trans(SchemaCacheLogLast->pk)

                    if ::SQLExec(l_cSQLCommand)
                    
//hb_orm_SendToDebugView("Done creating a new Schema Cache")
                        //Remove any previous cache
                        l_cSQLCommand := [SELECT pk]
                        l_cSQLCommand += [ FROM ]+l_HBORMSchemaName+::FixCasingOfSchemaCacheTables([."SchemaCacheLog"])
                        l_cSQLCommand += [ WHERE cachedschema]
                        l_cSQLCommand += [ AND pk < ]+trans(SchemaCacheLogLast->pk)
                        l_cSQLCommand += [ ORDER BY pk]  // Oldest to newest

                        if ::SQLExec(l_cSQLCommand,"SchemaCacheLogLast")
                            select SchemaCacheLogLast
                            scan all
                                if recno() == reccount()  // Since last record is the latest beside the one just added, will exit the scan
                                    exit
                                endif
                                l_cSQLCommand := [UPDATE ]+l_HBORMSchemaName+::FixCasingOfSchemaCacheTables([."SchemaCacheLog"])
                                l_cSQLCommand += [ SET cachedschema = FALSE]
                                l_cSQLCommand += [ WHERE pk = ]+trans(SchemaCacheLogLast->pk)
                                
                                if ::SQLExec(l_cSQLCommand)
                                    l_cSQLCommand := [DROP TABLE ]+l_HBORMSchemaName+::FixCasingOfSchemaCacheTables([."SchemaCacheFields_])+trans(SchemaCacheLogLast->pk)+["]
                                    ::SQLExec(l_cSQLCommand)
                                    l_cSQLCommand := [DROP TABLE ]+l_HBORMSchemaName+::FixCasingOfSchemaCacheTables([."SchemaCacheIndexes_])+trans(SchemaCacheLogLast->pk)+["]
                                    ::SQLExec(l_cSQLCommand)
                                endif
                            endscan

                        endif
                    endif
                endif
                // ::LoadSchema()
                l_lResult := .t.
            endif
        endif
    endif
    CloseAlias("SchemaCacheLogLast")
    select (l_nSelect)

endcase

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method IsReservedWord(par_cIdentifier) class hb_orm_SQLConnect
local l_lResult := .f.

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    // https://dev.mysql.com/doc/refman/8.0/en/keywords.html
    l_lResult := AScan( ::ReservedWordsMySQL, {|cWord|cWord == upper(alltrim(par_cIdentifier)) } ) > 0

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    // https://www.postgresql.org/docs/13/sql-keywords-appendix.html
    l_lResult := AScan( ::ReservedWordsPostgreSQL, {|cWord|cWord == upper(alltrim(par_cIdentifier)) } ) > 0

endcase

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method FormatIdentifier(par_cName) class hb_orm_SQLConnect
local l_cFormattedIdentifier
local l_nPos
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
    l_nPos := at(".",par_cName)
    if l_nPos == 0  // no Schema name was specified
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
        l_cSchemaName := left(par_cName,l_nPos-1)
        l_cTableName  := substr(par_cName,l_nPos+1)

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
local l_cSchemaAndTableName := hb_StrReplace(par_cSchemaAndTableName,{' '=>'','"'=>'',"'"=>""})
local l_nHashPos
//Fix The Casing of Table and Field based on he actual on file tables.
l_nHashPos := hb_hPos(::p_Schema,l_cSchemaAndTableName)
if l_nHashPos > 0
    l_cSchemaAndTableName := hb_hKeyAt(::p_Schema,l_nHashPos) 
else
    // Report Failed to find Table by returning empty.
    l_cSchemaAndTableName := ""
endif
return l_cSchemaAndTableName
//-----------------------------------------------------------------------------------------------------------------
method CaseFieldName(par_cSchemaAndTableName,par_cFieldName) class hb_orm_SQLConnect
// local l_cSchemaAndTableName := allt(par_cSchemaAndTableName)
local l_cSchemaAndTableName := hb_StrReplace(par_cSchemaAndTableName,{' '=>'','"'=>'',"'"=>""})
local l_cFieldName          := allt(par_cFieldName)
local l_nHashPos
l_nHashPos := hb_hPos(::p_Schema[l_cSchemaAndTableName][HB_ORM_SCHEMA_FIELD],l_cFieldName)
if l_nHashPos > 0
    l_cFieldName := hb_hKeyAt(::p_Schema[l_cSchemaAndTableName][HB_ORM_SCHEMA_FIELD],l_nHashPos)
else
    // Report Failed to find Field by returning empty.
    l_cFieldName := ""
endif
return l_cFieldName


//12345
//-----------------------------------------------------------------------------------------------------------------
method GetFieldInfo(par_cSchemaAndTableName,par_cFieldName) class hb_orm_SQLConnect    // Returns Array {SchemaName,TableName,FieldName,FieldType,FieldLen,FieldDec,FieldAllowNull,FieldAutoIncrement,FieldArray,FieldDefault}
local l_aResult := {}

local l_cSchemaAndTableName := hb_StrReplace(par_cSchemaAndTableName,{' '=>'','"'=>'',"'"=>""})
local l_cFieldName := allt(par_cFieldName)
local l_cSchemaName
local l_cTableName
local l_aFieldInfo
local l_nHashPos
local l_nPos

l_nHashPos := hb_hPos(::p_Schema,l_cSchemaAndTableName)
if l_nHashPos > 0
    l_cSchemaAndTableName := hb_hKeyAt(::p_Schema,l_nHashPos)   // To get the proper casing
    l_nHashPos := hb_hPos(::p_Schema[l_cSchemaAndTableName][HB_ORM_SCHEMA_FIELD],l_cFieldName)
    if l_nHashPos > 0
        l_cFieldName  := hb_hKeyAt(::p_Schema[l_cSchemaAndTableName][HB_ORM_SCHEMA_FIELD],l_nHashPos)
        l_aFieldInfo := hb_HValueAt(::p_Schema[l_cSchemaAndTableName][HB_ORM_SCHEMA_FIELD],l_nHashPos)

        l_nPos := at(".",l_cSchemaAndTableName)
        if empty(l_nPos)
            l_cSchemaName := ""
            l_cTableName  := l_cSchemaAndTableName
        else
            l_cSchemaName := left(l_cSchemaAndTableName,l_nPos-1)
            l_cTableName  := substr(l_cSchemaAndTableName,l_nPos+1)
        endif

// #define HB_ORM_SCHEMA_FIELD_BACKEND_TYPES  1
// #define HB_ORM_SCHEMA_FIELD_TYPE           2
// #define HB_ORM_SCHEMA_FIELD_LENGTH         3
// #define HB_ORM_SCHEMA_FIELD_DECIMALS       4
// #define HB_ORM_SCHEMA_FIELD_ATTRIBUTES     5
// #define HB_ORM_SCHEMA_FIELD_DEFAULT        6

        l_aResult := {l_cSchemaName,;
                      l_cTableName,;
                      l_cFieldName,;
                      l_aFieldInfo[HB_ORM_SCHEMA_FIELD_TYPE],;
                      l_aFieldInfo[HB_ORM_SCHEMA_FIELD_LENGTH],;
                      l_aFieldInfo[HB_ORM_SCHEMA_FIELD_DECIMALS],;
                      ("N" $ l_aFieldInfo[HB_ORM_SCHEMA_FIELD_ATTRIBUTES]),;
                      ("+" $ l_aFieldInfo[HB_ORM_SCHEMA_FIELD_ATTRIBUTES]),;
                      ("A" $ l_aFieldInfo[HB_ORM_SCHEMA_FIELD_ATTRIBUTES]),;
                      iif(len(l_aFieldInfo) < HB_ORM_SCHEMA_FIELD_DEFAULT, NIL, l_aFieldInfo[HB_ORM_SCHEMA_FIELD_DEFAULT])}
    endif
endif

return l_aResult
//-----------------------------------------------------------------------------------------------------------------
// Following used to handle index expressions
method FixCasingInFieldExpression(par_hFields,par_cExpression) class hb_orm_SQLConnect
local l_cResult := ""
local l_cFieldName
local l_Byte
local l_lByteIsToken
local l_FieldDetection := 0
local l_cStreamBuffer        := ""
local l_FieldHashPos
local l_TokenCouldBeCasting := .f. //Used to handle situations like "::text"

// See https://www.postgresql.org/docs/13/indexes-expressional.html

// Meaning of "Token", same as "Identifier"
hb_HCaseMatch(par_hFields,.f.)

// Discover Tokens. Tokens may not have a following "(" or preceding "::"

for each l_Byte in @par_cExpression
    l_lByteIsToken := (l_Byte $ "0123456789_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    do case
    case l_FieldDetection == 0  // Not in <FieldName> pattern
        if l_lByteIsToken
            l_FieldDetection := 1
            l_cStreamBuffer   := l_Byte
            l_cFieldName      := l_Byte
        else
            l_cResult += l_Byte
            l_TokenCouldBeCasting := (l_Byte == ":")
        endif
    case l_FieldDetection == 1 // in <Field> possibly
        do case
        case l_lByteIsToken
            l_cStreamBuffer += l_Byte
            l_cFieldName    += l_Byte
        case l_byte == "(" // Meaning token is used as a function.
            l_FieldDetection := 0
            l_cResult              += l_cStreamBuffer+l_Byte
            l_cStreamBuffer        := ""
            l_TokenCouldBeCasting := .f.
        otherwise
            // It was a <Field> possibly
            l_FieldDetection := 0
            if l_TokenCouldBeCasting
                l_cResult              += l_cFieldName + l_Byte
                l_cFieldName           := ""
                l_cStreamBuffer        := ""
                l_TokenCouldBeCasting := .f.
            else
                l_FieldHashPos := hb_hPos(par_hFields,l_cFieldName)
                if l_FieldHashPos > 0  //Token is one of the fields
                    l_cFieldName    := hb_hKeyAt(par_hFields,l_FieldHashPos) //Fix Token Casing   Many better method
                    l_cResult       += ::FormatIdentifier(l_cFieldName)+l_Byte
                    l_cFieldName    := ""
                    l_cStreamBuffer := ""
                else
                    l_cResult       += l_cFieldName + l_Byte   //Token is not a know field name for table par_cTableName
                    l_cFieldName    := ""
                    l_cStreamBuffer := ""
                endif
            endif
        endcase
    endcase
endfor
if !empty(l_cFieldName)  //We were detecting a fieldname possibly
    if l_TokenCouldBeCasting
        l_cResult += l_cFieldName
    else
        l_FieldHashPos := hb_hPos(par_hFields,l_cFieldName)
        if l_FieldHashPos > 0  //Token is one of the fields
            l_cFieldName := hb_hKeyAt(par_hFields,l_FieldHashPos) //Fix Token Casing   Many better method
            l_cResult    += ::FormatIdentifier(l_cFieldName)
        else
            l_cResult += l_cFieldName
        endif
    endif
endif

return l_cResult
//-----------------------------------------------------------------------------------------------------------------
method DeleteTable(par_cSchemaAndTableName) class hb_orm_SQLConnect
local l_lResult := .t.
local l_cSQLCommand
local l_cLastError
local l_cSchemaAndTableNameFixedCase

l_cSchemaAndTableNameFixedCase := ::CaseTableName(par_cSchemaAndTableName)
if empty(l_cSchemaAndTableNameFixedCase)
    hb_orm_SendToDebugView([Unable to delete field(s) in unknown table: "]+par_cSchemaAndTableName+["])
else
    l_cSQLCommand := [DROP TABLE IF EXISTS ]+::FormatIdentifier(l_cSchemaAndTableNameFixedCase)+[;]
    if ::SQLExec(l_cSQLCommand)
        hb_HDel(::p_Schema,l_cSchemaAndTableNameFixedCase)
    else
        l_lResult := .f.
        l_cLastError := ::GetSQLExecErrorMessage()
        hb_orm_SendToDebugView([Failed Delete Table "]+par_cSchemaAndTableName+[".   Error Text=]+l_cLastError)
    endif
endif
return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method DeleteIndex(par_cSchemaAndTableName,par_cIndexName) class hb_orm_SQLConnect
local l_lResult := .t.
local l_cSchemaAndTableNameFixedCase
local l_cLastError
local l_cSQLCommand := ""
local l_nHashPos

l_cSchemaAndTableNameFixedCase := ::CaseTableName(par_cSchemaAndTableName)
if empty(l_cSchemaAndTableNameFixedCase)
    hb_orm_SendToDebugView([Unable to delete index(s) in unknown table: "]+par_cSchemaAndTableName+["])

else
    //Test if the index is present. Only hb_orm indexes can be removed.
    l_nHashPos := hb_hPos(::p_Schema[par_cSchemaAndTableName][HB_ORM_SCHEMA_INDEX],lower(par_cIndexName))
    if l_nHashPos > 0
        
        do case
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
            l_cSQLCommand  := [DROP INDEX `]+strtran(lower(par_cSchemaAndTableName),".","_")+"_"+lower(par_cIndexName)+"_idx"+[` ON ]+::FormatIdentifier(l_cSchemaAndTableNameFixedCase)+[;]

        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
            l_cSQLCommand  := [DROP INDEX IF EXISTS ]+strtran(lower(par_cSchemaAndTableName),".","_")+"_"+lower(par_cIndexName)+"_idx"+[ CASCADE;]

        endcase

        if !empty(l_cSQLCommand)
            if ::SQLExec(l_cSQLCommand)
                hb_HDel(::p_Schema[par_cSchemaAndTableName][HB_ORM_SCHEMA_INDEX],lower(par_cIndexName))
            else
                l_lResult := .f.
                l_cLastError := ::GetSQLExecErrorMessage()
                hb_orm_SendToDebugView([Failed Delete index "]+par_cIndexName+[" for table "]+par_cSchemaAndTableName+[".   Error Text=]+l_cLastError)
            endif
        endif

    endif

endif

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method DeleteField(par_cSchemaAndTableName,par_xFieldNames) class hb_orm_SQLConnect
local l_lResult := .t.
local l_cSchemaAndTableNameFixedCase
local l_cLastError
local l_aFieldNames,l_cFieldName,l_cFieldNameFixedCase
local l_cSQLCommand
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

        l_cSQLCommand := []
        for each l_cFieldName in l_aFieldNames
            l_cFieldNameFixedCase := ::CaseFieldName(l_cSchemaAndTableNameFixedCase,l_cFieldName)
            if empty(l_cFieldNameFixedCase)
                hb_orm_SendToDebugView([Unable to delete unknown field: "]+par_cSchemaAndTableName+[.]+l_cFieldName+["])
            else
                if !empty(l_cSQLCommand)
                    l_cSQLCommand += [,]
                endif
                l_cSQLCommand += [ DROP COLUMN]+l_SQLIfExist+::FormatIdentifier(l_cFieldNameFixedCase)+[ CASCADE]
            endif
        endfor

        if !empty(l_cSQLCommand)
            l_cSQLCommand := l_SQLAlterTable + l_cSQLCommand + [;]
            if ::SQLExec(l_cSQLCommand)
                for each l_cFieldName in l_aFieldNames
                    l_cFieldNameFixedCase := ::CaseFieldName(l_cSchemaAndTableNameFixedCase,l_cFieldName)
                    if !empty(l_cFieldNameFixedCase)
                        hb_HDel(::p_Schema[l_cSchemaAndTableNameFixedCase][HB_ORM_SCHEMA_FIELD],l_cFieldNameFixedCase)
                    endif
                endfor
            else
                l_lResult := .f.
                l_cLastError := ::GetSQLExecErrorMessage()
                hb_orm_SendToDebugView([Failed Delete Field(s) in "]+par_cSchemaAndTableName+[".   Error Text=]+l_cLastError)
            endif
        endif

    endif

endif

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method TableExists(par_cSchemaAndTableName) class hb_orm_SQLConnect  // Is schema and table name case insensitive
local l_lResult
local l_cSQLCommand
local l_nPos,l_cSchemaName,l_cTableName

l_nPos := at(".",par_cSchemaAndTableName)
if l_nPos == 0
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_cSchemaName := ""
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        l_cSchemaName := ::GetCurrentSchemaName()   // To search in the current Schema
    endcase
    l_cTableName  := par_cSchemaAndTableName
else
    l_cSchemaName := left(par_cSchemaAndTableName,l_nPos-1)
    l_cTableName  := substr(par_cSchemaAndTableName,l_nPos+1)
endif

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cSQLCommand  := [SELECT count(*) as count FROM information_schema.tables WHERE lower(table_schema) = ']+lower(::GetDatabase())+[' AND lower(table_name) = ']+lower(l_cTableName)+[';]
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cSQLCommand  := [SELECT count(*) AS count FROM information_schema.tables WHERE lower(table_schema) = ']+lower(l_cSchemaName)  +[' AND lower(table_name) = ']+lower(l_cTableName)+[';]
endcase

if ::SQLExec(l_cSQLCommand,"TableExistsResult")
    l_lResult := (TableExistsResult->count > 0)
else
    l_lResult := .f.
    hb_orm_SendToDebugView([Failed TableExists "]+par_cSchemaAndTableName+[".   Error Text=]+::GetSQLExecErrorMessage())
endif

CloseAlias("TableExistsResult")

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method FieldExists(par_cSchemaAndTableName,par_cFieldName) class hb_orm_SQLConnect
local l_lResult
local l_cSQLCommand
local l_nPos,l_cSchemaName,l_cTableName

l_nPos := at(".",par_cSchemaAndTableName)
if l_nPos == 0
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_cSchemaName := ""
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        l_cSchemaName := ::GetCurrentSchemaName()   // To search in the current Schema
    endcase
    l_cTableName  := par_cSchemaAndTableName
else
    l_cSchemaName := left(par_cSchemaAndTableName,l_nPos-1)
    l_cTableName  := substr(par_cSchemaAndTableName,l_nPos+1)
endif

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cSQLCommand  := [SELECT count(*) as count FROM information_schema.columns WHERE lower(table_schema) = ']+lower(::GetDatabase())+[' AND lower(table_name) = ']+lower(l_cTableName)+[' AND lower(column_name) = ']+lower(par_cFieldName)+[';]
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cSQLCommand  := [SELECT count(*) AS count FROM information_schema.columns WHERE lower(table_schema) = ']+lower(l_cSchemaName)  +[' AND lower(table_name) = ']+lower(l_cTableName)+[' AND lower(column_name) = ']+lower(par_cFieldName)+[';]
endcase

if ::SQLExec(l_cSQLCommand,"FieldExistsResult")
    l_lResult := (FieldExistsResult->count > 0)
else
    l_lResult := .f.
    hb_orm_SendToDebugView([Failed TableExists "]+par_cSchemaAndTableName+[".   Error Text=]+::GetSQLExecErrorMessage())
endif

CloseAlias("FieldExistsResult")

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method UpdateORMSupportSchema() class hb_orm_SQLConnect
local l_lResult := .f.   // return .t. if overall schema changed
local l_cSQLScript,l_ErrorInfo   // can be removed later, only used during code testing
local l_PreviousSchemaName
local l_Schema := ;
    {"SchemaVersion"=>{;   //Field Definition
      {"pk"     =>{, "I",  0,  0,"+"};
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

if el_AUnpack(::MigrateSchema(l_Schema),,@l_cSQLScript,@l_ErrorInfo) <> 0
    // altd()
    l_lResult = .t.  // Will assume the schema change worked.
endif

::SetCurrentSchemaName(l_PreviousSchemaName)

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method UpdateORMSchemaTableNumber() class hb_orm_SQLConnect
local l_cSQLCommand

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    TEXT TO VAR l_cSQLCommand
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

    l_cSQLCommand := strtran(l_cSQLCommand,"-DataBase-",::GetDatabase())

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    TEXT TO VAR l_cSQLCommand
WITH
 ListOfTables AS (
    SELECT DISTINCT
           columns.table_schema::text as schemaname,
           columns.table_name::text   as tablename
    FROM information_schema.columns
    INNER JOIN information_schema.tables ON columns.table_schema = tables.table_schema AND columns.table_name = tables.table_name
    WHERE NOT (lower(left(columns.table_name,11)) = 'schemacache' OR lower(columns.table_schema) in ('information_schema','pg_catalog'))
 AND   tables.table_type = 'BASE TABLE'
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

    if ::PostgreSQLIdentifierCasing != 1  //HB_ORM_POSTGRESQL_CASE_SENSITIVE
        l_cSQLCommand := Strtran(l_cSQLCommand,["SchemaTableNumber"],[schematablenumber])
    endif

    if !(::PostgreSQLHBORMSchemaName == "hborm")
        l_cSQLCommand := strtran(l_cSQLCommand,"hborm",::FormatIdentifier(::PostgreSQLHBORMSchemaName))
    endif

endcase

::SQLExec(l_cSQLCommand)

return NIL
//-----------------------------------------------------------------------------------------------------------------
method GetSchemaDefinitionVersion(par_cSchemaDefinitionName) class hb_orm_SQLConnect                         // Since calling ::MigrateSchema() is cumulative with different hSchemaDefinition, each can be named and have a different version.
local l_Version := -1  //To report if failed to retrieve the version number.
local l_cSQLCommand
local l_cFormattedTableName

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    if ::TableExists("SchemaVersion")
        l_cFormattedTableName := ::FormatIdentifier("SchemaVersion")

        l_cSQLCommand := [SELECT pk,version]
        l_cSQLCommand += [ FROM ]+l_cFormattedTableName
        l_cSQLCommand += [ WHERE lower(name) = ']+strtran(lower(par_cSchemaDefinitionName),"'","")+[';]
        if ::SQLExec(l_cSQLCommand,"SchemaVersion")
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
        l_cFormattedTableName := ::FormatIdentifier(::PostgreSQLHBORMSchemaName+[.]+"SchemaVersion")

        l_cSQLCommand := [SELECT pk,version]
        l_cSQLCommand += [ FROM ]+l_cFormattedTableName
        l_cSQLCommand += [ WHERE lower(name) = ']+strtran(lower(par_cSchemaDefinitionName),"'","")+[';]

        if ::SQLExec(l_cSQLCommand,"SchemaVersion")
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
local l_lResult := .f.
local l_cSQLCommand := ""
local l_cFormattedTableName

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cFormattedTableName := ::FormatIdentifier("SchemaVersion")

    l_cSQLCommand := [SELECT pk,version]
    l_cSQLCommand += [ FROM ]+l_cFormattedTableName
    l_cSQLCommand += [ WHERE lower(name) = ']+strtran(lower(par_cSchemaDefinitionName),"'","")+[';]

    if ::SQLExec(l_cSQLCommand,"SchemaVersion")
        if empty(SchemaVersion->(reccount()))
            //Add an entry
            l_cSQLCommand := [INSERT INTO ]+l_cFormattedTableName+[ (]
            l_cSQLCommand += [name,version]
            l_cSQLCommand += [) VALUES (]
            l_cSQLCommand += [']+strtran(par_cSchemaDefinitionName,"'","")+[',]+trans(par_iVersion)
            l_cSQLCommand += [);]
        else
            if SchemaVersion->pk == 0  // To fix an initial bug in the hb_orm
                ::LoadSchema()
                ::DeleteField(l_cFormattedTableName,"pk")  // the pk field will be readded correctly.
                ::UpdateORMSupportSchema()
                ::LoadSchema()  // Only called again since the ORM schema changed
                ::SQLExec(l_cSQLCommand,"SchemaVersion")
            endif

            //Update Version
            l_cSQLCommand := [UPDATE ]+l_cFormattedTableName+[ SET ]
            l_cSQLCommand += [version=]+trans(par_iVersion)
            l_cSQLCommand += [ WHERE pk=]+trans(SchemaVersion->pk)+[;]
        endif
        if ::SQLExec(l_cSQLCommand)
            l_lResult := .t.
        else
            ::p_ErrorMessage := [Failed SQL on SchemaVersion (3).]
            hb_orm_SendToDebugView([Failed SQL on SchemaVersion (3).   Error Text=]+::GetSQLExecErrorMessage())
        endif
    else
        ::p_ErrorMessage := [Failed SQL on SchemaVersion (4).]
        hb_orm_SendToDebugView([Failed SQL on SchemaVersion (4).   Error Text=]+::GetSQLExecErrorMessage())
    endif

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cFormattedTableName := ::FormatIdentifier(::PostgreSQLHBORMSchemaName+[.]+"SchemaVersion")

    l_cSQLCommand := [SELECT pk,version]
    l_cSQLCommand += [ FROM ]+l_cFormattedTableName
    l_cSQLCommand += [ WHERE lower(name) = ']+strtran(lower(par_cSchemaDefinitionName),"'","")+[';]

    if ::SQLExec(l_cSQLCommand,"SchemaVersion")
        if empty(SchemaVersion->(reccount()))
            //Add an entry
            l_cSQLCommand := [INSERT INTO ]+l_cFormattedTableName+[ (]
            l_cSQLCommand += [name,version]
            l_cSQLCommand += [) VALUES (]
            l_cSQLCommand += [']+strtran(par_cSchemaDefinitionName,"'","")+[',]+trans(par_iVersion)
            l_cSQLCommand += [);]
        else
            if SchemaVersion->pk == 0  // To fix an initial bug in the hb_orm
                ::LoadSchema()
                ::DeleteField(l_cFormattedTableName,"pk")  // the pk field will be readded correctly.
                ::UpdateORMSupportSchema()
                ::LoadSchema()  // Only called again since the ORM schema changed
                ::SQLExec(l_cSQLCommand,"SchemaVersion")
            endif

            //Update Version
            l_cSQLCommand := [UPDATE ]+l_cFormattedTableName+[ SET ]
            l_cSQLCommand += [version=]+trans(par_iVersion)
            l_cSQLCommand += [ WHERE pk=]+trans(SchemaVersion->pk)+[;]
        endif
        if ::SQLExec(l_cSQLCommand)
            l_lResult := .t.
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

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method FixCasingOfSchemaCacheTables(par_cTableName) class hb_orm_SQLConnect
local l_cTableName
if ::PostgreSQLIdentifierCasing != HB_ORM_POSTGRESQL_CASE_SENSITIVE
    l_cTableName := lower(par_cTableName)
else
    l_cTableName := par_cTableName
endif

return l_cTableName
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
//-----------------------------------------------------------------------------------------------------------------
method SanitizeFieldDefaultFromDefaultBehavior(par_cSQLEngineType,par_cFieldType,par_cFieldAttributes,par_cFieldDefault) class hb_orm_SQLConnect
local l_cFieldDefault := par_cFieldDefault
local l_nPos

do case
case hb_IsNIL(l_cFieldDefault)
    //Nothing todo

case par_cSQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    do case
    case !empty(el_inlist(par_cFieldType,"I","IB","IS","N","Y"))
        if (right(par_cFieldDefault,1) == "0" .and. val(par_cFieldDefault) == 0)
            l_cFieldDefault := NIL
        elseif par_cFieldDefault == "NULL"
            l_cFieldDefault := NIL
        endif

    case !empty(el_inlist(par_cFieldType,"C","CV"))
        if par_cFieldDefault == "''"
            l_cFieldDefault := NIL
        elseif par_cFieldDefault == "NULL"
            l_cFieldDefault := NIL
        endif

    case par_cFieldType == "DTZ"
        if !empty(el_inlist(par_cFieldDefault,"'0000-00-00 00:00:00'","''"))
            l_cFieldDefault := NIL
        elseif par_cFieldDefault == "NULL"
            l_cFieldDefault := NIL
        endif
        
    case par_cFieldType == "D"
        if !empty(el_inlist(par_cFieldDefault,"'0000-00-00'","''"))
            l_cFieldDefault := NIL
        elseif par_cFieldDefault == "NULL"
            l_cFieldDefault := NIL
        endif
        
    case par_cFieldType == "UUI"
        if !empty(el_inlist(par_cFieldDefault,"'00000000-0000-0000-0000-000000000000'","''"))
            l_cFieldDefault := NIL
        elseif par_cFieldDefault == "NULL"
            l_cFieldDefault := NIL
        endif
        
    case par_cFieldType == "JS"
        if !empty(el_inlist(par_cFieldDefault,"'{}'","''"))
            l_cFieldDefault := NIL
        elseif par_cFieldDefault == "NULL"
            l_cFieldDefault := NIL
        endif
        
    case "N" $ par_cFieldAttributes   // Any other datatype and Nullable field
        if par_cFieldDefault == "NULL"
            l_cFieldDefault := NIL
        endif

    endcase

    // if !hb_IsNIL(l_cFieldDefault) .and. left(l_cFieldDefault,1) == "'" .and. right(l_cFieldDefault,1) == "'"
    //     //Get rid of surounding quotes
    //     l_cFieldDefault := substr(l_cFieldDefault,2,len(l_cFieldDefault)-2)
    // endif

case par_cSQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    do case
    case par_cFieldType == "N"
        if par_cFieldDefault == "0"
            l_cFieldDefault := NIL
        elseif !empty(el_inlist(par_cFieldDefault,"''::numeric","'0'::numeric","''","0"))
            l_cFieldDefault := NIL
        elseif right(par_cFieldDefault,len("::numeric")) == "::numeric"
            l_cFieldDefault = left(par_cFieldDefault,len(par_cFieldDefault)-len("::numeric"))
        endif

    case par_cFieldType == "I"
        if par_cFieldDefault == "0"
            l_cFieldDefault := NIL
        elseif !empty(el_inlist(par_cFieldDefault,"''::integer","'0'::integer","''","0"))
            l_cFieldDefault := NIL
        elseif right(par_cFieldDefault,len("::integer")) == "::integer"
            l_cFieldDefault = left(par_cFieldDefault,len(par_cFieldDefault)-len("::integer"))
        endif

    case par_cFieldType == "IB"
        if par_cFieldDefault == "0"
            l_cFieldDefault := NIL
        elseif !empty(el_inlist(par_cFieldDefault,"''::bigint","'0'::bigint","''","0"))
            l_cFieldDefault := NIL
        elseif right(par_cFieldDefault,len("::bigint")) == "::bigint"
            l_cFieldDefault = left(par_cFieldDefault,len(par_cFieldDefault)-len("::bigint"))
        endif

    case par_cFieldType == "IS"
        if par_cFieldDefault == "0"
            l_cFieldDefault := NIL
        elseif !empty(el_inlist(par_cFieldDefault,"''::smallint","'0'::smallint","''","0"))
            l_cFieldDefault := NIL
        elseif right(par_cFieldDefault,len("::smallint")) == "::smallint"
            l_cFieldDefault = left(par_cFieldDefault,len(par_cFieldDefault)-len("::smallint"))
        endif

    case par_cFieldType == "Y"
        if par_cFieldDefault == "0"
            l_cFieldDefault := NIL
        elseif !empty(el_inlist(par_cFieldDefault,"''::money","'0'::money","''","0"))
            l_cFieldDefault := NIL
        elseif right(par_cFieldDefault,len("::money")) == "::money"
            l_cFieldDefault = left(par_cFieldDefault,len(par_cFieldDefault)-len("::money"))
        endif

    case par_cFieldType == "L"
        if par_cFieldDefault == "false"
            l_cFieldDefault := NIL
        endif

    case par_cFieldType == "C"
        if !empty(el_inlist(par_cFieldDefault,"''::bpchar","''"))
            l_cFieldDefault := NIL
        elseif right(par_cFieldDefault,len("::bpchar")) == "::bpchar"
            l_cFieldDefault = left(par_cFieldDefault,len(par_cFieldDefault)-len("::bpchar"))
        endif
        
    case par_cFieldType == "M"
        if !empty(el_inlist(par_cFieldDefault,"''::text","''"))
            l_cFieldDefault := NIL
        elseif right(par_cFieldDefault,len("::text")) == "::text"
            l_cFieldDefault = left(par_cFieldDefault,len(par_cFieldDefault)-len("::text"))
        endif
        
    case par_cFieldType == "CV"
        if !empty(el_inlist(par_cFieldDefault,"''::character varying","''"))
            l_cFieldDefault := NIL
        elseif right(par_cFieldDefault,len("::character varying")) == "::character varying"
            l_cFieldDefault = left(par_cFieldDefault,len(par_cFieldDefault)-len("::character varying"))
        endif
        
    case par_cFieldType == "DTZ"
        if !empty(el_inlist(par_cFieldDefault,"'-infinity'::timestamp with time zone","'-infinity'","''"))
            l_cFieldDefault := NIL
        endif
        
    case par_cFieldType == "DT"
        if !empty(el_inlist(par_cFieldDefault,"'-infinity'::timestamp without time zone","'-infinity'","''"))
            l_cFieldDefault := NIL
        endif
        
    case par_cFieldType == "D"
        if !empty(el_inlist(par_cFieldDefault,"'-infinity'::date","'-infinity'","''"))
            l_cFieldDefault := NIL
        endif

    case par_cFieldType == "L"
        if par_cFieldDefault == "false"
            l_cFieldDefault := NIL
        endif
        
    case par_cFieldType == "UUI"
        if !empty(el_inlist(par_cFieldDefault,"'00000000-0000-0000-0000-000000000000'::uuid","'00000000-0000-0000-0000-000000000000'","''"))
            l_cFieldDefault := NIL
        endif
        
    case par_cFieldType == "JS"
        if !empty(el_inlist(par_cFieldDefault,"'{}'::json","'{}'","''"))
            l_cFieldDefault := NIL
        endif
        
    case "N" $ par_cFieldAttributes   // Any other datatype and Nullable field

    endcase

    if !hb_IsNIL(l_cFieldDefault)
        //Get rid of casting
        l_nPos := rat("::",l_cFieldDefault)
        if l_nPos > 0
            l_cFieldDefault := left(l_cFieldDefault,l_nPos-1)
        endif
        // if l_cFieldDefault == "''"
        //     l_cFieldDefault := NIL
        // endif

        // if left(l_cFieldDefault,1) == "'" .and. right(l_cFieldDefault,1) == "'"
        //     //Get rid of surounding quotes
        //     l_cFieldDefault := substr(l_cFieldDefault,2,len(l_cFieldDefault)-2)
        // endif
    endif

endcase
return l_cFieldDefault
//-----------------------------------------------------------------------------------------------------------------
method NormalizeFieldDefaultForCurrentEngineType(par_cFieldDefault,par_cFieldType,par_nFieldDec) class hb_orm_SQLConnect
local l_cFieldDefault := par_cFieldDefault

//Auto Adjust Field Default definition for Engine Type
do case
case hb_IsNIL(l_cFieldDefault)

case par_cFieldType == "L"
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        do case
        case !empty(el_inlist(upper(l_cFieldDefault),"FALSE",".F.","F"))
            l_cFieldDefault = "0"
        case !empty(el_inlist(upper(l_cFieldDefault),"TRUE",".T.","T"))
            l_cFieldDefault = "1"
        endcase
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        do case
        case !empty(el_inlist(upper(l_cFieldDefault),"0","FALSE",".F.","F"))
            l_cFieldDefault = "false"
        case !empty(el_inlist(upper(l_cFieldDefault),"1","TRUE",".T.","T"))
            l_cFieldDefault = "true"
        endcase
    endcase

case par_cFieldType == "UUI"
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        do case
        case !empty(el_inlist(upper(l_cFieldDefault),"UUI","UUID","UUI()","UUID()"))
            l_cFieldDefault = "uuid()"
        endcase
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        do case
        case !empty(el_inlist(upper(l_cFieldDefault),"UUI","UUID","UUI()","UUID()"))
            l_cFieldDefault = "gen_random_uuid()"
        endcase
    endcase

case !empty(el_inlist(upper(l_cFieldDefault),"NOW()","NOW"))
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        if par_nFieldDec == 0
            l_cFieldDefault = "current_timestamp()"
        else
            l_cFieldDefault = "current_timestamp("+Trans(par_nFieldDec)+")"
        endif

    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        l_cFieldDefault := "now()"

    endcase

endcase

return l_cFieldDefault
//-----------------------------------------------------------------------------------------------------------------
