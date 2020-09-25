//Copyright (c) 2020 Eric Lendvai MIT License

#include "hb_orm.ch"

//=================================================================================================================
#include "hb_orm_sqldata_class_definition.prg"
//-----------------------------------------------------------------------------------------------------------------
method Init() class hb_orm_SQLData
// hb_hSetCaseMatch(::QueryString,.f.)
return Self
//-----------------------------------------------------------------------------------------------------------------
method SetPrimaryKeyFieldName(par_name) class hb_orm_SQLData
    ::p_PKFN := par_name
return ::p_PKFN
//-----------------------------------------------------------------------------------------------------------------
method  IsConnected() class hb_orm_SQLData    //Return .t. if has a connection

return (::p_o_SQLConnection != NIL .and.  ::p_o_SQLConnection:GetHandle() > 0)
//-----------------------------------------------------------------------------------------------------------------
method UseConnection(par_oSQLConnection) class hb_orm_SQLData
::p_o_SQLConnection  := par_oSQLConnection
::p_SQLEngineType    := ::p_o_SQLConnection:GetSQLEngineType()
::p_ConnectionNumber := ::p_o_SQLConnection:GetConnectionNumber()
::p_Database         := ::p_o_SQLConnection:GetDatabase()
::p_SchemaName       := ::p_o_SQLConnection:GetSchemaName()
return Self
//-----------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------
method Echo(par_text) class hb_orm_SQLData
// return par_text+trans(::p_SQLEngineType)

// local l_Array := {{1,2},{3,4},{5,6},{7,8},{9,10}}
// local l_SubArray
// local l_i

// for each l_SubArray in l_Array
//     altd()
//     l_i := l_SubArray
// endfor

//Bogus call to force the linker
//VFP_GETCOMPATIBILITYPACKVERSION()

return par_text
//-----------------------------------------------------------------------------------------------------------------
method destroy() class hb_orm_SQLData
hb_orm_SendToDebugView("hb_orm destroy")
::p_ReferenceForSQLDataStrings := NIL
::p_o_SQLConnection            := NIL
return .t.
//-----------------------------------------------------------------------------------------------------------------
method Table(par_Name,par_Alias) class hb_orm_SQLData

if pcount() > 0
    ::p_TableName = par_Name
    if pcount() >= 2
        ::p_TableAlias := par_Alias
    else
        ::p_TableAlias := ::p_TableName
    endif
    
    ::p_Key = 0
    
    hb_HClear(::p_FieldsAndValues)
    
    asize(::p_Join,0)
    asize(::p_FieldToReturn,0)
    asize(::p_Where,0)
    asize(::p_GroupBy,0)
    asize(::p_Having,0)
    asize(::p_OrderBy,0)
    
    ::p_ReferenceForSQLDataStrings := NIL
    ::p_NumberOfSQLDataStrings := 0
    asize(::p_SQLDataStrings,0)
    
    ::p_ErrorMessage    := ""
    ::Tally             := 0
    
    ::p_TableFullPath   := ""
    ::p_CursorName      := ""
    ::p_CursorUpdatable := .f.
    ::p_ArrayHandle     := 0
    ::p_LastSQLCommand  := ""
    ::p_LastRunTime     := 0
    ::p_LastUpdateChangedData := .f.
    ::p_LastDateTimeOfChangeFieldName := ""
    ::p_AddLeadingBlankRecord := .f.
    ::p_AddLeadingRecordsCursorName := ""
    
    ::p_Distinct        := .f.
    ::p_Force           := .f.
    ::p_NoTrack         := .f.
    ::p_Limit           := 0
    
    ::p_NumberOfFetchedFields := 0          //  Used on Select *
    asize(::p_FetchedFieldsNames,0)
    
    ::p_MaxTimeForSlowWarning := 2.000  //  number of seconds
    
    ::p_TableStructureNumberOfFields := 0
    asize(::p_TableStructure,0)
    
    ::p_ExplainMode := 0

endif

return ::p_TableName

//-----------------------------------------------------------------------------------------------------------------
method UsedInUnion(par_o_dl) class hb_orm_SQLData
::p_ReferenceForSQLDataStrings := par_o_dl
return NIL
//-----------------------------------------------------------------------------------------------------------------
method Distinct(par_Mode) class hb_orm_SQLData
::p_Distinct := par_Mode
return NIL
//-----------------------------------------------------------------------------------------------------------------
method Limit(par_Limit) class hb_orm_SQLData
::p_Limit := par_Limit
return NIL
//-----------------------------------------------------------------------------------------------------------------
method Force(par_Mode) class hb_orm_SQLData       //Used for VFP ORM, to disabled rishmore optimizer
// Only used when accessing VFP backend -- Under Design
::p_Force := par_Mode
return NIL
//-----------------------------------------------------------------------------------------------------------------
method NoTrack() class hb_orm_SQLData
::p_NoTrack := .t.
return NIL
//-----------------------------------------------------------------------------------------------------------------
method Key(par_Key) class hb_orm_SQLData                                     //Set the key or retreive the last used key
if pcount() = 1
    ::p_Key := par_Key
else
    return ::p_Key
endif
return NIL
//-----------------------------------------------------------------------------------------------------------------
method Field(par_Name,par_Value) class hb_orm_SQLData                        //To set a field (par_name) in the Table() to the value (par_value). If par_Value is not provided, will return the value from previous set field value
local xResult := NIL
local l_FieldName
local l_HashPos

if !empty(par_Name)
    l_FieldName := vfp_strtran(vfp_strtran(allt(par_Name),::p_TableName+"->","",-1,-1,1),::p_TableName+".","",-1,-1,1)  //Remove the table alias and "->", in case it was used

    l_HashPos := hb_hPos(::p_o_SQLConnection:p_Schema[::p_TableName],l_FieldName)
    if l_HashPos > 0
        l_FieldName := hb_hKeyAt(::p_o_SQLConnection:p_Schema[::p_TableName],l_HashPos)
    else
        //_M_ Report Failed to Find Field
    endif

    if pcount() == 2
        ::p_FieldsAndValues[l_FieldName] := par_Value
        xResult := par_Value
    else
        xResult = hb_HGetDef(::p_FieldsAndValues, l_FieldName, NIL)
    endif
endif

return xResult
//-----------------------------------------------------------------------------------------------------------------
method ErrorMessage() class hb_orm_SQLData                                   //Retreive the error text of the last call to .SQL() or .Get() 
return ::p_ErrorMessage
//-----------------------------------------------------------------------------------------------------------------
// method GetFormattedErrorMessage() class hb_orm_SQLData                       //Retreive the error text of the last call to .SQL() or .Get()  in an HTML formatted Fasion  (ELS)
// return iif(empty(::p_ErrorMessage),[],g_OneCellTable(0,0,o_cw.p_Form_Label_Font_Start+[<font color="#FF0000">]+::p_ErrorMessage))
//-----------------------------------------------------------------------------------------------------------------
method Add(par_Key) class hb_orm_SQLData                                     //Adds a record. par_Key is optional and can only be used with table with non auto-increment key field

local l_Fields
local l_select
local l_SQL_Command
local l_TableName
local l_Value
local l_Values
local l_ValueType
local oField

::p_ErrorMessage := ""
::Tally          := 0
::p_Key          := 0

if !::IsConnected()
    ::p_ErrorMessage := [Missing SQL Connection]
endif

if empty(::p_ErrorMessage)
    do case
    case len(::p_FieldsAndValues) == 0
        ::p_ErrorMessage = [Missing Fields]
        
    case empty(::p_TableName)
        ::p_ErrorMessage = [Missing Table]
        
    otherwise
        l_select := iif(used(),select(),0)
        
        do case
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
            l_TableName = ::CaseTable(::p_TableName)
            
            // if pcount() == 1
            // 	l_Fields := [`KEY`,`SYSC`,`SYSM`]
            // 	l_Values := trans(par_key)+[,?m.v_LocalTime,?m.v_LocalTime]
            // else
            //     l_Fields := [`SYSC`,`SYSM`]
            //     l_Values := [?m.v_LocalTime,?m.v_LocalTime]
            // endif
            
            if pcount() == 1
                //Used in case the KEY field is not auto-increment
                l_Fields := "`"+::p_PKFN+"`"
                l_Values := Trans(par_key)
            else
                l_Fields := ""
                l_Values := ""
            endif
            
            for each oField in ::p_FieldsAndValues
                l_Value     := oField:__enumValue()
                l_ValueType := Valtype(l_Value)     //See https://github.com/Petewg/harbour-core/wiki/V

                switch l_ValueType
                case "C"  // Character string   https://dev.mysql.com/doc/refman/8.0/en/string-literals.html
                case "M"  // Memo field
                    // l_Value := '"'+hb_StrReplace( l_Value, { "'" => "\'",;
                    //                                          '"' => '\"',;
                    //                                          '\' => '\\'} )+'"'
                    l_Value := "x'"+hb_StrToHex(l_Value)+"'"
                    exit
                case "N"  // Numeric
                    l_Value := hb_ntoc(l_Value)
                    exit
                case "D"  // Date   https://dev.mysql.com/doc/refman/8.0/en/datetime.html
                    // l_Value := '"'+hb_DtoC(l_Value,"YYYY-MM-DD")+'"'           //_M_  Test on 1753-01-01
                    l_Value := ::FormatDateForSQLUpdate(l_Value)
                    exit
                case "T"  // TimeStamp (*)   https://dev.mysql.com/doc/refman/8.0/en/datetime.html
                    // l_Value := '"'+hb_TtoC(l_Value,"YYYY-MM-DD","hh:mm:ss")+'"'           //_M_  Test on 1753-01-01
                    l_Value := ::FormatDateTimeForSQLUpdate(l_Value)
                    exit
                case "L"  // Boolean (logical)   https://dev.mysql.com/doc/refman/8.0/en/boolean-literals.html
                    l_Value := iif(l_Value,"TRUE","FALSE")
                    exit
                case "U"  // Undefined (NIL)
                    l_Value := "NULL"
                    exit
                // case "A"  // Array
                // case "B"  // Code-Block
                // case "O"  // Object
                // case "H"  // Hash table (*)
                // case "P"  // Pointer to function, procedure or method (*)
                // case "S"  // Symbolic name (*)
                otherwise
                    hb_orm_SendToDebugView("Skipped Adding unknow value type: "+l_ValueType)
                    loop
                endswitch

                if !empty(l_Fields)
                    l_Fields += ","
                    l_Values += ","
                endif

                l_Fields += "`"+::CaseField(::p_TableName,oField:__enumKey())+"`"
                l_Values += l_Value

            endfor
            //_M_ Does the SQLExec support variable injections ????
            l_SQL_Command = [INSERT INTO `]+l_TableName+[` (]+l_Fields+[) VALUES (]+l_Values+[)]
            
            l_SQL_Command = strtran(l_SQL_Command,"->",".")  // Harbour can use  "table->field" instead of "table.field"

            ::p_LastSQLCommand = l_SQL_Command

            if ::p_o_SQLConnection:SQLExec(l_SQL_Command)
                do case
                case pcount() = 1
                    ::p_Key = par_key
                    
                otherwise
                    // LastInsertedID := hb_RDDInfo(RDDI_INSERTID,,"SQLMIX",::p_o_SQLConnection:GetHandle())
                    if ::p_o_SQLConnection:SQLExec([SELECT LAST_INSERT_ID() as result],"c_DB_Result")
                        ::Tally := 1
                        if Valtype(c_DB_Result->result) == "C"
                            ::p_Key := val(c_DB_Result->result)
                        else
                            ::p_Key := c_DB_Result->result
                        endif
                        // ::SQLSendToLogFileAndMonitoringSystem(0,0,l_SQL_Command+[ -> Key = ]+trans(::p_Key))
                    else
                        // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQL_Command+[ -> Failed Get Added Key])
                        ::p_ErrorMessage = [Failed To Get Added KEY]
                    endif
                    CloseAlias("c_DB_Result")
                    
                endcase
                
            else
                //Failed To Add
                // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQL_Command+[ -> ]+::p_ErrorMessage)
                ::p_ErrorMessage := ::p_o_SQLConnection:GetSQLExecErrorMessage()
                // hb_orm_SendToDebugView(::p_ErrorMessage)

            endif
   
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
            l_TableName = ::CaseTable(::p_TableName)
            
            if pcount() == 1
                //Used in case the KEY field is not auto-increment
                l_Fields := '"'+::p_PKFN+'"'
                l_Values := Trans(par_key)
            else
                l_Fields := ""
                l_Values := ""
            endif
            
            for each oField in ::p_FieldsAndValues
                l_Value     := oField:__enumValue()
                l_ValueType := Valtype(l_Value)     //See https://github.com/Petewg/harbour-core/wiki/V

                switch l_ValueType
                case "C"  // Character string   https://www.postgresql.org/docs/9.0/sql-syntax-lexical.html
                case "M"  // Memo field
                    // l_Value := '"'+hb_StrReplace( l_Value, { "'" => "\'",;
                    //                                          '"' => '\"',;
                    //                                          '\' => '\\'} )+'"'

                    if len(l_Value) == 0
                        // l_Value := "\x"+hb_StrToHex(l_Value,"\x")
                        // l_Value := "\x"+hb_StrToHex(l_Value,"\x")
                        l_Value := "''"
                    else
                        // l_Value := "'"+l_Value+"'"
                        // l_Value := "decode('"+hb_StrToHex(l_Value)+"', 'hex')"
                        l_Value := "E'\x"+hb_StrToHex(l_Value,"\x")+"'"
                    endif
                    exit
                case "N"  // Numeric
                    l_Value := hb_ntoc(l_Value)
                    exit
                case "D"  // Date
                    // l_Value := '"'+hb_DtoC(l_Value,"YYYY-MM-DD")+'"'           //_M_  Test on 1753-01-01
                    l_Value := ::FormatDateForSQLUpdate(l_Value)
                    exit
                case "T"  // TimeStamp (*)
                    // l_Value := '"'+hb_TtoC(l_Value,"YYYY-MM-DD","hh:mm:ss")+'"'           //_M_  Test on 1753-01-01
                    l_Value := ::FormatDateTimeForSQLUpdate(l_Value)
                    exit
                case "L"  // Boolean (logical)
                    l_Value := iif(l_Value,"TRUE","FALSE")
                    exit
                case "U"  // Undefined (NIL)
                    l_Value := "NULL"
                    exit
                // case "A"  // Array
                // case "B"  // Code-Block
                // case "O"  // Object
                // case "H"  // Hash table (*)
                // case "P"  // Pointer to function, procedure or method (*)
                // case "S"  // Symbolic name (*)
                otherwise
                    hb_orm_SendToDebugView("Skipped Adding unknow value type: "+l_ValueType)
                    loop
                endswitch

                if !empty(l_Fields)
                    l_Fields += ","
                    l_Values += ","
                endif
                l_Fields += '"'+::CaseField(l_TableName,oField:__enumKey())+'"'
                l_Values += l_Value

            endfor
            l_SQL_Command = [INSERT INTO "]+l_TableName+[" (]+l_Fields+[) VALUES (]+l_Values+[) RETURNING "]+::p_PKFN+["]
            
            l_SQL_Command = strtran(l_SQL_Command,"->",".")  // Harbour can use  "table->field" instead of "table.field"

            ::p_LastSQLCommand = l_SQL_Command
            if ::p_o_SQLConnection:SQLExec(l_SQL_Command,"c_DB_Result")
                do case
                case pcount() = 1
                    ::p_Key = par_key
                    
                otherwise
                    ::Tally := 1
                    if Valtype(c_DB_Result->key) == "C"
                        ::p_Key := val(c_DB_Result->key)
                    else
                        ::p_Key := c_DB_Result->key
                    endif
                    // ::SQLSendToLogFileAndMonitoringSystem(0,0,l_SQL_Command+[ -> Key = ]+trans(::p_Key))
                    
                endcase
                
            else
                //Failed To Add
                ::p_ErrorMessage := ::p_o_SQLConnection:GetSQLExecErrorMessage()

            endif
            CloseAlias("c_DB_Result")

        endcase

        select (l_select)
        
    endcase
endif

if !empty(::p_ErrorMessage)
    ::p_Key = -1
    ::Tally = -1
endif

return (::p_Key > 0)
//-----------------------------------------------------------------------------------------------------------------
method Delete(par_1,par_2) class hb_orm_SQLData                              //Delete record. Should be called as .Delete(Key) or .Delete(TableName,Key). The first form require a previous call to .Table(TableName)

local l_select
local l_SQL_Command
local l_TableName

::p_ErrorMessage := ""
::Tally          := 0

do case
case pcount() == 2
	::Table(par_1)
	::p_KEY := par_2
case pcount() == 1
	::p_KEY := par_1
otherwise
    ::p_ErrorMessage := [Invalid number of parameters when calling :Delete()]
endcase

if empty(::p_ErrorMessage)
    if !::IsConnected()
        ::p_ErrorMessage := [Missing SQL Connection]
    endif
endif

if empty(::p_ErrorMessage)
	do case
	case empty(::p_TableName)
		::p_ErrorMessage := [Missing Table]
		
	case empty(::p_KEY)
		::p_ErrorMessage := [Missing ]+upper(::p_PKFN)
		
	otherwise
		l_select := iif(used(),select(),0)
		
        do case
		case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
			l_TableName = ::CaseTable(::p_TableName)
			
			l_SQL_Command = [DELETE FROM `]+l_TableName+[` WHERE `]+::p_PKFN+[`=]+trans(::p_KEY)
			::p_LastSQLCommand = l_SQL_Command
			
		case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
			l_TableName = ::CaseTable(::p_TableName)
			
			l_SQL_Command = [DELETE FROM "]+l_TableName+[" WHERE "]+::p_PKFN+["=]+trans(::p_KEY)
			::p_LastSQLCommand = l_SQL_Command
			
		endcase

        if ::p_o_SQLConnection:SQLExec(l_SQL_Command)
            // ::SQLSendToLogFileAndMonitoringSystem(0,0,l_SQL_Command)
            ::Tally = 1
        else
            ::p_ErrorMessage := ::p_o_SQLConnection:GetSQLExecErrorMessage()
            // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQL_Command+[ -> ]+::p_ErrorMessage)
        endif

		select (l_select)
		
	endcase
endif

if !empty(::p_ErrorMessage)
	::Tally = -1
endif

return empty(::p_ErrorMessage)
//-----------------------------------------------------------------------------------------------------------------
method Update(par_Key) class hb_orm_SQLData                                  //Update a record in .Table(TableName)  where .Field(...) was called first

local l_select
local l_SQL_Command
local l_TableName
local l_Value
local l_ValueType
local oField

if pcount() = 1
	::p_KEY = par_key
endif

::p_ErrorMessage := ""
::Tally          := 0
::p_LastUpdateChangedData := .f.
*::p_LastDateTimeOfChangeFieldName := ""

if !::IsConnected()
    ::p_ErrorMessage := [Missing SQL Connection]
endif

if empty(::p_ErrorMessage)
	do case
	case len(::p_FieldsAndValues) == 0
		::p_ErrorMessage = [Missing Fields]
		
	case empty(::p_TableName)
		::p_ErrorMessage = [Missing Table]
		
	case empty(::p_KEY)
		::p_ErrorMessage = [Missing ]+::p_PKFN
		
	otherwise
		l_select = iif(used(),select(),0)
		
        do case
		case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
			// M_ find a way to integrade the same concept as the code below. Should the update be a stored Procedure ?
			*if !empty(::p_LastDateTimeOfChangeFieldName)
			*	replace (l_TableName+"->"+::p_LastDateTimeOfChangeFieldName) with v_LocalTime
			*endif
						
			l_TableName = ::CaseTable(::p_TableName)
			
            l_SQL_Command := ""
            
            //sysm field
            // l_VFPFieldValue = [']+strtran(ttoc(v_LocalTime,3),"T"," ")+[']
            // l_SQL_Command +=  [`]+l_TableName+[`.`sysm`=]+l_VFPFieldValue
            
            for each oField in ::p_FieldsAndValues
                l_Value     := oField:__enumValue()
                l_ValueType := Valtype(l_Value)     //See https://github.com/Petewg/harbour-core/wiki/V

                switch l_ValueType
                case "C"  // Character string   https://dev.mysql.com/doc/refman/8.0/en/string-literals.html
                case "M"  // Memo field
                    // l_Value := '"'+hb_StrReplace( l_Value, { "'" => "\'",;
                    //                                          '"' => '\"',;
                    //                                          '\' => '\\'} )+'"'
                    l_Value := "x'"+hb_StrToHex(l_Value)+"'"
                    exit
                case "N"  // Numeric
                    l_Value := hb_ntoc(l_Value)
                    exit
                case "D"  // Date   https://dev.mysql.com/doc/refman/8.0/en/datetime.html
                    // l_Value := '"'+hb_DtoC(l_Value,"YYYY-MM-DD")+'"'           //_M_  Test on 1753-01-01
                    l_Value := ::FormatDateForSQLUpdate(l_Value)
                    exit
                case "T"  // TimeStamp (*)   https://dev.mysql.com/doc/refman/8.0/en/datetime.html
                    // l_Value := '"'+hb_TtoC(l_Value,"YYYY-MM-DD","hh:mm:ss")+'"'           //_M_  Test on 1753-01-01
                    l_Value := ::FormatDateTimeForSQLUpdate(l_Value)
                    exit
                case "L"  // Boolean (logical)   https://dev.mysql.com/doc/refman/8.0/en/boolean-literals.html
                    l_Value := iif(l_Value,"TRUE","FALSE")
                    exit
                case "U"  // Undefined (NIL)
                    l_Value := "NULL"
                    exit
                // case "A"  // Array
                // case "B"  // Code-Block
                // case "O"  // Object
                // case "H"  // Hash table (*)
                // case "P"  // Pointer to function, procedure or method (*)
                // case "S"  // Symbolic name (*)
                otherwise
                    hb_orm_SendToDebugView("Skipped Updating unknow value type: "+l_ValueType)
                    loop
                endswitch

                if !empty(l_SQL_Command)
                    l_SQL_Command += ","
                endif

                // l_SQL_Command += [`]+l_TableName+[`.`]+lower(allt(oField:__enumKey()))+[` = ]+l_Value
                l_SQL_Command += [`]+::CaseField(l_TableName,oField:__enumKey())+[` = ]+l_Value

            endfor
            
            l_SQL_Command := [UPDATE `]+l_TableName+[` SET ]+l_SQL_Command+[ WHERE `]+l_TableName+[`.`]+::p_PKFN+[` = ]+trans(::p_KEY)
            ::p_LastSQLCommand = l_SQL_Command
            
            if ::p_o_SQLConnection:SQLExec(l_SQL_Command)
                ::Tally = 1
                // ::SQLSendToLogFileAndMonitoringSystem(0,0,l_SQL_Command)
                ::p_LastUpdateChangedData := .t.   // _M_ For now I am assuming the record changed. Later on create a generic Store Procedure that will do these data changes.
            else
                ::p_ErrorMessage = [Failed SQL Update.]
                // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQL_Command+[ -> ]+::p_ErrorMessage)
            endif

		case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
			// M_ find a way to integrate the same concept as the code below. Should the update be a stored Procedure ?
			*if !empty(::p_LastDateTimeOfChangeFieldName)
			*	replace (l_TableName+"->"+::p_LastDateTimeOfChangeFieldName) with v_LocalTime
			*endif
						
			l_TableName = ::CaseTable(::p_TableName)
			
            l_SQL_Command := ""
            
            //sysm field
            // l_VFPFieldValue = [']+strtran(ttoc(v_LocalTime,3),"T"," ")+[']
            // l_SQL_Command +=  [`]+l_TableName+[`.`sysm`=]+l_VFPFieldValue
            
            for each oField in ::p_FieldsAndValues
                l_Value     := oField:__enumValue()
                l_ValueType := Valtype(l_Value)     //See https://github.com/Petewg/harbour-core/wiki/V

                switch l_ValueType
                case "C"  // Character string   https://www.postgresql.org/docs/9.0/sql-syntax-lexical.html
                case "M"  // Memo field
                    // l_Value := '"'+hb_StrReplace( l_Value, { "'" => "\'",;
                    //                                          '"' => '\"',;
                    //                                          '\' => '\\'} )+'"'

                    if len(l_Value) == 0
                        // l_Value := "\x"+hb_StrToHex(l_Value,"\x")
                        // l_Value := "\x"+hb_StrToHex(l_Value,"\x")
                        l_Value := "''"
                    else
                        // l_Value := "'"+l_Value+"'"
                        // l_Value := "decode('"+hb_StrToHex(l_Value)+"', 'hex')"
                        l_Value := "E'\x"+hb_StrToHex(l_Value,"\x")+"'"
                    endif
                    exit
                case "N"  // Numeric
                    l_Value := hb_ntoc(l_Value)
                    exit
                case "D"  // Date
                    // l_Value := '"'+hb_DtoC(l_Value,"YYYY-MM-DD")+'"'           //_M_  Test on 1753-01-01
                    l_Value := ::FormatDateForSQLUpdate(l_Value)
                    exit
                case "T"  // TimeStamp (*)
                    // l_Value := '"'+hb_TtoC(l_Value,"YYYY-MM-DD","hh:mm:ss")+'"'           //_M_  Test on 1753-01-01
                    l_Value := ::FormatDateTimeForSQLUpdate(l_Value)
                    exit
                case "L"  // Boolean (logical)
                    l_Value := iif(l_Value,"TRUE","FALSE")
                    exit
                case "U"  // Undefined (NIL)
                    l_Value := "NULL"
                    exit
                // case "A"  // Array
                // case "B"  // Code-Block
                // case "O"  // Object
                // case "H"  // Hash table (*)
                // case "P"  // Pointer to function, procedure or method (*)
                // case "S"  // Symbolic name (*)
                otherwise
                    hb_orm_SendToDebugView("Skipped Updating unknow value type: "+l_ValueType)
                    loop
                endswitch

                if !empty(l_SQL_Command)
                    l_SQL_Command += ","
                endif

                l_SQL_Command += ["]+::CaseField(l_TableName,oField:__enumKey())+[" = ]+l_Value

            endfor
            
            l_SQL_Command := [UPDATE "]+l_TableName+[" SET ]+l_SQL_Command+[ WHERE "]+l_TableName+["."]+::p_PKFN+[" = ]+trans(::p_KEY)

            ::p_LastSQLCommand = l_SQL_Command
            
            if ::p_o_SQLConnection:SQLExec(l_SQL_Command)
                ::Tally = 1
                // ::SQLSendToLogFileAndMonitoringSystem(0,0,l_SQL_Command)
                ::p_LastUpdateChangedData := .t.   // _M_ For now I am assuming the record changed. Later on create a generic Store Procedure that will do these data changes.
            else
                ::p_ErrorMessage = [Failed SQL Update.]
                // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQL_Command+[ -> ]+::p_ErrorMessage)
            endif

		endcase
		
		select (l_select)
		
	endcase
endif

if !empty(::p_ErrorMessage)
	::Tally = -1
endif

return empty(::p_ErrorMessage)
//-----------------------------------------------------------------------------------------------------------------
method PrepExpression(par_Expression,...) class hb_orm_SQLData   //Used to convert from Source Language syntax to MySQL, and to make parameter static

local aParams := { ... }
local l_char
local l_MergeCodeNumber
local l_pos
local l_result
local l_Value

if pcount() > 1 .and. "^" $ par_Expression
	l_result := ""
	l_MergeCodeNumber := 0
    
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        for l_pos := 1 to len(par_Expression)
            l_char := substr(par_Expression,l_pos,1)
            //l_char := par_Expression[l_pos]
            if l_char == "^"
                l_MergeCodeNumber += 1
                l_Value = aParams[l_MergeCodeNumber]

                switch valtype(l_Value)
                case "C"  // Character string   https://dev.mysql.com/doc/refman/8.0/en/string-literals.html
                case "M"  // Memo field
                    l_result += '"'+hb_StrReplace( l_Value, { "'" => "\'",;
                                                            '"' => '\"',;
                                                            '\' => '\\'} )+'"'
                    exit

                case "N"  // Numeric
                    l_result += hb_ntoc(l_Value)
                    exit

                case "D"  // Date   https://dev.mysql.com/doc/refman/8.0/en/datetime.html
                    // l_Value := '"'+hb_DtoC(l_Value,"YYYY-MM-DD")+'"'           //_M_  Test on 1753-01-01
                    l_result += ::FormatDateForSQLUpdate(l_Value)
                    exit

                case "T"  // TimeStamp (*)   https://dev.mysql.com/doc/refman/8.0/en/datetime.html
                    // l_Value := '"'+hb_TtoC(l_Value,"YYYY-MM-DD","hh:mm:ss")+'"'           //_M_  Test on 1753-01-01
                    l_result += ::FormatDateTimeForSQLUpdate(l_Value)
                    exit

                case "L"  // Boolean (logical)   https://dev.mysql.com/doc/refman/8.0/en/boolean-literals.html
                    l_result += iif(l_Value,"TRUE","FALSE")
                    exit

                case "U"  // Undefined (NIL)
                    l_result += "NULL"
                    exit

                // case "A"  // Array
                // case "B"  // Code-Block
                // case "O"  // Object
                // case "H"  // Hash table (*)
                // case "P"  // Pointer to function, procedure or method (*)
                // case "S"  // Symbolic name (*)
                otherwise
                    ::p_ErrorMessage = [Wrong Parameter Type in Where()]
                    
                endswitch
            else
                l_result += l_char
                
            endif
        endfor

    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        for l_pos := 1 to len(par_Expression)
            l_char := substr(par_Expression,l_pos,1)
            // l_char := par_Expression[l_pos]
            if l_char == "^"
                l_MergeCodeNumber += 1
                l_Value = aParams[l_MergeCodeNumber]

                switch valtype(l_Value)
                case "C"  // Character string   https://dev.mysql.com/doc/refman/8.0/en/string-literals.html
                case "M"  // Memo field
                    l_result += '"'+hb_StrReplace( l_Value, { "'" => "\'",;
                                                            '"' => '\"',;
                                                            '\' => '\\'} )+'"'
                    exit

                case "N"  // Numeric
                    l_result += hb_ntoc(l_Value)
                    exit

                case "D"  // Date   https://dev.mysql.com/doc/refman/8.0/en/datetime.html
                    // l_Value := '"'+hb_DtoC(l_Value,"YYYY-MM-DD")+'"'           //_M_  Test on 1753-01-01
                    l_result += ::FormatDateForSQLUpdate(l_Value)
                    exit

                case "T"  // TimeStamp (*)   https://dev.mysql.com/doc/refman/8.0/en/datetime.html
                    // l_Value := '"'+hb_TtoC(l_Value,"YYYY-MM-DD","hh:mm:ss")+'"'           //_M_  Test on 1753-01-01
                    l_result += ::FormatDateTimeForSQLUpdate(l_Value)
                    exit

                case "L"  // Boolean (logical)   https://dev.mysql.com/doc/refman/8.0/en/boolean-literals.html
                    l_result += iif(l_Value,"TRUE","FALSE")
                    exit

                case "U"  // Undefined (NIL)
                    l_result += "NULL"
                    exit

                // case "A"  // Array
                // case "B"  // Code-Block
                // case "O"  // Object
                // case "H"  // Hash table (*)
                // case "P"  // Pointer to function, procedure or method (*)
                // case "S"  // Symbolic name (*)
                otherwise
                    ::p_ErrorMessage = [Wrong Parameter Type in Where()]
                    
                endswitch
            else
                l_result += l_char
                
            endif
        endfor
            
    endcase
		
else
	l_result = par_Expression
	
endif

return l_result
//-----------------------------------------------------------------------------------------------------------------
method Column(par_Expression,par_Columns_Alias,...) class hb_orm_SQLData     //Used with the .SQL() or .Get() to specify the fields/expressions to retreive

if !empty(par_Expression)
	if pcount() < 2
        AAdd(::p_FieldToReturn,{::PrepExpression(par_expression,...) , allt(strtran(strtran(allt(par_Expression),[->],[_]),[.],[_]))})
	else
        AAdd(::p_FieldToReturn,{::PrepExpression(par_expression,...) , allt(par_Columns_Alias)})
	endif
endif

return NIL
//-----------------------------------------------------------------------------------------------------------------
method Join(par_Type,par_Table,par_Table_Alias,par_expression,...) class hb_orm_SQLData    // Join Tables. Will return a handle that can be used later by ReplaceJoin()

if empty(par_Type)
	//Used to reserve a Join Position
    AAdd(::p_Join,{})
else
    AAdd(::p_Join,{upper(allt(par_Type)),allt(par_Table),allt(par_Table_Alias),allt(::PrepExpression(par_expression,...))})
endif

return len(::p_Join)
//-----------------------------------------------------------------------------------------------------------------
method ReplaceJoin(par_JoinNumber,par_Type,par_Table,par_Table_Alias,par_expression,...) class hb_orm_SQLData      // Replace a Join tables definition

if empty(par_Type)
	::p_Join[par_JoinNumber] := {}
else
    ::p_Join[par_JoinNumber] := {upper(allt(par_Type)),allt(par_Table),allt(par_Table_Alias),allt(::PrepExpression(par_expression,...))}
endif

return par_JoinNumber
//-----------------------------------------------------------------------------------------------------------------
method Where(par_Expression,...) class hb_orm_SQLData   // Adds Where condition. Will return a handle that can be used later by ReplaceWhere()

if empty(par_Expression)
    AAdd(::p_Where,{})
else
    AAdd(::p_Where,allt(::PrepExpression(par_expression,...)))
endif

return len(::p_Where)
//-----------------------------------------------------------------------------------------------------------------
method ReplaceWhere(par_WhereNumber,par_Expression,...) class hb_orm_SQLData   // Replace a Where definition

if !empty(par_Expression)
	::p_Where[par_WhereNumber] = allt(::PrepExpression(par_expression,...))
endif

return par_WhereNumber
//-----------------------------------------------------------------------------------------------------------------
method Having(par_Expression,...) class hb_orm_SQLData   // Adds Having condition. Will return a handle that can be used later by ReplaceHaving()

if empty(par_Expression)
    AAdd(::p_Having,{})
else
    AAdd(::p_Having,allt(::PrepExpression(par_expression,...)))
endif

return len(::p_Having)
//-----------------------------------------------------------------------------------------------------------------
method ReplaceHaving(par_HavingNumber,par_Expression,...) class hb_orm_SQLData   // Replace a Having definition

if !empty(par_Expression)
	::p_Having[par_HavingNumber] = allt(::PrepExpression(par_expression,...))
endif

return par_HavingNumber
//-----------------------------------------------------------------------------------------------------------------
method KeywordCondition(par_Keywords,par_FieldToSearchFor,par_Operand,par_AsHaving) class hb_orm_SQLData     // Creates Where or Having conditions as multi text search in fields.

local l_AsHaving
local l_Char
local l_CharPos
local l_condi
local l_CondiOperand
local l_ContainsStrings
local l_Keywords
local l_line
local l_NewKeyWords
local l_pos
local l_StringMode
local l_ConditionNumber
local l_word

l_ConditionNumber := 0
if !empty(par_Keywords)
	
	l_Keywords := upper(allt(par_Keywords))
	l_Keywords := strtran(l_Keywords,"[","")
	l_Keywords := strtran(l_Keywords,"]","")
	
	l_ContainsStrings := (["] $ par_Keywords)
	
	if pcount() >= 3 .and. !empty(par_Operand)
		l_CondiOperand := [ ]+padr(allt(par_Operand),3)+[ ]
	else
		l_CondiOperand := [ and ]
	endif
	
	l_AsHaving := (pcount() >= 4 .and. par_AsHaving)
	
	if l_ContainsStrings
		l_NewKeyWords := ""
		l_StringMode  := .f.
		for l_CharPos := 1 to len(l_Keywords)
			l_Char := substr(l_Keywords,l_CharPos,1)
			do case
			case l_Char == ["]
				l_StringMode := !l_StringMode
				l_NewKeyWords += [ ]
			case l_Char == [ ]
				if l_StringMode
					l_NewKeyWords += chr(1)
				else
					l_NewKeyWords += [ ]
				endif
			case l_Char == [,]
				if l_StringMode
					l_NewKeyWords += chr(2)
				else
					l_NewKeyWords += [ ]
				endif
			otherwise
				l_NewKeyWords += l_Char
			endcase
		endfor
		l_Keywords := l_NewKeyWords
	else
		l_Keywords := strtran(l_Keywords,","," ")
	endif
	
	do while "  " $ l_Keywords
		l_Keywords := strtran(l_Keywords,"  "," ")
	enddo
	
	l_line  := allt(l_Keywords)+" "
	l_condi := ""
	do while .t. // !empty(l_line)   //Work around needed to avoid error 62 in DLL Mode
		l_pos   := at(" ",l_line)
		l_word  := upper(left(l_line,l_pos-1))
		
		l_word := strtran(l_word,"[","")  // To Prevent Injections
		l_word := strtran(l_word,"]","")  // To Prevent Injections
		l_word := left(l_word,250)        // To Ensure it is not too long.
		
		l_condi += l_CondiOperand + "["+l_word+"] $ g_upper("+par_FieldToSearchFor+")"

		if l_pos+1 > len(l_line)   //Work around needed to avoid error 62 in DLL Mode
			exit
		else
			l_line := substr(l_line,l_pos+1)
		endif
	enddo
	
	l_condi := substr(l_condi,6)
	
	if l_ContainsStrings
		l_condi := strtran(l_condi,chr(1)," ")
		l_condi := strtran(l_condi,chr(2),",")
	endif
	
	*	if l_NumberOfConditions > 1
	*		l_condi = "("+l_condi+")"
	*	endif

	if l_AsHaving
        AAdd(::p_Having,l_condi)
        l_ConditionNumber := len(::p_Having)
	else
		AAdd(::p_Where,l_condi)         //_M_  later make this code other backend ready
        l_ConditionNumber := len(::p_Where)
	endif
	
endif

return l_ConditionNumber
//-----------------------------------------------------------------------------------------------------------------
method GroupBy(par_Expression) class hb_orm_SQLData       // Add a Group By definition

if !empty(par_Expression)
	AAdd(::p_GroupBy,allt(par_Expression))
endif

return NIL
//-----------------------------------------------------------------------------------------------------------------
method OrderBy(par_Expression,par_Direction) class hb_orm_SQLData       // Add an Order By definition    par_Direction = "A"scending or "D"escending

if !empty(par_Expression)
	if pcount() = 2
        AAdd(::p_OrderBy,{allt(par_Expression),(upper(left(par_Direction,1)) == "A")})
	else
        AAdd(::p_OrderBy,{allt(par_Expression),.t.})
	endif
endif

return NIL
//-----------------------------------------------------------------------------------------------------------------
method ResetOrderBy() class hb_orm_SQLData       // Delete all OrderBy definitions

asize(::p_OrderBy,0)

return NIL
//-----------------------------------------------------------------------------------------------------------------
method ReadWrite(par_value) class hb_orm_SQLData            // Was used in VFP ORM, not the Harbour version, since the result cursors are always ReadWriteable

if pcount() = 0 .or. par_value
	::p_CursorUpdatable := .t.
else
	::p_CursorUpdatable := .f.
endif

return NIL
//-----------------------------------------------------------------------------------------------------------------
method AddLeadingBlankRecord() class hb_orm_SQLData            // If the result cursor should have a leading blank record, used mainly to create the concept of "not-selected" row

::p_AddLeadingBlankRecord := .t.

return NIL
//-----------------------------------------------------------------------------------------------------------------
method AddLeadingRecords(par_CursorName) class hb_orm_SQLData    // Specify to add records from par_CursorName as leading record to the future result cursor

if !empty(par_CursorName)
	::p_AddLeadingRecordsCursorName := par_CursorName
	::p_AddLeadingBlankRecord       := .t.
endif

return NIL
//-----------------------------------------------------------------------------------------------------------------
method ExpressionToMYSQL(par_Expression) class hb_orm_SQLData    //_M_  to generalize UDF translation to backend
//_M_
return ::FixTableAndFieldNameCasingInExpression(par_Expression)
//-----------------------------------------------------------------------------------------------------------------
method ExpressionToPostgreSQL(par_Expression) class hb_orm_SQLData    //_M_  to generalize UDF translation to backend
//_M_
return ::FixTableAndFieldNameCasingInExpression(par_Expression)
//-----------------------------------------------------------------------------------------------------------------
method FixTableAndFieldNameCasingInExpression(par_expression) class hb_orm_SQLData   //_M_
local l_Pos,l_HashPos
local l_result := ""
local l_TableName,l_FieldName
local l_TokenDelimiterLeft,l_TokenDelimiterRight
local l_Byte
local l_ByteIsToken
local l_TableFieldDetection := 0
local l_StreamBuffer        := ""

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_TokenDelimiterLeft  := [`]
    l_TokenDelimiterRight := [`]
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_TokenDelimiterLeft  := ["]
    l_TokenDelimiterRight := ["]
endcase

for each l_Byte in @par_expression
    l_ByteIsToken := (l_Byte $ "0123456789_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    do case
    case l_TableFieldDetection == 0  // Not in <TableName>.<FieldName> pattern
        if l_ByteIsToken
            l_TableFieldDetection := 1
            l_StreamBuffer        := l_Byte
            l_TableName           := l_Byte
            l_FieldName           := ""
        else
            l_result += l_Byte
        endif
    case l_TableFieldDetection == 1 // in <TableName>
        do case
        case l_ByteIsToken
            l_StreamBuffer        += l_Byte
            l_TableName           += l_Byte
        case l_byte == "."
            l_TableFieldDetection := 2
            l_StreamBuffer        += l_Byte
        otherwise
            // Not a <TableName>.<FieldName> pattern
            l_TableFieldDetection := 0
            l_result              += l_StreamBuffer+l_Byte
            l_StreamBuffer        := ""
        endcase
    case l_TableFieldDetection == 2   //Beyond "."
        if l_ByteIsToken  // at least one IsTokenByte is needed
            l_TableFieldDetection := 3
            l_StreamBuffer        += l_Byte
            l_FieldName           += l_Byte
        else  // Invalid pattern
            l_TableFieldDetection := 0
            l_result              += l_StreamBuffer+l_Byte
            l_StreamBuffer        := ""
        endif
    case l_TableFieldDetection == 3   //Beyond ".?"
        do case
        case l_ByteIsToken
            l_StreamBuffer       += l_Byte
            l_FieldName          += l_Byte
        case l_byte == "."  // Invalid pattern
            l_TableFieldDetection := 0
            l_result              += l_StreamBuffer+l_Byte
            l_StreamBuffer        := ""
        otherwise // End of pattern
            l_TableFieldDetection := 0

            // Fix The Casing of l_TableName and l_FieldName based on he actual on file tables.
            l_HashPos := hb_hPos(::p_o_SQLConnection:p_Schema,l_TableName)
            if l_HashPos > 0
                l_TableName := hb_hKeyAt(::p_o_SQLConnection:p_Schema,l_HashPos) 
                l_HashPos := hb_hPos(::p_o_SQLConnection:p_Schema[l_TableName],l_FieldName)
                if l_HashPos > 0
                    l_FieldName := hb_hKeyAt(::p_o_SQLConnection:p_Schema[l_TableName],l_HashPos)
                    l_result += l_TokenDelimiterLeft+l_TableName+l_TokenDelimiterRight+"."+l_TokenDelimiterLeft+l_FieldName+l_TokenDelimiterRight+l_Byte
                else
                    //_M_ Report Failed to Find Field
                    l_result += l_StreamBuffer+l_Byte
                endif
            else
                //_M_ Report Failed to find Table
                l_result += l_StreamBuffer+l_Byte
            endif
            l_StreamBuffer := ""

        endcase
    endcase
    
endfor

if l_TableFieldDetection == 3
    // Fix The Casing of l_TableName and l_FieldName based on he actual on file tables.
    l_HashPos := hb_hPos(::p_o_SQLConnection:p_Schema,l_TableName)
    if l_HashPos > 0
        l_TableName := hb_hKeyAt(::p_o_SQLConnection:p_Schema,l_HashPos) 
        l_HashPos := hb_hPos(::p_o_SQLConnection:p_Schema[l_TableName],l_FieldName)
        if l_HashPos > 0
            l_FieldName := hb_hKeyAt(::p_o_SQLConnection:p_Schema[l_TableName],l_HashPos)
            l_result += l_TokenDelimiterLeft+l_TableName+l_TokenDelimiterRight+"."+l_TokenDelimiterLeft+l_FieldName+l_TokenDelimiterRight
        else
            //_M_ Report Failed to Find Field
            l_result += l_StreamBuffer
        endif
    else
        //_M_ Report Failed to find Table
        l_result += l_StreamBuffer
    endif
else
    l_result += l_StreamBuffer
endif

return l_result
//-----------------------------------------------------------------------------------------------------------------
method BuildSQL()  class hb_orm_SQLData   // Used internally

local l_Counter
local l_SQL_Command
local l_NumberOfOrderBys       := len(::p_OrderBy)
local l_NumberOfHavings        := len(::p_Having)
local l_NumberOfGroupBys       := len(::p_GroupBy)
local l_NumberOfWheres         := len(::p_Where)
local l_NumberOfJoins          := len(::p_Join)
local l_NumberOfFieldsToReturn := len(::p_FieldToReturn)

local l_bogus

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
	l_SQL_Command := [SELECT ]
	
	if ::p_Distinct
		l_SQL_Command += [DISTINCT ]
	endif
	
	// _M_ add support to "*"
	if empty(l_NumberOfFieldsToReturn)
		l_SQL_Command += [ ]+::p_TableAlias+[.`]+::p_PKFN+[` AS `]+::p_PKFN+[`]
	else
		for l_Counter := 1 to l_NumberOfFieldsToReturn
			if l_Counter > 1
				l_SQL_Command += [,]
			endif
			l_SQL_Command += ::ExpressionToMYSQL(::p_FieldToReturn[l_Counter,1])
			
			if !empty(::p_FieldToReturn[l_Counter,2])
				l_SQL_Command += [ AS `]+::p_FieldToReturn[l_Counter,2]+[`]
			else
				l_SQL_Command += [ AS `]+strtran(::p_FieldToReturn[l_Counter,1],[.],[_])+[`]
			endif
		endfor
	endif
	
	if ::p_TableName == ::p_TableAlias
		l_SQL_Command += [ FROM ]+::p_TableName
	else
		l_SQL_Command += [ FROM ]+::p_TableName+[ AS ]+::p_TableAlias
	endif
	
	for l_Counter = 1 to l_NumberOfJoins
		
		do case
		case left(::p_Join[l_Counter,1],1) == "I"  //Inner Join
			l_SQL_Command += [ INNER JOIN]
		case left(::p_Join[l_Counter,1],1) == "L"  //Left Outer
			l_SQL_Command += [ LEFT OUTER JOIN]
		case left(::p_Join[l_Counter,1],1) == "R"  //Right Outer
			l_SQL_Command += [ RIGHT OUTER JOIN]
		case left(::p_Join[l_Counter,1],1) == "F"  //Full Outer
			l_SQL_Command += [ FULL OUTER JOIN]
		otherwise
			loop
		endcase
		
		l_SQL_Command += [ ] + ::p_Join[l_Counter,2]
		
		if !empty(::p_Join[l_Counter,3])
			l_SQL_Command += [ ] + ::p_Join[l_Counter,3]
		endif

		l_SQL_Command += [ ON ] + ::ExpressionToMYSQL(::p_Join[l_Counter,4])
		
	endfor
	
	do case
	case l_NumberOfWheres = 1
		l_SQL_Command += [ WHERE (]+::ExpressionToMYSQL(::p_Where[1])+[)]
	case l_NumberOfWheres > 1
		l_SQL_Command += [ WHERE (]
		for l_Counter = 1 to l_NumberOfWheres
			if l_Counter > 1
				l_SQL_Command += [ AND ]
			endif
			l_SQL_Command += [(]+::ExpressionToMYSQL(::p_Where[l_Counter])+[)]
		endfor
		l_SQL_Command += [)]
	endcase
		
	if l_NumberOfGroupBys > 0
		l_SQL_Command += [ GROUP BY ]
		for l_Counter = 1 to l_NumberOfGroupBys
			if l_Counter > 1
				l_SQL_Command += [,]
			endif
			l_SQL_Command += ::ExpressionToMYSQL(::p_GroupBy[l_Counter])
		endfor
	endif
		
	do case
	case l_NumberOfHavings = 1
		l_SQL_Command += [ HAVING ]+::ExpressionToMYSQL(::p_Having[1])
	case l_NumberOfHavings > 1
		l_SQL_Command += [ HAVING (]
		for l_Counter = 1 to l_NumberOfHavings
			if l_Counter > 1
				l_SQL_Command += [ AND ]
			endif
			l_SQL_Command += [(]+::ExpressionToMYSQL(::p_Having[l_Counter])+[)]
		endfor
		l_SQL_Command += [)]
	endcase
		
	if l_NumberOfOrderBys > 0
		l_SQL_Command += [ ORDER BY ]
		for l_Counter = 1 to l_NumberOfOrderBys
			if l_Counter > 1
				l_SQL_Command += [ , ]
			endif
			l_SQL_Command += ::ExpressionToMYSQL(::p_OrderBy[l_Counter,1])
			if ::p_OrderBy(l_Counter,2)
				l_SQL_Command += [ ASC]
			else
				l_SQL_Command += [ DESC]
			endif
		endfor
	endif
	
	if ::p_Limit > 0
		l_SQL_Command += [LIMIT ]+trans(::p_Limit)+[ ]
	endif
	
	l_SQL_Command = strtran(l_SQL_Command,[->],[.])
	
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
	l_SQL_Command := [SELECT ]
	
	if ::p_Distinct
		l_SQL_Command += [DISTINCT ]
	endif
	
	// _M_ add support to "*"
	if empty(l_NumberOfFieldsToReturn)
		l_SQL_Command += [ ]+::p_TableAlias+[."]+::p_PKFN+[" AS "]+::p_PKFN+["]
	else
		for l_Counter := 1 to l_NumberOfFieldsToReturn
			if l_Counter > 1
				l_SQL_Command += [,]
			endif
			l_SQL_Command += ::ExpressionToPostgreSQL(::p_FieldToReturn[l_Counter,1])
			
			if !empty(::p_FieldToReturn[l_Counter,2])
				l_SQL_Command += [ AS "]+::p_FieldToReturn[l_Counter,2]+["]
			else
				l_SQL_Command += [ AS "]+strtran(::p_FieldToReturn[l_Counter,1],[.],[_])+["]
			endif
		endfor
	endif
	
	if ::p_TableName == ::p_TableAlias
		l_SQL_Command += [ FROM ]+::p_TableName
	else
		l_SQL_Command += [ FROM ]+::p_TableName+[ AS ]+::p_TableAlias
	endif
	
	for l_Counter = 1 to l_NumberOfJoins
		
		do case
		case left(::p_Join[l_Counter,1],1) == "I"  //Inner Join
			l_SQL_Command += [ INNER JOIN]
		case left(::p_Join[l_Counter,1],1) == "L"  //Left Outer
			l_SQL_Command += [ LEFT OUTER JOIN]
		case left(::p_Join[l_Counter,1],1) == "R"  //Right Outer
			l_SQL_Command += [ RIGHT OUTER JOIN]
		case left(::p_Join[l_Counter,1],1) == "F"  //Full Outer
			l_SQL_Command += [ FULL OUTER JOIN]
		otherwise
			loop
		endcase
		
		l_SQL_Command += [ ] + ::p_Join[l_Counter,2]
		
		if !empty(::p_Join[l_Counter,3])
			l_SQL_Command += [ ] + ::p_Join[l_Counter,3]
		endif
		
		l_SQL_Command += [ ON ] +  ::ExpressionToPostgreSQL(::p_Join[l_Counter,4])
		
	endfor
	
	do case
	case l_NumberOfWheres = 1
		l_SQL_Command += [ WHERE (]+::ExpressionToPostgreSQL(::p_Where[1])+[)]
	case l_NumberOfWheres > 1
		l_SQL_Command += [ WHERE (]
		for l_Counter = 1 to l_NumberOfWheres
			if l_Counter > 1
				l_SQL_Command += [ AND ]
			endif
			l_SQL_Command += [(]+::ExpressionToPostgreSQL(::p_Where[l_Counter])+[)]
		endfor
		l_SQL_Command += [)]
	endcase
		
	if l_NumberOfGroupBys > 0
		l_SQL_Command += [ GROUP BY ]
		for l_Counter = 1 to l_NumberOfGroupBys
			if l_Counter > 1
				l_SQL_Command += [,]
			endif
			l_SQL_Command += ::ExpressionToPostgreSQL(::p_GroupBy[l_Counter])
		endfor
	endif
		
	do case
	case l_NumberOfHavings = 1
		l_SQL_Command += [ HAVING ]+::ExpressionToPostgreSQL(::p_Having[1])
	case l_NumberOfHavings > 1
		l_SQL_Command += [ HAVING (]
		for l_Counter = 1 to l_NumberOfHavings
			if l_Counter > 1
				l_SQL_Command += [ AND ]
			endif
			l_SQL_Command += [(]+::ExpressionToPostgreSQL(::p_Having[l_Counter])+[)]
		endfor
		l_SQL_Command += [)]
	endcase
		
	if l_NumberOfOrderBys > 0
		l_SQL_Command += [ ORDER BY ]
		for l_Counter = 1 to l_NumberOfOrderBys
			if l_Counter > 1
				l_SQL_Command += [ , ]
			endif
			l_SQL_Command += ::ExpressionToPostgreSQL(::p_OrderBy[l_Counter,1])
			if ::p_OrderBy(l_Counter,2)
				l_SQL_Command += [ ASC]
			else
				l_SQL_Command += [ DESC]
			endif
		endfor
	endif
	
	if ::p_Limit > 0
		l_SQL_Command += [LIMIT ]+trans(::p_Limit)+[ ]
	endif
	
	l_SQL_Command = strtran(l_SQL_Command,[->],[.])

otherwise
	l_SQL_Command = ""
	
endcase

return l_SQL_Command
//-----------------------------------------------------------------------------------------------------------------
method SetExplainMode(par_mode) class hb_orm_SQLData                                          // Used to get explain information. 0 = Explain off, 1 = Explain with no run, 2 = Explain with run
    ::p_ExplainMode := par_mode
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SQL(par_1,par_2) class hb_orm_SQLData                                          // Assemble and Run SQL command

local l_CursorTempName
local l_FieldCounter
local l_FieldName
local l_FieldValue
local l_ValueType
local l_Value
local l_OutputType
local l_ParameterHoldingTheReferenceToTheArray
local l_result
local l_o_record
local l_select := iif(used(),select(),0)
local l_SQLID  := 0
local l_SQLResult
local l_SQL_Command
local l_TimeEnd
local l_TimeStart
local l_ErrorOccured
local l_NumberOfFields
local l_RecordFieldValues := {}

local v_InELSOffice := .f.

l_result := NIL

::Tally          := 0
::p_ErrorMessage := ""

*!*	l_OutputType
*!*	 0 = none
*!*	 1 = cursor
*!*	 2 = array
*!*	 3 = object
*!*	 4 = Table on disk

l_ParameterHoldingTheReferenceToTheArray := ""

do case
case pcount() == 2
	if valtype(par_1) == "N"
		l_SQLID := par_1
		
		do case
		case valtype(par_2) == "A"
			l_OutputType := 2
			l_ParameterHoldingTheReferenceToTheArray := par_2
		case valtype(par_2) == "C"
			if "\" $ par_2
				::p_TableFullPath := par_2
				l_OutputType      := 4
			else
				::p_TableFullPath := ""
				::p_CursorName    := par_2
				l_OutputType      := 1
                ::p_oCursor       := NIL
                CloseAlias(::p_CursorName)
			endif
		otherwise
			::p_ErrorMessage := "Invalid .SQL parameters"
			if v_InELSOffice
				//_M_ error 10
			endif
		endcase
		
	else
		::p_ErrorMessage := "Invalid .SQL parameters"
		if v_InELSOffice
			//_M_ error 10
		endif
	endif
	
case pcount() = 1
	do case
	case valtype(par_1) == "A"   // Have to test first it an array, because if the first element is an array valtype(par_1) will be "N"
		l_OutputType := 2
		l_ParameterHoldingTheReferenceToTheArray := par_1
		
	case valtype(par_1) == "N"
		l_SQLID := par_1
		
		//Threat as no parameter
		do case
		case empty(len(::p_FieldToReturn))
			l_OutputType := 0
		case empty(::p_CursorName)
			l_OutputType := 3
		otherwise
			l_OutputType := 1
			CloseAlias(::p_CursorName)
		endcase
		
	case valtype(par_1) == "C"
		if "\" $ par_1
			::p_TableFullPath := par_1
			l_OutputType      := 4
		else
			::p_TableFullPath := ""
			::p_CursorName    := par_1
			l_OutputType      := 1
            ::p_oCursor       := NIL
			CloseAlias(::p_CursorName)
		endif
	otherwise
		::p_ErrorMessage := "Invalid .SQL parameters"
		if v_InELSOffice
			//_M_ error 10
		endif
	endcase
	
otherwise
	// No parameters
    ::p_CursorName := ""
	if empty(len(::p_FieldToReturn))
		l_OutputType := 0
	else
		l_OutputType := 3
	endif
	
endcase

if !empty(::p_ErrorMessage)
	// ::SQLSendToLogFileAndMonitoringSystem(0,1,::p_ErrorMessage)
	::Tally := -1
	
else
	if .t. //::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
		//_M_ Add support to ::p_AddLeadingBlankRecord
		
		l_SQL_Command := ::BuildSQL()
        
		::p_LastSQLCommand := l_SQL_Command
		
		l_ErrorOccured := .t.   //Assumed it failed
		
		do case
        case ::p_ExplainMode > 0
            l_OutputType := 0  // will behave as no output but l_result will be the explain text.

			l_CursorTempName := "c_DB_Temp"
			
            do case
            case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
                do case
                case ::p_ExplainMode == 1
                    l_SQL_Command := "EXPLAIN " + l_SQL_Command
                case ::p_ExplainMode == 2
                    l_SQL_Command := "ANALYZE " + l_SQL_Command
                endcase
            case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
                do case
                case ::p_ExplainMode == 1
                    l_SQL_Command := "EXPLAIN " + l_SQL_Command
                case ::p_ExplainMode == 2
                    l_SQL_Command := "EXPLAIN ANALYZE " + l_SQL_Command
                endcase
            endcase

			l_TimeStart := seconds()
            l_SQLResult := ::p_o_SQLConnection:SQLExec(l_SQL_Command,l_CursorTempName)
			l_TimeEnd := seconds()
            ::p_LastRunTime := l_TimeEnd-l_TimeStart+0.0000
			
			if !l_SQLResult
                hb_orm_SendToDebugView("Failed SQLExec. SQLId="+trans(l_SQLID)+"  Error Text="+::p_o_SQLConnection:GetSQLExecErrorMessage())
            else
				l_result := ""

                // altd()
                select (l_CursorTempName)
                l_NumberOfFields := fcount()
                dbGoTop()
                do while !eof()
                    l_result += trans(recno())+chr(13)+chr(10)
                    for l_FieldCounter := 1 to l_NumberOfFields
                        l_FieldValue := FieldGet(l_FieldCounter)
                        l_ValueType  := ValType(l_FieldValue)
                        switch l_ValueType
                        case "C"  // Character string   https://dev.mysql.com/doc/refman/8.0/en/string-literals.html
                        case "M"  // Memo field
                            l_Value := l_FieldValue
                            exit
                        case "N"  // Numeric
                            l_Value := hb_ntoc(l_FieldValue)
                            exit
                        case "D"  // Date
                            l_Value := hb_DtoC(l_FieldValue,"YYYY-MM-DD")
                            exit
                        case "T"  // TimeStamp
                            l_Value := hb_TtoC(l_FieldValue,"YYYY-MM-DD","hh:mm:ss")
                            exit
                        case "L"  // Boolean (logical)
                            l_Value := iif(l_FieldValue,"TRUE","FALSE")
                            exit
                        case "U"  // Undefined (NIL)
                            l_Value := ""
                            exit
                        // case "A"  // Array
                        // case "B"  // Code-Block
                        // case "O"  // Object
                        // case "H"  // Hash table (*)
                        // case "P"  // Pointer to function, procedure or method (*)
                        // case "S"  // Symbolic name (*)
                        otherwise
                        endswitch                   
                        if !empty(l_Value)
                            l_result += "   "+FieldName(l_FieldCounter)+": "+l_Value+chr(13)+chr(10)
                        endif
                    endfor
                    dbSkip()
                enddo

				l_ErrorOccured := .f.
				::Tally        := (l_CursorTempName)->(reccount())
			endif
			CloseAlias(l_CursorTempName)
			




		case l_OutputType == 0 // none
			l_CursorTempName := "c_DB_Temp"
			
			l_TimeStart := seconds()
            l_SQLResult := ::p_o_SQLConnection:SQLExec(l_SQL_Command,l_CursorTempName)
			l_TimeEnd := seconds()
            ::p_LastRunTime := l_TimeEnd-l_TimeStart+0.0000
			
			if !l_SQLResult
                hb_orm_SendToDebugView("Failed SQLExec. SQLId="+trans(l_SQLID)+"  Error Text="+::p_o_SQLConnection:GetSQLExecErrorMessage())
            else
                //  _M_
				// if (l_TimeEnd - l_TimeStart + 0.0000 >= ::p_MaxTimeForSlowWarning)
					// ::SQLSendPerformanceIssueToMonitoringSystem(l_SQLID,2,::p_MaxTimeForSlowWarning,l_TimeStart,l_TimeEnd,l_SQLPerformanceInfo,l_SQL_Command)
				// endif
				
				l_ErrorOccured := .f.
				::Tally        := (l_CursorTempName)->(reccount())
				
			endif
			CloseAlias(l_CursorTempName)
			
		case l_OutputType == 1 // cursor
			
			l_TimeStart := seconds()
			l_SQLResult := ::p_o_SQLConnection:SQLExec(l_SQL_Command,::p_CursorName)
			l_TimeEnd := seconds()
            ::p_LastRunTime := l_TimeEnd-l_TimeStart+0.0000
			
			if !l_SQLResult
                hb_orm_SendToDebugView("Failed SQLExec. SQLId="+trans(l_SQLID)+"  Error Text="+::p_o_SQLConnection:GetSQLExecErrorMessage())
            else
                select (::p_CursorName)
                //_M_
				// if (l_TimeEnd - l_TimeStart + 0.0000 >= ::p_MaxTimeForSlowWarning)
					// ::SQLSendPerformanceIssueToMonitoringSystem(l_SQLID,2,::p_MaxTimeForSlowWarning,l_TimeStart,l_TimeEnd,l_SQLPerformanceInfo,l_SQL_Command)
				// endif
				
				l_ErrorOccured := .f.
				::Tally        := (::p_CursorName)->(reccount())
				
                ::p_oCursor := hb_orm_Cursor():Init():Associate(::p_CursorName)

                // Can not use the following logic, since this would force to call :SQL(...) to have a variable assignment, to avoid loosing scope
                // l_result := hb_orm_Cursor():Init()
                // l_result:Associate(::p_CursorName)
                // or the following compressed version, since Init() returns Self
                // l_result := hb_orm_Cursor():Init():Associate(::p_CursorName)

			endif
			
		case l_OutputType == 2 // array

            asize(l_ParameterHoldingTheReferenceToTheArray,0)

			l_CursorTempName := "c_DB_Temp"
            			
			l_TimeStart := seconds()
			l_SQLResult := ::p_o_SQLConnection:SQLExec(l_SQL_Command,l_CursorTempName)
			l_TimeEnd := seconds()
            ::p_LastRunTime := l_TimeEnd-l_TimeStart+0.0000
			
			if !l_SQLResult
                hb_orm_SendToDebugView("Failed SQLExec. SQLId="+trans(l_SQLID)+"  Error Text="+::p_o_SQLConnection:GetSQLExecErrorMessage())
            else
				// if (l_TimeEnd - l_TimeStart + 0.0000 >= ::p_MaxTimeForSlowWarning)
				// 	// ::SQLSendPerformanceIssueToMonitoringSystem(l_SQLID,2,::p_MaxTimeForSlowWarning,l_TimeStart,l_TimeEnd,l_SQLPerformanceInfo,l_SQL_Command)
				// endif
				
				l_ErrorOccured := .f.
				::Tally        := (l_CursorTempName)->(reccount())
				
				if ::Tally > 0
                    select (l_CursorTempName)
                    l_NumberOfFields := fcount()
                    asize(l_RecordFieldValues,l_NumberOfFields)

                    dbGoTop()
                    do while !eof()
						for l_FieldCounter := 1 to l_NumberOfFields
                            l_RecordFieldValues[l_FieldCounter] := FieldGet(l_FieldCounter)
						endfor
                        AAdd(l_ParameterHoldingTheReferenceToTheArray,l_RecordFieldValues)
                        dbSkip()
                    endwhile
				endif

			endif
			
            CloseAlias(l_CursorTempName)
			
		case l_OutputType = 3 // object
			l_CursorTempName := "c_DB_Temp"
			
			l_TimeStart = seconds()
			l_SQLResult = ::p_o_SQLConnection:SQLExec(l_SQL_Command,l_CursorTempName)
			l_TimeEnd = seconds()
			::p_LastRunTime := l_TimeEnd-l_TimeStart+0.0000
			
			if !l_SQLResult
                hb_orm_SendToDebugView("Failed SQLExec. SQLId="+trans(l_SQLID)+"  Error Text="+::p_o_SQLConnection:GetSQLExecErrorMessage())
            else
                select (l_CursorTempName)

				// if (l_TimeEnd - l_TimeStart + 0.0000 >= ::p_MaxTimeForSlowWarning)
				// 	::SQLSendPerformanceIssueToMonitoringSystem(l_SQLID,2,::p_MaxTimeForSlowWarning,l_TimeStart,l_TimeEnd,l_SQLPerformanceInfo,l_SQL_Command)
				// endif
				
				::Tally          := reccount()
				l_ErrorOccured   := .f.
                l_NumberOfFields := fcount()
				
				do case
				case ::Tally == 0
				case ::Tally == 1
					l_result := hb_orm_Data()
					for l_FieldCounter := 1 to l_NumberOfFields
                        l_FieldName  := FieldName(l_FieldCounter)
                        l_FieldValue := FieldGet(l_FieldCounter)
						l_result:AddField(l_FieldName,l_FieldValue)
					endfor
					
				otherwise
					//Create an array of objects
                    l_result := {}   //Initialize to an empty array.
                    dbGoTop()
                    do while !eof()
                        l_o_record := hb_orm_Data()
						for l_FieldCounter := 1 to l_NumberOfFields
                            l_FieldName  := FieldName(l_FieldCounter)
                            l_FieldValue := FieldGet(l_FieldCounter)
                            l_o_record:AddField(l_FieldName,l_FieldValue)
						endfor
                        AAdd(l_result,l_o_record)

                        dbSkip()
                    endwhile

				endcase
			endif
			
			CloseAlias(l_CursorTempName)
			
		endcase
		
		if l_ErrorOccured
			::Tally := -1
			
			if l_OutputType == 1   //Into Cursor
				select 0  //Move away from any areas on purpose
			else
				select (l_select)
			endif
			
			// ::SQLSendToLogFileAndMonitoringSystem(l_SQLID,1,l_SQL_Command+[ -> ]+::p_ErrorMessage)
			
		else
			if l_OutputType == 1   //Into Cursor
				select (::p_CursorName)
			else
				select (l_select)
			endif
			
			// ::SQLSendToLogFileAndMonitoringSystem(l_SQLID,0,l_SQL_Command+[ -> Reccount = ]+trans(::Tally))
		endif
		
	endif
endif

return l_result
//-----------------------------------------------------------------------------------------------------------------
method Get(par_1,par_2) class hb_orm_SQLData             // Returns an Object with properties matching a record referred by primary key

local l_Counter
local l_CursorTempName
local l_FieldCounter
local l_FieldName
local l_FieldValue
local l_result
local l_select
local l_SQL_Command
local l_ErrorOccured

if pcount() = 2
	::Table(par_1)
	::p_Key = par_2
else
	::p_Key = par_1
endif

::Tally          = 0
::p_ErrorMessage = ""

l_result := NIL

do case
case len(::p_FieldsAndValues) > 0
	::p_ErrorMessage = [Called Get() while using Fields()!]
	// ::SQLSendToLogFileAndMonitoringSystem(0,1,::p_ErrorMessage)
	
otherwise
	l_select = iif(used(),select(),0)
	
	do case
	case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_SQL_Command := [SELECT ]
        
        if empty(len(::p_FieldToReturn))
            l_SQL_Command += [ *]
        else
            for l_Counter = 1 to len(::p_FieldToReturn)
                if l_Counter > 1
                    l_SQL_Command += [,]
                endif
                l_SQL_Command +=  ::ExpressionToMYSQL(::p_FieldToReturn[l_Counter,1])
                
                if !empty(::p_FieldToReturn[l_Counter,2])
                    l_SQL_Command += [ AS `]+::p_FieldToReturn[l_Counter,2]+[`]
                else
                    l_SQL_Command += [ AS `]+strtran(::p_FieldToReturn[l_Counter,1],[.],[_])+[`]
                endif
                
            endfor
        endif
        
        l_SQL_Command += [ FROM `]+::p_TableName+[`]
        l_SQL_Command += [ WHERE (`]+::p_TableName+[`.`]+::p_PKFN+[` = ]+trans(::p_KEY)+[)]
        
        l_SQL_Command := strtran(l_SQL_Command,[->],[.])
        ::p_LastSQLCommand := l_SQL_Command
        
	case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL	
        l_SQL_Command := [SELECT ]
        
        if empty(len(::p_FieldToReturn))
            l_SQL_Command += [ *]
        else
            for l_Counter = 1 to len(::p_FieldToReturn)
                if l_Counter > 1
                    l_SQL_Command += [,]
                endif
                l_SQL_Command +=  ::ExpressionToPostgreSQL(::p_FieldToReturn[l_Counter,1])
                
                if !empty(::p_FieldToReturn[l_Counter,2])
                    l_SQL_Command += [ AS "]+::p_FieldToReturn[l_Counter,2]+["]
                else
                    l_SQL_Command += [ AS "]+strtran(::p_FieldToReturn[l_Counter,1],[.],[_])+["]
                endif
                
            endfor
        endif
        
        l_SQL_Command += [ FROM "]+::p_TableName+["]
        l_SQL_Command += [ WHERE ("]+::p_TableName+["."]+::p_PKFN+[" = ]+trans(::p_KEY)+[)]
        
        l_SQL_Command := strtran(l_SQL_Command,[->],[.])
        ::p_LastSQLCommand := l_SQL_Command
        
	endcase

    l_ErrorOccured := .t.   // Assumed it failed
    
    l_CursorTempName := "c_DB_Temp"

    if ::p_o_SQLConnection:SQLExec(l_SQL_Command,l_CursorTempName)
        select (l_CursorTempName)
        ::Tally        := reccount()
        l_ErrorOccured := .f.
        
        do case
        case ::Tally == 0
        case ::Tally == 1
            //Build an oject to return
            l_result := hb_orm_Data()
            
            for l_FieldCounter := 1 to fcount()
                l_FieldName  := FieldName(l_FieldCounter)
                l_FieldValue := FieldGet(l_FieldCounter)
                l_result:AddField(l_FieldName,l_FieldValue)
            endfor
        otherwise
            //Should not happen. Returned more than 1 record.
        endcase
    else
        ::Tally = -1
        ::p_ErrorMessage := ::p_o_SQLConnection:GetSQLExecErrorMessage()
// altd()
        hb_orm_SendToDebugView("Error in method get()",::p_ErrorMessage)
    endif
    
    CloseAlias(l_CursorTempName)
    
    if l_ErrorOccured
        ::Tally = -1
        select (l_select)
        
        // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQL_Command+[ -> ]+::p_ErrorMessage)
        
    else
        select (l_select)
        
        // ::SQLSendToLogFileAndMonitoringSystem(0,0,l_SQL_Command+[ -> Reccount = ]+trans(::Tally))
    endif

endcase

return l_result
//-----------------------------------------------------------------------------------------------------------------
method CaseTable(par_TableName) class hb_orm_SQLData
local l_TableName := allt(par_TableName)
local l_HashPos
//Fix The Casing of Table and Field based on he actual on file tables.
l_HashPos := hb_hPos(::p_o_SQLConnection:p_Schema,l_TableName)
if l_HashPos > 0
    l_TableName := hb_hKeyAt(::p_o_SQLConnection:p_Schema,l_HashPos) 
else
    //_M_ Report Failed to find Table
endif
return l_TableName
//-----------------------------------------------------------------------------------------------------------------
method CaseField(par_TableName,par_FieldName) class hb_orm_SQLData
local l_TableName := allt(par_TableName)
local l_FieldName := allt(par_FieldName)
local l_HashPos
l_HashPos := hb_hPos(::p_o_SQLConnection:p_Schema[l_TableName],l_FieldName)
if l_HashPos > 0
    l_FieldName := hb_hKeyAt(::p_o_SQLConnection:p_Schema[l_TableName],l_HashPos)
else
    //_M_ Report Failed to Find Field
endif
return l_FieldName
//-----------------------------------------------------------------------------------------------------------------
method DelimitToken(par_Text) class hb_orm_SQLData  // Format the tokens as handled by the SQL Server with delimiters
local l_result
do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_result := [`]+allt(par_Text)+[`]
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_result := ["]+allt(par_Text)+["]
endcase
return l_result
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
method FormatDateForSQLUpdate(par_Date) class hb_orm_SQLData

local l_result
if empty(par_Date)
	do case
	case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
		l_result := ['0000-00-00']
		
	case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
		l_result := [NULL]
		
	// case inlist(v_SQLServerType,"MSSQL2000","MSSQL2005","MSSQL2008")
	// 	l_result := [NULL]
		
	otherwise
		l_result := [NULL]
		
	endcase
else
	do case
	case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
		l_result := [']+hb_DtoC(par_Date,"YYYY-MM-DD")+[']
		
	case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
		l_result := [']+hb_DtoC(par_Date,"YYYY-MM-DD")+[']
		
	// case inlist(v_SQLServerType,"MSSQL2000","MSSQL2005","MSSQL2008")
	// 	l_result := [']+hb_DtoC(par_Date,"YYYY-MM-DD")+[']
		
	otherwise
		l_result := [']+hb_DtoC(par_Date,"YYYY-MM-DD")+[']
		
	endcase
	
endif
return l_result
//-----------------------------------------------------------------------------------------------------------------
method FormatDateTimeForSQLUpdate(par_Dati) class hb_orm_SQLData

local l_result
if empty(par_Dati)
	do case
	case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
		l_result := ['0000-00-00 00:00:00']
		
	case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
		l_result := [NULL]
		
    // case inlist(v_SQLServerType,"MSSQL2000","MSSQL2005","MSSQL2008")
    // 	l_result := [NULL]
		
	otherwise
		l_result := [NULL]
		
	endcase
	
else
	do case
	case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
		l_result := [']+hb_TtoC(par_Dati,"YYYY-MM-DD","hh:mm:ss")+[']
		
	case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
		l_result := [']+hb_TtoC(par_Dati,"YYYY-MM-DD","hh:mm:ss")+[']
		
	// case inlist(v_SQLServerType,"MSSQL2000","MSSQL2005","MSSQL2008")
	// 	l_result := [']+hb_TtoC(par_Dati,"YYYY-MM-DD","hh:mm:ss")+[']
		
	otherwise
		l_result := [']+hb_TtoC(par_Dati,"YYYY-MM-DD","hh:mm:ss")+[']
		
	endcase
	
endif
return l_result

//-----------------------------------------------------------------------------------------------------------------

#include "hb_orm_schema.prg"

//-----------------------------------------------------------------------------------------------------------------
// method UpdateTableStructure(par_TableName,par_Structure,par_AlsoRemoveFields) class hb_orm_SQLData                 // Fix if needed a single file structure
// return NIL
//-----------------------------------------------------------------------------------------------------------------
