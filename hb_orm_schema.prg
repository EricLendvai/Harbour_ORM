//Copyright (c) 2020 Eric Lendvai MIT License

#include "hb_orm.ch"
#include "hb_vfp.ch"

#include "hb_orm_sqldata_class_definition.prg"

//-----------------------------------------------------------------------------------------------------------------
method UpdateTableStructure(par_TableName,par_Structure,par_AlsoRemoveFields) class hb_orm_SQLData                 // Fix if needed a single file structure
local aField
local l_FieldName
local l_FieldStructure
local l_SQL_Command
local l_SQLFields := ""
local l_FieldType
local l_FieldDec
local l_FieldLen
local l_FieldAllowNull
local l_FieldAutoIncrement
local l_NumberOfFieldDefinitionParameters
local l_LastError
local l_SQLPrimaryKey := ""

// l_aStructure := {=>}
// l_aStructure["key"]        := {"I",,}
// l_aStructure["p_table001"] := {"I",,}
// l_aStructure["city"]       := {"C",50,0}

for each aField in par_Structure
    l_FieldName          := aField:__enumKey()
    l_FieldStructure     := aField:__enumValue()
    l_NumberOfFieldDefinitionParameters := len(l_FieldStructure)
    l_FieldType          := l_FieldStructure[1]
    l_FieldLen           := iif(l_NumberOfFieldDefinitionParameters >= 2,l_FieldStructure[2],NIL)   
    l_FieldDec           := iif(l_NumberOfFieldDefinitionParameters >= 3,l_FieldStructure[3],NIL)
    l_FieldAllowNull     := iif(l_NumberOfFieldDefinitionParameters >= 4,l_FieldStructure[4],NIL)
    l_FieldAutoIncrement := iif(l_NumberOfFieldDefinitionParameters >= 5,l_FieldStructure[5],NIL)

    hb_default(@l_FieldLen          ,0)
    hb_default(@l_FieldDec          ,0)
    hb_default(@l_FieldAllowNull    ,.f.)
    hb_default(@l_FieldAutoIncrement,.f.)

    if !empty(l_SQLFields)
        l_SQLFields += ","
    endif
    l_SQLFields += ::DelimitToken(l_FieldName) + [ ] + ::GetFieldDefinition(1,l_FieldName,l_FieldType,l_FieldLen,l_FieldDec,l_FieldAllowNull,l_FieldAutoIncrement)

    if l_FieldAutoIncrement
        do case
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
            l_SQLPrimaryKey := ",PRIMARY KEY ("+::DelimitToken(::p_PKFN)+") USING BTREE"
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
            l_SQLPrimaryKey := ",CONSTRAINT "+::CaseTable(par_TableName)+"_pkey PRIMARY KEY ("+::CaseField(par_TableName,::p_PKFN)+")"
        endcase
    endif

endfor

//altd()


//_M_ Deal with structure changes and table / field case comparison

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_SQL_Command := [CREATE TABLE ]+::DelimitToken(par_TableName)+[ (] + l_SQLFields+l_SQLPrimaryKey
    l_SQL_Command += [) ENGINE=InnoDB DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci]

    // CREATE TABLE `table004` (
    // 	`key` INT(11) NOT NULL AUTO_INCREMENT,
    // 	`fname` CHAR(50) NULL COLLATE 'utf8_general_ci',PRIMARY KEY (`key`) USING BTREE
    // )
    // COLLATE='utf8_general_ci'
    // ENGINE=InnoDB

//altd()
    if ::p_o_SQLConnection:SQLExec(l_SQL_Command)
    else
        l_LastError := ::p_o_SQLConnection:GetSQLExecErrorMessage()
        // altd()
        hb_orm_SendToDebugView("Failed UpdateTableStructure.   Error Text="+l_LastError)
    endif

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_SQL_Command := [CREATE TABLE ]+::DelimitToken(par_TableName)+[ (] + l_SQLFields+l_SQLPrimaryKey
    l_SQL_Command += [)]   // WITH OIDS
// altd()
    if ::p_o_SQLConnection:SQLExec(l_SQL_Command)
    else
        l_LastError := ::p_o_SQLConnection:GetSQLExecErrorMessage()
        // altd()
        hb_orm_SendToDebugView("Failed UpdateTableStructure.   Error Text="+l_LastError)
    endif

endcase

return NIL
//-----------------------------------------------------------------------------------------------------------------

method GetFieldDefinition(par_Mode,par_FieldSQLName,par_FieldType,par_FieldLen,par_FieldDec,par_FieldSQLAlNull,par_FieldSQLautoinc) class hb_orm_SQLData     // Build SQL Field Creation/Modification text

local l_result

* par_Mode
* 1 = Missing Table
* 2 = Missing Column
* 3 = Changed Column

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
	do case
	case par_FieldType == "C"
*		l_result := [CHAR(]+trans(par_FieldLen)+[) ASCII NOT NULL DEFAULT '' COLLATE 'utf8_general_ci']
		if par_FieldSQLAlNull
			l_result := [CHAR(]+trans(par_FieldLen)+[) NULL COLLATE 'utf8_general_ci']
		else
			l_result := [CHAR(]+trans(par_FieldLen)+[) NOT NULL DEFAULT '' COLLATE 'utf8_general_ci']
		endif
		
	case par_FieldType == "D"
		if par_FieldSQLAlNull
			l_result := [DATE NULL]
		else
			l_result := [DATE NOT NULL DEFAULT '0000-00-00']
		endif
		
	case par_FieldType == "T"
		if par_FieldSQLAlNull
			l_result := [DATETIME NULL]
		else
			l_result := [DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00']
		endif
		
	case par_FieldType == "TS"
		l_result := [TIMESTAMP NOT NULL DEFAULT current_timestamp]
		
	case par_FieldType == "I"
		do case
		case par_FieldSQLautoinc
			l_result := [INTEGER NOT NULL AUTO_INCREMENT]
		case par_FieldSQLAlNull
			l_result := [INTEGER NULL]
		otherwise
			l_result := [INTEGER NOT NULL DEFAULT 0]
		endcase
		
	case par_FieldType == "Y"
		if par_FieldSQLAlNull
			l_result := [MONEY NULL]
		else
			l_result := [MONEY NOT NULL DEFAULT 0]
		endif
		
	case par_FieldType == "N"
		do case
		case par_FieldSQLautoinc
			l_result := [DECIMAL(]+trans(iif(par_FieldDec == 0 , par_FieldLen , par_FieldLen-1))+[,]+trans(par_FieldDec)+[) NOT NULL AUTO_INCREMENT]
		case par_FieldSQLAlNull
			l_result := [DECIMAL(]+trans(iif(par_FieldDec == 0 , par_FieldLen , par_FieldLen-1))+[,]+trans(par_FieldDec)+[) NULL]
		otherwise
			l_result := [DECIMAL(]+trans(iif(par_FieldDec == 0 , par_FieldLen , par_FieldLen-1))+[,]+trans(par_FieldDec)+[) NOT NULL DEFAULT 0]
		endcase
		
	case par_FieldType == "L"
		if par_FieldSQLAlNull
			l_result := [TINYINT(1) UNSIGNED NULL]
		else
			l_result := [TINYINT(1) UNSIGNED NOT NULL DEFAULT 0]
		endif
		
	case par_FieldType == "M"
		*l_result := [LONGTEXT NOT NULL DEFAULT '']
		*l_result := [LONGTEXT NOT NULL]
		l_result := [LONGTEXT COLLATE 'utf8_general_ci']
		
	otherwise
		l_result := []
		
	endcase
	
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
	do case
	case par_Mode == 2  // Missing Column
		do case
		case par_FieldType == "C"
			if par_FieldSQLAlNull
				l_result := [character(]+trans(par_FieldLen)+[) DROP DEFAULT, ALTER COLUMN "] + par_FieldSQLName + [" DROP NOT NULL]
			else
				l_result := [character(]+trans(par_FieldLen)+[) DEFAULT '', ALTER COLUMN "] + par_FieldSQLName + [" SET NOT NULL]
			endif
			
		case par_FieldType == "D"
			if par_FieldSQLAlNull
				l_result := [date]
			else
				l_result := [date]
			endif
			
		case par_FieldType == "T"
			if par_FieldSQLAlNull
				l_result := [time]
			else
				l_result := [time]
			endif
			
		case par_FieldType == "TS"
			if par_FieldSQLAlNull
				l_result := [timestamp]
			else
				l_result := [timestamp]
			endif
			
		case par_FieldType == "I"
			if par_FieldSQLAlNull
				l_result := [integer DROP DEFAULT, ALTER COLUMN "] + par_FieldSQLName + [" DROP NOT NULL]
			else
				l_result := [integer DEFAULT 0, ALTER COLUMN "] + par_FieldSQLName + [" SET NOT NULL]
			endif
			
		case par_FieldType == "Y"
			if par_FieldSQLAlNull
				l_result := [money DROP DEFAULT, ALTER COLUMN "] + par_FieldSQLName + [" DROP NOT NULL]
			else
				l_result := [money DEFAULT 0, ALTER COLUMN "] + par_FieldSQLName + [" SET NOT NULL]
			endif
			
		case par_FieldType == "N"
			if par_FieldSQLAlNull
				l_result := [numeric(]+trans(iif(par_FieldDec == 0 , par_FieldLen , par_FieldLen-1))+[,]+trans(par_FieldDec)+[) DROP DEFAULT, ALTER COLUMN "] + par_FieldSQLName + [" DROP NOT NULL]
			else
				l_result := [numeric(]+trans(iif(par_FieldDec == 0 , par_FieldLen , par_FieldLen-1))+[,]+trans(par_FieldDec)+[) DEFAULT 0, ALTER COLUMN "] + par_FieldSQLName + [" SET NOT NULL]
			endif
			
		case par_FieldType == "L"
			if par_FieldSQLAlNull
				l_result := [boolean DROP DEFAULT, ALTER COLUMN "] + par_FieldSQLName + [" DROP NOT NULL]
			else
				l_result := [boolean DEFAULT FALSE, ALTER COLUMN "] + par_FieldSQLName + [" SET NOT NULL]
			endif
			
		case par_FieldType == "M"
			if par_FieldSQLAlNull
				l_result := [text DROP DEFAULT, ALTER COLUMN "] + par_FieldSQLName + [" DROP NOT NULL]
			else
				l_result := [text DEFAULT '', ALTER COLUMN "] + par_FieldSQLName + [" SET NOT NULL]
			endif
			
		otherwise
			l_result := []
			
		endcase
		
	case par_Mode == 3  // Changed Column
		do case
		case par_FieldType == "C"
			if par_FieldSQLAlNull
				l_result := [character(]+trans(par_FieldLen)+[), ALTER COLUMN "] + par_FieldSQLName + [" DROP DEFAULT, ALTER COLUMN "] + par_FieldSQLName + [" DROP NOT NULL]
			else
				l_result := [character(]+trans(par_FieldLen)+[), ALTER COLUMN "] + par_FieldSQLName + [" SET DEFAULT '', ALTER COLUMN "] + par_FieldSQLName + [" SET NOT NULL]
			endif
			
		case par_FieldType == "D"
			if par_FieldSQLAlNull
				l_result := [date, ALTER COLUMN "] + par_FieldSQLName + [" DROP NOT NULL]
			else
				l_result := [date, ALTER COLUMN "] + par_FieldSQLName + [" DROP NOT NULL]
			endif
			
		case par_FieldType == "T"
			if par_FieldSQLAlNull
				l_result := [time, ALTER COLUMN "] + par_FieldSQLName + [" DROP NOT NULL]
			else
				l_result := [time, ALTER COLUMN "] + par_FieldSQLName + [" DROP NOT NULL]
			endif
			
		case par_FieldType == "TS"
			if par_FieldSQLAlNull
				l_result := [timestamp, ALTER COLUMN "] + par_FieldSQLName + [" DROP NOT NULL]
			else
				l_result := [timestamp, ALTER COLUMN "] + par_FieldSQLName + [" DROP NOT NULL]
			endif
			
		case par_FieldType == "I"
			if par_FieldSQLAlNull
				l_result := [integer, ALTER COLUMN "] + par_FieldSQLName + [" DROP DEFAULT, ALTER COLUMN "] + par_FieldSQLName + [" DROP NOT NULL]
			else
				l_result := [integer, ALTER COLUMN "] + par_FieldSQLName + [" SET DEFAULT 0, ALTER COLUMN "] + par_FieldSQLName + [" SET NOT NULL]
			endif
			
		case par_FieldType == "Y"
			if par_FieldSQLAlNull
				l_result := [money, ALTER COLUMN "] + par_FieldSQLName + [" DROP DEFAULT, ALTER COLUMN "] + par_FieldSQLName + [" DROP NOT NULL]
			else
				l_result := [money, ALTER COLUMN "] + par_FieldSQLName + [" SET DEFAULT 0, ALTER COLUMN "] + par_FieldSQLName + [" SET NOT NULL]
			endif
			
		case par_FieldType == "N"
			if par_FieldSQLAlNull
				l_result := [numeric(]+trans(iif(par_FieldDec == 0 , par_FieldLen , par_FieldLen-1))+[,]+trans(par_FieldDec)+[), ALTER COLUMN "] + par_FieldSQLName + [" DROP DEFAULT, ALTER COLUMN "] + par_FieldSQLName + [" DROP NOT NULL]
			else
				l_result := [numeric(]+trans(iif(par_FieldDec == 0 , par_FieldLen , par_FieldLen-1))+[,]+trans(par_FieldDec)+[), ALTER COLUMN "] + par_FieldSQLName + [" SET DEFAULT 0, ALTER COLUMN "] + par_FieldSQLName + [" SET NOT NULL]
			endif
			
		case par_FieldType == "L"
			if par_FieldSQLAlNull
				l_result := [boolean, ALTER COLUMN "] + par_FieldSQLName + [" DROP DEFAULT, ALTER COLUMN "] + par_FieldSQLName + [" DROP NOT NULL]
			else
				l_result := [boolean, ALTER COLUMN "] + par_FieldSQLName + [" SET DEFAULT FALSE, ALTER COLUMN "] + par_FieldSQLName + [" SET NOT NULL]
			endif
			
		case par_FieldType == "M"
			if par_FieldSQLAlNull
				l_result := [text, ALTER COLUMN "] + par_FieldSQLName + [" DROP DEFAULT, ALTER COLUMN "] + par_FieldSQLName + [" DROP NOT NULL]
			else
				l_result := [text, ALTER COLUMN "] + par_FieldSQLName + [" SET DEFAULT '', ALTER COLUMN "] + par_FieldSQLName + [" SET NOT NULL]
			endif
			
		otherwise
			l_result := []
			
		endcase
		
	otherwise
		// Missing Table
		do case
		case par_FieldType == "C"
			if par_FieldSQLAlNull
				l_result := [character(]+trans(par_FieldLen)+[)]
			else
				l_result := [character(]+trans(par_FieldLen)+[) NOT NULL DEFAULT '']
			endif
			
		case par_FieldType == "D"
			if par_FieldSQLAlNull
				l_result := [date]
			else
				l_result := [date NULL]
			endif
			
		case par_FieldType == "T"
			if par_FieldSQLAlNull
				l_result := [time]
			else
				l_result := [time NULL]
			endif
			
		case par_FieldType == "TS"
			if par_FieldSQLAlNull
				l_result := [timestamp]
			else
				l_result := [timestamp NULL]
			endif
			
		case par_FieldType == "I"

            do case
            case par_FieldSQLautoinc
                l_result := [INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 )]
                //GENERATED ALWAYS AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 )
            case par_FieldSQLAlNull
                l_result := [INTEGER]
            otherwise
                l_result := [INTEGER NOT NULL DEFAULT 0]
            endcase


			// if par_FieldSQLAlNull
			// 	l_result := [integer]
			// else
			// 	l_result := [integer NOT NULL DEFAULT 0]
			// endif
			
		case par_FieldType == "Y"
			if par_FieldSQLAlNull
				l_result := [money]
			else
				l_result := [money NOT NULL DEFAULT 0]
			endif
			
		case par_FieldType == "N"
			if par_FieldSQLAlNull
				l_result := [numeric(]+trans(iif(par_FieldDec == 0 , par_FieldLen , par_FieldLen-1))+[,]+trans(par_FieldDec)+[)]
			else
				l_result := [numeric(]+trans(iif(par_FieldDec == 0 , par_FieldLen , par_FieldLen-1))+[,]+trans(par_FieldDec)+[) NOT NULL DEFAULT 0]
			endif
			
		case par_FieldType == "L"
			if par_FieldSQLAlNull
				l_result := [boolean]
			else
				l_result := [boolean NOT NULL DEFAULT FALSE]
			endif
			
		case par_FieldType == "M"
			if par_FieldSQLAlNull
				l_result := [text]
			else
				l_result := [text NOT NULL DEFAULT '']
			endif
			
		otherwise
			l_result := []
			
		endcase
		
	endcase
	
endcase

return l_result

//The following 2 methods logic was moved to hb_orm_sqlconnect.prg
//-----------------------------------------------------------------------------------------------------------------
// method ResetLoadTableStructure() class hb_orm_SQLData
// CloseAlias("hb_orm_sql_schema"+trans(::p_ConnectionNumber))
// return NIL
// //-----------------------------------------------------------------------------------------------------------------
// method LoadTableStructure(par_TableName) class hb_orm_SQLData
// local l_SQL_Command := ""
// local l_a_TableSchema := {=>}
// local l_TableName_lower := lower(allt(par_TableName))
// local l_FieldType,l_FieldLen,l_FieldDec,l_FieldAllowNull,l_FieldAutoIncrement

// do case
// case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
//     if !used("hb_orm_sql_schema"+trans(::p_ConnectionNumber))


//         l_SQL_Command += [select tables.table_name                as table_name,]
//         l_SQL_Command += [       columns.ordinal_position         as field_position,]
//         l_SQL_Command += [       columns.column_name              as field_name,]
//         l_SQL_Command += [       columns.data_type                as field_type,]
//         l_SQL_Command += [       columns.character_maximum_length as field_clength,]
//         l_SQL_Command += [       columns.numeric_precision        as field_nlength,]
//         l_SQL_Command += [       columns.numeric_scale            as field_decimals,]
//         l_SQL_Command += [       (columns.is_nullable = 'YES')    as field_nullable,]
//         l_SQL_Command += [       columns.column_default           as field_default,]
//         l_SQL_Command += [       upper(tables.table_name)         as tag1,]
//         l_SQL_Command += [       (columns.extra = 'auto_increment') AS field_identity_is]
//         //l_SQL_Command += [       COLUMNS.*]
//         l_SQL_Command += [ from information_schema.tables  as tables]
//         l_SQL_Command += [ join information_schema.columns as columns on columns.TABLE_NAME = tables.TABLE_NAME]
//         l_SQL_Command += [ where tables.table_schema    = ']+::p_Database+[']
//         l_SQL_Command += [ and   tables.table_type      = 'BASE TABLE']
//         l_SQL_Command += [ order by tag1,field_position]


//         if !::p_o_SQLConnection:SQLExec(l_SQL_Command,"hb_orm_sql_schema"+trans(::p_ConnectionNumber))
//             ::p_ErrorMessage = [Failed SQL for hb_orm_sql_schema.]
//             // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQL_Command+[ -> ]+::p_ErrorMessage)
//         endif
//     endif
//     if used("hb_orm_sql_schema"+trans(::p_ConnectionNumber))
//         // altd()
//         select ("hb_orm_sql_schema"+trans(::p_ConnectionNumber))
//         // copy to d:\303\hb_orm_sql_schema.txt SDF
//         //     dbGoTop()
//         locate for lower(trim(field->table_name)) == l_TableName_lower
//         if found()
//             scan while (lower(trim(field->table_name)) == l_TableName_lower)

//             // scan all for lower(trim(field->table_name)) == l_TableName_lower
//             // HB_ORM_OUTPUTDEBUGSTRING("[Harbour] "+lower(trim(field->field_Name)) )
//             // HB_ORM_OUTPUTDEBUGSTRING("[Harbour] "+lower(trim(field->field_type)) )

//                 // loop
//                 // altd()

//                 switch trim(field->field_type)
//                 case "int"
//                     l_FieldType          := "I"
//                     l_FieldLen           := 0
//                     l_FieldDec           := 0
//                     exit
//                 case "bigint"
//                     l_FieldType          := "IB"
//                     l_FieldLen           := 0
//                     l_FieldDec           := 0
//                     exit
//                 case "tinyint"
//                     l_FieldType          := "L"   //_M_?
//                     l_FieldLen           := 0
//                     l_FieldDec           := 0
//                     exit
//                 case "decimal"
//                     l_FieldType          := "N"
//                     l_FieldLen           := field->field_nlength
//                     l_FieldDec           := field->field_decimals
//                     exit
//                 case "char"
//                     l_FieldType          := "C"
//                     l_FieldLen           := field->field_clength
//                     l_FieldDec           := 0
//                     exit
//                 case "varchar"
//                     l_FieldType          := "CV"
//                     l_FieldLen           := field->field_clength
//                     l_FieldDec           := 0
//                     exit
//                 case "text"
//                     l_FieldType          := "M"
//                     l_FieldLen           := 0
//                     l_FieldDec           := 0
//                     exit
//                 case "date"
//                     l_FieldType          := "D"
//                     l_FieldLen           := 0
//                     l_FieldDec           := 0
//                     exit
//                 case "binary"
//                     l_FieldType          := "L"
//                     l_FieldLen           := field->field_clength
//                     l_FieldDec           := 0
//                     exit
//                 case "bit"
//                     l_FieldType          := "BT"
//                     l_FieldLen           := field->field_nlength
//                     l_FieldDec           := 0
//                     exit
//                 case "time"  //_M_ ?
//                     l_FieldType          := "T"
//                     l_FieldLen           := 0
//                     l_FieldDec           := 0
//                     exit
//                 case "datetime"
//                     l_FieldType          := "TS"
//                     l_FieldLen           := 0
//                     l_FieldDec           := 0
//                     exit
//                 otherwise
//                     l_FieldType          := "?"
//                     l_FieldLen           := 0
//                     l_FieldDec           := 0
//                 endswitch

//                 l_FieldAllowNull     := (field->field_nullable == 1)
//                 l_FieldAutoIncrement := (field->field_identity_is == 1)
//                 //{"I",,,,.t.}

//                 l_a_TableSchema[lower(trim(field->field_Name))] := {l_FieldType,l_FieldLen,l_FieldDec,l_FieldAllowNull,l_FieldAutoIncrement}
                
//             endscan
//         endif
//     endif

// case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
//     if !used("hb_orm_sql_schema"+trans(::p_ConnectionNumber))
//         l_SQL_Command += [select tables.table_name                as table_name,]
//         l_SQL_Command += [       columns.ordinal_position         as field_position,]
//         l_SQL_Command += [       columns.column_name              as field_name,]
//         l_SQL_Command += [       columns.data_type                as field_type,]
//         l_SQL_Command += [       columns.character_maximum_length as field_clength,]
//         l_SQL_Command += [       columns.numeric_precision        as field_nlength,]
//         l_SQL_Command += [       columns.numeric_scale            as field_decimals,]
//         l_SQL_Command += [       (columns.is_nullable = 'YES')    as field_nullable,]
//         l_SQL_Command += [       columns.column_default           as field_default,]
//         l_SQL_Command += [       upper(tables.table_name)         as tag1,]
//         l_SQL_Command += [       (columns.is_identity = 'YES')             as field_identity_is]   // ,
//         // l_SQL_Command += [       (columns.identity_generation = 'ALWAYS')  as field_identity_always,]
//         // l_SQL_Command += [       columns.identity_start                    as field_identity_start,]
//         // l_SQL_Command += [       columns.identity_increment                as field_identity_increment]
//         l_SQL_Command += [ from information_schema.tables  as tables]
//         l_SQL_Command += [ join information_schema.columns as columns on columns.TABLE_NAME = tables.TABLE_NAME]
//         l_SQL_Command += [ where tables.table_schema    = ']+::p_SchemaName+[']
//         // l_SQL_Command += [ and   columns.table_schema   = ']+::p_SchemaName+[']
//         l_SQL_Command += [ and   tables.table_type      = 'BASE TABLE']
//         l_SQL_Command += [ order by tag1,field_position]


//         if !::p_o_SQLConnection:SQLExec(l_SQL_Command,"hb_orm_sql_schema"+trans(::p_ConnectionNumber))
//             ::p_ErrorMessage = [Failed SQL for hb_orm_sql_schema.]
//             // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQL_Command+[ -> ]+::p_ErrorMessage)
//         endif
//     endif
//     if used("hb_orm_sql_schema"+trans(::p_ConnectionNumber))
//         select ("hb_orm_sql_schema"+trans(::p_ConnectionNumber))
//         // altd()
//         // copy to d:\303\hb_orm_sql_schema.txt SDF
//         //     dbGoTop()
//         locate for lower(trim(field->table_name)) == l_TableName_lower
//         if found()
//             scan while (lower(trim(field->table_name)) == l_TableName_lower)

//             // scan all for lower(trim(field->table_name)) == l_TableName_lower
//                 // HB_ORM_OUTPUTDEBUGSTRING("[Harbour] "+lower(trim(field->field_Name)) )
//                 // HB_ORM_OUTPUTDEBUGSTRING("[Harbour] "+lower(trim(field->field_type)) )

//                 // loop
//                 // altd()

//                 switch trim(field->field_type)
//                 case "integer"
//                     l_FieldType          := "I"
//                     l_FieldLen           := 0
//                     l_FieldDec           := 0
//                     exit
//                 case "bigint"
//                     l_FieldType          := "IB"
//                     l_FieldLen           := 0
//                     l_FieldDec           := 0
//                     exit
//                 case "numeric"
//                     l_FieldType          := "N"
//                     l_FieldLen           := field->field_nlength
//                     l_FieldDec           := field->field_decimals
//                     exit
//                 case "character"
//                     l_FieldType          := "C"
//                     l_FieldLen           := field->field_clength
//                     l_FieldDec           := 0
//                     exit
//                 case "character varying"
//                     l_FieldType          := "CV"
//                     l_FieldLen           := field->field_clength
//                     l_FieldDec           := 0
//                     exit
//                 case "text"
//                     l_FieldType          := "M"
//                     l_FieldLen           := 0
//                     l_FieldDec           := 0
//                     exit
//                 case "date"
//                     l_FieldType          := "D"
//                     l_FieldLen           := 0
//                     l_FieldDec           := 0
//                     exit
//                 case "boolean"
//                     l_FieldType          := "L"
//                     l_FieldLen           := 0
//                     l_FieldDec           := 0
//                     exit
//                 case "time"
//                     l_FieldType          := "T"
//                     l_FieldLen           := 0
//                     l_FieldDec           := 0
//                     exit
//                 case "timestamp"
//                 case "timestamp without time zone"
//                     l_FieldType          := "TS"
//                     l_FieldLen           := 0
//                     l_FieldDec           := 0
//                     exit
//                 case "money"
//                     l_FieldType          := "Y"
//                     l_FieldLen           := 0
//                     l_FieldDec           := 0
//                     exit
//                 otherwise
//                     l_FieldType          := "?"
//                     l_FieldLen           := 0
//                     l_FieldDec           := 0
//                 endswitch

//                 l_FieldAllowNull     := (field->field_nullable == "1")
//                 l_FieldAutoIncrement := (field->field_identity_is == "1")
//                 //{"I",,,,.t.}

//                 l_a_TableSchema[lower(trim(field->field_Name))] := {l_FieldType,l_FieldLen,l_FieldDec,l_FieldAllowNull,l_FieldAutoIncrement}
                
//             endscan
//         endif
//     endif

// endcase



// return l_a_TableSchema
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
