//Copyright (c) 2024 Eric Lendvai, MIT License

#include "hb_orm.ch"
#include "hb_el.ch"

#ifndef DONOTINCLUDE   //Will be defined by BuilLib.bat
#include "hb_orm_sqlconnect_class_definition.prg"
#endif

// RND Notes
// autoincrement fields are not null with no default.

//-----------------------------------------------------------------------------------------------------------------
method LoadMetadata(par_cSource) class hb_orm_SQLConnect
//par_cSource is optional, will help to debug ORM

local l_nSelect := iif(used(),select(),0)
local l_cSQLCommand
local l_cSQLCommandFields  := ""
local l_cSQLCommandIndexes := ""
local l_cFieldType,l_cFieldTypeEnumName,l_nFieldLen,l_nFieldDec,l_lFieldNullable,l_lFieldAutoIncrement,l_lFieldArray,l_cFieldComment,l_cFieldDefault
local l_cTableName
local l_cNamespaceAndTableName,l_cNamespaceAndTableNameLast
local l_cNamespaceAndEnumerationName
local l_cIndexName,l_cIndexDefinition,l_cIndexExpression,l_lIndexUnique,l_cIndexType
local l_hTableSchemaField   := {=>}
local l_hTableSchemaFields  := {=>}
local l_hTableSchemaIndexes := {=>}
local l_hEnumerationValues
local l_nPos1,l_nPos2,l_nPos3,l_nPos4
local l_lLoadedCache
local l_cFieldCommentType
local l_nFieldCommentLength
local l_lUnlogged
local l_lUnloggedLast
local l_cSource := nvl(par_cSource,"Not Specified")
local l_lNoCache := (::p_HBORMNamespace == "nohborm")

hb_orm_SendToDebugView("LoadSchema Start - Source: "+l_cSource)

hb_HCaseMatch(l_hTableSchemaField ,.f.)
hb_HCaseMatch(l_hTableSchemaFields ,.f.)
hb_HCaseMatch(l_hTableSchemaIndexes,.f.)
hb_HClear(::p_hMetadataTable)
hb_HCaseMatch(::p_hMetadataTable,.f.)
hb_HClear(::p_hMetadataNamespace)
hb_HCaseMatch(::p_hMetadataNamespace,.f.)
hb_HClear(::p_hMetadataEnumeration)
hb_HCaseMatch(::p_hMetadataEnumeration,.f.)

CloseAlias("hb_orm_sqlconnect_schema_fields")
CloseAlias("hb_orm_sqlconnect_schema_indexes")

::p_iMetadataTableCacheLogLastPk := 0

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    // In MySQL engine, internally, if a table does not have a Namespace (a name before a "." character.), will be using "public" as namespace.
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

    if !::SQLExec("LoadMetadata",l_cSQLCommandFields,"hb_orm_sqlconnect_schema_fields")
        ::p_ErrorMessage := [Failed SQL for hb_orm_sqlconnect_schema_fields.]
        // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_cSQLCommandFields+[ -> ]+::p_ErrorMessage)
    elseif !::SQLExec("LoadMetadata",l_cSQLCommandIndexes,"hb_orm_sqlconnect_schema_indexes")
        ::p_ErrorMessage := [Failed SQL for hb_orm_sqlconnect_schema_indexes.]
    else
        if used("hb_orm_sqlconnect_schema_fields") .and. used("hb_orm_sqlconnect_schema_indexes")
            select hb_orm_sqlconnect_schema_fields
            if Reccount() > 0
                l_cNamespaceAndTableNameLast := Trim(hb_orm_sqlconnect_schema_fields->table_name)
                l_nPos1 := at(".",l_cNamespaceAndTableNameLast)
                if empty(l_nPos1)
                    l_cNamespaceAndTableNameLast := "public."+l_cNamespaceAndTableNameLast
                endif

                hb_HClear(l_hTableSchemaFields)
                scan all
                    l_cNamespaceAndTableName := Trim(hb_orm_sqlconnect_schema_fields->table_name)
                    l_nPos1 := at(".",l_cNamespaceAndTableName)
                    if empty(l_nPos1)
                        l_cNamespaceAndTableName := "public."+l_cNamespaceAndTableName
                    endif

                    if !(l_cNamespaceAndTableName == l_cNamespaceAndTableNameLast)  // Method to for an exact not equal
                        ::p_hMetadataTable[l_cNamespaceAndTableNameLast] := {HB_ORM_SCHEMA_FIELD=>hb_hClone(l_hTableSchemaFields),HB_ORM_SCHEMA_INDEX=>NIL}
                        hb_HClear(l_hTableSchemaFields)
                        l_cNamespaceAndTableNameLast := l_cNamespaceAndTableName
                    endif

                    //Parse the comment field to see if recorded the field type and its length
                    l_cFieldCommentType   := ""
                    l_cFieldComment := nvl(field->field_comment,"")
                    l_cFieldComment := upper(MemoLine(l_cFieldComment,1000,1))  // Extract first line of comment, max 1000 char length
                    if !empty(l_cFieldComment) 
                        l_nPos1 := at("|",l_cFieldComment)
                        l_nPos2 := at("TYPE=",l_cFieldComment)
                        if l_nPos1 > 0 .and. l_nPos2 > 0
                            l_cFieldCommentType := Alltrim(substr(l_cFieldComment,l_nPos2+len("TYPE="),l_nPos1-(l_nPos2+len("TYPE="))))
                        elseif l_nPos2 > 0
                            l_cFieldCommentType := Alltrim(substr(l_cFieldComment,l_nPos2+len("TYPE=")))
                        endif
                    endif

                    switch trim(field->field_type)
                    case "int"
                        l_cFieldType          := "I"
                        l_nFieldLen           := 0
                        l_nFieldDec           := 0
                        exit
                    case "bigint"
                        if l_cFieldCommentType == "OID"
                            l_cFieldType      := "OID"
                            l_nFieldLen       := 0
                            l_nFieldDec       := 0
                        else
                            l_cFieldType      := "IB"
                            l_nFieldLen       := 0
                            l_nFieldDec       := 0
                        endif
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
                        do case
                        case l_cFieldCommentType == "JSB"
                            l_cFieldType      := "JSB"
                            l_nFieldLen       := 0
                            l_nFieldDec       := 0
                        case l_cFieldCommentType == "JS"
                            l_cFieldType      := "JS"
                            l_nFieldLen       := 0
                            l_nFieldDec       := 0
                        otherwise
                            l_cFieldType          := "M"
                            l_nFieldLen           := 0
                            l_nFieldDec           := 0
                        endcase
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

                    l_lFieldNullable      := (field->field_nullable == 1)
                    l_lFieldAutoIncrement := (field->field_auto_increment == 1)
                    l_lFieldArray         := .f.

                    l_cFieldDefault := ::SanitizeFieldDefaultFromDefaultBehavior(::p_SQLEngineType,l_cFieldType,l_lFieldNullable,field->field_default)

                    l_hTableSchemaFields[trim(field->field_Name)] := {HB_ORM_SCHEMA_FIELD_TYPE => l_cFieldType}
                    l_hTableSchemaField := l_hTableSchemaFields[trim(field->field_Name)]
                    if !hb_IsNil(l_nFieldLen) .and. l_nFieldLen > 0
                        l_hTableSchemaField[HB_ORM_SCHEMA_FIELD_LENGTH] := l_nFieldLen
                    endif
                    if !hb_IsNil(l_nFieldDec) .and. l_nFieldDec > 0
                        l_hTableSchemaField[HB_ORM_SCHEMA_FIELD_DECIMALS] := l_nFieldDec
                    endif
                    if !hb_IsNil(l_lFieldNullable) .and. l_lFieldNullable
                        l_hTableSchemaField[HB_ORM_SCHEMA_FIELD_NULLABLE] := .t.
                    endif
                    if !hb_IsNil(l_lFieldAutoIncrement) .and. l_lFieldAutoIncrement
                        l_hTableSchemaField[HB_ORM_SCHEMA_FIELD_AUTOINCREMENT] := .t.
                    endif
                    if !hb_IsNil(l_lFieldArray) .and. l_lFieldArray
                        l_hTableSchemaField[HB_ORM_SCHEMA_FIELD_ARRAY] := .t.
                    endif
                    if !hb_IsNil(l_cFieldDefault) .and. !empty(l_cFieldDefault)
                        l_hTableSchemaField[HB_ORM_SCHEMA_FIELD_DEFAULT] := l_cFieldDefault
                    endif

                endscan

                ::p_hMetadataTable[l_cNamespaceAndTableNameLast] := {HB_ORM_SCHEMA_FIELD=>hb_hClone(l_hTableSchemaFields),HB_ORM_SCHEMA_INDEX=>NIL}
                hb_HClear(l_hTableSchemaFields)

                //Since Indexes could only exists for an existing table we simply assign to a ::p_hMetadataTable[][HB_ORM_SCHEMA_INDEX] cell
                select hb_orm_sqlconnect_schema_indexes
                if Reccount() > 0
                    l_cNamespaceAndTableNameLast := Trim(hb_orm_sqlconnect_schema_indexes->table_name)
                    l_nPos1 := at(".",l_cNamespaceAndTableNameLast)
                    if empty(l_nPos1)
                        l_cNamespaceAndTableNameLast := "public."+l_cNamespaceAndTableNameLast
                    endif

                    hb_HClear(l_hTableSchemaIndexes)

                    scan all
                        l_cNamespaceAndTableName := Trim(hb_orm_sqlconnect_schema_indexes->table_name)
                        l_nPos1 := at(".",l_cNamespaceAndTableName)
                        if empty(l_nPos1)
                            l_cNamespaceAndTableName := "public."+l_cNamespaceAndTableName
                        endif

                        //Test that the index is for a real table, not a view or other type of objects. Since we used "tables.table_type = 'BASE TABLE'" earlier we need to check if we loaded that table in the p_hMetadataTable
                        if hb_HHasKey(::p_hMetadataTable,l_cNamespaceAndTableName)

                            if !(l_cNamespaceAndTableName == l_cNamespaceAndTableNameLast)
                                if len(l_hTableSchemaIndexes) > 0
                                    ::p_hMetadataTable[l_cNamespaceAndTableNameLast][HB_ORM_SCHEMA_INDEX] := hb_hClone(l_hTableSchemaIndexes)
                                    hb_HClear(l_hTableSchemaIndexes)
                                else
                                    ::p_hMetadataTable[l_cNamespaceAndTableNameLast][HB_ORM_SCHEMA_INDEX] := NIL
                                endif
                                l_cNamespaceAndTableNameLast := l_cNamespaceAndTableName
                            endif

                            l_cIndexName := lower(trim(field->index_name))
                            // if left(l_cIndexName,len(l_cNamespaceAndTableName)+1) == lower(l_cNamespaceAndTableName)+"_" .and. right(l_cIndexName,4) == "_idx"  // only record indexes maintained by hb_orm
                            if right(l_cIndexName,4) == "_idx"  // only record indexes maintained by hb_orm
                                l_cIndexName      := hb_orm_RootIndexName(l_cNamespaceAndTableName,l_cIndexName)

                                l_cIndexExpression := trim(field->index_columns)
                                if !(lower(l_cIndexExpression) == lower(::p_PrimaryKeyFieldName))   // No reason to record the index of the PRIMARY key
                                    l_lIndexUnique := (field->is_unique == 1)
                                    l_cIndexType   := field->index_type
                                    l_hTableSchemaIndexes[l_cIndexName] := {HB_ORM_SCHEMA_INDEX_EXPRESSION => l_cIndexExpression,;
                                                                            HB_ORM_SCHEMA_INDEX_UNIQUE     => l_lIndexUnique,;
                                                                            HB_ORM_SCHEMA_INDEX_ALGORITHM  => l_cIndexType}
                                endif
                            endif
                        endif
                    endscan

                    if len(l_hTableSchemaIndexes) > 0
                        ::p_hMetadataTable[l_cNamespaceAndTableNameLast][HB_ORM_SCHEMA_INDEX] := hb_hClone(l_hTableSchemaIndexes)
                        hb_HClear(l_hTableSchemaIndexes)
                    else
                        ::p_hMetadataTable[l_cNamespaceAndTableNameLast][HB_ORM_SCHEMA_INDEX] := NIL
                    endif

                endif

            endif

        endif

    endif

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL

    // -- Load the Metadata Namespace in p_hMetadataNamespace
    TEXT TO VAR l_cSQLCommand
    select ns.nspname as "NamespaceName"
    from pg_namespace ns
    where ns.nspname not in ('cyanaudit','pg_catalog','information_schema','pg_toast')
    ENDTEXT

    if ::SQLExec("LoadMetadata",l_cSQLCommand,"SchemaListOfNamespace")
        select SchemaListOfNamespace
        scan all
            ::p_hMetadataNamespace[SchemaListOfNamespace->NamespaceName] := SchemaListOfNamespace->NamespaceName
        endscan
        CloseAlias("SchemaListOfNamespace")
    endif

    // -- Load the Metadata Enumeration in p_hMetadataEnumeration
    TEXT TO VAR l_cSQLCommand
    SELECT
      ns.nspname          as "namespace_name",
      pt.typname          as "enumeration_name",
      pe.enumlabel        as "EnumValueName",
      pe.enumsortorder    as "EnumValueOrder"
     FROM pg_type      as pt
     join pg_namespace as ns on pt.typnamespace = ns.oid
     join pg_enum      as pe on pe.enumtypid = pt.oid
     WHERE pt.typcategory = 'E'
     and   ns.nspname not in ('cyanaudit','pg_catalog','information_schema','pg_toast')
     order by "namespace_name","enumeration_name"
    ENDTEXT
    if ::SQLExec("LoadMetadata",l_cSQLCommand,"SchemaListOfEnumerations")
        l_hEnumerationValues := {=>}
        select SchemaListOfEnumerations
        scan all
            if empty(l_cNamespaceAndEnumerationName)
                l_cNamespaceAndEnumerationName := Trim(SchemaListOfEnumerations->namespace_name)+"."+Trim(SchemaListOfEnumerations->enumeration_name)
            endif
            if !(l_cNamespaceAndEnumerationName == Trim(SchemaListOfEnumerations->namespace_name)+"."+Trim(SchemaListOfEnumerations->enumeration_name))
                ::p_hMetadataEnumeration[l_cNamespaceAndEnumerationName] := {"ImplementAs"=>"NativeSQLEnum","Values"=>l_hEnumerationValues}
                l_hEnumerationValues := {=>}  // Should not use hb_HClear since we Hashes are used by reference.
                l_cNamespaceAndEnumerationName := Trim(SchemaListOfEnumerations->namespace_name)+"."+Trim(SchemaListOfEnumerations->enumeration_name)
            endif
            l_hEnumerationValues[SchemaListOfEnumerations->EnumValueName] := SchemaListOfEnumerations->EnumValueOrder
        endscan
        if !empty(l_hEnumerationValues)  // In case no SQLEnum enumeration exists
            ::p_hMetadataEnumeration[l_cNamespaceAndEnumerationName] := {"ImplementAs"=>"NativeSQLEnum","Values"=>l_hEnumerationValues}
            l_hEnumerationValues := {=>}
        endif
        CloseAlias("SchemaListOfEnumerations")
    endif

    // -- Load the Metadata Table
    if l_lNoCache
        ::SQLExec("90b44078-1424-4c22-99a1-da3defbddc60","SET enable_nestloop = false")
        ::SQLExec("90b44078-1424-4c22-99a1-da3defbddc61",::GetPostgresTableSchemaQuery(),"hb_orm_sqlconnect_schema_fields")
        ::SQLExec("90b44078-1424-4c22-99a1-da3defbddc62",::GetPostgresIndexSchemaQuery(),"hb_orm_sqlconnect_schema_indexes")
        ::SQLExec("90b44078-1424-4c22-99a1-da3defbddc63","SET enable_nestloop = true")
    else
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

        if !(::p_HBORMNamespace == "hborm")
            l_cSQLCommand := strtran(l_cSQLCommand,"hborm",::FormatIdentifier(::p_HBORMNamespace))
        endif

        if ::SQLExec("LoadMetadata",l_cSQLCommand,"SchemaCacheLogLast")
            if SchemaCacheLogLast->(reccount()) > 0

                l_cSQLCommandFields  := [SELECT namespace_name,]
                l_cSQLCommandFields  +=        [table_name,]
                l_cSQLCommandFields  +=        [table_is_unlogged,]
                l_cSQLCommandFields  +=        [field_position,]
                l_cSQLCommandFields  +=        [field_name,]
                l_cSQLCommandFields  +=        [field_type_enum_spacename,]
                l_cSQLCommandFields  +=        [field_type_enum_name,]
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
                // l_cSQLCommandFields  += [ FROM ]+::FormatIdentifier(::p_HBORMNamespace)+::FixCasingOfSchemaCacheTables([."SchemaCacheFields_])+trans(SchemaCacheLogLast->pk)+["]
                l_cSQLCommandFields  += [ FROM ]+::FormatIdentifier(::p_HBORMNamespace)+::FixCasingOfSchemaCacheTables([."SchemaCacheFields_])+[p_iMetadataTableCacheLogLastPk]+["]
                l_cSQLCommandFields  += [ ORDER BY tag1,tag2,field_position]


                l_cSQLCommandIndexes := [SELECT namespace_name,]
                l_cSQLCommandIndexes +=        [table_name,]
                l_cSQLCommandIndexes +=        [index_name,]
                l_cSQLCommandIndexes +=        [index_definition,]
                l_cSQLCommandIndexes +=        [tag1,]
                l_cSQLCommandIndexes +=        [tag2]
                // l_cSQLCommandIndexes += [ FROM ]+::FormatIdentifier(::p_HBORMNamespace)+::FixCasingOfSchemaCacheTables([."SchemaCacheIndexes_])+trans(SchemaCacheLogLast->pk)+["]
                l_cSQLCommandIndexes += [ FROM ]+::FormatIdentifier(::p_HBORMNamespace)+::FixCasingOfSchemaCacheTables([."SchemaCacheIndexes_])+[p_iMetadataTableCacheLogLastPk]+["]
                l_cSQLCommandIndexes += [ ORDER BY tag1,tag2,index_name]

                if       ::SQLExec("LoadMetadata",strtran(l_cSQLCommandFields ,"p_iMetadataTableCacheLogLastPk",trans(SchemaCacheLogLast->pk)),"hb_orm_sqlconnect_schema_fields") ;
                .and. ::SQLExec("LoadMetadata",strtran(l_cSQLCommandIndexes,"p_iMetadataTableCacheLogLastPk",trans(SchemaCacheLogLast->pk)),"hb_orm_sqlconnect_schema_indexes")
                    l_lLoadedCache := .t.
                    ::p_iMetadataTableCacheLogLastPk := SchemaCacheLogLast->pk
                else
                    CloseAlias("hb_orm_sqlconnect_schema_fields")
                    CloseAlias("hb_orm_sqlconnect_schema_indexes")
                    ::EnableSchemaChangeTracking()
                    ::UpdateSchemaCache(.t.)

                    if ::SQLExec("LoadMetadata",l_cSQLCommand,"SchemaCacheLogLast")
                        if       ::SQLExec("LoadMetadata",strtran(l_cSQLCommandFields ,"p_iMetadataTableCacheLogLastPk",trans(SchemaCacheLogLast->pk)),"hb_orm_sqlconnect_schema_fields") ;
                        .and. ::SQLExec("LoadMetadata",strtran(l_cSQLCommandIndexes,"p_iMetadataTableCacheLogLastPk",trans(SchemaCacheLogLast->pk)),"hb_orm_sqlconnect_schema_indexes")
                            l_lLoadedCache := .t.
                            ::p_iMetadataTableCacheLogLastPk := SchemaCacheLogLast->pk
                        endif
                    endif
                endif

                if !l_lLoadedCache
                    CloseAlias("hb_orm_sqlconnect_schema_fields")
                    CloseAlias("hb_orm_sqlconnect_schema_indexes")
                endif

            endif
        endif
    endif

    if !(used("hb_orm_sqlconnect_schema_fields") .and. used("hb_orm_sqlconnect_schema_indexes"))
        ::p_ErrorMessage := [Failed load cached PostgreSQL schema.]
    else
        select hb_orm_sqlconnect_schema_fields
        
        if Reccount() > 0
            l_cNamespaceAndTableNameLast := Trim(hb_orm_sqlconnect_schema_fields->namespace_name)+"."+Trim(hb_orm_sqlconnect_schema_fields->table_name)
            l_lUnloggedLast              := hb_orm_sqlconnect_schema_fields->table_is_unlogged
            hb_HClear(l_hTableSchemaFields)

            scan all
                l_cNamespaceAndTableName := Trim(hb_orm_sqlconnect_schema_fields->namespace_name)+"."+Trim(hb_orm_sqlconnect_schema_fields->table_name)
                l_lUnlogged              := hb_orm_sqlconnect_schema_fields->table_is_unlogged
                if !(l_cNamespaceAndTableName == l_cNamespaceAndTableNameLast)
                    ::p_hMetadataTable[l_cNamespaceAndTableNameLast] := {HB_ORM_SCHEMA_FIELD=>hb_hClone(l_hTableSchemaFields),HB_ORM_SCHEMA_INDEX=>NIL,"Unlogged"=>l_lUnloggedLast}    //{Table Fields (HB_ORM_SCHEMA_FIELD), Table Indexes (HB_ORM_SCHEMA_INDEX)}
                    hb_HClear(l_hTableSchemaFields)
                    l_cNamespaceAndTableNameLast := l_cNamespaceAndTableName
                    l_lUnloggedLast           := l_lUnlogged
                endif

                //Parse the comment field to see if recorded the field type and its length
                l_cFieldCommentType   := ""
                l_nFieldCommentLength := 0
                l_cFieldComment := nvl(field->field_comment,"")
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

                l_cFieldTypeEnumName := ""

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
                case "jsonb"
                    l_cFieldType      := "JSB"
                    l_nFieldLen       := 0
                    l_nFieldDec       := 0
                    exit
                case "json"
                    l_cFieldType      := "JS"
                    l_nFieldLen       := 0
                    l_nFieldDec       := 0
                    exit
                case "oid"
                    l_cFieldType          := "OID"
                    l_nFieldLen           := 0
                    l_nFieldDec           := 0
                    exit
                case "USER-DEFINED"
                    l_cFieldType          := "E"
                    l_cFieldTypeEnumName  := trim(field->field_type_enum_name)
                    l_nFieldLen           := 0
                    l_nFieldDec           := 0
                    // _M_ Maybe for future support of enumerations stored in other namespaces trim(field->field_type_enum_spacename)
                    exit
                otherwise
                    l_cFieldType          := "?"
                    l_nFieldLen           := 0
                    l_nFieldDec           := 0
                endswitch

                l_lFieldNullable      := field->field_nullable
                l_lFieldAutoIncrement := field->field_auto_increment                    //{"I",,,,.t.}
                l_lFieldArray         := field->field_array

                l_cFieldDefault := ::SanitizeFieldDefaultFromDefaultBehavior(::p_SQLEngineType,l_cFieldType,l_lFieldNullable,field->field_default)

                l_hTableSchemaFields[trim(field->field_Name)] := {HB_ORM_SCHEMA_FIELD_TYPE => l_cFieldType}
                l_hTableSchemaField := l_hTableSchemaFields[trim(field->field_Name)]
                if !empty(l_cFieldTypeEnumName)
                    l_hTableSchemaField[HB_ORM_SCHEMA_FIELD_ENUMNAME] := l_cFieldTypeEnumName
                endif
                if !hb_IsNil(l_nFieldLen) .and. l_nFieldLen > 0
                    l_hTableSchemaField[HB_ORM_SCHEMA_FIELD_LENGTH] := l_nFieldLen
                endif
                if !hb_IsNil(l_nFieldDec) .and. l_nFieldDec > 0
                    l_hTableSchemaField[HB_ORM_SCHEMA_FIELD_DECIMALS] := l_nFieldDec
                endif
                if !hb_IsNil(l_lFieldNullable) .and. l_lFieldNullable
                    l_hTableSchemaField[HB_ORM_SCHEMA_FIELD_NULLABLE] := .t.
                endif
                if !hb_IsNil(l_lFieldAutoIncrement) .and. l_lFieldAutoIncrement
                    l_hTableSchemaField[HB_ORM_SCHEMA_FIELD_AUTOINCREMENT] := .t.
                endif
                if !hb_IsNil(l_lFieldArray) .and. l_lFieldArray
                    l_hTableSchemaField[HB_ORM_SCHEMA_FIELD_ARRAY] := .t.
                endif
                if !hb_IsNil(l_cFieldDefault) .and. !empty(l_cFieldDefault)
                    l_hTableSchemaField[HB_ORM_SCHEMA_FIELD_DEFAULT] := l_cFieldDefault
                endif

            endscan

            ::p_hMetadataTable[l_cNamespaceAndTableNameLast] := {HB_ORM_SCHEMA_FIELD=>hb_hClone(l_hTableSchemaFields),;
                                                                 HB_ORM_SCHEMA_INDEX=>NIL,"Unlogged"=>l_lUnloggedLast}    //{Table Fields (HB_ORM_SCHEMA_FIELD), Table Indexes (HB_ORM_SCHEMA_INDEX)}
            hb_HClear(l_hTableSchemaFields)

            //Since Indexes could only exists for an existing table we simply assign to a ::p_hMetadataTable[][HB_ORM_SCHEMA_INDEX] cell
            //Stopped added the namespace name to the index names, to help fit objects length to 63 characters and in any case "Two indexes in the same schema cannot have the same name.", meaning can be the same in two different namespace_name.
            select hb_orm_sqlconnect_schema_indexes
            if Reccount() > 0
                l_cNamespaceAndTableNameLast := Trim(hb_orm_sqlconnect_schema_indexes->namespace_name)+"."+Trim(hb_orm_sqlconnect_schema_indexes->table_name)
                hb_HClear(l_hTableSchemaIndexes)

                scan all
                    l_cNamespaceAndTableName := Trim(hb_orm_sqlconnect_schema_indexes->namespace_name)+"."+Trim(hb_orm_sqlconnect_schema_indexes->table_name)
                    l_cTableName             := Trim(hb_orm_sqlconnect_schema_indexes->table_name)

                    //Test that the index is for a real table, not a view or other type of objects. Since we used "tables.table_type = 'BASE TABLE'" earlier we need to check if we loaded that table in the p_hMetadataTable
                    if hb_HHasKey(::p_hMetadataTable,l_cNamespaceAndTableName)

                        if !(l_cNamespaceAndTableName == l_cNamespaceAndTableNameLast)
                            if len(l_hTableSchemaIndexes) > 0
                                ::p_hMetadataTable[l_cNamespaceAndTableNameLast][HB_ORM_SCHEMA_INDEX] := hb_hClone(l_hTableSchemaIndexes)
                                hb_HClear(l_hTableSchemaIndexes)
                            else
                                ::p_hMetadataTable[l_cNamespaceAndTableNameLast][HB_ORM_SCHEMA_INDEX] := NIL
                            endif
                            l_cNamespaceAndTableNameLast := l_cNamespaceAndTableName
                        endif

                        l_cIndexName := lower(trim(field->index_name))
                        // if left(l_cIndexName,len(l_cTableName)+1) == lower(l_cTableName)+"_" .and. right(l_cIndexName,4) == "_idx"  // only record indexes maintained by hb_orm
                        if right(l_cIndexName,4) == "_idx"  // only record indexes maintained by hb_orm. Remove the restriction about table name in front, since a past spec also had the name space.
                            l_cIndexName      := hb_orm_RootIndexName(l_cTableName,l_cIndexName)
                            
                            l_cIndexDefinition := field->index_definition
                            l_nPos1 := hb_ati(" USING ",l_cIndexDefinition)
                            if l_nPos1 > 0
                                l_nPos2 := hb_at(" ",l_cIndexDefinition,l_nPos1+1)
                                l_nPos3 := hb_at("(",l_cIndexDefinition,l_nPos1)
                                l_nPos4 := hb_rat(")",l_cIndexDefinition,l_nPos1)
                                l_cIndexExpression := substr(l_cIndexDefinition,l_nPos3+1,l_nPos4-l_nPos3-1)

                                if !(lower(l_cIndexExpression) == lower(::p_PrimaryKeyFieldName))   // No reason to record the index of the PRIMARY key
                                    l_lIndexUnique := ("UNIQUE INDEX" $ l_cIndexDefinition)
                                    l_cIndexType   := upper(substr(l_cIndexDefinition,l_nPos2+1,l_nPos3-l_nPos2-2))
                                    l_hTableSchemaIndexes[l_cIndexName] := {HB_ORM_SCHEMA_INDEX_EXPRESSION => l_cIndexExpression,;
                                                                            HB_ORM_SCHEMA_INDEX_UNIQUE     => l_lIndexUnique,;
                                                                            HB_ORM_SCHEMA_INDEX_ALGORITHM  => l_cIndexType}
                                endif

                            endif
                        endif
                    endif
                endscan
                if len(l_hTableSchemaIndexes) > 0
                    ::p_hMetadataTable[l_cNamespaceAndTableNameLast][HB_ORM_SCHEMA_INDEX] := hb_hClone(l_hTableSchemaIndexes)
                    hb_HClear(l_hTableSchemaIndexes)
                else
                    ::p_hMetadataTable[l_cNamespaceAndTableNameLast][HB_ORM_SCHEMA_INDEX] := NIL
                endif

            endif

        endif

    endif

endcase

CloseAlias("hb_orm_sqlconnect_schema_fields")
CloseAlias("hb_orm_sqlconnect_schema_indexes")

select (l_nSelect)

hb_orm_SendToDebugView("LoadSchema End")

return NIL
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
method GenerateMigrateSchemaScript(par_hWharfConfig) class hb_orm_SQLConnect

local l_cTableName,l_hTableDefinition
local l_cFieldName,l_hFieldDefinition
local l_cIndexName,l_hIndexDefinition
local l_hFields,l_hIndexes
local l_hField,l_hIndex
local l_hCurrentTableDefinition
local l_hCurrentFieldDefinition
local l_hCurrentIndexDefinition
local l_cFieldType,       l_cFieldTypeEnumName       ,l_lFieldArray,       l_nFieldLen,       l_nFieldDec,       l_lFieldNullable,       l_lFieldAutoIncrement,       l_cFieldDefault
local l_cCurrentFieldType,l_cCurrentFieldTypeEnumName,l_lCurrentFieldArray,l_nCurrentFieldLen,l_nCurrentFieldDec,l_lCurrentFieldNullable,l_lCurrentFieldAutoIncrement,l_cCurrentFieldDefault
local l_lMatchingFieldDefinition
local l_cMismatchType
local l_cNamespaceName
local l_cSQLScriptPreUpdate := ""
local l_cSQLScript := ""
local l_cSQLScriptPostUpdate := ""
local l_cSQLScriptFieldChanges,l_cSQLScriptFieldChangesCycle1,l_cSQLScriptFieldChangesCycle2
local l_cNamespaceAndTableName
local l_cFormattedTableName
local l_nPos

local l_cCurrentNamespaceAndTableName
local l_cCurrentNamespaceName
local l_cCurrentTableName
local l_cCurrentFieldName

local l_lCurrentUnlogged
local l_lUnlogged

local l_cFieldUsedAs
local l_cFieldParentTable
local l_cSQLPrimaryKeyConstraints
local l_oCursorPrimaryKeyConstraints
local l_hExistingIndexesOfExistingTable
local l_cEnumerationName
local l_hEnumerationDefinition
local l_hEnumValues
local l_cSQLEnumerations
local l_cEnumValueName
local l_lProcessedValue
local l_oCursorExistingEnumerations
local l_hRename
local l_hRenameNamespace
local l_hRenameTable
local l_hRenameIndex
local l_hRenameColumn
local l_hRenameEnumeration
local l_hRenameEnumValue
local l_cNamespaceAndEnumerationName
local l_hCurrentEnumerationDefinition
local l_cNamespaceNameExistingCasing
local l_cNameFrom
local l_cNameTo
local l_cHashValue
local l_cHashKey
local l_cHashNewKey
local l_cPrefix
local l_nPrefixLength
local l_cNamespaceOnFile
local l_cSQLScriptForeignKeyConstraints
local l_cNamespaceAndTableFrom

//Following needed to ignore constraint changes, since Postgres will already handle these when namespace, table and columns are renamed.
local l_hAppliedRenameNamespace := {=>}
local l_hAppliedRenameTable     := {=>}
local l_hAppliedRenameColumn    := {=>}
local l_hMetadataCurrentTable
local l_hMetadataCurrentFields
local l_hMetadataCurrentEnumeration
local l_hMetadataCurrentValues

local l_cNamespaceAndTable
local l_hColumnDefinition

if ::UpdateSchemaCache()
    ::LoadMetadata("GenerateMigrateSchemaScript")
endif

//Check if should do some renaming first
l_hRename := hb_hGetDef(par_hWharfConfig,"Rename",{=>})
if !empty( l_hRename )
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        //_M_ Not supported Yet
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL

        // Rename Namespaces if needed -----------------------------------------------------------------------------------------------------------
        for each l_hRenameNamespace in hb_hGetDef(l_hRename,"Namespace",{=>})
            l_cNameFrom := l_hRenameNamespace:__enumkey
            l_cNameTo   := l_hRenameNamespace

            l_cNameFrom := hb_hGetDef(::p_hMetadataNamespace,l_cNameFrom,"")  // To check if currently present and get the casing on file
            if !empty(l_cNameFrom)
                l_cSQLScript += [ALTER SCHEMA ]+::FormatIdentifier(l_cNameFrom)+[ RENAME TO ]+::FormatIdentifier(l_cNameTo)+[;]+CRLF

                l_hAppliedRenameNamespace[l_cNameFrom] := l_cNameTo

                //Update the ::p_hMetadataTable to ensure we will not create tables simply because their namespace was changed
                //There is no Hash Key rename, so has to copy the entire entry. For now will leave the old version, in any case a new LoadMetadata() will be done after migration.
                l_cPrefix := lower(l_cNameFrom)+[.]
                l_nPrefixLength := len(l_cPrefix)

                for each l_cHashKey in hb_HKeys(::p_hMetadataTable)  // Since changing the ::p_hMetadataTable itself, it is safer to make an array list of the keys
                    l_cHashValue := ::p_hMetadataTable[l_cHashKey]
                    if lower(left(l_cHashKey,l_nPrefixLength)) == l_cPrefix
                        l_cHashNewKey := l_cNameTo+"."+substr(l_cHashKey,l_nPrefixLength+1)
                       ::p_hMetadataTable[l_cHashNewKey] := ::p_hMetadataTable[l_cHashKey]

                        l_hAppliedRenameTable[l_cHashKey] := l_cHashNewKey

                       hb_HDel(::p_hMetadataTable,l_cHashKey)   // Not certain if can delete while looping
                    endif
                endfor

                for each l_cHashKey in hb_HKeys(::p_hMetadataEnumeration)  // Since changing the ::p_hMetadataEnumeration itself, it is safer to make an array list of the keys
                   l_cHashValue := ::p_hMetadataEnumeration[l_cHashKey]
                   if lower(left(l_cHashKey,l_nPrefixLength)) == l_cPrefix
                        l_cHashNewKey := l_cNameTo+"."+substr(l_cHashKey,l_nPrefixLength+1)
                        ::p_hMetadataEnumeration[l_cHashNewKey] := ::p_hMetadataEnumeration[l_cHashKey]
                        hb_HDel(::p_hMetadataEnumeration,l_cHashKey)   // Not certain if can delete while looping
                    endif
                endfor

                //Update the ::p_hMetadataNamespace itself
                ::p_hMetadataNamespace[l_cNameTo] := l_cNameTo
                hb_HDel(::p_hMetadataNamespace,l_cNameFrom)

            endif
        endfor

        // Rename Tables if needed -----------------------------------------------------------------------------------------------------------
        for each l_hRenameNamespace in hb_hGetDef(l_hRename,"Table",{=>})
            l_cNamespaceName := l_hRenameNamespace:__enumkey

            for each l_hRenameTable in l_hRenameNamespace
                l_cNameFrom := l_hRenameTable:__enumkey
                l_cNameTo   := l_hRenameTable

                l_nPos := hb_HPos(::p_hMetadataTable,l_cNamespaceName+"."+l_cNameFrom)  // To check if currently present. Its position will help to get the casing on file
                if l_nPos > 0
                    l_cNamespaceAndTableFrom := hb_HKeyAt(::p_hMetadataTable,l_nPos) 
                    l_nPos := at(".",l_cNamespaceAndTableFrom)
                    if l_nPos > 0
                        l_cNameFrom := substr(l_cNamespaceAndTableFrom,l_nPos+1)

                        l_cSQLScript += [ALTER TABLE IF EXISTS ]+::FormatIdentifier(l_cNamespaceName)+"."+::FormatIdentifier(l_cNameFrom)+[ RENAME TO ]+::FormatIdentifier(l_cNameTo)+[;]+CRLF

                        l_hAppliedRenameTable[l_cNamespaceName+"."+l_cNameFrom] := l_cNamespaceName+"."+l_cNameTo

                        //Update the ::p_hMetadataTable itself
                        ::p_hMetadataTable[l_cNamespaceName+"."+l_cNameTo] := hb_HClone(::p_hMetadataTable[l_cNamespaceName+"."+l_cNameFrom])  // Have to copy over all the field and index definitions.
                        hb_HDel(::p_hMetadataTable,l_cNamespaceName+"."+l_cNameFrom)

                        //Rename table related indexes
                        for each l_hRenameIndex in nvl(hb_hGetDef(::p_hMetadataTable[l_cNamespaceName+"."+l_cNameTo],HB_ORM_SCHEMA_INDEX,{=>}),{=>})
                            l_cIndexName := l_hRenameIndex:__enumkey
                            l_cSQLScript += [ALTER INDEX IF EXISTS ]+::FormatIdentifier(l_cNamespaceName)+"."+::FormatIdentifier(lower(l_cNameFrom)+"_"+lower(l_cIndexName)+"_idx")+;
                                                        [ RENAME TO ]+::FormatIdentifier(lower(l_cNameTo)+"_"+lower(l_cIndexName)+"_idx")+[;]+CRLF
                        endfor
                    endif
                endif
            endfor
        endfor

        // Rename Columns if needed -----------------------------------------------------------------------------------------------------------
        for each l_hRenameNamespace in hb_hGetDef(l_hRename,"Column",{=>})
            l_cNamespaceName := l_hRenameNamespace:__enumkey
            for each l_hRenameTable in l_hRenameNamespace
                l_cTableName := l_hRenameTable:__enumkey

                l_hMetadataCurrentTable := hb_hGetDef(::p_hMetadataTable,l_cNamespaceName+"."+l_cTableName,{=>})
                if !empty(l_hMetadataCurrentTable)   // We should always find the table since any namespace and table renames happened before.
                    l_hMetadataCurrentFields := l_hMetadataCurrentTable[HB_ORM_SCHEMA_FIELD]
                    for each l_hRenameColumn in l_hRenameTable
                        l_cNameFrom := l_hRenameColumn:__enumkey
                        l_cNameTo   := l_hRenameColumn

                        l_nPos := hb_HPos(l_hMetadataCurrentFields,l_cNameFrom)  // To check if currently present. Its position will help to get the casing on file
                        if l_nPos > 0
                            l_cNameFrom := hb_HKeyAt(l_hMetadataCurrentFields,l_nPos)
                            l_hMetadataCurrentFields[l_cNameTo] := hb_HClone(l_hMetadataCurrentFields[l_cNameFrom])
                            hb_HDel(l_hMetadataCurrentFields,l_cNameFrom)

                            l_cSQLScript += [ALTER TABLE IF EXISTS ]+::FormatIdentifier(l_cNamespaceName)+"."+::FormatIdentifier(l_cTableName)+[ RENAME ]+::FormatIdentifier(l_cNameFrom)+[ TO ]+::FormatIdentifier(l_cNameTo)+[;]+CRLF

                            //Will need the following by GenerateMigrateForeignKeyConstraintsScript
                            l_hAppliedRenameColumn[l_cNamespaceName+"."+l_cTableName+"."+l_cNameFrom] := l_cNameTo

                            // Rename related index, in case this is a foreign key field which means DataWharf may have auto-generated and index for.
                            for each l_hRenameIndex in nvl(hb_hGetDef(l_hMetadataCurrentTable,HB_ORM_SCHEMA_INDEX,{=>}),{=>})
                                l_cIndexName := l_hRenameIndex:__enumkey
                                if lower(l_cIndexName) == lower(l_cNameFrom)
                                    l_cSQLScript += [ALTER INDEX IF EXISTS ]+::FormatIdentifier(l_cNamespaceName)+"."+::FormatIdentifier(lower(l_cTableName)+"_"+lower(l_cNameFrom)+"_idx")+;
                                                                [ RENAME TO ]+::FormatIdentifier(lower(l_cTableName)+"_"+lower(l_cNameTo)+"_idx")+[;]+CRLF

                                    //To prevent creating later on the index, not needed since the current one is renamed.
                                    l_hRenameIndex["Expression"] := lower(l_cNameTo)
                                    l_hMetadataCurrentTable[HB_ORM_SCHEMA_INDEX][l_cNameTo] := hb_hClone( l_hMetadataCurrentTable[HB_ORM_SCHEMA_INDEX][l_cNameFrom] )
                                    hb_HDel(l_hMetadataCurrentTable[HB_ORM_SCHEMA_INDEX],l_cNameFrom)

                                    // The Rename of any potential Constraints will be done in GenerateMigrateForeignKeyConstraintsScript

                                    exit  // only one  index could be named by the column name
                                endif
                            endfor
                            //We don't need to update the ::p_hMetadataTable column info since will reload it
                            // ::p_hMetadataTable[l_cNamespaceName+"."+l_cNameTo] := hb_HClone(::p_hMetadataTable[l_cNamespaceName+"."+l_cNameFrom])  // Have to copy over all the field and index definitions.
                            // hb_HDel(::p_hMetadataTable,l_cNamespaceName+"."+l_cNameFrom)

                        endif
                    endfor
                    // ::p_hMetadataTable[l_cNamespaceName+"."+l_cTableName][HB_ORM_SCHEMA_FIELD] := l_hMetadataCurrentFields  No need for this, since was modifying l_hMetadataCurrentFields use by reference.
                    l_hMetadataCurrentTable := {=>}   // To ensure will not alter the previous step mapping


                endif
            endfor
        endfor

        // Rename Enumerations if needed -----------------------------------------------------------------------------------------------------------
        for each l_hRenameNamespace in hb_hGetDef(l_hRename,"Enumeration",{=>})
            l_cNamespaceName := l_hRenameNamespace:__enumkey

            for each l_hRenameEnumeration in l_hRenameNamespace
                l_cNameFrom := l_hRenameEnumeration:__enumkey
                l_cNameTo   := l_hRenameEnumeration

                l_nPos := hb_HPos(::p_hMetadataEnumeration,l_cNamespaceName+"."+l_cNameFrom)  // To check if currently present. Its position will help to get the casing on file
                if l_nPos > 0
                    l_cNamespaceAndTableFrom := hb_HKeyAt(::p_hMetadataEnumeration,l_nPos) 
                    l_nPos := at(".",l_cNamespaceAndTableFrom)
                    if l_nPos > 0
                        l_cNameFrom := substr(l_cNamespaceAndTableFrom,l_nPos+1)

                        l_cSQLScript += [ALTER TYPE ]+::FormatIdentifier(l_cNamespaceName)+"."+::FormatIdentifier(l_cNameFrom)+[ RENAME TO ]+::FormatIdentifier(l_cNameTo)+[;]+CRLF

                        // l_hAppliedRenameTable[l_cNamespaceName+"."+l_cNameFrom] := l_cNamespaceName+"."+l_cNameTo

                        //Update the ::p_hMetadataEnumeration itself
                        ::p_hMetadataEnumeration[l_cNamespaceName+"."+l_cNameTo] := hb_HClone(::p_hMetadataEnumeration[l_cNamespaceName+"."+l_cNameFrom])  // Have to copy over all the field and index definitions.
                        hb_HDel(::p_hMetadataEnumeration,l_cNamespaceName+"."+l_cNameFrom)

                        // Patch ::p_hMetadataTable since changing the enumeration name will also automatically remapped, so we don't have to alter the field definition of the current enumeration being renamed.
                        for each l_hMetadataCurrentTable in ::p_hMetadataTable
                            //Check if the Namespace is same as the enumeration. For now we don't support tables using enumeration from other namespaces.
                            l_cNamespaceAndTable := l_hMetadataCurrentTable:__enumkey
                            l_nPos := at(".",l_cNamespaceAndTable)
                            if l_nPos > 0
                                if lower(left(l_cNamespaceAndTable,l_nPos-1)) == lower(l_cNamespaceName)
                                    for each l_hColumnDefinition in hb_hGetDef(l_hMetadataCurrentTable,HB_ORM_SCHEMA_FIELD,{=>})  //"Fields"
                                        if l_hColumnDefinition["Type"] == "E" .and. lower(l_hColumnDefinition["Enumeration"]) == lower(l_cNameFrom)
                                            l_hColumnDefinition["Enumeration"] := l_cNameTo  // Since Hashes are stored by reference, changing a node value will affect the original ::p_hMetadataTable structure.
                                        endif
                                    endfor
                                endif
                            endif
                        endfor

                    endif
                endif
            endfor
        endfor

        // Rename EnumValues if needed -----------------------------------------------------------------------------------------------------------
        for each l_hRenameNamespace in hb_hGetDef(l_hRename,"EnumValue",{=>})
            l_cNamespaceName := l_hRenameNamespace:__enumkey

            for each l_hRenameEnumeration in l_hRenameNamespace
                l_cEnumerationName := l_hRenameEnumeration:__enumkey

                l_hMetadataCurrentEnumeration := hb_hGetDef(::p_hMetadataEnumeration,l_cNamespaceName+"."+l_cEnumerationName,{=>})
                if !empty(l_hMetadataCurrentEnumeration)   // We should always find the table since any namespace and table renames happened before.
                    l_hMetadataCurrentValues := l_hMetadataCurrentEnumeration["Values"]
                    for each l_hRenameColumn in l_hRenameEnumeration
                        l_cNameFrom := l_hRenameColumn:__enumkey
                        l_cNameTo   := l_hRenameColumn

                        l_nPos := hb_HPos(l_hMetadataCurrentValues,l_cNameFrom)  // To check if currently present. Its position will help to get the casing on file
                        if l_nPos > 0
                            l_cNameFrom := hb_HKeyAt(l_hMetadataCurrentValues,l_nPos)
                            l_hMetadataCurrentValues[l_cNameTo] := l_hMetadataCurrentValues[l_cNameFrom]    // Only storing the order of the value, no sub-hash structure
                            hb_HDel(l_hMetadataCurrentValues,l_cNameFrom)

                            l_cSQLScript += [ALTER TYPE ]+::FormatIdentifier(l_cNamespaceName)+"."+::FormatIdentifier(l_cEnumerationName)+[ RENAME VALUE ]+::FormatValue(l_cNameFrom)+[ TO ]+::FormatValue(l_cNameTo)+[;]+CRLF

                            //We don't need to update the ::p_hMetadataEnumeration column info since will reload it
                            // ::p_hMetadataEnumeration[l_cNamespaceName+"."+l_cNameTo] := hb_HClone(::p_hMetadataEnumeration[l_cNamespaceName+"."+l_cNameFrom])  // Have to copy over all the field and index definitions.
                            // hb_HDel(::p_hMetadataEnumeration,l_cNamespaceName+"."+l_cNameFrom)

                        endif
                    endfor
                    // ::p_hMetadataEnumeration[l_cNamespaceName+"."+l_cEnumerationName][HB_ORM_SCHEMA_FIELD] := l_hMetadataCurrentValues  No need for this, since was modifying l_hMetadataCurrentValues use by reference.
                    l_hMetadataCurrentEnumeration := {=>}   // To ensure will not alter the previous step mapping

                endif
            endfor
        endfor


    endcase
endif

//Create any missing namespaces or case fix already existing ones
do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    //When you get a connection to PostgreSQL it is always to a particular database. To access a different database, you must get a new connection.

    for each l_cNamespaceName in hb_hGetDef(par_hWharfConfig,"Namespaces",{})
        l_cNamespaceOnFile := hb_hGetDef(::p_hMetadataNamespace,l_cNamespaceName,nil)
        if hb_IsNil(l_cNamespaceOnFile)
            //Missing Name space
            l_cSQLScript += [CREATE SCHEMA IF NOT EXISTS ]+::FormatIdentifier(l_cNamespaceName)+[;]+CRLF
            ::p_hMetadataNamespace[l_cNamespaceName] := l_cNamespaceName
        else
            //Present but maybe the casing changed
            if !(l_cNamespaceOnFile == l_cNamespaceName)
                l_cSQLScript += [ALTER SCHEMA ]+::FormatIdentifier(l_cNamespaceOnFile)+[ RENAME TO ]+::FormatIdentifier(l_cNamespaceName)+[;]+CRLF
                ::p_hMetadataNamespace[l_cNamespaceName] := l_cNamespaceName
            endif
        endif
    endfor

endcase

//Get the list of Primary Keys in case we need to add them.  
// Renaming the primakey will affect the constraints name. But that one is managed by Postgresql itself since we made the fields incremental
CloseAlias("hb_orm_ListOfPrimaryKeyConstraints")
do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cSQLPrimaryKeyConstraints := [select ns.nspname   as "NamespaceName",]
    l_cSQLPrimaryKeyConstraints +=       [ cl.relname   as "TableName",]
    l_cSQLPrimaryKeyConstraints +=       [ con1.conname as "ConstraintName"]
    l_cSQLPrimaryKeyConstraints += [ from pg_class cl]
    l_cSQLPrimaryKeyConstraints += [ join pg_namespace ns on cl.relnamespace = ns.oid]
    l_cSQLPrimaryKeyConstraints += [ join pg_constraint con1 on con1.conrelid = cl.oid]
    l_cSQLPrimaryKeyConstraints += [ where con1.contype = 'p' and ns.nspname not in ('cyanaudit','pg_catalog')]

    if ! ::SQLExec("a660c126-8361-4bfb-9342-4dcd26778aaf",l_cSQLPrimaryKeyConstraints,"hb_orm_ListOfPrimaryKeyConstraints")
        hb_orm_SendToDebugView("GenerateMigrateSchemaScript - Failed on hb_orm_ListOfPrimaryKeyConstraints")
    else
        l_oCursorPrimaryKeyConstraints := hb_orm_Cursor():Init():Associate("hb_orm_ListOfPrimaryKeyConstraints")   // Associating it with the variable will ensure the alias is also closed once the variable is gone.

        with object l_oCursorPrimaryKeyConstraints
            :Index("tag1","padr(upper(NamespaceName+'*'+TableName+'*'),240)")
            :CreateIndexes()
        endwith
    endif

endcase

//Add / Update any Enumerations
if !empty( hb_hGetDef(par_hWharfConfig,"Enumerations",{=>}) )
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL

        //We can only create actual enumeration definitions for Postgresql when the enumeration "ImplementAs" is "NativeSQLEnum"
        for each l_hEnumerationDefinition in hb_hGetDef(par_hWharfConfig,"Enumerations",{=>})
            if nvl(hb_hGetDef(l_hEnumerationDefinition,"ImplementAs",""),"") == "NativeSQLEnum"
                l_cNamespaceAndEnumerationName := l_hEnumerationDefinition:__enumKey()

                l_nPos := at(".",l_cNamespaceAndEnumerationName)
                if empty(l_nPos)
                    l_cNamespaceName   := "public"
                    l_cEnumerationName := l_cNamespaceAndEnumerationName
                else
                    l_cNamespaceName   := left(l_cNamespaceAndEnumerationName,l_nPos-1)
                    l_cEnumerationName := substr(l_cNamespaceAndEnumerationName,l_nPos+1)
                endif
                l_cNamespaceAndEnumerationName := l_cNamespaceName+"."+l_cEnumerationName

                l_hEnumValues := hb_hGetDef(l_hEnumerationDefinition,"Values",{=>})
                if len(l_hEnumValues) > 0
                    l_hCurrentEnumerationDefinition := hb_HGetDef(::p_hMetadataEnumeration,l_cNamespaceAndEnumerationName,NIL)
                    if hb_IsNIL(l_hCurrentEnumerationDefinition)
                        // Enumeration does not exists
                        l_cSQLScript += [CREATE TYPE ]+::FormatIdentifier(l_cNamespaceName)+[.]+::FormatIdentifier(l_cEnumerationName)+[ AS ENUM (]
                        l_lProcessedValue := .f.
                        
                        for each l_cEnumValueName in l_hEnumValues
                            if l_lProcessedValue
                                l_cSQLScript += [,]
                            else
                                l_lProcessedValue := .t.
                            endif
                            l_cSQLScript += [']+l_cEnumValueName:__enumKey+[']
                        endfor
                        l_cSQLScript += [);]+CRLF
                    else
                        // Enumeration exists, lets see if we have all the possible values.
                        for each l_cEnumValueName in l_hEnumValues
                            if hb_IsNil(l_hCurrentEnumerationDefinition,l_cEnumValueName:__enumKey,NIL)
                                l_cSQLScript += [ALTER TYPE ]+::FormatIdentifier(l_cNamespaceName)+[.]+::FormatIdentifier(l_cEnumerationName)+[ ADD VALUE ']+l_cEnumValueName:__enumKey+[';]+CRLF
                            endif
                        endfor
                    endif
                    
                endif
            endif
        endfor
    endcase
endif

if !empty(l_cEnumValueName)
    hb_orm_SendToDebugView(l_cEnumValueName)
endif

//Add / Update any Tables
for each l_hTableDefinition in hb_hGetDef(par_hWharfConfig,"Tables",{=>})
    l_cNamespaceAndTableName := l_hTableDefinition:__enumKey()

    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        // l_cNamespaceName := ""
        // //Will ignore "public" as NameSpace
        // if left(l_cNamespaceAndTableName,len("public.")) == "public."
        //     l_cNamespaceAndTableName := substr(l_cNamespaceAndTableName,len("public.")+1)
        // endif
        // l_cTableName  := l_cNamespaceAndTableName

        l_nPos := at(".",l_cNamespaceAndTableName)
        if empty(l_nPos)
            l_cNamespaceName         := "public"
            l_cTableName             := l_cNamespaceAndTableName
            // l_cNamespaceAndTableName := l_cNamespaceName+"."+l_cTableName
        else
            l_cNamespaceName := left(l_cNamespaceAndTableName,l_nPos-1)
            l_cTableName     := substr(l_cNamespaceAndTableName,l_nPos+1)
            if l_cNamespaceName == "hborm" .and. !(::p_HBORMNamespace == "hborm")
                if ::MySQLEngineConvertIdentifierToLowerCase
                    l_cNamespaceName := lower(::p_HBORMNamespace)
                else
                    l_cNamespaceName := ::p_HBORMNamespace
                endif
            endif
        endif
        l_cNamespaceAndTableName := l_cNamespaceName+"."+l_cTableName

    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        l_nPos := at(".",l_cNamespaceAndTableName)
        if empty(l_nPos)
            l_cNamespaceName         := "public"
            l_cTableName             := l_cNamespaceAndTableName
            // l_cNamespaceAndTableName := l_cNamespaceName+"."+l_cTableName
        else
            l_cNamespaceName := left(l_cNamespaceAndTableName,l_nPos-1)
            l_cTableName     := substr(l_cNamespaceAndTableName,l_nPos+1)
        endif
        if l_cNamespaceName == "hborm" .and. !(::p_HBORMNamespace == "hborm")
            l_cNamespaceName := ::p_HBORMNamespace
        endif
        l_cNamespaceAndTableName := l_cNamespaceName+"."+l_cTableName

    endcase

    l_hCurrentTableDefinition := hb_HGetDef(::p_hMetadataTable,l_cNamespaceAndTableName,NIL)

    l_hFields   := l_hTableDefinition[HB_ORM_SCHEMA_FIELD]
    l_hIndexes  := hb_HGetDef(l_hTableDefinition,HB_ORM_SCHEMA_INDEX,NIL)
    l_lUnlogged := hb_HGetDef(l_hTableDefinition,"Unlogged",.f.)

    if hb_IsNIL(l_hCurrentTableDefinition)

        // Table does not exist in the current catalog
        hb_orm_SendToDebugView("Add Table: "+l_cNamespaceAndTableName)
        l_cSQLScript += ::GMSSAddTable(l_cNamespaceName,l_cTableName,l_hFields,l_lUnlogged)
        
        // Add all the indexes
        if !hb_IsNIL(l_hIndexes)
            for each l_hIndex in l_hIndexes
                l_cIndexName       := lower(l_hIndex:__enumKey())
                l_hIndexDefinition := l_hIndex:__enumValue()
                
                if !(lower(l_hIndexDefinition[HB_ORM_SCHEMA_INDEX_EXPRESSION]) == lower(::p_PrimaryKeyFieldName))   // Don't Create and index, since PRIMARY will already do so. This should not happen since no loaded in p_hMetadataTable to start with. But this method accepts any p_hMetadataTable hash arrays.
                    l_cSQLScript += ::GMSSAddIndex(l_cNamespaceName,l_cTableName,l_hFields,l_cIndexName,l_hIndexDefinition)  //Passing l_hFields to help with index expressions
                endif
                
            endfor
        endif

    else
        // Found the table in the current ::p_hMetadataTable, now lets test all the fields are also there and matching
        // Test Every Fields to see if structure must be updated.
        l_cCurrentNamespaceAndTableName := hb_HKeyAt(::p_hMetadataTable,hb_HPos(::p_hMetadataTable,l_cNamespaceAndTableName))

        l_lCurrentUnlogged              := hb_HGetDef(::p_hMetadataTable[l_cNamespaceAndTableName],"Unlogged",.f.)

        if !(l_cCurrentNamespaceAndTableName == l_cNamespaceAndTableName)

            //Case Mismatch. Could be the NamespaceName and/or TableName
            do case
            case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
                //Ignore casing issues, since in MySQL engine everything will be used as lower case.
                // This will also resolve the issue of:  SQLExec Error Code: 2014 - Error description: HY000 [ma-3.1.19][10.11.6-MariaDB]Commands out of sync; you can't run this command now

                // l_cCurrentNamespaceName := ""
                // l_cCurrentTableName  := l_cCurrentNamespaceAndTableName

                // if !(l_cCurrentTableName == l_cTableName)
                //     l_cSQLScriptPreUpdate += ::GMSSUpdateTableName(l_cNamespaceName,l_cTableName,l_cCurrentNamespaceName,l_cCurrentTableName)
                // endif

            case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
                l_nPos := at(".",l_cCurrentNamespaceAndTableName)
                l_cCurrentNamespaceName := left(l_cCurrentNamespaceAndTableName,l_nPos-1)
                l_cCurrentTableName     := substr(l_cCurrentNamespaceAndTableName,l_nPos+1)

                if !(l_cCurrentTableName == l_cTableName)
                    l_cSQLScriptPreUpdate += ::GMSSUpdateTableName(l_cNamespaceName,l_cTableName,l_cCurrentNamespaceName,l_cCurrentTableName)
                endif

            endcase
        endif

        if ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
            if l_lCurrentUnlogged <> l_lUnlogged
                //Need to Set or Remove the UNLOGGED table attribute.
                if l_lUnlogged
                    l_cSQLScriptPreUpdate += [ALTER TABLE ]+::FormatIdentifier(l_cNamespaceAndTableName)+[ SET UNLOGGED;]
                else
                    l_cSQLScriptPreUpdate += [ALTER TABLE ]+::FormatIdentifier(l_cNamespaceAndTableName)+[ SET LOGGED;]
                endif
            endif
        endif

        l_cSQLScriptFieldChangesCycle1 := ""
        l_cSQLScriptFieldChangesCycle2 := ""

        for each l_hField in l_hFields
            l_cFieldName       := l_hField:__enumKey()
            l_hFieldDefinition := l_hField:__enumValue()

            l_cFieldType                 := iif(l_hFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE] == "T","DT",l_hFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE])
            l_cFieldTypeEnumName         := hb_HGetDef(l_hFieldDefinition,HB_ORM_SCHEMA_FIELD_ENUMNAME,"")
            l_nFieldLen                  := hb_HGetDef(l_hFieldDefinition,HB_ORM_SCHEMA_FIELD_LENGTH,0)
            l_nFieldDec                  := hb_HGetDef(l_hFieldDefinition,HB_ORM_SCHEMA_FIELD_DECIMALS,0)
            l_cFieldDefault              := hb_HGetDef(l_hFieldDefinition,HB_ORM_SCHEMA_FIELD_DEFAULT,"")
            l_lFieldNullable             := hb_HGetDef(l_hFieldDefinition,HB_ORM_SCHEMA_FIELD_NULLABLE,.f.)
            l_lFieldAutoIncrement        := hb_HGetDef(l_hFieldDefinition,HB_ORM_SCHEMA_FIELD_AUTOINCREMENT,.f.)
            l_lFieldArray                := hb_HGetDef(l_hFieldDefinition,HB_ORM_SCHEMA_FIELD_ARRAY,.f.)

            if lower(l_cFieldName) == lower(::p_PrimaryKeyFieldName)
                l_lFieldAutoIncrement := .t.
            endif
            if l_lFieldAutoIncrement .and. empty(el_InlistPos(l_cFieldType,"I","IB","IS"))  //Only those fields types may be flagged as Auto-Increment
                l_lFieldAutoIncrement := .f.
            endif
            if l_lFieldAutoIncrement .and. l_lFieldNullable  //Auto-Increment fields may not be null (and not have a default)
                l_lFieldNullable := .f.
            endif

            l_hCurrentFieldDefinition := hb_HGetDef(::p_hMetadataTable[l_cNamespaceAndTableName][HB_ORM_SCHEMA_FIELD],l_cFieldName,NIL)
            if hb_IsNIL(l_hCurrentFieldDefinition)
                //Missing Field
                hb_orm_SendToDebugView("Table: "+l_cNamespaceAndTableName+" Add Field: "+l_cFieldName)

                l_cSQLScriptFieldChanges := ::GMSSAddField(l_cNamespaceName,;
                                                           l_cTableName,;
                                                           l_cFieldName,;
                                                           {HB_ORM_SCHEMA_FIELD_TYPE=>l_cFieldType,;
                                                            HB_ORM_SCHEMA_FIELD_ENUMNAME=>l_cFieldTypeEnumName,;
                                                            HB_ORM_SCHEMA_FIELD_LENGTH=>l_nFieldLen,;
                                                            HB_ORM_SCHEMA_FIELD_DECIMALS=>l_nFieldDec,;
                                                            HB_ORM_SCHEMA_FIELD_DEFAULT=>l_cFieldDefault,;
                                                            HB_ORM_SCHEMA_FIELD_NULLABLE=>l_lFieldNullable,;
                                                            HB_ORM_SCHEMA_FIELD_AUTOINCREMENT=>l_lFieldAutoIncrement,;
                                                            HB_ORM_SCHEMA_FIELD_ARRAY=>l_lFieldArray})
                l_cSQLScriptPreUpdate          += l_cSQLScriptFieldChanges[1]  // Allways blank for now MYSQL+POSTGRESQL
                l_cSQLScriptFieldChangesCycle1 += l_cSQLScriptFieldChanges[2]
                l_cSQLScriptFieldChangesCycle2 += l_cSQLScriptFieldChanges[3]  // Allways blank for now MYSQL+POSTGRESQL
                l_cSQLScriptPostUpdate         += l_cSQLScriptFieldChanges[4]

            else
                //Compare the field definition using arrays l_hCurrentFieldDefinition and l_hFieldDefinition

                //Test if the field Name Casing Changed
                l_cCurrentFieldName := hb_HKeyAt(::p_hMetadataTable[l_cNamespaceAndTableName][HB_ORM_SCHEMA_FIELD],hb_HPos(::p_hMetadataTable[l_cNamespaceAndTableName][HB_ORM_SCHEMA_FIELD],l_cFieldName))
                if !(l_cCurrentFieldName == l_cFieldName)
                    l_cSQLScriptPreUpdate += ::GMSSUpdateFieldName(l_cNamespaceName,l_cTableName,l_cFieldName,l_cCurrentFieldName)
                endif

                l_cCurrentFieldType          := iif(l_hCurrentFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE] == "T","DT",l_hCurrentFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE])
                l_cCurrentFieldTypeEnumName  := hb_HGetDef(l_hCurrentFieldDefinition,HB_ORM_SCHEMA_FIELD_ENUMNAME,"")
                l_nCurrentFieldLen           := hb_HGetDef(l_hCurrentFieldDefinition,HB_ORM_SCHEMA_FIELD_LENGTH,0)
                l_nCurrentFieldDec           := hb_HGetDef(l_hCurrentFieldDefinition,HB_ORM_SCHEMA_FIELD_DECIMALS,0)
                l_cCurrentFieldDefault       := hb_HGetDef(l_hCurrentFieldDefinition,HB_ORM_SCHEMA_FIELD_DEFAULT,"")
                l_lCurrentFieldNullable      := hb_HGetDef(l_hCurrentFieldDefinition,HB_ORM_SCHEMA_FIELD_NULLABLE,.f.)
                l_lCurrentFieldAutoIncrement := hb_HGetDef(l_hCurrentFieldDefinition,HB_ORM_SCHEMA_FIELD_AUTOINCREMENT,.f.)
                l_lCurrentFieldArray         := hb_HGetDef(l_hCurrentFieldDefinition,HB_ORM_SCHEMA_FIELD_ARRAY,.f.)

                if l_lCurrentFieldAutoIncrement .and. empty(el_InlistPos(l_cCurrentFieldType,"I","IB","IS"))  //Only those fields types may be flagged as Auto-Increment
                    l_lCurrentFieldAutoIncrement := .f.
                endif
                if l_lCurrentFieldAutoIncrement .and. l_lCurrentFieldNullable  //Auto-Increment fields may not be null (and not have a default)
                    l_lCurrentFieldNullable := .f.
                endif

                l_cFieldDefault := ::NormalizeFieldDefaultForCurrentEngineType(l_cFieldDefault,l_cFieldType,l_nFieldDec)
                l_cFieldDefault := nvl(::SanitizeFieldDefaultFromDefaultBehavior(::p_SQLEngineType,l_cFieldType,l_lFieldNullable,l_cFieldDefault),"")

                l_lMatchingFieldDefinition := .t.
                l_cMismatchType := ""
                do case
                case !(l_cFieldType == l_cCurrentFieldType)   // Field Type is always defined.  !(==) is a method to deal with SET EXACT being OFF by default.
                    l_lMatchingFieldDefinition := .f.
                    l_cMismatchType := "Field Type"
                case l_lFieldArray != l_lCurrentFieldArray
                    l_lMatchingFieldDefinition := .f.
                    l_cMismatchType := "Field Array"
                case l_cFieldType == "E" .and. !(l_cFieldTypeEnumName == l_cCurrentFieldTypeEnumName)
                    l_lMatchingFieldDefinition := .f.  // The problem is that in Postgres, it is not allowed to change enumeration type.
                    l_cMismatchType := "Field Enumeration Type"
                case el_IsInlist(l_cFieldType,"I","IB","IS","M","R","L","D","Y","UUI","JS","JSB","OID","E")  //Field type with no length
                case empty(el_InlistPos(l_cFieldType,"TOZ","TO","DTZ","DT")) .and. l_nFieldLen <> l_nCurrentFieldLen   //Ignore Length matching for datetime and time fields
                    l_lMatchingFieldDefinition := .f.
                    l_cMismatchType := "Field Length"
                case el_IsInlist(l_cFieldType,"C","CV","B","BV")  //Field type with a length but no decimal
                case l_nFieldDec  <> l_nCurrentFieldDec
                    l_lMatchingFieldDefinition := .f.
                    l_cMismatchType := "Field Decimal"
                endcase

                if l_lMatchingFieldDefinition  // Should still test on nullable and incremental
                    if l_lFieldAutoIncrement .and. l_cFieldDefault == "Wharf-AutoIncrement()"
                        l_cFieldDefault := ""
                    endif

                    do case
                    case !(l_lFieldNullable == l_lCurrentFieldNullable)
                        l_lMatchingFieldDefinition := .f.
                        l_cMismatchType := "Field Nullable"
                    case !(l_lFieldAutoIncrement == l_lCurrentFieldAutoIncrement)
                        l_lMatchingFieldDefinition := .f.
                        l_cMismatchType := "Field Auto Increment"
                    case !(l_lFieldArray == l_lCurrentFieldArray)
                        l_lMatchingFieldDefinition := .f.
                        l_cMismatchType := "Field Array"
                    case !(l_cFieldDefault == l_cCurrentFieldDefault)
                        l_lMatchingFieldDefinition := .f.
                        l_cMismatchType := "Field Default Value"
                    endcase
                endif

                if !l_lMatchingFieldDefinition
                    hb_orm_SendToDebugView("Table: "+l_cNamespaceAndTableName+" Field: "+l_cFieldName+"  Mismatch: "+l_cMismatchType)
                    l_cSQLScriptFieldChanges := ::GMSSUpdateField(l_cNamespaceName,;
                                                              l_cTableName,;
                                                              l_cFieldName,;
                                                            {HB_ORM_SCHEMA_FIELD_TYPE          => l_cFieldType,;
                                                             HB_ORM_SCHEMA_FIELD_ENUMNAME      => l_cFieldTypeEnumName,;
                                                             HB_ORM_SCHEMA_FIELD_LENGTH        => l_nFieldLen,;
                                                             HB_ORM_SCHEMA_FIELD_DECIMALS      => l_nFieldDec,;
                                                             HB_ORM_SCHEMA_FIELD_NULLABLE      => l_lFieldNullable,;
                                                             HB_ORM_SCHEMA_FIELD_AUTOINCREMENT => l_lFieldAutoIncrement,;
                                                             HB_ORM_SCHEMA_FIELD_ARRAY         => l_lFieldArray,;
                                                             HB_ORM_SCHEMA_FIELD_DEFAULT       => l_cFieldDefault},;
                                                            {HB_ORM_SCHEMA_FIELD_TYPE          => l_cCurrentFieldType,;
                                                             HB_ORM_SCHEMA_FIELD_ENUMNAME      => l_cCurrentFieldTypeEnumName,;
                                                             HB_ORM_SCHEMA_FIELD_LENGTH        => l_nCurrentFieldLen,;
                                                             HB_ORM_SCHEMA_FIELD_DECIMALS      => l_nCurrentFieldDec,;
                                                             HB_ORM_SCHEMA_FIELD_NULLABLE      => l_lCurrentFieldNullable,;
                                                             HB_ORM_SCHEMA_FIELD_AUTOINCREMENT => l_lCurrentFieldAutoIncrement,;
                                                             HB_ORM_SCHEMA_FIELD_ARRAY         => l_lCurrentFieldArray,;
                                                             HB_ORM_SCHEMA_FIELD_DEFAULT       => l_cCurrentFieldDefault})
                    l_cSQLScriptPreUpdate          += l_cSQLScriptFieldChanges[1]
                    l_cSQLScriptFieldChangesCycle1 += l_cSQLScriptFieldChanges[2]
                    l_cSQLScriptFieldChangesCycle2 += l_cSQLScriptFieldChanges[3]
                    l_cSQLScriptPostUpdate         += l_cSQLScriptFieldChanges[4]
                endif

            endif

        endfor

        if !empty(l_cSQLScriptFieldChangesCycle1) .or. !empty(l_cSQLScriptFieldChangesCycle2)
            // do case
            // case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
            //     l_cFormattedTableName := ::FormatIdentifier(l_cTableName)
            // case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
            //     l_cFormattedTableName := ::FormatIdentifier(l_cNamespaceAndTableName)
            // endcase
            l_cFormattedTableName := ::FormatIdentifier(::NormalizeTableNamePhysical(l_cNamespaceAndTableName))

            if !empty(l_cSQLScriptFieldChangesCycle1)
                l_cSQLScript += [ALTER TABLE ]+l_cFormattedTableName+[ ]+substr(l_cSQLScriptFieldChangesCycle1,2)+[;]+CRLF   //Drop the leading "," in l_cSQLScriptFieldChangesCycle1
            endif
            if !empty(l_cSQLScriptFieldChangesCycle2)
                l_cSQLScript += [ALTER TABLE ]+l_cFormattedTableName+[ ]+substr(l_cSQLScriptFieldChangesCycle2,2)+[;]+CRLF   //Drop the leading "," in l_cSQLScriptFieldChangesCycle2
            endif
        endif

        //Clone the list of existing indexes, so to search them and remove the ones we don't have defined afterwards
        l_hExistingIndexesOfExistingTable := hb_HClone(nvl(hb_HGetDef(::p_hMetadataTable[l_cNamespaceAndTableName],HB_ORM_SCHEMA_INDEX,{=>}),{=>}))

        if !hb_IsNIL(l_hIndexes)
            for each l_hIndex in l_hIndexes
                l_cIndexName       := hb_orm_RootIndexName(l_cTableName,l_hIndex:__enumKey())
                l_hIndexDefinition := l_hIndex:__enumValue()
                if !(lower(l_hIndexDefinition[HB_ORM_SCHEMA_INDEX_EXPRESSION]) == lower(::p_PrimaryKeyFieldName))   // Don't Create and index, since PRIMARY will already do so.

                    if empty(l_hExistingIndexesOfExistingTable)
                        l_hCurrentIndexDefinition := NIL
                    else
                        l_hCurrentIndexDefinition := hb_HGetDef(l_hExistingIndexesOfExistingTable,l_cIndexName,NIL)
                    endif
                    
                    if hb_IsNIL(l_hCurrentIndexDefinition)
                        //Missing Index
                        hb_orm_SendToDebugView("Table: "+l_cNamespaceAndTableName+" Add Index: "+l_cIndexName)
                        l_cSQLScript += ::GMSSAddIndex(l_cNamespaceName,l_cTableName,l_hFields,l_cIndexName,l_hIndexDefinition)  //Passing l_hFields to help with index expressions
                    else
                        // _M_ Compare the index definition
                        //Remove the index entry in the list of Exist indexes, so not be removed later on
                        hb_HDel(l_hExistingIndexesOfExistingTable,l_cIndexName)
                    endif

                endif

            endfor
        endif

        //Delete non define hb_orm indexes existing in table. LoadMetadata() method only loaded indexes maintained by hb_orm (ending with "_idx")
        for each l_hIndex in l_hExistingIndexesOfExistingTable
            l_cIndexName := l_hIndex:__enumKey()     // the hash key is already the hb_orm_RootIndexName of the physical index name.
            l_cNamespaceNameExistingCasing := hb_hGetDef(::p_hMetadataNamespace,l_cNamespaceName,"")
            if !empty(l_cNamespaceNameExistingCasing)
                // l_cIndexName := hb_orm_RootIndexName(l_cTableName,l_cIndexName)
                l_cSQLScript += ::GMSSDeleteIndex(l_cNamespaceNameExistingCasing,l_cTableName,l_cIndexName)+CRLF
                // l_cSQLScript := [DROP INDEX IF EXISTS ]+::FormatIdentifier(l_cNamespaceNameExistingCasing+"."+lower(l_cIndexName)+"_idx")+[ CASCADE;]
            endif
        endfor

    endif
endfor

//Prepare result script and also add any Foreign Key Constraints.
if !empty(l_cSQLScript) .or. ;
   !empty(l_cSQLScriptPreUpdate) .or. ;
   !empty(l_cSQLScriptPostUpdate)

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
    endcase
endif

if !empty(l_cSQLScript)
    l_cSQLScript := "--Structure Changes generated at "+strtran(hb_TSToStr(hb_TSToUTC(hb_DateTime()))," ","T")+"Z"+["]+CRLF+l_cSQLScript
endif

l_cSQLScriptForeignKeyConstraints := ::GenerateMigrateForeignKeyConstraintsScript( nvl(hb_hGetDef(par_hWharfConfig,"Tables",{=>}),{=>}) ,;
                                                                                   .t.,;
                                                                                   l_hAppliedRenameNamespace,;
                                                                                   l_hAppliedRenameTable,;
                                                                                   l_hAppliedRenameColumn)
if !empty(l_cSQLScriptForeignKeyConstraints)
    if !empty(l_cSQLScript)
        l_cSQLScript += CRLF
    endif
    l_cSQLScript += l_cSQLScriptForeignKeyConstraints
endif

return l_cSQLScript
//-----------------------------------------------------------------------------------------------------------------
method MigrateSchema(par_hWharfConfig) class hb_orm_SQLConnect
local l_cSQLScript
local l_nResult := 0   // 0 = Nothing Migrated, 1 = Migrated, -1 = Error Migrating
local l_cLastError := ""
local l_aInstructions
local l_cStatement
local l_nCounter := 0

l_cSQLScript := ::GenerateMigrateSchemaScript(par_hWharfConfig)
if !empty(l_cSQLScript)
    l_nResult := 1
    l_aInstructions := hb_ATokens(l_cSQLScript,.t.)
    for each l_cStatement in l_aInstructions
        if !empty(l_cStatement)
            l_nCounter++
            if ::SQLExec("MigrateSchema",l_cStatement)
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
    ::LoadMetadata("MigrateSchema")
endif

::UpdateORMNamespaceTableNumber()  // Will call this routine even if no tables where modified.

return {l_nResult,l_cSQLScript,l_cLastError}
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
method GMSSAddTable(par_cNamespaceName,par_cTableName,par_hStructure,par_lUnlogged) class hb_orm_SQLConnect                 // Fix if needed a single file structure. GMSS (Generate Migrate Schema Script).
local l_aField
local l_cFieldName
local l_hFieldDefinition
local l_cSQLCommand := ""
local l_cSQLFields := ""
local l_cFieldType
local l_cFieldTypeEnumName
local l_nFieldDec
local l_nFieldLen
local l_lFieldNullable
local l_lFieldAutoIncrement
local l_lFieldArray
local l_cFieldDefault
local l_cDefaultString := ""
local l_cSQLExtra := ""
local l_cFormattedTableName
local l_cFormattedFieldName
local l_cAdditionalSQLCommand :=""
local l_cFieldTypeSuffix

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cFormattedTableName := ::FormatIdentifier(iif(empty(par_cNamespaceName) .or. lower(par_cNamespaceName) == "public","",par_cNamespaceName+".")+par_cTableName)
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cFormattedTableName := ::FormatIdentifier(par_cNamespaceName+"."+par_cTableName)
endcase

for each l_aField in par_hStructure
    l_cFieldName       := l_aField:__enumKey()
    l_hFieldDefinition := l_aField:__enumValue()

    l_cFieldType          := l_hFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE]
    l_cFieldTypeEnumName  := hb_HGetDef(l_hFieldDefinition,HB_ORM_SCHEMA_FIELD_ENUMNAME,"")
    l_nFieldLen           := hb_HGetDef(l_hFieldDefinition,HB_ORM_SCHEMA_FIELD_LENGTH,0)
    l_nFieldDec           := hb_HGetDef(l_hFieldDefinition,HB_ORM_SCHEMA_FIELD_DECIMALS,0)
    l_cFieldDefault       := hb_HGetDef(l_hFieldDefinition,HB_ORM_SCHEMA_FIELD_DEFAULT,"")
    l_lFieldNullable      := hb_HGetDef(l_hFieldDefinition,HB_ORM_SCHEMA_FIELD_NULLABLE,.f.)
    l_lFieldAutoIncrement := hb_HGetDef(l_hFieldDefinition,HB_ORM_SCHEMA_FIELD_AUTOINCREMENT,.f.)
    l_lFieldArray         := hb_HGetDef(l_hFieldDefinition,HB_ORM_SCHEMA_FIELD_ARRAY,.f.)

    if lower(l_cFieldName) == lower(::p_PrimaryKeyFieldName)
        l_lFieldAutoIncrement := .t.
    endif
    if l_lFieldAutoIncrement .and. empty(el_InlistPos(l_cFieldType,"I","IB","IS"))  //Only those fields types may be flagged as Auto-Increment
        l_lFieldAutoIncrement := .f.
    endif
    if l_lFieldAutoIncrement .and. l_lFieldNullable  //Auto-Increment fields may not be null (and not have a default)
        l_lFieldNullable := .f.
    endif

    l_cFieldDefault := ::NormalizeFieldDefaultForCurrentEngineType(l_cFieldDefault,l_cFieldType,l_nFieldDec)

    if l_lFieldAutoIncrement .and. l_cFieldDefault == "Wharf-AutoIncrement()"
        l_cFieldDefault := ""
    endif

    if !empty(l_cSQLFields)
        l_cSQLFields += ","
    endif

    l_cFormattedFieldName := ::FormatIdentifier(l_cFieldName)
    l_cSQLFields += l_cFormattedFieldName + [ ]

    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        do case
        case el_IsInlist(l_cFieldType,"I","IB","IS","N")
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
                l_cDefaultString := ""
            else
                l_cDefaultString := "0"
            endif

        case el_IsInlist(l_cFieldType,"C","CV","B","BV","M","R")
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
            
        case el_IsInlist(l_cFieldType,"D","TOZ","TO","DTZ","T","DT")
            do case
            case l_cFieldType == "D"
                l_cSQLFields += [DATE]
                l_cDefaultString   := ['0000-00-00']
            case l_cFieldType == "TOZ"
                if el_between(l_nFieldDec,0,6)
                    l_cSQLFields += [TIME(]+trans(l_nFieldDec)+[) COMMENT 'Type=TOZ']
                else
                    l_cSQLFields += [TIME COMMENT 'Type=TOZ']
                endif
                l_cDefaultString   := ['00:00:00']
            case l_cFieldType == "TO"
                if el_between(l_nFieldDec,0,6)
                    l_cSQLFields += [TIME(]+trans(l_nFieldDec)+[)]
                else
                    l_cSQLFields += [TIME]
                endif
                l_cDefaultString   := ['00:00:00']
            case l_cFieldType == "DTZ"
                if el_between(l_nFieldDec,0,6)
                    l_cSQLFields += [TIMESTAMP(]+trans(l_nFieldDec)+[)]
                else
                    l_cSQLFields += [TIMESTAMP]
                endif
                l_cDefaultString   := ['0000-00-00 00:00:00']
            case l_cFieldType == "DT" .or. l_cFieldType == "T"
                if el_between(l_nFieldDec,0,6)
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

        case l_cFieldType == "JSB"
            l_cSQLFields += [LONGTEXT COMMENT 'Type=JSB']
            l_cDefaultString := "'{}'"
            
        case l_cFieldType == "JS"
            l_cSQLFields += [LONGTEXT COMMENT 'Type=JS']
            l_cDefaultString := "'{}'"
            
        case l_cFieldType == "OID"
            l_cSQLFields += [BIGINT COMMENT 'Type=OID']
            l_cDefaultString := "0"

        otherwise
            
        endcase

        if !empty(l_cDefaultString)
            if l_lFieldNullable
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
        case el_IsInlist(l_cFieldType,"I","IB","IS","N")
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
                l_cDefaultString := ""
            else
                l_cDefaultString := "0"
            endif


        case el_IsInlist(l_cFieldType,"C","CV","B","BV","M","R")
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
            
        case el_IsInlist(l_cFieldType,"D","TOZ","TO","DTZ","T","DT")
            do case
            case l_cFieldType == "D"
                l_cSQLFields += [date]+l_cFieldTypeSuffix
            case l_cFieldType == "TOZ"
                if el_between(l_nFieldDec,0,6)
                    l_cSQLFields += [time(]+trans(l_nFieldDec)+[) with time zone]+l_cFieldTypeSuffix
                else
                    l_cSQLFields += [time with time zone]+l_cFieldTypeSuffix
                endif
            case l_cFieldType == "TO"
                if el_between(l_nFieldDec,0,6)
                    l_cSQLFields += [time(]+trans(l_nFieldDec)+[) without time zone]+l_cFieldTypeSuffix
                else
                    l_cSQLFields += [time without time zone]+l_cFieldTypeSuffix
                endif
            case l_cFieldType == "DTZ"
                if el_between(l_nFieldDec,0,6)
                    l_cSQLFields += [timestamp(]+trans(l_nFieldDec)+[) with time zone]+l_cFieldTypeSuffix
                else
                    l_cSQLFields += [timestamp with time zone]+l_cFieldTypeSuffix
                endif
            case l_cFieldType == "DT" .or. l_cFieldType == "T"
                if el_between(l_nFieldDec,0,6)
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

        case l_cFieldType == "JSB"
            l_cSQLFields += [jsonb]+l_cFieldTypeSuffix

            l_cDefaultString := "'{}'::jsonb"
            
        case l_cFieldType == "JS"
            l_cSQLFields += [json]+l_cFieldTypeSuffix

            l_cDefaultString := "'{}'::json"
            
        case l_cFieldType == "OID"
            l_cSQLFields += [oid]+l_cFieldTypeSuffix

            l_cDefaultString := ""
            
        case l_cFieldType == "E"
            if empty(l_cFieldTypeEnumName)
                //_M_
            else
                l_cSQLFields += ["]+par_cNamespaceName+["."]+l_cFieldTypeEnumName+["]+l_cFieldTypeSuffix
                l_cDefaultString := "''"
            endif

        otherwise
            
        endcase

        if !empty(l_cDefaultString)
            if l_lFieldNullable
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

endfor

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cSQLCommand := [CREATE TABLE ]+l_cFormattedTableName+[ (] + l_cSQLFields + l_cSQLExtra
    l_cSQLCommand += [) ENGINE=InnoDB COLLATE='utf8_general_ci';]+CRLF

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cSQLCommand := [CREATE]+iif(par_lUnlogged,[ UNLOGGED],[])+[ TABLE ]+l_cFormattedTableName+[ (] + l_cSQLFields
    l_cSQLCommand += [);]+CRLF

endcase

return l_cSQLCommand+l_cAdditionalSQLCommand
//-----------------------------------------------------------------------------------------------------------------
method GMSSUpdateNamespaceName(par_cNamespaceName,par_cCurrentNamespaceName) class hb_orm_SQLConnect  // GMSS (Generate Migrate Schema Script).
local l_cSQLCommand := ""

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    // Schemas don't exists in MySQL Engine. If a namespace name changed, the UpdateTableName will be impacted instead.

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cSQLCommand += [ALTER SCHEMA ]+::FormatIdentifier(par_cCurrentNamespaceName)+[ RENAME TO ]+::FormatIdentifier(par_cNamespaceName)+[;]

endcase

return l_cSQLCommand
//-----------------------------------------------------------------------------------------------------------------
method GMSSUpdateTableName(par_cNamespaceName,par_cTableName,par_cCurrentNamespaceName,par_cCurrentTableName) class hb_orm_SQLConnect   // GMSS (Generate Migrate Schema Script).
// Due to a bug in MySQL engine of the "ALTER TABLE" command cannot mix "CHANGE COLUMN" and "ALTER COLUMN" options. Therefore separating those in 2 Cycles
local l_cSQLCommand := ""
local l_cTableNameFrom
local l_cTableNameTo

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    if empty(par_cCurrentNamespaceName)
        l_cTableNameFrom := par_cCurrentTableName
    else
        l_cTableNameFrom := par_cCurrentNamespaceName+"."+par_cCurrentTableName
    endif

    if empty(par_cNamespaceName)
        l_cTableNameTo   := par_cTableName
    else
        l_cTableNameTo   := par_cNamespaceName+"."+par_cTableName
    endif

    l_cSQLCommand += [ALTER TABLE ]+::FormatIdentifier(l_cTableNameFrom)+[ RENAME TO ]+::FormatIdentifier(l_cTableNameTo)+[;]

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cTableNameFrom := par_cNamespaceName+"."+par_cCurrentTableName   // In Postgresql the Namespace name would have already be renamed if needed.
    l_cTableNameTo   := par_cTableName
    l_cSQLCommand += [ALTER TABLE ]+::FormatIdentifier(l_cTableNameFrom)+[ RENAME TO ]+::FormatIdentifier(l_cTableNameTo)+[;]

endcase

return l_cSQLCommand
//-----------------------------------------------------------------------------------------------------------------
method GMSSUpdateFieldName(par_cNamespaceName,par_cTableName,par_cFieldName,par_cCurrentFieldName) class hb_orm_SQLConnect   // GMSS (Generate Migrate Schema Script).
// Due to a bug in MySQL engine of the "ALTER TABLE" command cannot mix "CHANGE COLUMN" and "ALTER COLUMN" options. Therefore separating those in 2 Cycles
local l_cSQLCommand := ""

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    //_M_
    // l_cFormattedTableName := ::FormatIdentifier(par_cTableName)
    if empty(par_cNamespaceName)
        l_cSQLCommand += [ALTER TABLE ]+::FormatIdentifier(par_cTableName)+[ RENAME COLUMN ]+::FormatIdentifier(par_cCurrentFieldName)+[ TO ]+::FormatIdentifier(par_cFieldName)+[;]
    else
        l_cSQLCommand += [ALTER TABLE ]+::FormatIdentifier(par_cNamespaceName+"."+par_cTableName)+[ RENAME COLUMN ]+::FormatIdentifier(par_cCurrentFieldName)+[ TO ]+::FormatIdentifier(par_cFieldName)+[;]
    endif

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    //ALTER TABLE table_name RENAME COLUMN column_name TO new_column_name;
    l_cSQLCommand += [ALTER TABLE ]+::FormatIdentifier(par_cNamespaceName+"."+par_cTableName)+[ RENAME COLUMN ]+::FormatIdentifier(par_cCurrentFieldName)+[ TO ]+::FormatIdentifier(par_cFieldName)+[;]

endcase

return l_cSQLCommand
//-----------------------------------------------------------------------------------------------------------------
method GMSSUpdateField(par_cNamespaceName,par_cTableName,par_cFieldName,par_hFieldDefinition,par_hCurrentFieldDefinition) class hb_orm_SQLConnect   // GMSS (Generate Migrate Schema Script).
// Due to a bug in MySQL engine of the "ALTER TABLE" command cannot mix "CHANGE COLUMN" and "ALTER COLUMN" options. Therefore separating those in 2 Cycles
local l_cSQLCommandPreUpdate := ""
local l_cSQLCommandCycle1    := ""
local l_cSQLCommandCycle2    := ""
local l_cFieldType,       l_cFieldTypeEnumName,       l_nFieldLen,       l_nFieldDec,       l_lFieldNullable,       l_lFieldAutoIncrement,       l_lFieldArray       ,l_cFieldDefault
local l_cCurrentFieldType,l_cCurrentFieldTypeEnumName,                   l_nCurrentFieldDec,l_lCurrentFieldNullable,l_lCurrentFieldAutoIncrement                     ,l_cCurrentFieldDefault
local l_cFormattedFieldName := ::FormatIdentifier(par_cFieldName)
local l_cFormattedTableName
local l_cAdditionalSQLCommands := ""
local l_cFieldTypeSuffix
local l_cDefaultString := ""

l_cFieldType                 := par_hFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE]
l_cFieldTypeEnumName         := hb_HGetDef(par_hFieldDefinition,HB_ORM_SCHEMA_FIELD_ENUMNAME,"")
l_nFieldLen                  := hb_HGetDef(par_hFieldDefinition,HB_ORM_SCHEMA_FIELD_LENGTH,0)
l_nFieldDec                  := hb_HGetDef(par_hFieldDefinition,HB_ORM_SCHEMA_FIELD_DECIMALS,0)
l_cFieldDefault              := hb_HGetDef(par_hFieldDefinition,HB_ORM_SCHEMA_FIELD_DEFAULT,"")
l_lFieldNullable             := hb_HGetDef(par_hFieldDefinition,HB_ORM_SCHEMA_FIELD_NULLABLE,.f.)
l_lFieldAutoIncrement        := hb_HGetDef(par_hFieldDefinition,HB_ORM_SCHEMA_FIELD_AUTOINCREMENT,.f.)
l_lFieldArray                := hb_HGetDef(par_hFieldDefinition,HB_ORM_SCHEMA_FIELD_ARRAY,.f.)

l_cCurrentFieldType          := par_hCurrentFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE]
l_cCurrentFieldTypeEnumName  := hb_HGetDef(par_hCurrentFieldDefinition,HB_ORM_SCHEMA_FIELD_ENUMNAME,"")
l_nCurrentFieldDec           := hb_HGetDef(par_hCurrentFieldDefinition,HB_ORM_SCHEMA_FIELD_DECIMALS,0)
l_cCurrentFieldDefault       := hb_HGetDef(par_hCurrentFieldDefinition,HB_ORM_SCHEMA_FIELD_DEFAULT,"")
l_lCurrentFieldNullable      := hb_HGetDef(par_hCurrentFieldDefinition,HB_ORM_SCHEMA_FIELD_NULLABLE,.f.)
l_lCurrentFieldAutoIncrement := hb_HGetDef(par_hCurrentFieldDefinition,HB_ORM_SCHEMA_FIELD_AUTOINCREMENT,.f.)

l_cFieldDefault        := ::NormalizeFieldDefaultForCurrentEngineType(l_cFieldDefault       ,l_cFieldType       ,l_nFieldDec)
l_cCurrentFieldDefault := ::NormalizeFieldDefaultForCurrentEngineType(l_cCurrentFieldDefault,l_cCurrentFieldType,l_nCurrentFieldDec)

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    // l_cFormattedTableName := ::FormatIdentifier(par_cTableName)
    l_cFormattedTableName := ::FormatIdentifier(iif(empty(par_cNamespaceName) .or. lower(par_cNamespaceName) == "public","",par_cNamespaceName+".")+par_cTableName)

    // MySQL has issues of DROP DEFAULT before a field is set to allow NULL
    l_cSQLCommandCycle2 += [,CHANGE COLUMN ]+l_cFormattedFieldName+[ ]+l_cFormattedFieldName+[ ]

    do case
    case el_IsInlist(l_cFieldType,"I","IB","IS","N")
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
             l_cDefaultString := ""

        else
            if l_lFieldNullable
            else
                //do not allow NULL
                l_cSQLCommandPreUpdate += [UPDATE ]+l_cFormattedTableName+[ SET ]+l_cFormattedFieldName+[ = 0  WHERE ]+l_cFormattedFieldName+[ IS NULL;]
            endif

            l_cDefaultString := "0"

        endif

    case el_IsInlist(l_cFieldType,"C","CV","B","BV","M","R")
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
        
    case el_IsInlist(l_cFieldType,"D","TOZ","TO","DTZ","T","DT")
        do case
        case l_cFieldType == "D"
            l_cSQLCommandCycle2 += [DATE]
            l_cDefaultString := ['0000-00-00']
        case l_cFieldType == "TOZ"
            if el_between(l_nFieldDec,0,6)
                l_cSQLCommandCycle2 += [TIME(]+trans(l_nFieldDec)+[) COMMENT 'Type=TOZ']
            else
                l_cSQLCommandCycle2 += [TIME COMMENT 'Type=TOZ']
            endif
            l_cDefaultString := ['00:00:00']
        case l_cFieldType == "TO"
            if el_between(l_nFieldDec,0,6)
                l_cSQLCommandCycle2 += [TIME(]+trans(l_nFieldDec)+[)]
            else
                l_cSQLCommandCycle2 += [TIME]
            endif
            l_cDefaultString := ['00:00:00']
        case l_cFieldType == "DTZ"
            if el_between(l_nFieldDec,0,6)
                l_cSQLCommandCycle2 += [TIMESTAMP(]+trans(l_nFieldDec)+[)]
            else
                l_cSQLCommandCycle2 += [TIMESTAMP]
            endif
            l_cDefaultString := ['0000-00-00 00:00:00']
        case l_cFieldType == "DT" .or. l_cFieldType == "T"
            if el_between(l_nFieldDec,0,6)
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

    case l_cFieldType == "JSB"
        l_cSQLCommandCycle2 += [LONGTEXT COMMENT 'Type=JSB']
        l_cDefaultString := "'{}'"

    case l_cFieldType == "JS"
        l_cSQLCommandCycle2 += [LONGTEXT COMMENT 'Type=JS']
        l_cDefaultString := "'{}'"

    case l_cFieldType == "OID"
        l_cSQLCommandCycle2 += [BIGINT COMMENT 'Type=OID']
        l_cDefaultString := "0"

    otherwise
    
    endcase
    
    if !empty(l_cDefaultString)
        if l_lFieldNullable
            l_cSQLCommandCycle2 += [ NULL]
            if empty(l_cFieldDefault)
                l_cSQLCommandCycle1 += [,ALTER COLUMN ]+l_cFormattedFieldName+[ DROP DEFAULT]
            else
                l_cSQLCommandCycle2 += [ DEFAULT ]+l_cFieldDefault
            endif
        else
            l_cSQLCommandCycle2 += [ NOT NULL]
            if empty(l_cFieldDefault) // .or. !(l_cFieldType == l_cCurrentFieldType)
                l_cSQLCommandCycle2 += [ DEFAULT ]+l_cDefaultString
            else
                l_cSQLCommandCycle2 += [ DEFAULT ]+l_cFieldDefault
            endif
        endif
    endif

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cFormattedTableName := ::FormatIdentifier(par_cNamespaceName+"."+par_cTableName)

    l_cSQLCommandCycle1 += [,ALTER COLUMN ]+l_cFormattedFieldName+[ ]

    l_cFieldTypeSuffix := iif(l_lFieldArray,"[]","")

    do case
    case el_IsInlist(l_cFieldType,"I","IB","IS","N")
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
                hb_orm_SendToDebugView("May not make numeric field auto-increment. Table: "+par_cNamespaceName+"."+par_cTableName+" - Field: "+par_cFieldName)
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

            if used("hb_orm_ListOfPrimaryKeyConstraints")
                if !el_seek(padr(upper(par_cNamespaceName+'*'+par_cTableName+'*'),240),"hb_orm_ListOfPrimaryKeyConstraints","tag1")
                    // It does not matter what the constraint name is.
                    l_cSQLCommandCycle1 += [,ADD CONSTRAINT ]+lower(par_cTableName)+[_pkey PRIMARY KEY (]+::FormatIdentifier(par_cFieldName)+[)]
                    l_cDefaultString := ""
                endif
            endif

        else
            do case
            case l_lFieldNullable = l_lCurrentFieldNullable
            case l_lFieldNullable
                // //Was NOT NULL
            otherwise    // Stop NULL
                l_cSQLCommandPreUpdate += [UPDATE ]+l_cFormattedTableName+[ SET ]+l_cFormattedFieldName+[ = 0  WHERE ]+l_cFormattedFieldName+[ IS NULL;]
            endcase

            l_cDefaultString := "0"

        endif

    case el_IsInlist(l_cFieldType,"C","CV","B","BV","M","R")
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

    case el_IsInlist(l_cFieldType,"D","TOZ","TO","DTZ","T","DT")
        do case
        case l_cFieldType == "D"
            l_cSQLCommandCycle1 += [TYPE date]+l_cFieldTypeSuffix
        case l_cFieldType == "TOZ"
            if el_between(l_nFieldDec,0,6)
                l_cSQLCommandCycle1 += [TYPE time(]+trans(l_nFieldDec)+[) with time zone]+l_cFieldTypeSuffix
            else
                l_cSQLCommandCycle1 += [TYPE time with time zone]+l_cFieldTypeSuffix
            endif
        case l_cFieldType == "TO"
            if el_between(l_nFieldDec,0,6)
                l_cSQLCommandCycle1 += [TYPE time(]+trans(l_nFieldDec)+[) without time zone]+l_cFieldTypeSuffix
            else
                l_cSQLCommandCycle1 += [TYPE time without time zone]+l_cFieldTypeSuffix
            endif
        case l_cFieldType == "DTZ"
            if el_between(l_nFieldDec,0,6)
                l_cSQLCommandCycle1 += [TYPE timestamp(]+trans(l_nFieldDec)+[) with time zone]+l_cFieldTypeSuffix
            else
                l_cSQLCommandCycle1 += [TYPE timestamp with time zone]+l_cFieldTypeSuffix
            endif
        case l_cFieldType == "DT" .or. l_cFieldType == "T"
            if el_between(l_nFieldDec,0,6)
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

    case l_cFieldType == "JSB"
        l_cSQLCommandCycle1 += [TYPE jsonb]+l_cFieldTypeSuffix
        l_cDefaultString := "'{}'::jsonb"

    case l_cFieldType == "JS"
        l_cSQLCommandCycle1 += [TYPE json]+l_cFieldTypeSuffix
        l_cDefaultString := "'{}'::json"

    case l_cFieldType == "OID"
        l_cSQLCommandCycle1 += [TYPE oid]+l_cFieldTypeSuffix
        l_cDefaultString := "0"

    case l_cFieldType == "E"
        l_cSQLCommandCycle1 += [TYPE ]+::FormatIdentifier(par_cNamespaceName)+[.]+::FormatIdentifier(l_cFieldTypeEnumName)+l_cFieldTypeSuffix
        l_cDefaultString := "''"

    otherwise
        
    endcase

    if !empty(l_cDefaultString)
        do case
        case !(l_cFieldType == l_cCurrentFieldType)   // Field Type changed
            if l_lFieldNullable
                if empty(l_cFieldDefault)
                    l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ DROP DEFAULT]
                else
                    l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ SET DEFAULT ]+l_cFieldDefault
                endif
                l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ DROP NOT NULL]
            else
                if empty(l_cFieldDefault)
                    l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ SET DEFAULT ]+l_cDefaultString
                else
                    l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ SET DEFAULT ]+l_cFieldDefault
                endif
                l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ SET NOT NULL]
            endif

        case l_lFieldNullable = l_lCurrentFieldNullable    //Nullability not changed.
            if !(l_cFieldDefault == l_cCurrentFieldDefault)
                if empty(l_cFieldDefault)
                    if l_lFieldNullable
                        l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ DROP DEFAULT]
                    else
                        l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ SET DEFAULT ]+l_cDefaultString
                    endif
                else
                    l_cSQLCommandCycle1 += [,ALTER COLUMN ] + l_cFormattedFieldName + [ SET DEFAULT ]+l_cFieldDefault
                endif
            endif

        case l_lFieldNullable
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
method GMSSAddField(par_cNamespaceName,par_cTableName,par_cFieldName,par_hFieldDefinition) class hb_orm_SQLConnect   // GMSS (Generate Migrate Schema Script).
local l_cSQLCommand := ""
local l_cAdditionalSQLCommands := ""
local l_cFieldType,l_cFieldTypeEnumName,l_lFieldArray,l_nFieldLen,l_nFieldDec,l_lFieldNullable,l_lFieldAutoIncrement,l_cFieldDefault
local l_cFieldTypeSuffix
local l_cFormattedTableName
local l_cFormattedFieldName := ::FormatIdentifier(par_cFieldName)
local l_cDefaultString := ""

l_cFieldType          := par_hFieldDefinition[HB_ORM_SCHEMA_FIELD_TYPE]
l_cFieldTypeEnumName  := hb_HGetDef(par_hFieldDefinition,HB_ORM_SCHEMA_FIELD_ENUMNAME,"")
l_nFieldLen           := hb_HGetDef(par_hFieldDefinition,HB_ORM_SCHEMA_FIELD_LENGTH,0)
l_nFieldDec           := hb_HGetDef(par_hFieldDefinition,HB_ORM_SCHEMA_FIELD_DECIMALS,0)
l_cFieldDefault       := hb_HGetDef(par_hFieldDefinition,HB_ORM_SCHEMA_FIELD_DEFAULT,"")
l_lFieldNullable      := hb_HGetDef(par_hFieldDefinition,HB_ORM_SCHEMA_FIELD_NULLABLE,.f.)
l_lFieldAutoIncrement := hb_HGetDef(par_hFieldDefinition,HB_ORM_SCHEMA_FIELD_AUTOINCREMENT,.f.)
l_lFieldArray         := hb_HGetDef(par_hFieldDefinition,HB_ORM_SCHEMA_FIELD_ARRAY,.f.)

l_cFieldDefault := ::NormalizeFieldDefaultForCurrentEngineType(l_cFieldDefault,l_cFieldType,l_nFieldDec)

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    // l_cFormattedTableName := ::FormatIdentifier(par_cTableName)
    
    l_cSQLCommand += [,ADD COLUMN ]+l_cFormattedFieldName+[ ]

    do case
    case el_IsInlist(l_cFieldType,"I","IB","IS","N")
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
        
    case el_IsInlist(l_cFieldType,"C","CV","B","BV","M","R")
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
        
    case el_IsInlist(l_cFieldType,"D","TOZ","TO","DTZ","T","DT")
        do case
        case l_cFieldType == "D"
            l_cSQLCommand += [DATE]
            l_cDefaultString    := ['0000-00-00']
        case l_cFieldType == "TOZ"
            if el_between(l_nFieldDec,0,6)
                l_cSQLCommand += [TIME(]+trans(l_nFieldDec)+[) COMMENT 'Type=TOZ']
            else
                l_cSQLCommand += [TIME COMMENT 'Type=TOZ']
            endif
            l_cDefaultString    := ['00:00:00']
        case l_cFieldType == "TO"
            if el_between(l_nFieldDec,0,6)
                l_cSQLCommand += [TIME(]+trans(l_nFieldDec)+[)]
            else
                l_cSQLCommand += [TIME]
            endif
            l_cDefaultString    := ['00:00:00']
        case l_cFieldType == "DTZ"
            if el_between(l_nFieldDec,0,6)
                l_cSQLCommand += [TIMESTAMP(]+trans(l_nFieldDec)+[)]
            else
                l_cSQLCommand += [TIMESTAMP]
            endif
            l_cDefaultString    := ['0000-00-00 00:00:00']
        case l_cFieldType == "DT" .or. l_cFieldType == "T"
            if el_between(l_nFieldDec,0,6)
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

    case l_cFieldType == "JSB"
        l_cSQLCommand += [LONGTEXT COMMENT 'Type=JSB']
        l_cDefaultString := "'{}'"

    case l_cFieldType == "JS"
        l_cSQLCommand += [LONGTEXT COMMENT 'Type=JS']
        l_cDefaultString := "'{}'"

    case l_cFieldType == "OID"
        l_cSQLCommand += [BIGINT COMMENT 'Type=OID']
        l_cDefaultString := "0"

    otherwise
        
    endcase

    if !empty(l_cDefaultString)
        if l_lFieldNullable
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

    l_cFormattedTableName := ::FormatIdentifier(par_cNamespaceName+"."+par_cTableName)

    l_cSQLCommand += [,ADD COLUMN ]+l_cFormattedFieldName+[ ]

    l_cFieldTypeSuffix := iif(l_lFieldArray,"[]","")

    do case
    case el_IsInlist(l_cFieldType,"I","IB","IS","N")
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
                hb_orm_SendToDebugView("May not make numeric field auto-increment. Table: "+par_cNamespaceName+"."+par_cTableName+" - Field: "+par_cFieldName)
            endif
        endcase

        if l_lFieldAutoIncrement
            l_cSQLCommand += [ NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 )]

            if used("hb_orm_ListOfPrimaryKeyConstraints")
                if !el_seek(padr(upper(par_cNamespaceName+'*'+par_cTableName+'*'),240),"hb_orm_ListOfPrimaryKeyConstraints","tag1")
                    l_cSQLCommand += [,ADD CONSTRAINT ]+lower(par_cTableName)+[_pkey PRIMARY KEY (]+::FormatIdentifier(par_cFieldName)+[)]
                    l_cDefaultString := ""
                endif
            endif

        else
            l_cDefaultString := "0"
        endif
        
    case el_IsInlist(l_cFieldType,"C","CV","M","B","BV","R")
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

    case el_IsInlist(l_cFieldType,"D","TOZ","TO","DTZ","T","DT")
        do case
        case l_cFieldType == "D"
            l_cSQLCommand += [date]+l_cFieldTypeSuffix
        case l_cFieldType == "TOZ"
            if el_between(l_nFieldDec,0,6)
                l_cSQLCommand += [time(]+trans(l_nFieldDec)+[) with time zone]+l_cFieldTypeSuffix
            else
                l_cSQLCommand += [time with time zone]+l_cFieldTypeSuffix
            endif
        case l_cFieldType == "TO"
            if el_between(l_nFieldDec,0,6)
                l_cSQLCommand += [time(]+trans(l_nFieldDec)+[) without time zone]+l_cFieldTypeSuffix
            else
                l_cSQLCommand += [time without time zone]+l_cFieldTypeSuffix
            endif
        case l_cFieldType == "DTZ"
            if el_between(l_nFieldDec,0,6)
                l_cSQLCommand += [timestamp(]+trans(l_nFieldDec)+[) with time zone]+l_cFieldTypeSuffix
            else
                l_cSQLCommand += [timestamp with time zone]+l_cFieldTypeSuffix
            endif
        case l_cFieldType == "DT" .or. l_cFieldType == "T"
            if el_between(l_nFieldDec,0,6)
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

    case l_cFieldType == "JSB"
        l_cSQLCommand += [jsonb]+l_cFieldTypeSuffix
        l_cDefaultString := "'{}'::jsonb"

    case l_cFieldType == "JS"
        l_cSQLCommand += [json]+l_cFieldTypeSuffix
        l_cDefaultString := "'{}'::json"

    case l_cFieldType == "OID"
        l_cSQLCommand += [oid]+l_cFieldTypeSuffix
        l_cDefaultString := "FALSE"

    case l_cFieldType == "E"
        if empty(l_cFieldTypeEnumName)
            //_M_ Report as an error
        else
            l_cSQLCommand +=  ::FormatIdentifier(par_cNamespaceName)+[.]+::FormatIdentifier(l_cFieldTypeEnumName)+l_cFieldTypeSuffix
            l_cDefaultString := "''"
        endif

    otherwise
        
    endcase

    if !empty(l_cDefaultString)
        if l_lFieldNullable
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
//-----------------------------------------------------------------------------------------------------------------
method GMSSAddIndex(par_cNamespaceName,par_cTableName,par_hFields,par_cIndexName,par_hIndexDefinition) class hb_orm_SQLConnect   // GMSS (Generate Migrate Schema Script).
local l_cSQLCommand := ""
local l_cIndexNameOnFile
local l_cIndexExpression
local l_lIndexUnique
local l_cIndexType
local l_cFormattedTableName

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cIndexNameOnFile := lower(par_cIndexName)+"_idx"
    do case
    case empty(par_cNamespaceName)
        // l_cIndexNameOnFile    := lower(par_cTableName+"_"+par_cIndexName)+"_idx"
        l_cFormattedTableName := ::FormatIdentifier(par_cTableName)
    case lower(par_cNamespaceName) == "public"
        // l_cIndexNameOnFile    := lower(par_cTableName+"_"+par_cIndexName)+"_idx"
        l_cFormattedTableName := ::FormatIdentifier(par_cTableName)
    otherwise
        // l_cIndexNameOnFile   := lower(par_cNamespaceName+"_"+par_cTableName+"_"+par_cIndexName)+"_idx"
        l_cFormattedTableName := ::FormatIdentifier(par_cNamespaceName+"."+par_cTableName)
    endif
    
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    // Since "Two indexes in the same schema cannot have the same name."
    // l_cIndexNameOnFile   := lower(par_cNamespaceName)+"_"+lower(par_cTableName)+"_"+lower(par_cIndexName)+"_idx"
    l_cIndexNameOnFile    := lower(par_cTableName+"_"+par_cIndexName)+"_idx"
    l_cFormattedTableName := ::FormatIdentifier(par_cNamespaceName+"."+par_cTableName)
    
endcase

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cIndexExpression := ::FixCasingInFieldExpression(par_hFields,par_hIndexDefinition[HB_ORM_SCHEMA_INDEX_EXPRESSION])
    l_lIndexUnique     := hb_HGetDef(par_hIndexDefinition,HB_ORM_SCHEMA_INDEX_UNIQUE,.f.)
    l_cIndexType       := hb_HGetDef(par_hIndexDefinition,HB_ORM_SCHEMA_INDEX_ALGORITHM,"")
    if empty(l_cIndexType)
        l_cIndexType := "BTREE"
    endif

    l_cSQLCommand := [ALTER TABLE ]+l_cFormattedTableName
	l_cSQLCommand += [ ADD ]+iif(l_lIndexUnique,"UNIQUE ","")+[INDEX `]+l_cIndexNameOnFile+[` (]+l_cIndexExpression+[) USING ]+l_cIndexType+[;]+CRLF

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cIndexExpression := ::FixCasingInFieldExpression(par_hFields,par_hIndexDefinition[HB_ORM_SCHEMA_INDEX_EXPRESSION])
    l_lIndexUnique     := hb_HGetDef(par_hIndexDefinition,HB_ORM_SCHEMA_INDEX_UNIQUE,.f.)
    l_cIndexType       := hb_HGetDef(par_hIndexDefinition,HB_ORM_SCHEMA_INDEX_ALGORITHM,"")
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
method GMSSDeleteIndex(par_cNamespaceName,par_cTableName,par_cIndexName) class hb_orm_SQLConnect   // GMSS (Generate Migrate Schema Script).
local l_cSQLCommand
local l_cNamespaceAndTableNameFixedCase
local l_cPrefix
local l_cIndexName := par_cIndexName

l_cPrefix := lower(par_cNamespaceName)+"_"+lower(par_cTableName)+"_"
if left(l_cIndexName,len(l_cPrefix)) == l_cPrefix
    l_cIndexName := substr(l_cIndexName,len(l_cPrefix)+1)
else
    l_cPrefix := lower(par_cTableName)+"_"
    if left(l_cIndexName,len(l_cPrefix)) == l_cPrefix
        l_cIndexName := substr(l_cIndexName,len(l_cPrefix)+1)
    endif
endif

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cNamespaceAndTableNameFixedCase := ::CaseTableName(iif(empty(par_cNamespaceName) .or. lower(par_cNamespaceName) == "public","",par_cNamespaceName+".")+par_cTableName)
    l_cSQLCommand := [DROP INDEX IF EXISTS `]+lower(l_cIndexName)+"_idx"+[` ON ]+::FormatIdentifier(::NormalizeTableNamePhysical(l_cNamespaceAndTableNameFixedCase))+[;]

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    //In Postgresql the index are named spaced in the Schema, not the table it belongs to
    l_cSQLCommand := [DROP INDEX IF EXISTS ]+::FormatIdentifier(par_cNamespaceName+"."+lower(par_cTableName)+"_"+lower(l_cIndexName)+"_idx")+[ CASCADE;]
    //Previously added the Namespace as prefix to the index
    l_cSQLCommand += [DROP INDEX IF EXISTS ]+::FormatIdentifier(par_cNamespaceName+"."+lower(par_cNamespaceName)+"_"+lower(par_cTableName)+"_"+lower(l_cIndexName)+"_idx")+[ CASCADE;]

endcase

return l_cSQLCommand
//-----------------------------------------------------------------------------------------------------------------
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

    if !(::p_HBORMNamespace == "hborm")
        l_cSQLCommand := strtran(l_cSQLCommand,"hborm",::FormatIdentifier(::p_HBORMNamespace))
    endif

    l_Success := ::SQLExec("EnableSchemaChangeTracking",l_cSQLCommand)

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

    if !(::p_HBORMNamespace == "hborm")
        l_cSQLCommand := strtran(l_cSQLCommand,"hborm",::FormatIdentifier(::p_HBORMNamespace))
    endif

    l_Success := ::SQLExec("DisableSchemaChangeTracking",l_cSQLCommand)

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
    
    if !(::p_HBORMNamespace == "hborm")
        l_cSQLCommand := strtran(l_cSQLCommand,"hborm",::FormatIdentifier(::p_HBORMNamespace))
    endif

    l_Success := ::SQLExec("RemoveSchemaChangeTracking",l_cSQLCommand)

endcase

return l_Success
//-----------------------------------------------------------------------------------------------------------------
method UpdateSchemaCache(par_lForce) class hb_orm_SQLConnect   //returns .t. if cache was updated
local l_cSQLCommand
local l_nSelect := iif(used(),select(),0)
local l_CacheFullNameField
local l_CacheFullNameIndex
local l_lResult := .f.
local l_HBORMNamespaceName

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_HBORMNamespaceName := ::FormatIdentifier(::p_HBORMNamespace)
    hb_Default(@par_lForce,.f.)
    // altd()

    if par_lForce
        //Add an Entry in SchemaCacheLog to notify to make a cache
        l_cSQLCommand := [INSERT INTO ]+l_HBORMNamespaceName+::FixCasingOfSchemaCacheTables([."SchemaCacheLog"])+[ (action) VALUES ('No Change');]
        ::SQLExec("UpdateSchemaCache",l_cSQLCommand)
    endif

    l_cSQLCommand := [SELECT pk,]
    l_cSQLCommand += [       cachedschema::integer]
    l_cSQLCommand += [ FROM  ]+l_HBORMNamespaceName+::FixCasingOfSchemaCacheTables([."SchemaCacheLog"])
    l_cSQLCommand += [ ORDER BY pk DESC]
    l_cSQLCommand += [ LIMIT 1]

    if ::SQLExec("UpdateSchemaCache",l_cSQLCommand,"SchemaCacheLogLast")
        if SchemaCacheLogLast->(reccount()) == 1
            if SchemaCacheLogLast->cachedschema == 0   //Meaning the last schema change log was not cached  (0 = false)
//hb_orm_SendToDebugView("Will create a new Schema Cache")

l_CacheFullNameField := l_HBORMNamespaceName+::FixCasingOfSchemaCacheTables([."SchemaCacheFields_])+trans(SchemaCacheLogLast->pk)+["]
l_CacheFullNameIndex := l_HBORMNamespaceName+::FixCasingOfSchemaCacheTables([."SchemaCacheIndexes_])+trans(SchemaCacheLogLast->pk)+["]

//====================================
l_cSQLCommand := [DROP FUNCTION IF EXISTS ]+l_HBORMNamespaceName+[.hb_orm_update_schema_cache;]+CRLF
//====================================
l_cSQLCommand += [CREATE OR REPLACE FUNCTION ]+l_HBORMNamespaceName+[.hb_orm_update_schema_cache(par_cache_full_name_field text,par_cache_full_name_index text) RETURNS boolean]
l_cSQLCommand += [ LANGUAGE plpgsql VOLATILE SECURITY DEFINER AS $BODY$]+CRLF
l_cSQLCommand += [DECLARE]+CRLF
l_cSQLCommand += [   v_SQLCommand text;]+CRLF
l_cSQLCommand += [   v_lReturn boolean := TRUE;]+CRLF
l_cSQLCommand += [BEGIN]+CRLF
l_cSQLCommand += [SET enable_nestloop = false;]+CRLF //    -- See  https://github.com/yugabyte/yugabyte-db/issues/9938
// -------------------------------------------------------------------------------------
l_cSQLCommand += [EXECUTE format('DROP TABLE IF EXISTS %s', par_cache_full_name_field);]+CRLF

l_cSQLCommand += [v_SQLCommand := $$]+CRLF
l_cSQLCommand += ::GetPostgresTableSchemaQuery()
l_cSQLCommand += [$$;]+CRLF
l_cSQLCommand += [v_SQLCommand := CONCAT('CREATE TABLE ',par_cache_full_name_field,' AS ',v_SQLCommand);]+CRLF
l_cSQLCommand += [EXECUTE v_SQLCommand;]+CRLF
// -------------------------------------------------------------------------------------
l_cSQLCommand += [EXECUTE format('DROP TABLE IF EXISTS %s', par_cache_full_name_index);]+CRLF
// -------------------------------------------------------------------------------------
l_cSQLCommand += [v_SQLCommand := $$]+CRLF
l_cSQLCommand += ::GetPostgresIndexSchemaQuery()
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
l_cSQLCommand += [SELECT ]+l_HBORMNamespaceName+[.hb_orm_update_schema_cache(']+l_CacheFullNameField+[',']+l_CacheFullNameIndex+[');]+CRLF
//====================================
l_cSQLCommand += [DROP FUNCTION IF EXISTS ]+l_HBORMNamespaceName+[.hb_orm_update_schema_cache;]+CRLF
//====================================

// -------------------------------------------------------------------------------------
                if ::SQLExec("UpdateSchemaCache",l_cSQLCommand)


                    l_cSQLCommand := [UPDATE ]+l_HBORMNamespaceName+::FixCasingOfSchemaCacheTables([."SchemaCacheLog"])
                    l_cSQLCommand += [ SET cachedschema = TRUE]
                    l_cSQLCommand += [ WHERE pk = ]+trans(SchemaCacheLogLast->pk)

                    if ::SQLExec("UpdateSchemaCache",l_cSQLCommand)
                    
                        //Remove any previous cache
                        l_cSQLCommand := [SELECT pk]
                        l_cSQLCommand += [ FROM ]+l_HBORMNamespaceName+::FixCasingOfSchemaCacheTables([."SchemaCacheLog"])
                        l_cSQLCommand += [ WHERE cachedschema]
                        l_cSQLCommand += [ AND pk < ]+trans(SchemaCacheLogLast->pk)
                        l_cSQLCommand += [ ORDER BY pk]  // Oldest to newest

                        if ::SQLExec("UpdateSchemaCache",l_cSQLCommand,"SchemaCacheLogLast")
                            select SchemaCacheLogLast
                            scan all
                                if recno() == reccount()  // Since last record is the latest beside the one just added, will exit the scan
                                    exit
                                endif
                                l_cSQLCommand := [UPDATE ]+l_HBORMNamespaceName+::FixCasingOfSchemaCacheTables([."SchemaCacheLog"])
                                l_cSQLCommand += [ SET cachedschema = FALSE]
                                l_cSQLCommand += [ WHERE pk = ]+trans(SchemaCacheLogLast->pk)
                                
                                if ::SQLExec("UpdateSchemaCache",l_cSQLCommand)
                                    l_cSQLCommand := [DROP TABLE ]+l_HBORMNamespaceName+::FixCasingOfSchemaCacheTables([."SchemaCacheFields_])+trans(SchemaCacheLogLast->pk)+["]
                                    ::SQLExec("UpdateSchemaCache",l_cSQLCommand)
                                    l_cSQLCommand := [DROP TABLE ]+l_HBORMNamespaceName+::FixCasingOfSchemaCacheTables([."SchemaCacheIndexes_])+trans(SchemaCacheLogLast->pk)+["]
                                    ::SQLExec("UpdateSchemaCache",l_cSQLCommand)
                                endif
                            endscan

                        endif
                    endif
                endif
                // ::LoadMetadata()
                l_lResult := .t.
            endif
        endif
    endif
    CloseAlias("SchemaCacheLogLast")
    select (l_nSelect)

endcase

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method GetPostgresTableSchemaQuery() class hb_orm_SQLConnect
local l_cSQLCommand
l_cSQLCommand := [WITH unlogged_tables as ]+CRLF
l_cSQLCommand += [(SELECT pg_namespace.nspname as namespace_name,]+CRLF
l_cSQLCommand += [        pg_class.relname     as table_name]+CRLF
l_cSQLCommand += [   FROM pg_class]+CRLF
l_cSQLCommand += [   inner join pg_namespace on pg_namespace.oid = pg_class.relnamespace]+CRLF
l_cSQLCommand += [   inner join pg_type      on pg_class.reltype = pg_type.oid]+CRLF
l_cSQLCommand += [   where pg_class.relpersistence = 'u']+CRLF
l_cSQLCommand += [   and   pg_type.typtype = 'c')]+CRLF
l_cSQLCommand += [SELECT columns.table_schema::text        AS namespace_name,]+CRLF
l_cSQLCommand += [       columns.table_name::text          AS table_name,]+CRLF
l_cSQLCommand += [       CASE WHEN unlogged_tables.table_name IS NULL THEN false]+CRLF
l_cSQLCommand += [            ELSE true]+CRLF
l_cSQLCommand += [            END AS table_is_unlogged,]+CRLF
l_cSQLCommand += [       columns.ordinal_position::integer AS field_position,]+CRLF
l_cSQLCommand += [       columns.column_name::text         AS field_name,]+CRLF
l_cSQLCommand += [       CASE WHEN columns.data_type = 'ARRAY' THEN element_types.data_type::text]+CRLF
l_cSQLCommand += [            ELSE columns.data_type::text]+CRLF
l_cSQLCommand += [            END AS field_type,]+CRLF
l_cSQLCommand += [       columns.udt_schema                AS field_type_enum_spacename,]+CRLF
l_cSQLCommand += [       columns.udt_name                  AS field_type_enum_name,]+CRLF
l_cSQLCommand += [       CASE WHEN columns.data_type = 'ARRAY' THEN true]+CRLF
l_cSQLCommand += [            ELSE false]+CRLF
l_cSQLCommand += [            END AS field_array,]+CRLF
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
l_cSQLCommand += [ INNER JOIN pg_catalog.pg_statio_all_tables AS st ON columns.table_schema = st.schemaname AND columns.table_name = st.relname]+CRLF
l_cSQLCommand += [ INNER JOIN information_schema.tables             ON columns.table_schema = tables.table_schema AND columns.table_name = tables.table_name]+CRLF
l_cSQLCommand += [ LEFT JOIN pg_catalog.pg_description pgd          ON pgd.objoid=st.relid AND pgd.objsubid=columns.ordinal_position]+CRLF
l_cSQLCommand += [ LEFT JOIN information_schema.element_types       ON ((columns.table_catalog, columns.table_schema, columns.table_name, 'TABLE', columns.dtd_identifier) = (element_types.object_catalog, element_types.object_schema, element_types.object_name, element_types.object_type, element_types.collection_type_identifier))]+CRLF
l_cSQLCommand += [ LEFT JOIN unlogged_tables                        ON unlogged_tables.namespace_name = tables.table_schema AND unlogged_tables.table_name = tables.table_name]+CRLF
l_cSQLCommand += [ WHERE NOT (lower(left(columns.table_name,11)) = 'schemacache' OR lower(columns.table_schema) in ('information_schema','pg_catalog'))]+CRLF
l_cSQLCommand += [ AND   tables.table_type = 'BASE TABLE']+CRLF
l_cSQLCommand += [ ORDER BY tag1,tag2,field_position;]+CRLF
return l_cSQLCommand
//-----------------------------------------------------------------------------------------------------------------
method GetPostgresIndexSchemaQuery()  class hb_orm_SQLConnect
local l_cSQLCommand
l_cSQLCommand := [SELECT pg_indexes.schemaname      AS namespace_name,]+CRLF
l_cSQLCommand += [       pg_indexes.tablename       AS table_name,]+CRLF
l_cSQLCommand += [       pg_indexes.indexname       AS index_name,]+CRLF
l_cSQLCommand += [       pg_indexes.indexdef        AS index_definition,]+CRLF
l_cSQLCommand += [       upper(pg_indexes.schemaname) AS tag1,]+CRLF
l_cSQLCommand += [       upper(pg_indexes.tablename) AS tag2]+CRLF
l_cSQLCommand += [ FROM pg_indexes]+CRLF
l_cSQLCommand += [ WHERE NOT (lower(left(pg_indexes.tablename,11)) = 'schemacache' OR lower(pg_indexes.schemaname) in ('information_schema','pg_catalog'))]+CRLF
l_cSQLCommand += [ ORDER BY tag1,index_name;]+CRLF
return l_cSQLCommand
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
local l_cNamespaceName,l_cTableName

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    // // Since a namespace name could be a prefix to the table name, detect its presence.
    // l_nPos := at(".",par_cName)
    // if l_nPos == 0  // no namespace was specified
    //     if ::MySQLEngineConvertIdentifierToLowerCase
    //         l_cFormattedIdentifier := "`"+lower(par_cName)+"`"
    //     else
    //         l_cFormattedIdentifier := "`"+par_cName+"`"
    //     endif
    // else
    //     l_cNamespaceName := left(par_cName,l_nPos-1)
    //     l_cTableName  := substr(par_cName,l_nPos+1)

    //     if ::MySQLEngineConvertIdentifierToLowerCase
    //         l_cFormattedIdentifier := "`"+lower(l_cNamespaceName)+"."+lower(l_cTableName)+"`"
    //     else
    //         l_cFormattedIdentifier := "`"+l_cNamespaceName+"."+l_cTableName+"`"
    //     endif
    // endif
    //In MySQL there is no need to separate the Namespace name from the Table name
    if ::MySQLEngineConvertIdentifierToLowerCase
        l_cFormattedIdentifier := "`"+lower(par_cName)+"`"
    else
        l_cFormattedIdentifier := "`"+par_cName+"`"
    endif

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    // Since a namespace name could be a prefix to the table name, detect its presence.
    l_nPos := at(".",par_cName)
    if l_nPos == 0  // no namespace name was specified
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
        l_cNamespaceName := left(par_cName,l_nPos-1)
        l_cTableName  := substr(par_cName,l_nPos+1)

        do case
        case ::PostgreSQLIdentifierCasing == 0  // Case Insensitive (displayed as lower case) except reserved words always lower case
            if ::IsReservedWord(l_cNamespaceName)
                l_cFormattedIdentifier := '"'+lower(l_cNamespaceName)+'".'
            else
                l_cFormattedIdentifier := l_cNamespaceName+"."
            endif
            if ::IsReservedWord(l_cTableName)
                l_cFormattedIdentifier += '"'+lower(l_cTableName)+'"'
            else
                l_cFormattedIdentifier += l_cTableName
            endif
        case ::PostgreSQLIdentifierCasing == 1
            l_cFormattedIdentifier := '"'+l_cNamespaceName+'"."'+l_cTableName+'"'
        case ::PostgreSQLIdentifierCasing == 2  // convert to lower case
            l_cFormattedIdentifier := '"'+lower(l_cNamespaceName)+'"."'+lower(l_cTableName)+'"'
        otherwise  // Should not happen
            l_cFormattedIdentifier := '"'+l_cNamespaceName+'"."'+l_cTableName+'"'
        endcase

    endif

endcase

return l_cFormattedIdentifier
//-----------------------------------------------------------------------------------------------------------------
method FormatValue(par_cValue) class hb_orm_SQLConnect
local l_cFormattedValue

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    // See https://dev.mysql.com/doc/refman/8.0/en/string-literals.html
    l_cFormattedValue := hb_StrReplace( par_cValue, {'\' => '\\',;
                                                     '"' => '\"',;
                                                     "'" => "\'"} )

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cFormattedValue := "'"+strtran(par_cValue,"'","''")+"'"

endcase

return l_cFormattedValue
//-----------------------------------------------------------------------------------------------------------------
method NormalizeTableNameInternal(par_cNamespaceAndTableName) class hb_orm_SQLConnect
local l_cNamespaceAndTableName := hb_StrReplace(par_cNamespaceAndTableName,{' '=>'','"'=>'',"'"=>""})
local l_nPos

l_nPos := at(".",l_cNamespaceAndTableName)
if empty(l_nPos)
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_cNamespaceAndTableName := "public."+l_cNamespaceAndTableName
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        l_cNamespaceAndTableName := ::GetCurrentNamespaceName()+"."+l_cNamespaceAndTableName
    endcase
endif

return l_cNamespaceAndTableName
//-----------------------------------------------------------------------------------------------------------------
method NormalizeTableNamePhysical(par_cNamespaceAndTableName) class hb_orm_SQLConnect
local l_cNamespaceAndTableName := hb_StrReplace(par_cNamespaceAndTableName,{' '=>'','"'=>'',"'"=>""})

if ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    if left(l_cNamespaceAndTableName,len("public.")) == "public."
        l_cNamespaceAndTableName := substr(l_cNamespaceAndTableName,len("public.")+1)
    endif
endif

return l_cNamespaceAndTableName
//-----------------------------------------------------------------------------------------------------------------
method CaseTableName(par_cNamespaceAndTableName) class hb_orm_SQLConnect
local l_cNamespaceAndTableName := ::NormalizeTableNameInternal(par_cNamespaceAndTableName)
local l_nHashPos

//Fix The Casing of Table and Field based on he actual on file tables.
l_nHashPos := hb_hPos(::p_hMetadataTable,l_cNamespaceAndTableName)
if l_nHashPos > 0
    l_cNamespaceAndTableName := hb_hKeyAt(::p_hMetadataTable,l_nHashPos) 
else
    // Report Failed to find Table by returning empty.
    l_cNamespaceAndTableName := ""
endif

return l_cNamespaceAndTableName
//-----------------------------------------------------------------------------------------------------------------
method CaseFieldName(par_cNamespaceAndTableName,par_cFieldName) class hb_orm_SQLConnect
local l_cNamespaceAndTableName := ::NormalizeTableNameInternal(par_cNamespaceAndTableName)
local l_cFieldName             := allt(par_cFieldName)
local l_nHashPos
l_nHashPos := hb_hPos(::p_hMetadataTable[l_cNamespaceAndTableName][HB_ORM_SCHEMA_FIELD],l_cFieldName)
if l_nHashPos > 0
    l_cFieldName := hb_hKeyAt(::p_hMetadataTable[l_cNamespaceAndTableName][HB_ORM_SCHEMA_FIELD],l_nHashPos)
else
    // Report Failed to find Field by returning empty.
    l_cFieldName := ""
endif
return l_cFieldName
//-----------------------------------------------------------------------------------------------------------------
method GetFieldInfo(par_cNamespaceAndTableName,par_cFieldName) class hb_orm_SQLConnect
// Returns Hash Array {"NameSpace"=><NamespaceName>,
//                     "TableName"=><TableName>,
//                     "FieldName"=><FieldName>,
//                     "FieldType"=><FieldType>,
//                     "FieldLen"=><FieldLen>,
//                     "FieldDec"=><FieldDec>,
//                     "FieldNullable"=><FieldNullable>,
//                     "FieldAutoIncrement"=><FieldAutoIncrement>,
//                     "FieldArray"=><FieldArray>,
//                     "FieldDefault"=><FieldDefault>}
local l_hResult := {=>}

local l_cNamespaceAndTableName := ::NormalizeTableNameInternal(par_cNamespaceAndTableName)
local l_cFieldName := allt(par_cFieldName)
local l_cNamespaceName
local l_cTableName
local l_hFieldInfo
local l_nHashPos
local l_nPos

l_nHashPos := hb_hPos(::p_hMetadataTable,l_cNamespaceAndTableName)
if l_nHashPos > 0
    l_cNamespaceAndTableName := hb_hKeyAt(::p_hMetadataTable,l_nHashPos)   // To get the proper casing
    l_nHashPos := hb_hPos(::p_hMetadataTable[l_cNamespaceAndTableName][HB_ORM_SCHEMA_FIELD],l_cFieldName)
    if l_nHashPos > 0
        l_cFieldName  := hb_hKeyAt(::p_hMetadataTable[l_cNamespaceAndTableName][HB_ORM_SCHEMA_FIELD],l_nHashPos)
        l_hFieldInfo := hb_HValueAt(::p_hMetadataTable[l_cNamespaceAndTableName][HB_ORM_SCHEMA_FIELD],l_nHashPos)

        l_nPos := at(".",l_cNamespaceAndTableName)
        if empty(l_nPos)
            l_cNamespaceName := ""
            l_cTableName  := l_cNamespaceAndTableName
        else
            l_cNamespaceName := left(l_cNamespaceAndTableName,l_nPos-1)
            l_cTableName  := substr(l_cNamespaceAndTableName,l_nPos+1)
        endif

        l_hResult := {HB_ORM_GETFIELDINFO_NAMESPACE_NAME=>l_cNamespaceName,;
                      HB_ORM_GETFIELDINFO_TABLENAME=>l_cTableName,;
                      HB_ORM_GETFIELDINFO_FIELDNAME=>l_cFieldName,;
                      HB_ORM_GETFIELDINFO_FIELDTYPE=>l_hFieldInfo[HB_ORM_SCHEMA_FIELD_TYPE],;
                      HB_ORM_GETFIELDINFO_FIELDLENGTH=>hb_HGetDef(l_hFieldInfo,HB_ORM_SCHEMA_FIELD_LENGTH,0),;
                      HB_ORM_GETFIELDINFO_FIELDDECIMALS=>hb_HGetDef(l_hFieldInfo,HB_ORM_SCHEMA_FIELD_DECIMALS,0),;
                      HB_ORM_GETFIELDINFO_FIELDNULLABLE=>hb_HGetDef(l_hFieldInfo,HB_ORM_SCHEMA_FIELD_NULLABLE,.f.),;
                      HB_ORM_GETFIELDINFO_FIELDAUTOINCREMENT=>hb_HGetDef(l_hFieldInfo,HB_ORM_SCHEMA_FIELD_AUTOINCREMENT,.f.),;
                      HB_ORM_GETFIELDINFO_FIELDARRAY=>hb_HGetDef(l_hFieldInfo,HB_ORM_SCHEMA_FIELD_ARRAY,.f.),;
                      HB_ORM_GETFIELDINFO_FIELDDEFAULT=>hb_HGetDef(l_hFieldInfo,HB_ORM_SCHEMA_FIELD_DEFAULT,"")}

    endif
endif

return l_hResult
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
method DeleteTable(par_cNamespaceAndTableName) class hb_orm_SQLConnect
local l_lResult := .t.
local l_cSQLCommand
local l_cLastError
local l_cNamespaceAndTableName          := ::NormalizeTableNameInternal(par_cNamespaceAndTableName)
local l_cNamespaceAndTableNameFixedCase := ::CaseTableName(l_cNamespaceAndTableName)

if empty(l_cNamespaceAndTableNameFixedCase)
    hb_orm_SendToDebugView([Unable to delete field(s) in unknown table: "]+par_cNamespaceAndTableName+["])
else
    l_cSQLCommand := [DROP TABLE IF EXISTS ]+::FormatIdentifier(::NormalizeTableNamePhysical(l_cNamespaceAndTableNameFixedCase))+[;]
    if ::SQLExec("DeleteTable",l_cSQLCommand)
        hb_HDel(::p_hMetadataTable,l_cNamespaceAndTableNameFixedCase)
    else
        l_lResult := .f.
        l_cLastError := ::GetSQLExecErrorMessage()
        hb_orm_SendToDebugView([Failed Delete Table "]+par_cNamespaceAndTableName+[".   Error Text=]+l_cLastError)
    endif
endif
return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method DeleteIndex(par_cNamespaceAndTableName,par_cIndexName) class hb_orm_SQLConnect
local l_lResult := .t.
local l_cNamespaceAndTableName          := ::NormalizeTableNameInternal(par_cNamespaceAndTableName)
local l_cNamespaceAndTableNameFixedCase := ::CaseTableName(l_cNamespaceAndTableName)
local l_cLastError
local l_cSQLCommand := ""
local l_nHashPos
local l_nPos
local l_cNamespaceName
local l_cTableName

if empty(l_cNamespaceAndTableNameFixedCase)
    hb_orm_SendToDebugView([Unable to delete index(s) in unknown table: "]+par_cNamespaceAndTableName+["])

else
    //Test if the index is present. Only hb_orm indexes can be removed.
    l_nHashPos := hb_hPos(::p_hMetadataTable[par_cNamespaceAndTableName][HB_ORM_SCHEMA_INDEX],lower(par_cIndexName))
    if l_nHashPos > 0
        
        do case
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
            // l_cSQLCommand  := [DROP INDEX `]+strtran(lower(par_cNamespaceAndTableName),".","_")+"_"+lower(par_cIndexName)+"_idx"+[` ON ]+::FormatIdentifier(::NormalizeTableNamePhysical(l_cNamespaceAndTableNameFixedCase))+[;]
            l_cSQLCommand := [DROP INDEX IF EXISTS `]+lower(par_cIndexName)+"_idx"+[` ON ]+::FormatIdentifier(::NormalizeTableNamePhysical(l_cNamespaceAndTableNameFixedCase))+[;]

        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
            l_nPos           := at(".",l_cNamespaceAndTableNameFixedCase)   // Will always be set, due to calling NormalizeTableNameInternal() before
            l_cNamespaceName := left(l_cNamespaceAndTableNameFixedCase,l_nPos-1)
            l_cTableName     := substr(l_cNamespaceAndTableNameFixedCase,l_nPos+1)

            // l_cSQLCommand  := [DROP INDEX IF EXISTS ]+strtran(lower(par_cNamespaceAndTableName),".","_")+"_"+lower(par_cIndexName)+"_idx"+[ CASCADE;]
            l_cSQLCommand := [DROP INDEX IF EXISTS ]+::FormatIdentifier(lower(l_cNamespaceName)+"."+lower(l_cTableName)+"_"+lower(par_cIndexName)+"_idx")+[ CASCADE;]

        endcase

        if !empty(l_cSQLCommand)
            if ::SQLExec("DeleteIndex",l_cSQLCommand)
                hb_HDel(::p_hMetadataTable[par_cNamespaceAndTableName][HB_ORM_SCHEMA_INDEX],lower(par_cIndexName))
            else
                l_lResult := .f.
                l_cLastError := ::GetSQLExecErrorMessage()
                hb_orm_SendToDebugView([Failed Delete index "]+par_cIndexName+[" for table "]+par_cNamespaceAndTableName+[".   Error Text=]+l_cLastError)
            endif
        endif

    endif

endif

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method DeleteField(par_cNamespaceAndTableName,par_xFieldNames) class hb_orm_SQLConnect
local l_lResult := .t.
local l_cNamespaceAndTableName          := ::NormalizeTableNameInternal(par_cNamespaceAndTableName)
local l_cNamespaceAndTableNameFixedCase := ::CaseTableName(l_cNamespaceAndTableName)
local l_cLastError
local l_aFieldNames,l_cFieldName,l_cFieldNameFixedCase
local l_cSQLCommand
local l_SQLAlterTable
local l_SQLIfExist

// par_xFieldNames can be an array of field names or a single field name

if empty(l_cNamespaceAndTableNameFixedCase)
    hb_orm_SendToDebugView([Unable to delete field(s) in unknown table: "]+par_cNamespaceAndTableName+["])

else
    if ValType(par_xFieldNames) == "A"
        l_aFieldNames := par_xFieldNames
    elseif ValType(par_xFieldNames) == "C"
        l_aFieldNames := {par_xFieldNames}
    else
        l_aFieldNames := {}
    endif

    if len(l_aFieldNames) > 0

        l_SQLAlterTable := [ALTER TABLE ]+::FormatIdentifier(::NormalizeTableNamePhysical(l_cNamespaceAndTableNameFixedCase))

        do case
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
            l_SQLIfExist    := [ ]
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
            l_SQLIfExist    := [ IF EXISTS ]
        endcase

        l_cSQLCommand := []
        for each l_cFieldName in l_aFieldNames
            l_cFieldNameFixedCase := ::CaseFieldName(l_cNamespaceAndTableNameFixedCase,l_cFieldName)
            if empty(l_cFieldNameFixedCase)
                hb_orm_SendToDebugView([Unable to delete unknown field: "]+par_cNamespaceAndTableName+[.]+l_cFieldName+["])
            else
                if !empty(l_cSQLCommand)
                    l_cSQLCommand += [,]
                endif
                l_cSQLCommand += [ DROP COLUMN]+l_SQLIfExist+::FormatIdentifier(l_cFieldNameFixedCase)+[ CASCADE]
            endif
        endfor

        if !empty(l_cSQLCommand)
            l_cSQLCommand := l_SQLAlterTable + l_cSQLCommand + [;]
            if ::SQLExec("DeleteField",l_cSQLCommand)
                for each l_cFieldName in l_aFieldNames
                    l_cFieldNameFixedCase := ::CaseFieldName(l_cNamespaceAndTableNameFixedCase,l_cFieldName)
                    if !empty(l_cFieldNameFixedCase)
                        hb_HDel(::p_hMetadataTable[l_cNamespaceAndTableNameFixedCase][HB_ORM_SCHEMA_FIELD],l_cFieldNameFixedCase)
                    endif
                endfor
            else
                l_lResult := .f.
                l_cLastError := ::GetSQLExecErrorMessage()
                hb_orm_SendToDebugView([Failed Delete Field(s) in "]+par_cNamespaceAndTableName+[".   Error Text=]+l_cLastError)
            endif
        endif

    endif

endif

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method TableExists(par_cNamespaceAndTableName) class hb_orm_SQLConnect  // Is namespace and table name case insensitive
local l_lResult
local l_cSQLCommand
local l_cNamespaceAndTableName := ::NormalizeTableNameInternal(par_cNamespaceAndTableName)
local l_nPos,l_cNamespaceName,l_cTableName

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cSQLCommand  := [SELECT count(*) as count FROM information_schema.tables WHERE lower(table_schema) = ']+lower(::GetDatabase())+[' AND lower(table_name) = ']+lower(::NormalizeTableNamePhysical(l_cNamespaceAndTableName))+[';]
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_nPos           := at(".",l_cNamespaceAndTableName)   // Will always be set, due to calling NormalizeTableNameInternal() before
    l_cNamespaceName := left(l_cNamespaceAndTableName,l_nPos-1)
    l_cTableName     := substr(l_cNamespaceAndTableName,l_nPos+1)

    l_cSQLCommand  := [SELECT count(*) AS count FROM information_schema.tables WHERE lower(table_schema) = ']+lower(l_cNamespaceName)  +[' AND lower(table_name) = ']+lower(l_cTableName)+[';]
endcase

if ::SQLExec("TableExists",l_cSQLCommand,"TableExistsResult")
    l_lResult := (TableExistsResult->count > 0)
else
    l_lResult := .f.
    hb_orm_SendToDebugView([Failed TableExists "]+par_cNamespaceAndTableName+[".   Error Text=]+::GetSQLExecErrorMessage())
endif

CloseAlias("TableExistsResult")

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method FieldExists(par_cNamespaceAndTableName,par_cFieldName) class hb_orm_SQLConnect
local l_lResult
local l_cSQLCommand
local l_cNamespaceAndTableName := ::NormalizeTableNameInternal(par_cNamespaceAndTableName)
local l_nPos,l_cNamespaceName,l_cTableName

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cSQLCommand  := [SELECT count(*) as count FROM information_schema.columns WHERE lower(table_schema) = ']+lower(::GetDatabase())+[' AND lower(table_name) = ']+lower(::NormalizeTableNamePhysical(l_cNamespaceAndTableName))+[' AND lower(column_name) = ']+lower(par_cFieldName)+[';]

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_nPos           := at(".",l_cNamespaceAndTableName)
    l_cNamespaceName := left(l_cNamespaceAndTableName,l_nPos-1)
    l_cTableName     := substr(l_cNamespaceAndTableName,l_nPos+1)

    l_cSQLCommand  := [SELECT count(*) AS count FROM information_schema.columns WHERE lower(table_schema) = ']+lower(l_cNamespaceName)  +[' AND lower(table_name) = ']+lower(l_cTableName)+[' AND lower(column_name) = ']+lower(par_cFieldName)+[';]
endcase

if ::SQLExec("FieldExists",l_cSQLCommand,"FieldExistsResult")
    l_lResult := (FieldExistsResult->count > 0)
else
    l_lResult := .f.
    hb_orm_SendToDebugView([Failed TableExists "]+par_cNamespaceAndTableName+[".   Error Text=]+::GetSQLExecErrorMessage())
endif

CloseAlias("FieldExistsResult")

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method UpdateORMSupportSchema() class hb_orm_SQLConnect
local l_lResult := .f.   // return .t. if overall schema changed
local l_cSQLScript,l_ErrorInfo   // can be removed later, only used during code testing
local l_PreviousNamespaceName
local l_hWharfConfig

l_hWharfConfig := ;
    {"DataWharfVersion"=>4.3,;
     "Enumerations"=>{=>},;
     "Tables"=>;
        {"hborm.SchemaAndDataErrorLog"=>{HB_ORM_SCHEMA_FIELD=>;
            {"pk"            =>{"Type"=>"IB","AutoIncrement"=>.t.};
            ,"eventid"       =>{"Type"=>"CV","Length"=>50,"Nullable"=>.t.};
            ,"datetime"      =>{"Type"=>"DTZ"};
            ,"ip"            =>{"Type"=>"CV","Length"=>43};
            ,"namespacename" =>{"Type"=>"CV","Length"=>254,"Nullable"=>.t.};
            ,"tablename"     =>{"Type"=>"CV","Length"=>254,"Nullable"=>.t.};
            ,"recordpk"      =>{"Type"=>"IB","Nullable"=>.t.};
            ,"errormessage"  =>{"Type"=>"M","Nullable"=>.t.};
            ,"appstack"      =>{"Type"=>"M","Nullable"=>.t.}};
                                    };
        ,"hborm.SchemaAutoTrimLog"=>{HB_ORM_SCHEMA_FIELD=>;
            {"pk"            =>{"Type"=>"IB","AutoIncrement"=>.t.};
            ,"eventid"       =>{"Type"=>"CV","Length"=>50,"Nullable"=>.t.};
            ,"datetime"      =>{"Type"=>"DTZ"};
            ,"ip"            =>{"Type"=>"CV","Length"=>43};
            ,"namespacename" =>{"Type"=>"CV","Length"=>254,"Nullable"=>.t.};
            ,"tablename"     =>{"Type"=>"CV","Length"=>254};
            ,"recordpk"      =>{"Type"=>"IB"};
            ,"fieldname"     =>{"Type"=>"CV","Length"=>254};
            ,"fieldtype"     =>{"Type"=>"C","Length"=>3};
            ,"fieldlen"      =>{"Type"=>"I"};
            ,"fieldvaluer"   =>{"Type"=>"R","Nullable"=>.t.};
            ,"fieldvaluem"   =>{"Type"=>"M","Nullable"=>.t.}};
                                };
        ,"hborm.NamespaceTableNumber"=>{HB_ORM_SCHEMA_FIELD=>;
            {"pk"           =>{"Type"=>"I","AutoIncrement"=>.t.};   //Will never have more than 2**32 tables.
            ,"namespacename"=>{"Type"=>"CV","Length"=>254,"Nullable"=>.t.};
            ,"tablename"    =>{"Type"=>"CV","Length"=>254}};
                                ,HB_ORM_SCHEMA_INDEX=>;
            {"namespacename"=>{"Expression"=>"namespacename"};
            ,"tablename"    =>{"Expression"=>"tablename"}}};
        ,"hborm.WharfConfig"=>{HB_ORM_SCHEMA_FIELD=>;
            {"pk"                  =>{"Type"=>"I","AutoIncrement"=>.t.};
            ,"taskname"            =>{"Type"=>"CV","Length"=>50,"Nullable"=>.t.};      // Since the pk is not constant it is better to Search/Add by a Task Name
            ,"datetime"            =>{"Type"=>"DTZ","Nullable"=>.t.};                  // Time the task ran last
            ,"ip"                  =>{"Type"=>"CV","Length"=>43,"Nullable"=>.t.};      // Where the task ran
            ,"generationtime"      =>{"Type"=>"CV","Length"=>24,"Nullable"=>.t.};      // The GenerationTime of a WharfConfig structure.
            ,"generationsignature" =>{"Type"=>"CV","Length"=>36,"Nullable"=>.t.}}};    // The GenerationSignature of a WharfConfig structure.
        ,"hborm.SchemaVersion"=>{HB_ORM_SCHEMA_FIELD=>;
            {"pk"     =>{"Type"=>"I","AutoIncrement"=>.t.};
            ,"name"   =>{"Type"=>"CV","Length"=>254};
            ,"version"=>{"Type"=>"I"}};
                            };
        };
    }

l_PreviousNamespaceName := ::SetCurrentNamespaceName(::p_HBORMNamespace)

if el_AUnpack(::MigrateSchema(l_hWharfConfig),,@l_cSQLScript,@l_ErrorInfo) <> 0
    // altd()
    l_lResult = .t.  // Will assume the schema change worked.
endif

::SetCurrentNamespaceName(l_PreviousNamespaceName)

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method UpdateORMNamespaceTableNumber() class hb_orm_SQLConnect
local l_cSQLCommand

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    TEXT TO VAR l_cSQLCommand
INSERT INTO `hborm.NamespaceTableNumber` (tablename)
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
 LEFT OUTER JOIN `hborm.NamespaceTableNumber` AS TablesOnFile ON AllTables.tablename = TablesOnFile.tablename
 WHERE TablesOnFile.tablename IS NULL
    ENDTEXT

    if ::MySQLEngineConvertIdentifierToLowerCase
        l_cSQLCommand := strtran(l_cSQLCommand,"NamespaceTableNumber","NamespaceTableNumber")
    endif

    if !(::p_HBORMNamespace == "hborm")
        // l_cSQLCommand := strtran(l_cSQLCommand,"hborm",::FormatIdentifier(::p_HBORMNamespace))
        if ::MySQLEngineConvertIdentifierToLowerCase
            l_cSQLCommand := strtran(l_cSQLCommand,"hborm",lower(::p_HBORMNamespace))
        else
            l_cSQLCommand := strtran(l_cSQLCommand,"hborm",::p_HBORMNamespace)
        endif
    endif

    l_cSQLCommand := strtran(l_cSQLCommand,"-DataBase-",::GetDatabase())

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    TEXT TO VAR l_cSQLCommand
WITH
 ListOfTables AS (
    SELECT DISTINCT
           columns.table_schema::text as namespacename,
           columns.table_name::text   as tablename
    FROM information_schema.columns
    INNER JOIN information_schema.tables ON columns.table_schema = tables.table_schema AND columns.table_name = tables.table_name
    WHERE NOT (lower(left(columns.table_name,11)) = 'schemacache' OR lower(columns.table_schema) in ('information_schema','pg_catalog'))
 AND   tables.table_type = 'BASE TABLE'
),
 ListOfMissingTablesInNamespaceTableNumber AS (
    SELECT AllTables.namespacename,
           AllTables.tablename
    FROM ListOfTables AS AllTables
    LEFT OUTER JOIN hborm."NamespaceTableNumber" AS TablesOnFile ON AllTables.namespacename = TablesOnFile.namespacename and AllTables.tablename = TablesOnFile.tablename
    WHERE TablesOnFile.tablename IS NULL
)
 INSERT INTO hborm."NamespaceTableNumber" ("namespacename","tablename") SELECT namespacename,tablename FROM ListOfMissingTablesInNamespaceTableNumber;
    ENDTEXT

    if ::PostgreSQLIdentifierCasing != 1  //HB_ORM_POSTGRESQL_CASE_SENSITIVE
        l_cSQLCommand := Strtran(l_cSQLCommand,["NamespaceTableNumber"],[NamespaceTableNumber])
    endif

    if !(::p_HBORMNamespace == "hborm")
        l_cSQLCommand := strtran(l_cSQLCommand,"hborm",::FormatIdentifier(::p_HBORMNamespace))
    endif

endcase

::SQLExec("UpdateORMNamespaceTableNumber",l_cSQLCommand)

return NIL
//-----------------------------------------------------------------------------------------------------------------
method GetSchemaDefinitionVersion(par_cSchemaDefinitionName) class hb_orm_SQLConnect                         // Since calling ::MigrateSchema() is cumulative with different hTableSchemaDefinition, each can be named and have a different version.
local l_Version := -1  //To report if failed to retrieve the version number.
local l_cSQLCommand
local l_cFormattedTableName

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    if ::TableExists(::p_HBORMNamespace+".SchemaVersion")
        l_cFormattedTableName := ::FormatIdentifier(::p_HBORMNamespace+[.]+"SchemaVersion")

        l_cSQLCommand := [SELECT pk,version]
        l_cSQLCommand += [ FROM ]+l_cFormattedTableName
        l_cSQLCommand += [ WHERE lower(name) = ']+strtran(lower(par_cSchemaDefinitionName),"'","")+[';]
        if ::SQLExec("GetSchemaDefinitionVersion",l_cSQLCommand,"SchemaVersion")
            if !empty(SchemaVersion->(reccount()))
                l_Version := SchemaVersion->version
            endif
        else
            ::p_ErrorMessage := [Failed SQL on SchemaVersion (1).]
            hb_orm_SendToDebugView([Failed SQL on SchemaVersion (1).   Error Text=]+::GetSQLExecErrorMessage())
        endif
    endif

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    if ::TableExists(::p_HBORMNamespace+".SchemaVersion")
        l_cFormattedTableName := ::FormatIdentifier(::p_HBORMNamespace+[.]+"SchemaVersion")

        l_cSQLCommand := [SELECT pk,version]
        l_cSQLCommand += [ FROM ]+l_cFormattedTableName
        l_cSQLCommand += [ WHERE lower(name) = ']+strtran(lower(par_cSchemaDefinitionName),"'","")+[';]

        if ::SQLExec("GetSchemaDefinitionVersion",l_cSQLCommand,"SchemaVersion")
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
method SetSchemaDefinitionVersion(par_cSchemaDefinitionName,par_iVersion) class hb_orm_SQLConnect                         // Since calling ::MigrateSchema() is cumulative with different hTableSchemaDefinition, each can be named and have a different version.
local l_lResult := .f.
local l_cSQLCommand := ""
local l_cFormattedTableName

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cFormattedTableName := ::FormatIdentifier(::p_HBORMNamespace+[.]+"SchemaVersion")

    l_cSQLCommand := [SELECT pk,version]
    l_cSQLCommand += [ FROM ]+l_cFormattedTableName
    l_cSQLCommand += [ WHERE lower(name) = ']+strtran(lower(par_cSchemaDefinitionName),"'","")+[';]

    if ::SQLExec("SetSchemaDefinitionVersion",l_cSQLCommand,"SchemaVersion")
        if empty(SchemaVersion->(reccount()))
            //Add an entry
            l_cSQLCommand := [INSERT INTO ]+l_cFormattedTableName+[ (]
            l_cSQLCommand += [name,version]
            l_cSQLCommand += [) VALUES (]
            l_cSQLCommand += [']+strtran(par_cSchemaDefinitionName,"'","")+[',]+trans(par_iVersion)
            l_cSQLCommand += [);]
        else
            if SchemaVersion->pk == 0  // To fix an initial bug in the hb_orm
                ::LoadMetadata("SetSchemaDefinitionVersion - 1")
                ::DeleteField(l_cFormattedTableName,"pk")  // the pk field will be readded correctly.
                ::UpdateORMSupportSchema()  //"MySQL"
                ::LoadMetadata("SetSchemaDefinitionVersion - 2")  // Only called again since the ORM schema changed
                ::SQLExec("SetSchemaDefinitionVersion",l_cSQLCommand,"SchemaVersion")
            endif

            //Update Version
            l_cSQLCommand := [UPDATE ]+l_cFormattedTableName+[ SET ]
            l_cSQLCommand += [version=]+trans(par_iVersion)
            l_cSQLCommand += [ WHERE pk=]+trans(SchemaVersion->pk)+[;]
        endif
        if ::SQLExec("SetSchemaDefinitionVersion",l_cSQLCommand)
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
    l_cFormattedTableName := ::FormatIdentifier(::p_HBORMNamespace+[.]+"SchemaVersion")

    l_cSQLCommand := [SELECT pk,version]
    l_cSQLCommand += [ FROM ]+l_cFormattedTableName
    l_cSQLCommand += [ WHERE lower(name) = ']+strtran(lower(par_cSchemaDefinitionName),"'","")+[';]

    if ::SQLExec("SetSchemaDefinitionVersion",l_cSQLCommand,"SchemaVersion")
        if empty(SchemaVersion->(reccount()))
            //Add an entry
            l_cSQLCommand := [INSERT INTO ]+l_cFormattedTableName+[ (]
            l_cSQLCommand += [name,version]
            l_cSQLCommand += [) VALUES (]
            l_cSQLCommand += [']+strtran(par_cSchemaDefinitionName,"'","")+[',]+trans(par_iVersion)
            l_cSQLCommand += [);]
        else
            if SchemaVersion->pk == 0  // To fix an initial bug in the hb_orm
                ::LoadMetadata("SetSchemaDefinitionVersion - 3")
                ::DeleteField(l_cFormattedTableName,"pk")  // the pk field will be readded correctly.
                ::UpdateORMSupportSchema()  //"PostgreSQL"
                ::LoadMetadata("SetSchemaDefinitionVersion - 4")  // Only called again since the ORM schema changed
                ::SQLExec("SetSchemaDefinitionVersion",l_cSQLCommand,"SchemaVersion")
            endif

            //Update Version
            l_cSQLCommand := [UPDATE ]+l_cFormattedTableName+[ SET ]
            l_cSQLCommand += [version=]+trans(par_iVersion)
            l_cSQLCommand += [ WHERE pk=]+trans(SchemaVersion->pk)+[;]
        endif
        if ::SQLExec("SetSchemaDefinitionVersion",l_cSQLCommand)
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
function hb_orm_RootIndexName(par_cTableName,par_cIndexNameOnFile)
// local l_cIndexName := strtran(lower(par_cIndexNameOnFile),".","_")  // Had to also convert the "." to "_" to deal with MySQL lack of schema, and the orm prefixing table name with what the namespace name would have been.
// local l_cTableName := strtran(par_cTableName,".","_")

local l_cIndexName := lower(par_cIndexNameOnFile)
local l_cTableName := par_cTableName

do case
case (left(l_cIndexName,len(l_cTableName)+1) == lower(l_cTableName)+"_") .and. right(l_cIndexName,4) == "_idx"  // A PostgreSQL way to make a unique index name
    l_cIndexName := substr(l_cIndexName,len(l_cTableName)+2,len(par_cIndexNameOnFile)-len(l_cTableName)-1-4)

case right(l_cIndexName,4) == "_idx"  // A MySQL to make a unique index name
    l_cIndexName := left(l_cIndexName,len(l_cIndexName)-4)

endcase

return l_cIndexName
//-----------------------------------------------------------------------------------------------------------------
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
        case el_IsInlist(upper(l_cFieldDefault),"FALSE",".F.","F","WHARF-FALSE")
            l_cFieldDefault = "0"
        case el_IsInlist(upper(l_cFieldDefault),"TRUE",".T.","T","WHARF-TRUE")
            l_cFieldDefault = "1"
        endcase
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        do case
        case el_IsInlist(upper(l_cFieldDefault),"0","FALSE",".F.","F","WHARF-FALSE")
            l_cFieldDefault = "false"
        case el_IsInlist(upper(l_cFieldDefault),"1","TRUE",".T.","T","WHARF-TRUE")
            l_cFieldDefault = "true"
        endcase
    endcase

case par_cFieldType == "UUI"
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        do case
        case el_IsInlist(upper(l_cFieldDefault),"UUI","UUID","UUI()","UUID()","WHARF-UUID()")
            l_cFieldDefault = "uuid()"
        endcase
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        do case
        case el_IsInlist(upper(l_cFieldDefault),"UUI","UUID","UUI()","UUID()","WHARF-UUID()")
            l_cFieldDefault = "gen_random_uuid()"
        endcase
    endcase

case el_IsInlist(par_cFieldType,"TOZ","TO","DTZ","DT")
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        do case
        case el_IsInlist(upper(l_cFieldDefault),"NOW","NOW()","WHARF-NOW()")
            if par_nFieldDec == 0
                l_cFieldDefault = "current_timestamp()"
            else
                l_cFieldDefault = "current_timestamp("+Trans(par_nFieldDec)+")"
            endif
        endcase
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        do case
        case el_IsInlist(upper(l_cFieldDefault),"NOW","NOW()","WHARF-NOW()")
            l_cFieldDefault := "now()"
        endcase
    endcase

case el_IsInlist(par_cFieldType,"D")
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        do case
        case el_IsInlist(upper(l_cFieldDefault),"TODAY","TODAY()","WHARF-TODAY()")
            l_cFieldDefault = "current_date()"
        endcase
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        do case
        case el_IsInlist(upper(l_cFieldDefault),"TODAY","TODAY()","WHARF-TODAY()")
            l_cFieldDefault := "current_date()"
        endcase
    endcase

// //_M_  Add on 
// //https://www.postgresqltutorial.com/postgresql-tutorial/postgresql-serial/

// case el_IsInlist(par_cFieldType,"I","IB","IS","N")
//     do case
//     case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
//         do case
//         case el_IsInlist(upper(l_cFieldDefault),"AUTOINCREMENT", "AUTOINCREMENT()","WHARF-AUTOINCREMENT()")
//             // l_cFieldDefault = "current_date()"
//         endcase
//     case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
//         do case
//         case el_IsInlist(upper(l_cFieldDefault),"AUTOINCREMENT", "AUTOINCREMENT()","WHARF-AUTOINCREMENT()")
//             // l_cFieldDefault := "current_date()"
//         endcase
//     endcase
endcase

return l_cFieldDefault
//-----------------------------------------------------------------------------------------------------------------
method SanitizeFieldDefaultFromDefaultBehavior(par_cSQLEngineType,par_cFieldType,par_lFieldNullable,par_cFieldDefault) class hb_orm_SQLConnect
local l_cFieldDefault := par_cFieldDefault
local l_nPos

do case
case hb_IsNIL(l_cFieldDefault)
    //Nothing todo

case par_cSQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    do case
    case el_IsInlist(par_cFieldType,"I","IB","IS","N","Y","L","OID")
        if (right(par_cFieldDefault,1) == "0" .and. val(par_cFieldDefault) == 0)
            l_cFieldDefault := NIL
        elseif par_cFieldDefault == "NULL"
            l_cFieldDefault := NIL
        endif

    // case par_cFieldType == "L"  //Not tested yet (2023/12/13)
    //     if par_cFieldDefault == "false" .or. par_cFieldDefault == ""
    //         l_cFieldDefault := NIL
    //     endif

    case el_IsInlist(par_cFieldType,"C","CV")
        if par_cFieldDefault == "''"
            l_cFieldDefault := NIL
        elseif par_cFieldDefault == "NULL"
            l_cFieldDefault := NIL
        endif

    case par_cFieldType == "DTZ"
        if el_IsInlist(par_cFieldDefault,"'0000-00-00 00:00:00'","''")
            l_cFieldDefault := NIL
        elseif par_cFieldDefault == "NULL"
            l_cFieldDefault := NIL
        endif
        
    case par_cFieldType == "D"
        if el_IsInlist(par_cFieldDefault,"'0000-00-00'","''")
            l_cFieldDefault := NIL
        elseif par_cFieldDefault == "NULL"
            l_cFieldDefault := NIL
        endif
        
    case par_cFieldType == "UUI"
        if el_IsInlist(par_cFieldDefault,"'00000000-0000-0000-0000-000000000000'","''")
            l_cFieldDefault := NIL
        elseif par_cFieldDefault == "NULL"
            l_cFieldDefault := NIL
        endif
        
    case el_IsInlist(par_cFieldType,"JS","JSB")
        if el_IsInlist(par_cFieldDefault,"'{}'","''")
            l_cFieldDefault := NIL
        elseif par_cFieldDefault == "NULL"
            l_cFieldDefault := NIL
        endif
        
    case par_lFieldNullable
        if par_cFieldDefault == "NULL"
            l_cFieldDefault := NIL
        endif

    endcase

case par_cSQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    do case
    case par_cFieldType == "N"
        if par_cFieldDefault == "0"
            l_cFieldDefault := NIL
        elseif el_IsInlist(par_cFieldDefault,"''::numeric","'0'::numeric","''","0")
            l_cFieldDefault := NIL
        elseif right(par_cFieldDefault,len("::numeric")) == "::numeric"
            l_cFieldDefault = left(par_cFieldDefault,len(par_cFieldDefault)-len("::numeric"))
        endif

    case par_cFieldType == "I"
        if par_cFieldDefault == "0"
            l_cFieldDefault := NIL
        elseif el_IsInlist(par_cFieldDefault,"''::integer","'0'::integer","''","0")
            l_cFieldDefault := NIL
        elseif right(par_cFieldDefault,len("::integer")) == "::integer"
            l_cFieldDefault = left(par_cFieldDefault,len(par_cFieldDefault)-len("::integer"))
        endif

    case par_cFieldType == "IB"
        if par_cFieldDefault == "0"
            l_cFieldDefault := NIL
        elseif el_IsInlist(par_cFieldDefault,"''::bigint","'0'::bigint","''","0")
            l_cFieldDefault := NIL
        elseif right(par_cFieldDefault,len("::bigint")) == "::bigint"
            l_cFieldDefault = left(par_cFieldDefault,len(par_cFieldDefault)-len("::bigint"))
        endif

    case par_cFieldType == "IS"
        if par_cFieldDefault == "0"
            l_cFieldDefault := NIL
        elseif el_IsInlist(par_cFieldDefault,"''::smallint","'0'::smallint","''","0")
            l_cFieldDefault := NIL
        elseif right(par_cFieldDefault,len("::smallint")) == "::smallint"
            l_cFieldDefault = left(par_cFieldDefault,len(par_cFieldDefault)-len("::smallint"))
        endif

    case par_cFieldType == "Y"
        if par_cFieldDefault == "0"
            l_cFieldDefault := NIL
        elseif el_IsInlist(par_cFieldDefault,"''::money","'0'::money","''","0")
            l_cFieldDefault := NIL
        elseif right(par_cFieldDefault,len("::money")) == "::money"
            l_cFieldDefault = left(par_cFieldDefault,len(par_cFieldDefault)-len("::money"))
        endif

    case par_cFieldType == "L"
        if par_cFieldDefault == "false"
            l_cFieldDefault := NIL
        endif

    case par_cFieldType == "C"
        if el_IsInlist(par_cFieldDefault,"''::bpchar","''")
            l_cFieldDefault := NIL
        elseif right(par_cFieldDefault,len("::bpchar")) == "::bpchar"
            l_cFieldDefault = left(par_cFieldDefault,len(par_cFieldDefault)-len("::bpchar"))
        endif
        
    case par_cFieldType == "M"
        if el_IsInlist(par_cFieldDefault,"''::text","''")
            l_cFieldDefault := NIL
        elseif right(par_cFieldDefault,len("::text")) == "::text"
            l_cFieldDefault = left(par_cFieldDefault,len(par_cFieldDefault)-len("::text"))
        endif
        
    case par_cFieldType == "CV"
        if el_IsInlist(par_cFieldDefault,"''::character varying","''")
            l_cFieldDefault := NIL
        elseif right(par_cFieldDefault,len("::character varying")) == "::character varying"
            l_cFieldDefault = left(par_cFieldDefault,len(par_cFieldDefault)-len("::character varying"))
        endif
        
    case par_cFieldType == "DTZ"
        if el_IsInlist(par_cFieldDefault,"'-infinity'::timestamp with time zone","'-infinity'","''")
            l_cFieldDefault := NIL
        endif
        
    case par_cFieldType == "DT"
        if el_IsInlist(par_cFieldDefault,"'-infinity'::timestamp without time zone","'-infinity'","''")
            l_cFieldDefault := NIL
        endif
        
    case par_cFieldType == "D"
        if el_IsInlist(par_cFieldDefault,"'-infinity'::date","'-infinity'","''")
            l_cFieldDefault := NIL
        endif

    case par_cFieldType == "UUI"
        if el_IsInlist(par_cFieldDefault,"'00000000-0000-0000-0000-000000000000'::uuid","'00000000-0000-0000-0000-000000000000'","''")
            l_cFieldDefault := NIL
        endif
        
    case el_IsInlist(par_cFieldType,"JS","JSB")
        if el_IsInlist(par_cFieldDefault,"'{}'::json","'{}'::jsonb","'{}'","''")
            l_cFieldDefault := NIL
        endif
        
    case par_cFieldType == "OID"
        if par_cFieldDefault == "0"
            l_cFieldDefault := NIL
        elseif el_IsInlist(par_cFieldDefault,"''::oid","'0'::oid","''","0")
            l_cFieldDefault := NIL
        elseif right(par_cFieldDefault,len("::oid")) == "::oid"
            l_cFieldDefault = left(par_cFieldDefault,len(par_cFieldDefault)-len("::oid"))
        endif

    case par_lFieldNullable

    endcase

    if !hb_IsNIL(l_cFieldDefault)
        //Get rid of casting
        l_nPos := rat("::",l_cFieldDefault)
        if l_nPos > 0
            l_cFieldDefault := left(l_cFieldDefault,l_nPos-1)
        endif
    endif

endcase
return l_cFieldDefault
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
// Remove any Foreign Key Constraint that and with "_fkc"
method RemoveWharfForeignKeyConstraints(par_hTableSchemaDefinition) class hb_orm_SQLConnect

local l_hTableDefinition
local l_cNamespaceAndTableName
local l_nPos
local l_cNamespaceName
local l_cTableName
local l_hFields
local l_hField
local l_cFieldName
local l_hFieldDefinition
local l_cFieldUsedAs
local l_cParentNamespaceAndTable
local l_cParentNamespaceName
local l_cParentTableName
local l_cSQLCommand
local l_lForeignKeyOptional

if ::UpdateSchemaCache()
    ::LoadMetadata("RemoveWharfForeignKeyConstraints")
endif

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL

    hb_orm_SendToDebugView("DeleteAllOrphanRecords - In Loop")
    for each l_hTableDefinition in par_hTableSchemaDefinition
        l_cNamespaceAndTableName := l_hTableDefinition:__enumKey()

        l_nPos := at(".",l_cNamespaceAndTableName)
        if empty(l_nPos)
            l_cNamespaceName := "public"
            l_cTableName     := l_cNamespaceAndTableName
        else
            l_cNamespaceName := left(l_cNamespaceAndTableName,l_nPos-1)
            l_cTableName     := substr(l_cNamespaceAndTableName,l_nPos+1)
        endif
        if l_cNamespaceName == "hborm" .and. !(::p_HBORMNamespace == "hborm")
            l_cNamespaceName := ::p_HBORMNamespace
        endif
        // l_cNamespaceAndTableName := l_cNamespaceName+"."+l_cTableName

        l_hFields := l_hTableDefinition[HB_ORM_SCHEMA_FIELD]

        for each l_hField in l_hFields
            l_cFieldName       := l_hField:__enumKey()
            l_hFieldDefinition := l_hField:__enumValue()
            l_cFieldUsedAs     := hb_HGetDef(l_hFieldDefinition,"UsedAs","")
            if l_cFieldUsedAs == "Foreign"
                l_cParentNamespaceAndTable := hb_HGetDef(l_hFieldDefinition,"ParentTable","")

                if !empty(l_cParentNamespaceAndTable)

                    l_lForeignKeyOptional := hb_HGetDef(l_hFieldDefinition,"ForeignKeyOptional",.f.)

                    l_nPos := at(".",l_cParentNamespaceAndTable)
                    if empty(l_nPos)
                        l_cParentNamespaceName := "public"
                        l_cParentTableName     := l_cParentNamespaceAndTable
                    else
                        l_cParentNamespaceName := left(l_cParentNamespaceAndTable,l_nPos-1)
                        l_cParentTableName     := substr(l_cParentNamespaceAndTable,l_nPos+1)
                    endif
                    if l_cParentNamespaceName == "hborm" .and. !(::p_HBORMNamespace == "hborm")
                        l_cParentNamespaceName := ::p_HBORMNamespace
                    endif

                    //Will try to remove case sensitive and all lower case constraint name
                    l_cSQLCommand := [ALTER TABLE "]+l_cNamespaceName+["."]+l_cTableName+[" DROP CONSTRAINT IF EXISTS "]+l_cFieldName+[_fkc"] //+CRLF
                    if ! ::SQLExec("0350f45e-a7ab-49d4-8dd0-93b069b24a2f",l_cSQLCommand)
                        hb_orm_SendToDebugView("RemoveWharfForeignKeyConstraints - Failed on Table: "+l_cTableName)
                    endif

                    if !(l_cFieldName == lower(l_cFieldName))
                        l_cSQLCommand := [ALTER TABLE "]+l_cNamespaceName+["."]+l_cTableName+[" DROP CONSTRAINT IF EXISTS "]+lower(l_cFieldName)+[_fkc"] //+CRLF
                        if ! ::SQLExec("d81496b0-4546-46d3-81a9-e25a076b33dd",l_cSQLCommand)
                            hb_orm_SendToDebugView("RemoveWharfForeignKeyConstraints - Failed on Table: "+l_cTableName)
                        endif
                    endif

                endif

            endif

        endfor

    endfor

endcase

return nil
//-----------------------------------------------------------------------------------------------------------------
// Generate the Script to Add/Update if missing any Foreign Key Constraint that and with "_fkc"
method GenerateMigrateForeignKeyConstraintsScript(par_hTableSchemaDefinition,par_lSimulationMode,;
                                                                             par_hAppliedRenameNamespace,;
                                                                             par_hAppliedRenameTable,;
                                                                             par_hAppliedRenameColumn) class hb_orm_SQLConnect

local l_hTableDefinition
local l_cNamespaceAndTableName
local l_nPos
local l_cNamespaceName
local l_cTableName
local l_hFields
local l_hField
local l_cFieldName
local l_hFieldDefinition
local l_cFieldUsedAs
local l_cParentNamespaceAndTable
local l_cParentNamespaceName
local l_cParentTableName
local l_cParentTablePrimaryKey
local l_cSQLScript := ""
local l_lForeignKeyOptional
local l_cOnDelete
local l_cSQLForeignKeyConstraints
local l_oCursor
local l_cConstraintAction
local l_cCurrentOnUpdateConstraintAction
local l_cCurrentOnDeleteConstraintAction
local l_lAddConstraints
local l_hPrimaryKeys
local l_lSimulationMode := nvl(par_lSimulationMode,.f.)
local l_cNamespaceFrom
local l_cNamespaceTo
local l_cTableFrom
local l_cTableTo
local l_cNamespaceAndTableFrom
local l_cNamespaceAndTableTo
local l_cColumnNameTo
local l_cColumnNameFrom

if !l_lSimulationMode
    if ::UpdateSchemaCache()
        ::LoadMetadata("GenerateMigrateForeignKeyConstraintsScript")
    endif
endif

l_hPrimaryKeys := ::GetListOfPrimaryKeysForAllTables(par_hTableSchemaDefinition)

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL

// confupdtype char
//     Foreign key update action code: a = no action, r = restrict, c = cascade, n = set null, d = set default

// confdeltype char
//     Foreign key deletion action code: a = no action, r = restrict, c = cascade, n = set null, d = set default

    l_cSQLForeignKeyConstraints := [select ]
    l_cSQLForeignKeyConstraints += [    con."ChildNamespace" as "ChildNamespace",]
    l_cSQLForeignKeyConstraints += [    con."ChildTable"     as "ChildTable",]
    l_cSQLForeignKeyConstraints += [    att2.attname         as "ChildColumn", ]
    l_cSQLForeignKeyConstraints += [    ns.nspname           as "ParentNamespace",]
    l_cSQLForeignKeyConstraints += [    cl.relname           as "ParentTable", ]
    l_cSQLForeignKeyConstraints += [    att.attname          as "ParentColumn",]
    l_cSQLForeignKeyConstraints += [    con.conname          as "ConstraintName",]
    l_cSQLForeignKeyConstraints += [    con."UpdateAction"   as "UpdateAction",]
    l_cSQLForeignKeyConstraints += [    con."DeleteAction"   as "DeleteAction"]
    l_cSQLForeignKeyConstraints += [from]
    l_cSQLForeignKeyConstraints += [   (select ]
    l_cSQLForeignKeyConstraints += [        unnest(con1.conkey)  as "parent", ]
    l_cSQLForeignKeyConstraints += [        unnest(con1.confkey) as "child", ]
    l_cSQLForeignKeyConstraints += [        con1.confrelid, ]
    l_cSQLForeignKeyConstraints += [        con1.conrelid,]
    l_cSQLForeignKeyConstraints += [        con1.conname,]
    l_cSQLForeignKeyConstraints += [        con1.confupdtype as "UpdateAction",]
    l_cSQLForeignKeyConstraints += [        con1.confdeltype as "DeleteAction",]
    l_cSQLForeignKeyConstraints += [        cl.relname     as "ChildTable",]
    l_cSQLForeignKeyConstraints += [        ns.nspname     as "ChildNamespace"]
    l_cSQLForeignKeyConstraints += [    from ]
    l_cSQLForeignKeyConstraints += [        pg_class cl]
    l_cSQLForeignKeyConstraints += [        join pg_namespace ns on cl.relnamespace = ns.oid]
    l_cSQLForeignKeyConstraints += [        join pg_constraint con1 on con1.conrelid = cl.oid]
    l_cSQLForeignKeyConstraints += [    where con1.contype = 'f']
    l_cSQLForeignKeyConstraints += [    and   ns.nspname not in ('cyanaudit')]
    // l_cSQLForeignKeyConstraints += [--        cl.relname = 'child_table']
    // l_cSQLForeignKeyConstraints += [--        and ns.nspname = 'child_schema']
    l_cSQLForeignKeyConstraints += [   ) con]
    l_cSQLForeignKeyConstraints += [   join pg_attribute att  on att.attrelid = con.confrelid and att.attnum = con.child]
    l_cSQLForeignKeyConstraints += [   join pg_class     cl   on cl.oid = con.confrelid]
    l_cSQLForeignKeyConstraints += [   join pg_namespace ns   on cl.relnamespace = ns.oid]
    l_cSQLForeignKeyConstraints += [   join pg_attribute att2 on att2.attrelid = con.conrelid and att2.attnum = con.parent]

    if ! ::SQLExec("419ada7d-7e90-4c30-9c95-0d5c15ccdfd7",l_cSQLForeignKeyConstraints,"hb_orm_ListOfForeignKeyConstraints")
        hb_orm_SendToDebugView("GenerateMigrateForeignKeyConstraintsScript - Failed on ListOfForeignKeyConstraints")
    else
        l_oCursor := hb_orm_Cursor():Init():Associate("hb_orm_ListOfForeignKeyConstraints")

        select hb_orm_ListOfForeignKeyConstraints
        if l_lSimulationMode
        // ExportTableToHtmlFile("hb_orm_ListOfForeignKeyConstraints","D:\336\BeforeReplace","From PostgreSQL",,,.t.)

        //-- Apply Namespace renames, which also affect table names
            for each l_cNamespaceTo in par_hAppliedRenameNamespace
                l_cNamespaceFrom := l_cNamespaceTo:__enumKey()
                replace all ChildNamespace  with l_cNamespaceTo FOR alltrim(field->ChildNamespace)  == l_cNamespaceFrom
                replace all ParentNamespace with l_cNamespaceTo FOR alltrim(field->ParentNamespace) == l_cNamespaceFrom
            endfor

            for each l_cNamespaceAndTableTo in par_hAppliedRenameTable
                l_cNamespaceAndTableFrom := l_cNamespaceAndTableTo:__enumKey()

                l_nPos := at(".",l_cNamespaceAndTableTo)
                if l_nPos > 0
                    l_cNamespaceTo := left(l_cNamespaceAndTableTo,l_nPos-1)
                    l_cTableTo     := substr(l_cNamespaceAndTableTo,l_nPos+1)

                    l_nPos := at(".",l_cNamespaceAndTableFrom)
                    if l_nPos > 0
                        l_cNamespaceFrom := left(l_cNamespaceAndTableFrom,l_nPos-1)
                        l_cTableFrom     := substr(l_cNamespaceAndTableFrom,l_nPos+1)

                        replace all ChildNamespace  with l_cNamespaceTo,;
                                    ChildTable      with l_cTableTo;
                                    FOR alltrim(field->ChildNamespace) == l_cNamespaceFrom .and. alltrim(field->ChildTable) == l_cTableFrom

                        replace all ParentNamespace  with l_cNamespaceTo,;
                                    ParentTable      with l_cTableTo;
                                    FOR alltrim(field->ParentNamespace) == l_cNamespaceFrom .and. alltrim(field->ParentTable) == l_cTableFrom

                    endif
                endif
            endfor

        //-- Apply Table renames
            //Constraints names are not affected by table name changes

        //-- Apply Column renames
            //Rename constraints names that depended on a column being renamed.

            for each l_cColumnNameTo in par_hAppliedRenameColumn
                l_cColumnNameFrom := l_cColumnNameTo:__enumkey
                l_nPos := at(".",l_cColumnNameFrom)
                if l_nPos > 0
                    l_cNamespaceName  := left(l_cColumnNameFrom,l_nPos-1)
                    l_cColumnNameFrom := substr(l_cColumnNameFrom,l_nPos+1)
                    l_nPos := at(".",l_cColumnNameFrom)
                    if l_nPos > 0
                        l_cTableName      := left(l_cColumnNameFrom,l_nPos-1)
                        l_cColumnNameFrom := substr(l_cColumnNameFrom,l_nPos+1)

                        select hb_orm_ListOfForeignKeyConstraints
                        locate for lower(alltrim(field->ChildNamespace)) == lower(l_cNamespaceName) .and.;
                                lower(alltrim(field->ChildTable))     == lower(l_cTableName)     .and.;
                                lower(alltrim(field->ChildColumn))    == lower(l_cColumnNameFrom)
                        if found()
                            l_cSQLScript += [ALTER TABLE IF EXISTS "]+l_cNamespaceName+["."]+l_cTableName+[" RENAME CONSTRAINT "]+lower(l_cColumnNameFrom)+[_fkc" TO "]+lower(l_cColumnNameTo)+[_fkc";]+CRLF
                            replace ChildColumn    with l_cColumnNameTo
                            replace ConstraintName with lower(l_cColumnNameTo)+[_fkc]   // To ensure a future compare will not trigger a DROP+ADD
                        endif

                    endif
                endif
            endfor

        endif

        with object l_oCursor
            :Index("tag1","padr(upper(ChildNamespace+'*'+ChildTable+'*'+ChildColumn+'*'),240)")
            :CreateIndexes()
        endwith

        for each l_hTableDefinition in par_hTableSchemaDefinition
            l_cNamespaceAndTableName := l_hTableDefinition:__enumKey()

            l_nPos := at(".",l_cNamespaceAndTableName)
            if empty(l_nPos)
                l_cNamespaceName := "public"
                l_cTableName     := l_cNamespaceAndTableName
            else
                l_cNamespaceName := left(l_cNamespaceAndTableName,l_nPos-1)
                l_cTableName     := substr(l_cNamespaceAndTableName,l_nPos+1)
            endif
            if l_cNamespaceName == "hborm" .and. !(::p_HBORMNamespace == "hborm")
                l_cNamespaceName := ::p_HBORMNamespace
            endif
            // l_cNamespaceAndTableName := l_cNamespaceName+"."+l_cTableName

            l_hFields := l_hTableDefinition[HB_ORM_SCHEMA_FIELD]

            for each l_hField in l_hFields
                l_cFieldName       := l_hField:__enumKey()
                l_hFieldDefinition := l_hField:__enumValue()
                l_cFieldUsedAs     := hb_HGetDef(l_hFieldDefinition,"UsedAs","")
                if l_cFieldUsedAs == "Foreign"
                    l_cParentNamespaceAndTable := hb_HGetDef(l_hFieldDefinition,"ParentTable","")

                    if !empty(l_cParentNamespaceAndTable)

                        l_lForeignKeyOptional := hb_HGetDef(l_hFieldDefinition,"ForeignKeyOptional",.f.)
                        l_cOnDelete           := hb_HGetDef(l_hFieldDefinition,"OnDelete","")
                        do case
                        case l_cOnDelete == "Protect"
                            l_cConstraintAction := "RESTRICT"
                        case l_cOnDelete == "Cascade"
                            l_cConstraintAction := "CASCADE"
                        case l_cOnDelete == "BreakLink"
                            l_cConstraintAction := "SET NULL"
                        otherwise
                            l_cConstraintAction := ""
                        endcase

                        if empty(l_cConstraintAction)
                            //Check if we should remove a constraint
                            if el_seek(upper(l_cNamespaceName+"*"+l_cTableName+"*"+l_cFieldName+"*"),"hb_orm_ListOfForeignKeyConstraints","tag1")
                                l_cSQLScript += [ALTER TABLE "]+l_cNamespaceName+["."]+l_cTableName+[" DROP CONSTRAINT IF EXISTS "]+l_cFieldName+[_fkc";]
                                l_cSQLScript += [  /*OnFailMessage: Delete Foreign Key Constraint Failed on Table: ]+l_cTableName+[ Field: ]+l_cFieldName+[*/]+CRLF
                                if !(l_cFieldName == lower(l_cFieldName))
                                    l_cSQLScript += [ALTER TABLE "]+l_cNamespaceName+["."]+l_cTableName+[" DROP CONSTRAINT IF EXISTS "]+lower(l_cFieldName)+[_fkc";]
                                    l_cSQLScript += [  /*OnFailMessage: Delete Foreign Key Constraint Failed on Table: ]+l_cTableName+[ Field: ]+lower(l_cFieldName)+[*/]+CRLF
                                endif
                            endif
                        else
                            l_nPos := at(".",l_cParentNamespaceAndTable)
                            if empty(l_nPos)
                                l_cParentNamespaceName := "public"
                                l_cParentTableName     := l_cParentNamespaceAndTable
                            else
                                l_cParentNamespaceName := left(l_cParentNamespaceAndTable,l_nPos-1)
                                l_cParentTableName     := substr(l_cParentNamespaceAndTable,l_nPos+1)
                            endif
                            if l_cParentNamespaceName == "hborm" .and. !(::p_HBORMNamespace == "hborm")
                                l_cParentNamespaceName := ::p_HBORMNamespace
                            endif

                            l_cParentTablePrimaryKey := hb_HGetDef(l_hPrimaryKeys,l_cParentNamespaceName+"."+l_cParentTableName,"")
                            if empty(l_cParentTablePrimaryKey)
                                hb_orm_SendToDebugView("GenerateMigrateForeignKeyConstraintsScript - Failed to find Primary key of Table: "+l_cParentNamespaceName+"."+l_cParentTableName)
                            else

                                if el_seek(upper(l_cNamespaceName+"*"+l_cTableName+"*"+l_cFieldName+"*"),"hb_orm_ListOfForeignKeyConstraints","tag1")
                                    //Compare if the constraint is the same
                                    l_lAddConstraints := .f.

                                    l_cCurrentOnUpdateConstraintAction := alltrim(hb_orm_ListOfForeignKeyConstraints->UpdateAction)
                                    l_cCurrentOnDeleteConstraintAction := alltrim(hb_orm_ListOfForeignKeyConstraints->DeleteAction)

                                    do case
                                    case l_cConstraintAction == "RESTRICT" .and. !(l_cCurrentOnDeleteConstraintAction == "r")   // r = restrict
                                        l_lAddConstraints := .t.
                                    case l_cConstraintAction == "CASCADE"  .and. !(l_cCurrentOnDeleteConstraintAction == "c")   // c = cascade
                                        l_lAddConstraints := .t.
                                    case l_cConstraintAction == "SET NULL" .and. !(l_cCurrentOnDeleteConstraintAction == "n")   // n = set null
                                        l_lAddConstraints := .t.
                                    case !(hb_orm_ListOfForeignKeyConstraints->ParentColumn == l_cParentTablePrimaryKey)
                                        l_lAddConstraints := .t.
                                    case !(hb_orm_ListOfForeignKeyConstraints->ParentNamespace == l_cParentNamespaceName)
                                        l_lAddConstraints := .t.
                                    case !(hb_orm_ListOfForeignKeyConstraints->ParentTable == l_cParentTableName)
                                        l_lAddConstraints := .t.
                                    case !(l_cCurrentOnUpdateConstraintAction == "c")
                                        // We are always going to make the OnUpdate to CASCADE, meaning if the primary key is changed, it will be updated in all the related child tables.
                                        l_lAddConstraints := .t.
                                    case !(hb_orm_ListOfForeignKeyConstraints->ConstraintName == lower(l_cFieldName)+[_fkc])
                                        l_lAddConstraints := .t.   // Probably constraint name is not in lower case
                                    endcase

                                    if l_lAddConstraints   //Remove the Constraints since it is different, will re-add it.
                                        l_cSQLScript += [ALTER TABLE "]+l_cNamespaceName+["."]+l_cTableName+[" DROP CONSTRAINT IF EXISTS "]+l_cFieldName+[_fkc";]
                                        l_cSQLScript += [  /*OnFailMessage: Delete Foreign Key Constraint Failed on Table: ]+l_cTableName+[ Field: ]+l_cFieldName+[*/]+CRLF
                                        if !(l_cFieldName == lower(l_cFieldName))
                                            l_cSQLScript += [ALTER TABLE "]+l_cNamespaceName+["."]+l_cTableName+[" DROP CONSTRAINT IF EXISTS "]+lower(l_cFieldName)+[_fkc";]
                                            l_cSQLScript += [  /*OnFailMessage: Delete Foreign Key Constraint Failed on Table: ]+l_cTableName+[ Field: ]+lower(l_cFieldName)+[*/]+CRLF
                                        endif
                                    endif
                                else
                                    l_lAddConstraints := .t.
                                endif

                                if l_lAddConstraints
                                    l_cSQLScript += [ALTER TABLE "]+l_cNamespaceName+["."]+l_cTableName+[" ADD CONSTRAINT "]+lower(l_cFieldName)+[_fkc" FOREIGN KEY ("]+l_cFieldName+[") REFERENCES "]+l_cParentNamespaceName+["."]+l_cParentTableName+[" ("]+l_cParentTablePrimaryKey+[") ON DELETE ]+l_cConstraintAction+[ ON UPDATE CASCADE;]
                                    l_cSQLScript += [  /*OnFailMessage: Add Foreign Key Constraint Failed on Table: ]+l_cTableName+[ Field: ]+l_cFieldName+[*/]+CRLF
                                endif
                            endif
                        endif
                    endif

                endif

            endfor

        endfor
    endif

    CloseAlias("hb_orm_ListOfForeignKeyConstraints")

endcase

if !empty(l_cSQLScript)
    l_cSQLScript := "--Foreign Key Constraint Changes generated at "+strtran(hb_TSToStr(hb_TSToUTC(hb_DateTime()))," ","T")+"Z"+["]+CRLF+l_cSQLScript
endif

return l_cSQLScript
//-----------------------------------------------------------------------------------------------------------------
// Add any Foreign Key Constraint that and with "_fkc".
method MigrateForeignKeyConstraints(par_hTableSchemaDefinition) class hb_orm_SQLConnect
local l_cSQLScript
local l_nResult := 0   // 0 = Nothing Migrated, 1 = Migrated, -1 = Error Migrating
local l_cLastError := ""
local l_aInstructions
local l_cStatement
local l_nCounter := 0

l_cSQLScript := ::GenerateMigrateForeignKeyConstraintsScript(par_hTableSchemaDefinition)
if !empty(l_cSQLScript)
    l_nResult := 1
    l_aInstructions := hb_ATokens(l_cSQLScript,.t.)
    for each l_cStatement in l_aInstructions
        if !empty(l_cStatement)
            l_nCounter++
            if ::SQLExec("MigrateForeignKeyConstraints",l_cStatement)
                // hb_orm_SendToDebugView("Updated Table Structure.")
            else
//_M_ Extract Error Message from the Command Line.
                l_cLastError := ::GetSQLExecErrorMessage()
                hb_orm_SendToDebugView("Failed MigrateForeignKeyConstraints on instruction "+Trans(l_nCounter)+".   Error Text="+l_cLastError)
                l_nResult := -1
                exit
            endif
        endif
    endfor
    ::UpdateSchemaCache()
    ::LoadMetadata("MigrateSchema")
endif

::UpdateORMNamespaceTableNumber()  // Will call this routine even if no tables where modified.

return {l_nResult,l_cSQLScript,l_cLastError}
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
method RecordCurrentAppliedWharfConfig() class hb_orm_SQLConnect
//123456
local l_cGenerationTime
local l_cGenerationSignature
local l_lResult := .f.
local l_cSQLCommand := ""
local l_cFormattedTableName

if !empty(::p_hWharfConfig)
    l_cGenerationTime      := hb_hGetDef(::p_hWharfConfig,"GenerationTime","")
    l_cGenerationSignature := hb_hGetDef(::p_hWharfConfig,"GenerationSignature","")
    if !empty(l_cGenerationTime) .and. !empty(l_cGenerationSignature)

        do case
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
//_M_

        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
            l_cFormattedTableName := ::FormatIdentifier(::p_HBORMNamespace+[.]+"WharfConfig")

            // ,"hborm.WharfConfig"=>{HB_ORM_SCHEMA_FIELD=>;
            //     {"pk"                  =>{"Type"=>"I","AutoIncrement"=>.t.};
            //     ,"taskname"            =>{"Type"=>"CV","Length"=>50,"Nullable"=>.t.};      // Since the pk is not constant it is better to Search/Add by a Task Name
            //     ,"datetime"            =>{"Type"=>"DTZ","Nullable"=>.t.};                  // Time the task ran last
            //     ,"ip"                  =>{"Type"=>"CV","Length"=>43,"Nullable"=>.t.};      // Where the task ran
            //     ,"generationtime"      =>{"Type"=>"CV","Length"=>24,"Nullable"=>.t.};      // The GenerationTime of a WharfConfig structure.
            //     ,"generationsignature" =>{"Type"=>"CV","Length"=>36,"Nullable"=>.t.}}};    // The GenerationSignature of a WharfConfig structure.

            l_cSQLCommand := [SELECT pk,generationtime,generationsignature]
            l_cSQLCommand += [ FROM ]+l_cFormattedTableName
            l_cSQLCommand += [ WHERE taskname = 'AppliedWharfConfig';]
            if ::SQLExec("RecordCurrentAppliedWharfConfig",l_cSQLCommand,"AppliedWharfConfig")
                if empty(AppliedWharfConfig->(reccount()))
                    //Add an entry
                    l_cSQLCommand := [INSERT INTO ]+l_cFormattedTableName+[ (]
                    l_cSQLCommand += [taskname,generationtime,generationsignature,datetime,ip]
                    l_cSQLCommand += [) VALUES (]
                    l_cSQLCommand += ['AppliedWharfConfig',']+l_cGenerationTime+[',']+l_cGenerationSignature+[',now(),cast(inet_server_addr() as varchar(43))]
                    l_cSQLCommand += [);]
                    ::SQLExec("InsertAppliedWharfConfig",l_cSQLCommand)
                else
                    if (AppliedWharfConfig->generationtime <> l_cGenerationTime) .or. (AppliedWharfConfig->generationsignature <> l_cGenerationSignature)
                        //Update Version
                        l_cSQLCommand := [UPDATE ]+l_cFormattedTableName+[ SET ]
                        l_cSQLCommand += [generationtime=']+l_cGenerationTime+[',generationsignature=']+l_cGenerationSignature+[',datetime=now(),ip=cast(inet_server_addr() as varchar(43))]
                        l_cSQLCommand += [ WHERE pk=]+trans(AppliedWharfConfig->pk)+[;]
                        ::SQLExec("UpdateAppliedWharfConfig",l_cSQLCommand)
                    endif
                endif

            endif
            CloseAlias("AppliedWharfConfig")
        endcase

    endif
endif

return nil
//-----------------------------------------------------------------------------------------------------------------
method GetWharfConfigAppliedStatus()                  // Will use the WharfConfig of the connection.
local l_nResult := -1
        //0  Current Database matches 
        //1  No information on File, meaning we should run the UpdateSchema and stamp it
        //2  Not up-to-date
        //3  Future Schema, meaning running an old app.
        //-1 Error


local l_cGenerationTime
local l_tGenerationTime

local l_cRecordedTime
local l_tRecordedTime

local l_cGenerationSignature
local l_cSQLCommand := ""
local l_cFormattedTableName

if !empty(::p_hWharfConfig)
    l_cGenerationTime      := hb_hGetDef(::p_hWharfConfig,"GenerationTime","")
    l_cGenerationSignature := hb_hGetDef(::p_hWharfConfig,"GenerationSignature","")
    if !empty(l_cGenerationTime) .and. !empty(l_cGenerationSignature)

        do case
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
//_M_

        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
            l_cFormattedTableName := ::FormatIdentifier(::p_HBORMNamespace+[.]+"WharfConfig")

            // ,"hborm.WharfConfig"=>{HB_ORM_SCHEMA_FIELD=>;
            //     {"pk"                  =>{"Type"=>"I","AutoIncrement"=>.t.};
            //     ,"taskname"            =>{"Type"=>"CV","Length"=>50,"Nullable"=>.t.};      // Since the pk is not constant it is better to Search/Add by a Task Name
            //     ,"datetime"            =>{"Type"=>"DTZ","Nullable"=>.t.};                  // Time the task ran last
            //     ,"ip"                  =>{"Type"=>"CV","Length"=>43,"Nullable"=>.t.};      // Where the task ran
            //     ,"generationtime"      =>{"Type"=>"CV","Length"=>24,"Nullable"=>.t.};      // The GenerationTime of a WharfConfig structure.
            //     ,"generationsignature" =>{"Type"=>"CV","Length"=>36,"Nullable"=>.t.}}};    // The GenerationSignature of a WharfConfig structure.

            l_cSQLCommand := [SELECT generationtime,generationsignature]
            l_cSQLCommand += [ FROM ]+l_cFormattedTableName
            l_cSQLCommand += [ WHERE taskname = 'AppliedWharfConfig';]
            if ::SQLExec("RecordCurrentAppliedWharfConfig",l_cSQLCommand,"AppliedWharfConfig")
                if empty(AppliedWharfConfig->(reccount()))
                    l_nResult := 1   // No information on File, meaning we should run the UpdateSchema and stamp it
                else
                    if (AppliedWharfConfig->generationtime == l_cGenerationTime) .and. (AppliedWharfConfig->generationsignature == l_cGenerationSignature)
                        l_nResult := 0   // Current Database matches 
                    else
                        l_cGenerationTime := strtran(l_cGenerationTime,"T"," ")
                        l_cGenerationTime := strtran(l_cGenerationTime,"Z","")
                        l_tGenerationTime := hb_StrToTS(l_cGenerationTime)

                        l_cRecordedTime := AppliedWharfConfig->generationtime
                        l_cRecordedTime := strtran(l_cRecordedTime,"T"," ")
                        l_cRecordedTime := strtran(l_cRecordedTime,"Z","")
                        l_tRecordedTime := hb_StrToTS(l_cRecordedTime)

                        if l_tGenerationTime > l_tRecordedTime
                            l_nResult := 2   // Not up-to-date
                        else
                            l_nResult := 3   // Future Schema, meaning running an old app.
                        endif

                    endif
                endif
            endif
            CloseAlias("AppliedWharfConfig")
        endcase
    endif
endif

return l_nResult
//-----------------------------------------------------------------------------------------------------------------
