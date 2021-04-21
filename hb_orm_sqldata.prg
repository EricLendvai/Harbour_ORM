//Copyright (c) 2021 Eric Lendvai MIT License

#include "hb_orm.ch"

#define INVALUEWITCH chr(1)

//=================================================================================================================
#include "hb_orm_sqldata_class_definition.prg"
//-----------------------------------------------------------------------------------------------------------------
method Init() class hb_orm_SQLData
// hb_HCaseMatch(::QueryString,.f.)
return Self
//-----------------------------------------------------------------------------------------------------------------
method  IsConnected() class hb_orm_SQLData    //Return .t. if has a connection

return (::p_oSQLConnection != NIL .and.  ::p_oSQLConnection:GetHandle() > 0)
//-----------------------------------------------------------------------------------------------------------------
method UseConnection(par_oSQLConnection) class hb_orm_SQLData
::p_oSQLConnection      := par_oSQLConnection
::p_SQLEngineType       := ::p_oSQLConnection:GetSQLEngineType()
::p_ConnectionNumber    := ::p_oSQLConnection:GetConnectionNumber()
::p_Database            := ::p_oSQLConnection:GetDatabase()
::p_SchemaName          := ::p_oSQLConnection:GetCurrentSchemaName()   // Will "Freeze" the current connection p_SchemaName
::p_PKFN                := ::p_oSQLConnection:GetPrimaryKeyFieldName() //  p_PKFN
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
::p_oSQLConnection             := NIL
return .t.
//-----------------------------------------------------------------------------------------------------------------
method Table(par_cSchemaAndTableName,par_cAlias) class hb_orm_SQLData
local l_iPos

if pcount() > 0

    // hb_HCaseMatch(::p_AliasToSchemaAndTableNames,.f.)     No Need to make it case insensitive since Aliases are always converted to lower case
    hb_HClear(::p_AliasToSchemaAndTableNames)

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
    
    ::p_ExplainMode := 0

    if empty(::p_SchemaName)   // Meaning not on HB_ORM_ENGINETYPE_POSTGRESQL
        ::p_SchemaAndTableName = ::p_oSQLConnection:CaseTableName(par_cSchemaAndTableName)
        if pcount() >= 2 .and. !empty(par_cAlias)
            ::p_TableAlias := lower(par_cAlias)
        else
            ::p_TableAlias := lower(::p_SchemaAndTableName)
        endif
    else
        l_iPos = at(".",par_cSchemaAndTableName)
        if empty(l_iPos)
            ::p_SchemaAndTableName := ::p_oSQLConnection:CaseTableName(::p_SchemaName+"."+par_cSchemaAndTableName)
            l_iPos = at(".",::p_SchemaAndTableName)
        else
            ::p_SchemaAndTableName := ::p_oSQLConnection:CaseTableName(par_cSchemaAndTableName)
        endif
        if pcount() >= 2 .and. !empty(par_cAlias)
            ::p_TableAlias := lower(par_cAlias)
        else
            ::p_TableAlias := lower(substr(::p_SchemaAndTableName,l_iPos+1))
        endif
    endif
    if empty(::p_SchemaAndTableName)
        ::p_ErrorMessage := [Auto-Casing Error: Failed To find table "]+par_cSchemaAndTableName+[".]
        hb_orm_SendToDebugView(::p_ErrorMessage)
    else
      ::p_AliasToSchemaAndTableNames[::p_TableAlias] := ::p_SchemaAndTableName
    endif
    
    ::p_Key     := 0
    ::p_EventId := ""

endif

return ::p_SchemaAndTableName
//-----------------------------------------------------------------------------------------------------------------
method SetEventId(par_xId) class hb_orm_SQLData
if ValType(par_xId) == "N"
    ::p_EventId := trans(par_xId)
else
    ::p_EventId := left(AllTrim(par_xId),HB_ORM_MAX_EVENTID_SIZE)
endif
return NIL
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
method Key(par_Key) class hb_orm_SQLData                                     //Set the key or retrieve the last used key
if pcount() == 1
    ::p_Key := par_Key
else
    return ::p_Key
endif
return NIL
//-----------------------------------------------------------------------------------------------------------------
method Field(par_cName,par_Value) class hb_orm_SQLData                        //To set a field (par_cName) in the Table() to the value (par_value). If par_Value is not provided, will return the value from previous set field value
local l_xResult := NIL
local l_FieldName
local l_HashPos

if !empty(par_cName)
    l_FieldName := vfp_strtran(vfp_strtran(allt(par_cName),::p_SchemaAndTableName+"->","",-1,-1,1),::p_SchemaAndTableName+".","",-1,-1,1)  //Remove the table alias and "->", in case it was used

    l_HashPos := hb_hPos(::p_oSQLConnection:p_Schema[::p_SchemaAndTableName][HB_ORM_SCHEMA_FIELD],l_FieldName)
    if l_HashPos > 0
        l_FieldName := hb_hKeyAt(::p_oSQLConnection:p_Schema[::p_SchemaAndTableName][HB_ORM_SCHEMA_FIELD],l_HashPos)
    else
        //_M_ Report Failed to Find Field
    endif

    if pcount() == 2
        ::p_FieldsAndValues[l_FieldName] := par_Value
        l_xResult := par_Value
    else
        l_xResult = hb_HGetDef(::p_FieldsAndValues, l_FieldName, NIL)
    endif
endif

return l_xResult
//-----------------------------------------------------------------------------------------------------------------
method ErrorMessage() class hb_orm_SQLData                                   //Retrieve the error text of the last call to .SQL() or .Get() 
return ::p_ErrorMessage
//-----------------------------------------------------------------------------------------------------------------
// method GetFormattedErrorMessage() class hb_orm_SQLData                       //Retrieve the error text of the last call to .SQL() or .Get()  in an HTML formatted Fasion  (ELS)
// return iif(empty(::p_ErrorMessage),[],g_OneCellTable(0,0,o_cw.p_Form_Label_Font_Start+[<font color="#FF0000">]+::p_ErrorMessage))
//-----------------------------------------------------------------------------------------------------------------
method Add(par_Key) class hb_orm_SQLData                                     //Adds a record. par_Key is optional and can only be used with table with non auto-increment key field

local l_Fields
local l_select
local l_SQLCommand
local l_FieldName,l_FieldInfo
local l_Value
local l_Values
local l_oField
local l_aAutoTrimmedFields := {}
local l_aErrors := {}
local l_KeyFieldValue

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
        
    case empty(::p_SchemaAndTableName)
        ::p_ErrorMessage = [Missing Table]
        
    otherwise
        l_select := iif(used(),select(),0)
        
        do case
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
            
            if pcount() == 1
                //Used in case the KEY field is not auto-increment
                l_Fields := ::p_oSQLConnection:FormatIdentifier(::p_PKFN)
                l_Values := Trans(par_key)
            else
                l_Fields := ""
                l_Values := ""
            endif
            
            for each l_oField in ::p_FieldsAndValues
                l_FieldName := ::p_oSQLConnection:CaseFieldName(::p_SchemaAndTableName,l_oField:__enumKey())
                if empty(l_FieldName)
                    hb_orm_SendToDebugView([Auto-Casing Error: Failed To find Field "]+l_oField:__enumKey()+[" in table "]+::p_SchemaAndTableName+[".])
                else
                    l_FieldInfo := ::p_oSQLConnection:p_Schema[::p_SchemaAndTableName][HB_ORM_SCHEMA_FIELD][l_FieldName]
                    l_Value     := l_oField:__enumValue()
                    
                    if !el_AUnpack(::PrepValueForMySQL("adding",l_Value,::p_SchemaAndTableName,0,l_FieldName,l_FieldInfo,@l_aAutoTrimmedFields,@l_aErrors),,@l_Value)
                        loop
                    endif

                    if !empty(l_Fields)
                        l_Fields += ","
                        l_Values += ","
                    endif
                    l_Fields += ::p_oSQLConnection:FormatIdentifier(l_FieldName)
                    l_Values += l_Value
                endif

            endfor
            l_SQLCommand := [INSERT INTO ]+::p_oSQLConnection:FormatIdentifier(::p_SchemaAndTableName)+[ (]+l_Fields+[) VALUES (]+l_Values+[)]
            
            l_SQLCommand := strtran(l_SQLCommand,"->",".")  // Harbour can use  "table->field" instead of "table.field"

            ::p_LastSQLCommand = l_SQLCommand

            if ::p_oSQLConnection:SQLExec(l_SQLCommand)
                do case
                case pcount() == 1
                    ::p_Key = par_key
                    
                otherwise
                    // LastInsertedID := hb_RDDInfo(RDDI_INSERTID,,"SQLMIX",::p_oSQLConnection:GetHandle())
                    if ::p_oSQLConnection:SQLExec([SELECT LAST_INSERT_ID() as result],"c_DB_Result")
                        ::Tally := 1
                        if Valtype(c_DB_Result->result) == "C"
                            ::p_Key := val(c_DB_Result->result)
                        else
                            ::p_Key := c_DB_Result->result
                        endif
                        // ::SQLSendToLogFileAndMonitoringSystem(0,0,l_SQLCommand+[ -> Key = ]+trans(::p_Key))
                    else
                        // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQLCommand+[ -> Failed Get Added Key])
                        ::p_ErrorMessage = [Failed To Get Added KEY]
                    endif
                    CloseAlias("c_DB_Result")
                    
                endcase
                
            else
                //Failed To Add
                // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQLCommand+[ -> ]+::p_ErrorMessage)
                ::p_ErrorMessage := ::p_oSQLConnection:GetSQLExecErrorMessage()
                // hb_orm_SendToDebugView(::p_ErrorMessage)

            endif
   
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
            
            if pcount() == 1
                //Used in case the KEY field is not auto-increment
                l_Fields := ::p_oSQLConnection:FormatIdentifier(::p_PKFN)
                l_Values := Trans(par_key)
            else
                l_Fields := ""
                l_Values := ""
            endif
            
            for each l_oField in ::p_FieldsAndValues
                l_FieldName := ::p_oSQLConnection:CaseFieldName(::p_SchemaAndTableName,l_oField:__enumKey())
                if empty(l_FieldName)
                    hb_orm_SendToDebugView([Auto-Casing Error: Failed To find Field "]+l_oField:__enumKey()+[" in table "]+::p_SchemaAndTableName+[".])
                else
                    l_FieldInfo := ::p_oSQLConnection:p_Schema[::p_SchemaAndTableName][HB_ORM_SCHEMA_FIELD][l_FieldName]
                    l_Value     := l_oField:__enumValue()

                    if !el_AUnpack(::PrepValueForPostgreSQL("adding",l_Value,::p_SchemaAndTableName,0,l_FieldName,l_FieldInfo,@l_aAutoTrimmedFields,@l_aErrors),,@l_Value)
                        loop
                    endif

                    if !empty(l_Fields)
                        l_Fields += ","
                        l_Values += ","
                    endif
                    l_Fields += ::p_oSQLConnection:FormatIdentifier(l_FieldName)
                    l_Values += l_Value
                endif

            endfor
            l_SQLCommand := [INSERT INTO ]+::p_oSQLConnection:FormatIdentifier(::p_SchemaAndTableName)+[ (]+l_Fields+[) VALUES (]+l_Values+[) RETURNING ]+::p_oSQLConnection:FormatIdentifier(::p_PKFN)
            
            l_SQLCommand := strtran(l_SQLCommand,"->",".")  // Harbour can use  "table->field" instead of "table.field"

            ::p_LastSQLCommand = l_SQLCommand
            if ::p_oSQLConnection:SQLExec(l_SQLCommand,"c_DB_Result")
                do case
                case pcount() == 1
                    ::p_Key = par_key
                    
                otherwise
                    ::Tally := 1
                    l_KeyFieldValue := c_DB_Result->(FieldGet(FieldPos(::p_PKFN)))
                    if Valtype(l_KeyFieldValue) == "C"
                        ::p_Key := val(l_KeyFieldValue)
                    else
                        ::p_Key := l_KeyFieldValue
                    endif
                    // ::SQLSendToLogFileAndMonitoringSystem(0,0,l_SQLCommand+[ -> Key = ]+trans(::p_Key))
                    
                endcase
                
            else
                //Failed To Add
                ::p_ErrorMessage := ::p_oSQLConnection:GetSQLExecErrorMessage()

            endif
            CloseAlias("c_DB_Result")

        endcase

        select (l_select)
        
    endcase
endif

if empty(::p_ErrorMessage)
    if len(l_aAutoTrimmedFields) > 0
        ::p_oSQLConnection:LogAutoTrimEvent(::p_EventId,::p_SchemaAndTableName,::p_KEY,l_aAutoTrimmedFields)
    endif
else
    ::p_Key = -1
    ::Tally = -1
endif

if len(l_aErrors) > 0
    ::p_oSQLConnection:LogErrorEvent(::p_EventId,hb_orm_GetApplicationStack(),l_aErrors)
endif

return (::p_Key > 0)
//-----------------------------------------------------------------------------------------------------------------
method Delete(par_1,par_2) class hb_orm_SQLData                              //Delete record. Should be called as .Delete(Key) or .Delete(TableName,Key). The first form require a previous call to .Table(TableName)

local l_select
local l_SQLCommand

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
    case empty(::p_SchemaAndTableName)
        ::p_ErrorMessage := [Missing Table]
        
    case empty(::p_KEY)
        ::p_ErrorMessage := [Missing ]+upper(::p_PKFN)
        
    otherwise
        l_select := iif(used(),select(),0)
        
        do case
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
            
            l_SQLCommand := [DELETE FROM ]+::p_oSQLConnection:FormatIdentifier(::p_SchemaAndTableName)+[ WHERE ]+::p_oSQLConnection:FormatIdentifier(::p_PKFN)+[=]+trans(::p_KEY)
            ::p_LastSQLCommand = l_SQLCommand
            
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
            
            l_SQLCommand := [DELETE FROM ]+::p_oSQLConnection:FormatIdentifier(::p_SchemaAndTableName)+[ WHERE ]+::p_oSQLConnection:FormatIdentifier(::p_PKFN)+[=]+trans(::p_KEY)
            ::p_LastSQLCommand = l_SQLCommand
            
        endcase

        if empty(::p_ErrorMessage)
            if ::p_oSQLConnection:SQLExec(l_SQLCommand)
                // ::SQLSendToLogFileAndMonitoringSystem(0,0,l_SQLCommand)
                ::Tally = 1
            else
                ::p_ErrorMessage := ::p_oSQLConnection:GetSQLExecErrorMessage()
                // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQLCommand+[ -> ]+::p_ErrorMessage)
            endif
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
local l_SQLCommand
local l_FieldName,l_FieldInfo
local l_Value
local l_oField
local l_aAutoTrimmedFields := {}
local l_aErrors := {}

if pcount() == 1
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
        
    case empty(::p_SchemaAndTableName)
        ::p_ErrorMessage = [Missing Table]
        
    case empty(::p_KEY)
        ::p_ErrorMessage = [Missing ]+::p_PKFN
        
    otherwise
        l_select = iif(used(),select(),0)
        
        do case
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
            // M_ find a way to integrade the same concept as the code below. Should the update be a stored Procedure ?
            *if !empty(::p_LastDateTimeOfChangeFieldName)
            *	replace (::p_SchemaAndTableName+"->"+::p_LastDateTimeOfChangeFieldName) with v_LocalTime
            *endif
            
            l_SQLCommand := ""
            
            //sysm field
            // l_VFPFieldValue = [']+strtran(ttoc(v_LocalTime,3),"T"," ")+[']
            // l_SQLCommand +=  [`]+::p_SchemaAndTableName+[`.`sysm`=]+l_VFPFieldValue
            
            for each l_oField in ::p_FieldsAndValues
                l_FieldName := ::p_oSQLConnection:CaseFieldName(::p_SchemaAndTableName,l_oField:__enumKey())
                if empty(l_FieldName)
                    hb_orm_SendToDebugView([Auto-Casing Error: Failed To find Field "]+l_oField:__enumKey()+[" in table "]+::p_SchemaAndTableName+[".])
                else
                    l_FieldInfo := ::p_oSQLConnection:p_Schema[::p_SchemaAndTableName][HB_ORM_SCHEMA_FIELD][l_FieldName]
                    l_Value     := l_oField:__enumValue()

                    if !el_AUnpack(::PrepValueForMySQL("updating",l_Value,::p_SchemaAndTableName,::p_KEY,l_FieldName,l_FieldInfo,@l_aAutoTrimmedFields,@l_aErrors),,@l_Value)
                        loop
                    endif
                    
                    if !empty(l_SQLCommand)
                        l_SQLCommand += ","
                    endif
                    l_SQLCommand += ::p_oSQLConnection:FormatIdentifier(l_FieldName)+[ = ]+l_Value
                endif

            endfor
            
            l_SQLCommand := [UPDATE ]+::p_oSQLConnection:FormatIdentifier(::p_SchemaAndTableName)+[ SET ]+l_SQLCommand+[ WHERE ]+::p_oSQLConnection:FormatIdentifier(::p_PKFN)+[ = ]+trans(::p_KEY)
            ::p_LastSQLCommand = l_SQLCommand
            
            if ::p_oSQLConnection:SQLExec(l_SQLCommand)
                ::Tally = 1
                // ::SQLSendToLogFileAndMonitoringSystem(0,0,l_SQLCommand)
                ::p_LastUpdateChangedData := .t.   // _M_ For now I am assuming the record changed. Later on create a generic Store Procedure that will do these data changes.
            else
                ::p_ErrorMessage = [Failed SQL Update.]
                // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQLCommand+[ -> ]+::p_ErrorMessage)
            endif

        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
            // M_ find a way to integrate the same concept as the code below. Should the update be a stored Procedure ?
            *if !empty(::p_LastDateTimeOfChangeFieldName)
            *	replace (::p_SchemaAndTableName+"->"+::p_LastDateTimeOfChangeFieldName) with v_LocalTime
            *endif
                        
            l_SQLCommand := ""
            
            //sysm field
            // l_VFPFieldValue = [']+strtran(ttoc(v_LocalTime,3),"T"," ")+[']
            // l_SQLCommand +=  [`]+::p_SchemaAndTableName+[`.`sysm`=]+l_VFPFieldValue
            
            for each l_oField in ::p_FieldsAndValues
                l_FieldName := ::p_oSQLConnection:CaseFieldName(::p_SchemaAndTableName,l_oField:__enumKey())
                if empty(l_FieldName)
                    hb_orm_SendToDebugView([Auto-Casing Error: Failed To find Field "]+l_oField:__enumKey()+[" in table "]+::p_SchemaAndTableName+[".])
                else
                    l_FieldInfo := ::p_oSQLConnection:p_Schema[::p_SchemaAndTableName][HB_ORM_SCHEMA_FIELD][l_FieldName]
                    l_Value     := l_oField:__enumValue()

                    if !el_AUnpack(::PrepValueForPostgreSQL("updating",l_Value,::p_SchemaAndTableName,::p_KEY,l_FieldName,l_FieldInfo,@l_aAutoTrimmedFields,@l_aErrors),,@l_Value)
                        loop
                    endif

                    if !empty(l_SQLCommand)
                        l_SQLCommand += ","
                    endif
                    l_SQLCommand += ::p_oSQLConnection:FormatIdentifier(l_FieldName)+[ = ]+l_Value
                endif

            endfor
            
            l_SQLCommand := [UPDATE ]+::p_oSQLConnection:FormatIdentifier(::p_SchemaAndTableName)+[ SET ]+l_SQLCommand+[ WHERE ]+::p_oSQLConnection:FormatIdentifier(::p_PKFN)+[ = ]+trans(::p_KEY)

            ::p_LastSQLCommand = l_SQLCommand
            
            if ::p_oSQLConnection:SQLExec(l_SQLCommand)
                ::Tally = 1
                // ::SQLSendToLogFileAndMonitoringSystem(0,0,l_SQLCommand)
                ::p_LastUpdateChangedData := .t.   // _M_ For now I am assuming the record changed. Later on create a generic Store Procedure that will do these data changes.
            else
                ::p_ErrorMessage = [Failed SQL Update.]
                // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQLCommand+[ -> ]+::p_ErrorMessage)
            endif

        endcase
        
        select (l_select)
        
    endcase
endif

if empty(::p_ErrorMessage)
    if len(l_aAutoTrimmedFields) > 0
        ::p_oSQLConnection:LogAutoTrimEvent(::p_EventId,::p_SchemaAndTableName,::p_KEY,l_aAutoTrimmedFields)
    endif
else
    ::Tally = -1
endif

if len(l_aErrors) > 0
    ::p_oSQLConnection:LogErrorEvent(::p_EventId,hb_orm_GetApplicationStack(),l_aErrors)
endif

return empty(::p_ErrorMessage)
//-----------------------------------------------------------------------------------------------------------------
method PrepExpression(par_Expression,...) class hb_orm_SQLData   //Used to convert from Source Language syntax to MySQL, and to make parameter static

local l_aParams := { ... }
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
                l_Value = l_aParams[l_MergeCodeNumber]

                switch valtype(l_Value)
                case "C"  // Character string   https://dev.mysql.com/doc/refman/8.0/en/string-literals.html
                case "M"  // Memo field
                    l_result += INVALUEWITCH+'"'+hb_StrReplace( l_Value, { "'" => "\'",;
                                                                            '"' => '\"',;
                                                                            '\' => '\\'} )+'"'+INVALUEWITCH
                    exit

                case "N"  // Numeric
                    l_result += INVALUEWITCH+hb_ntoc(l_Value)+INVALUEWITCH
                    exit

                case "D"  // Date   https://dev.mysql.com/doc/refman/8.0/en/datetime.html
                    // l_Value := '"'+hb_DtoC(l_Value,"YYYY-MM-DD")+'"'           //_M_  Test on 1753-01-01
                    l_result += INVALUEWITCH+::FormatDateForSQLUpdate(l_Value)+INVALUEWITCH
                    exit

                case "T"  // TimeStamp (*)   https://dev.mysql.com/doc/refman/8.0/en/datetime.html
                    // l_Value := '"'+hb_TtoC(l_Value,"YYYY-MM-DD","hh:mm:ss")+'"'           //_M_  Test on 1753-01-01
                    l_result += INVALUEWITCH+::FormatDateTimeForSQLUpdate(l_Value)+INVALUEWITCH
                    exit

                case "L"  // Boolean (logical)   https://dev.mysql.com/doc/refman/8.0/en/boolean-literals.html
                    l_result += INVALUEWITCH+iif(l_Value,"TRUE","FALSE")+INVALUEWITCH
                    exit

                case "U"  // Undefined (NIL)
                    l_result += INVALUEWITCH+"NULL"+INVALUEWITCH
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
                l_Value = l_aParams[l_MergeCodeNumber]

                switch valtype(l_Value)
                case "C"  // Character string   https://dev.mysql.com/doc/refman/8.0/en/string-literals.html
                case "M"  // Memo field
                    l_result += INVALUEWITCH+"'"+hb_StrReplace( l_Value, { "'" => "\'",;
                                                                            '"' => '\"',;
                                                                            '\' => '\\'} )+"'"+INVALUEWITCH
                    exit

                case "N"  // Numeric
                    l_result += INVALUEWITCH+hb_ntoc(l_Value)+INVALUEWITCH
                    exit

                case "D"  // Date   https://dev.mysql.com/doc/refman/8.0/en/datetime.html
                    // l_Value := "'"+hb_DtoC(l_Value,"YYYY-MM-DD")+"'"          //_M_  Test on 1753-01-01
                    l_result += INVALUEWITCH+::FormatDateForSQLUpdate(l_Value)+INVALUEWITCH
                    exit

                case "T"  // TimeStamp (*)   https://dev.mysql.com/doc/refman/8.0/en/datetime.html
                    // l_Value := "'" +hb_TtoC(l_Value,"YYYY-MM-DD","hh:mm:ss")+"'"            //_M_  Test on 1753-01-01
                    l_result += INVALUEWITCH+::FormatDateTimeForSQLUpdate(l_Value)+INVALUEWITCH
                    exit

                case "L"  // Boolean (logical)   https://dev.mysql.com/doc/refman/8.0/en/boolean-literals.html
                    l_result += INVALUEWITCH+iif(l_Value,"TRUE","FALSE")+INVALUEWITCH
                    exit

                case "U"  // Undefined (NIL)
                    l_result += INVALUEWITCH+"NULL"+INVALUEWITCH
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
method Column(par_Expression,par_Columns_Alias,...) class hb_orm_SQLData     //Used with the .SQL() or .Get() to specify the fields/expressions to retrieve

if !empty(par_Expression)
    if pcount() < 2
        AAdd(::p_FieldToReturn,{::PrepExpression(par_expression,...) , allt(strtran(strtran(allt(par_Expression),[->],[_]),[.],[_]))})
    else
        AAdd(::p_FieldToReturn,{::PrepExpression(par_expression,...) , allt(par_Columns_Alias)})
    endif
endif

return NIL
//-----------------------------------------------------------------------------------------------------------------
method Join(par_Type,par_cSchemaAndTableName,par_cAlias,par_expression,...) class hb_orm_SQLData    // Join Tables. Will return a handle that can be used later by ReplaceJoin()
local l_cSchemaAndTableName
local l_cAlias
local l_iPos

if empty(par_Type)
    //Used to reserve a Join Position
    AAdd(::p_Join,{})
else
    if empty(::p_SchemaName)   // Meaning not on HB_ORM_ENGINETYPE_POSTGRESQL
        l_cSchemaAndTableName = ::p_oSQLConnection:CaseTableName(par_cSchemaAndTableName)
        if pcount() >= 3 .and. !empty(par_cAlias)
            l_cAlias := lower(par_cAlias)
        else
            l_cAlias := lower(l_cSchemaAndTableName)
        endif
    else
        l_iPos = at(".",par_cSchemaAndTableName)
        if empty(l_iPos)
            l_cSchemaAndTableName := ::p_oSQLConnection:CaseTableName(::p_SchemaName+"."+par_cSchemaAndTableName)
            l_iPos = at(".",l_cSchemaAndTableName)
        else
            l_cSchemaAndTableName := ::p_oSQLConnection:CaseTableName(par_cSchemaAndTableName)
        endif
        if pcount() >= 3 .and. !empty(par_cAlias)
            l_cAlias := lower(par_cAlias)
        else
            l_cAlias := lower(substr(l_cSchemaAndTableName,l_iPos+1))
        endif
    endif
    if empty(l_cSchemaAndTableName)
        ::p_ErrorMessage := [Auto-Casing Error: Failed To find table "]+par_cSchemaAndTableName+[".]
        hb_orm_SendToDebugView(::p_ErrorMessage)
    else
        ::p_AliasToSchemaAndTableNames[l_cAlias] := l_cSchemaAndTableName
    endif

    AAdd(::p_Join,{upper(allt(par_Type)),l_cSchemaAndTableName,l_cAlias,allt(::PrepExpression(par_expression,...))})
endif

return len(::p_Join)
//-----------------------------------------------------------------------------------------------------------------
method ReplaceJoin(par_JoinNumber,par_Type,par_cSchemaAndTableName,par_cAlias,par_expression,...) class hb_orm_SQLData      // Replace a Join tables definition
local l_cSchemaAndTableName
local l_cAlias
local l_iPos

if empty(par_Type)
    ::p_Join[par_JoinNumber] := {}
else
    // if ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    //     l_cAlias := allt(hb_DefaultValue(par_cAlias,""))
    //     l_iPos := at(".",par_cSchemaAndTableName)
    //     if empty(l_iPos)
    //         if empty(l_cAlias)
    //             l_cAlias := allt(par_cSchemaAndTableName)
    //         endif
    //         l_cSchemaAndTableName := ::p_oSQLConnection:GetCurrentSchemaName()+"."+allt(par_cSchemaAndTableName)
    //     else
    //         l_cSchemaAndTableName := allt(par_cSchemaAndTableName)
    //         if empty(l_cAlias)
    //             //Extract the table name from the l_cSchemaAndTableName
    //             l_cAlias := substr(l_cAlias,l_iPos+1)
    //         endif
    //     endif
    // else
    //     l_cSchemaAndTableName := allt(par_cSchemaAndTableName)
    //     l_cAlias := allt(hb_DefaultValue(par_cAlias,""))
    //     if empty(l_cAlias)
    //         l_cAlias := l_cSchemaAndTableName
    //     endif
    // endif

    if empty(::p_SchemaName)   // Meaning not on HB_ORM_ENGINETYPE_POSTGRESQL
        l_cSchemaAndTableName = ::p_oSQLConnection:CaseTableName(par_cSchemaAndTableName)
        if pcount() >= 4 .and. !empty(par_cAlias)
            l_cAlias := lower(par_cAlias)
        else
            l_cAlias := lower(l_cSchemaAndTableName)
        endif
    else
        l_iPos = at(".",par_cSchemaAndTableName)
        if empty(l_iPos)
            l_cSchemaAndTableName := ::p_oSQLConnection:CaseTableName(::p_SchemaName+"."+par_cSchemaAndTableName)
            l_iPos = at(".",l_cSchemaAndTableName)
        else
            l_cSchemaAndTableName := ::p_oSQLConnection:CaseTableName(par_cSchemaAndTableName)
        endif
        if pcount() >= 4 .and. !empty(par_cAlias)
            l_cAlias := lower(par_cAlias)
        else
            l_cAlias := lower(substr(l_cSchemaAndTableName,l_iPos+1))
        endif
    endif
    if empty(l_cSchemaAndTableName)
        ::p_ErrorMessage := [Auto-Casing Error: Failed To find table "]+par_cSchemaAndTableName+[".]
        hb_orm_SendToDebugView(::p_ErrorMessage)
    else
        ::p_AliasToSchemaAndTableNames[l_cAlias] := l_cSchemaAndTableName
    endif

    ::p_Join[par_JoinNumber] := {upper(allt(par_Type)),l_cSchemaAndTableName,l_cAlias,allt(::PrepExpression(par_expression,...))}
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
    if pcount() == 2
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

if pcount() == 0 .or. par_value
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
return ::FixAliasAndFieldNameCasingInExpression(par_Expression)
//-----------------------------------------------------------------------------------------------------------------
method ExpressionToPostgreSQL(par_Expression) class hb_orm_SQLData    //_M_  to generalize UDF translation to backend
//_M_
return ::FixAliasAndFieldNameCasingInExpression(par_Expression)
//-----------------------------------------------------------------------------------------------------------------
method FixAliasAndFieldNameCasingInExpression(par_expression) class hb_orm_SQLData   //_M_
local l_HashPos
local l_result := ""
local l_AliasName,l_FieldName
local l_SchemaAndTableName
local l_TokenDelimiterLeft,l_TokenDelimiterRight
local l_Byte
local l_ByteIsToken
local l_TableFieldDetection := 0
local l_StreamBuffer        := ""
//local l_SchemaPrefix
local l_iPos
local l_lValueMode := .f.

// if par_expression == "table003.Bit"
//     altd()
// endif

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_TokenDelimiterLeft  := [`]
    l_TokenDelimiterRight := [`]
    //l_SchemaPrefix        := ""
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_TokenDelimiterLeft  := ["]
    l_TokenDelimiterRight := ["]
    //l_SchemaPrefix        := ::p_SchemaName+"."  // ::p_oSQLConnection:GetCurrentSchemaName()+"."
endcase

for each l_Byte in @par_expression

    if l_Byte == INVALUEWITCH
        l_lValueMode := !l_lValueMode
        loop
    endif
    if l_lValueMode
        l_result += l_Byte
        loop
    endif

    l_ByteIsToken := (l_Byte $ "0123456789_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    do case
    case l_TableFieldDetection == 0  // Not in <AliasName>.<FieldName> pattern
        if l_ByteIsToken
            l_TableFieldDetection := 1
            l_StreamBuffer        := l_Byte
            l_AliasName           := l_Byte
            l_FieldName           := ""
        else
            l_result += l_Byte
        endif
    case l_TableFieldDetection == 1 // in <AliasName>
        do case
        case l_ByteIsToken
            l_StreamBuffer        += l_Byte
            l_AliasName           += l_Byte
        case l_byte == "."
            l_TableFieldDetection := 2
            l_StreamBuffer        += l_Byte
        otherwise
            // Not a <AliasName>.<FieldName> pattern
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
            l_AliasName := lower(l_AliasName)   //Alias are always converted to lowercase.

            // Fix The Casing of l_AliasName and l_FieldName based on the actual on file tables.
            l_HashPos := hb_hPos(::p_oSQLConnection:p_Schema,::p_AliasToSchemaAndTableNames[l_AliasName])
            if l_HashPos > 0
                l_SchemaAndTableName := hb_hKeyAt(::p_oSQLConnection:p_Schema,l_HashPos)
                // l_iPos := at(".",l_SchemaAndTableName)
                // if !empty(l_iPos)
                //     l_AliasName := substr(l_SchemaAndTableName,l_iPos+1)
                // endif
                l_HashPos := hb_hPos(::p_oSQLConnection:p_Schema[l_SchemaAndTableName][HB_ORM_SCHEMA_FIELD],l_FieldName)
                if l_HashPos > 0
                    l_FieldName := hb_hKeyAt(::p_oSQLConnection:p_Schema[l_SchemaAndTableName][HB_ORM_SCHEMA_FIELD],l_HashPos)
                    l_result += l_TokenDelimiterLeft+l_AliasName+l_TokenDelimiterRight+"."+l_TokenDelimiterLeft+l_FieldName+l_TokenDelimiterRight+l_Byte
                else
                    l_result += l_StreamBuffer+l_Byte
                    hb_orm_SendToDebugView([Auto-Casing Error: Failed To find Field "]+l_FieldName+[" in alias "]+l_AliasName+[".])
                endif
            else
                l_result += l_StreamBuffer+l_Byte
                hb_orm_SendToDebugView([Auto-Casing Error: Failed To find alias "]+l_AliasName+[".])
            endif
            l_StreamBuffer := ""

        endcase
    endcase
    
endfor

if l_TableFieldDetection == 3
    // Fix The Casing of l_AliasName and l_FieldName based on he actual on file tables.
    l_AliasName := lower(l_AliasName)   //Alias are always converted to lowercase.

    l_HashPos := hb_hPos(::p_oSQLConnection:p_Schema,::p_AliasToSchemaAndTableNames[l_AliasName])
    if l_HashPos > 0
        l_SchemaAndTableName := hb_hKeyAt(::p_oSQLConnection:p_Schema,l_HashPos) 
        // l_iPos := at(".",l_SchemaAndTableName)
        // if !empty(l_iPos)
        //     l_AliasName := substr(l_SchemaAndTableName,l_iPos+1)
        // endif
        l_HashPos := hb_hPos(::p_oSQLConnection:p_Schema[l_SchemaAndTableName][HB_ORM_SCHEMA_FIELD],l_FieldName)
        if l_HashPos > 0
            l_FieldName := hb_hKeyAt(::p_oSQLConnection:p_Schema[l_SchemaAndTableName][HB_ORM_SCHEMA_FIELD],l_HashPos)
            l_result += l_TokenDelimiterLeft+l_AliasName+l_TokenDelimiterRight+"."+l_TokenDelimiterLeft+l_FieldName+l_TokenDelimiterRight
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

//l_TableName

//-----------------------------------------------------------------------------------------------------------------
method BuildSQL() class hb_orm_SQLData   // Used internally

local l_Counter
local l_SQLCommand
local l_NumberOfOrderBys       := len(::p_OrderBy)
local l_NumberOfHavings        := len(::p_Having)
local l_NumberOfGroupBys       := len(::p_GroupBy)
local l_NumberOfWheres         := len(::p_Where)
local l_NumberOfJoins          := len(::p_Join)
local l_NumberOfFieldsToReturn := len(::p_FieldToReturn)

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_SQLCommand := [SELECT ]
    
    if ::p_Distinct
        l_SQLCommand += [DISTINCT ]
    endif
    
    // _M_ add support to "*"
    if empty(l_NumberOfFieldsToReturn)
        l_SQLCommand += [ ]+::p_TableAlias+[.]+::p_oSQLConnection:FormatIdentifier(::p_PKFN)+[ AS ]+::p_oSQLConnection:FormatIdentifier(::p_PKFN)
    else
        for l_Counter := 1 to l_NumberOfFieldsToReturn
            if l_Counter > 1
                l_SQLCommand += [,]
            endif
            l_SQLCommand += ::ExpressionToMYSQL(::p_FieldToReturn[l_Counter,1])
            
            if !empty(::p_FieldToReturn[l_Counter,2])
                l_SQLCommand += [ AS `]+::p_FieldToReturn[l_Counter,2]+[`]
            else
                l_SQLCommand += [ AS `]+strtran(::p_FieldToReturn[l_Counter,1],[.],[_])+[`]
            endif
        endfor
    endif
    
    if ::p_SchemaAndTableName == ::p_TableAlias
        l_SQLCommand += [ FROM ]+::p_oSQLConnection:FormatIdentifier(::p_SchemaAndTableName)
    else
        l_SQLCommand += [ FROM ]+::p_oSQLConnection:FormatIdentifier(::p_SchemaAndTableName)+[ AS ]+::p_oSQLConnection:FormatIdentifier(::p_TableAlias)
    endif
    
    for l_Counter = 1 to l_NumberOfJoins
        
        do case
        case left(::p_Join[l_Counter,1],1) == "I"  //Inner Join
            l_SQLCommand += [ INNER JOIN]
        case left(::p_Join[l_Counter,1],1) == "L"  //Left Outer
            l_SQLCommand += [ LEFT OUTER JOIN]
        case left(::p_Join[l_Counter,1],1) == "R"  //Right Outer
            l_SQLCommand += [ RIGHT OUTER JOIN]
        case left(::p_Join[l_Counter,1],1) == "F"  //Full Outer
            l_SQLCommand += [ FULL OUTER JOIN]
        otherwise
            loop
        endcase
        
        l_SQLCommand += [ ] + ::p_oSQLConnection:FormatIdentifier(::p_Join[l_Counter,2])
        
        // if !empty(::p_Join[l_Counter,3])   the ::Join() method ensured it is never empty
            l_SQLCommand += [ AS ] + ::p_oSQLConnection:FormatIdentifier(lower(::p_Join[l_Counter,3]))
        // endif

        l_SQLCommand += [ ON ] + ::ExpressionToMYSQL(::p_Join[l_Counter,4])
        
    endfor
    
    do case
    case l_NumberOfWheres = 1
        l_SQLCommand += [ WHERE (]+::ExpressionToMYSQL(::p_Where[1])+[)]
    case l_NumberOfWheres > 1
        l_SQLCommand += [ WHERE (]
        for l_Counter = 1 to l_NumberOfWheres
            if l_Counter > 1
                l_SQLCommand += [ AND ]
            endif
            l_SQLCommand += [(]+::ExpressionToMYSQL(::p_Where[l_Counter])+[)]
        endfor
        l_SQLCommand += [)]
    endcase
        
    if l_NumberOfGroupBys > 0
        l_SQLCommand += [ GROUP BY ]
        for l_Counter = 1 to l_NumberOfGroupBys
            if l_Counter > 1
                l_SQLCommand += [,]
            endif
            l_SQLCommand += ::ExpressionToMYSQL(::p_GroupBy[l_Counter])
        endfor
    endif
        
    do case
    case l_NumberOfHavings = 1
        l_SQLCommand += [ HAVING ]+::ExpressionToMYSQL(::p_Having[1])
    case l_NumberOfHavings > 1
        l_SQLCommand += [ HAVING (]
        for l_Counter = 1 to l_NumberOfHavings
            if l_Counter > 1
                l_SQLCommand += [ AND ]
            endif
            l_SQLCommand += [(]+::ExpressionToMYSQL(::p_Having[l_Counter])+[)]
        endfor
        l_SQLCommand += [)]
    endcase
        
    if l_NumberOfOrderBys > 0
        l_SQLCommand += [ ORDER BY ]
        for l_Counter = 1 to l_NumberOfOrderBys
            if l_Counter > 1
                l_SQLCommand += [ , ]
            endif
            l_SQLCommand += ::ExpressionToMYSQL(::p_OrderBy[l_Counter,1])
            if ::p_OrderBy[l_Counter,2]
                l_SQLCommand += [ ASC]
            else
                l_SQLCommand += [ DESC]
            endif
        endfor
    endif
    
    if ::p_Limit > 0
        l_SQLCommand += [ LIMIT ]+trans(::p_Limit)+[ ]
    endif
    
    l_SQLCommand := strtran(l_SQLCommand,[->],[.])
    
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_SQLCommand := [SELECT ]
    
    if ::p_Distinct
        l_SQLCommand += [DISTINCT ]
    endif
    
    // _M_ add support to "*"
    if empty(l_NumberOfFieldsToReturn)
        l_SQLCommand += [ ]+::p_TableAlias+[.]+::p_oSQLConnection:FormatIdentifier(::p_PKFN)+[ AS ]+::p_oSQLConnection:FormatIdentifier(::p_PKFN)
    else
        for l_Counter := 1 to l_NumberOfFieldsToReturn
            if l_Counter > 1
                l_SQLCommand += [,]
            endif
            l_SQLCommand += ::ExpressionToPostgreSQL(::p_FieldToReturn[l_Counter,1])
            
            if !empty(::p_FieldToReturn[l_Counter,2])
                l_SQLCommand += [ AS "]+::p_FieldToReturn[l_Counter,2]+["]
            else
                l_SQLCommand += [ AS "]+strtran(::p_FieldToReturn[l_Counter,1],[.],[_])+["]
            endif
        endfor
    endif
    
    if ::p_SchemaAndTableName == ::p_TableAlias
        l_SQLCommand += [ FROM ]+::p_oSQLConnection:FormatIdentifier(::p_SchemaAndTableName)
    else
        l_SQLCommand += [ FROM ]+::p_oSQLConnection:FormatIdentifier(::p_SchemaAndTableName)+[ AS ]+::p_oSQLConnection:FormatIdentifier(::p_TableAlias)
    endif
    
    for l_Counter = 1 to l_NumberOfJoins
        
        do case
        case left(::p_Join[l_Counter,1],1) == "I"  //Inner Join
            l_SQLCommand += [ INNER JOIN]
        case left(::p_Join[l_Counter,1],1) == "L"  //Left Outer
            l_SQLCommand += [ LEFT OUTER JOIN]
        case left(::p_Join[l_Counter,1],1) == "R"  //Right Outer
            l_SQLCommand += [ RIGHT OUTER JOIN]
        case left(::p_Join[l_Counter,1],1) == "F"  //Full Outer
            l_SQLCommand += [ FULL OUTER JOIN]
        otherwise
            loop
        endcase
        
        l_SQLCommand += [ ]+::p_oSQLConnection:FormatIdentifier(::p_Join[l_Counter,2])
        
        // if !empty(::p_Join[l_Counter,3])   the ::Join() method ensured it is never empty
            l_SQLCommand += [ AS ] + ::p_oSQLConnection:FormatIdentifier(lower(::p_Join[l_Counter,3]))
        // endif
        
        l_SQLCommand += [ ON ] +  ::ExpressionToPostgreSQL(::p_Join[l_Counter,4])
        
    endfor
    
    do case
    case l_NumberOfWheres = 1
        l_SQLCommand += [ WHERE (]+::ExpressionToPostgreSQL(::p_Where[1])+[)]
    case l_NumberOfWheres > 1
        l_SQLCommand += [ WHERE (]
        for l_Counter = 1 to l_NumberOfWheres
            if l_Counter > 1
                l_SQLCommand += [ AND ]
            endif
            l_SQLCommand += [(]+::ExpressionToPostgreSQL(::p_Where[l_Counter])+[)]
        endfor
        l_SQLCommand += [)]
    endcase
        
    if l_NumberOfGroupBys > 0
        l_SQLCommand += [ GROUP BY ]
        for l_Counter = 1 to l_NumberOfGroupBys
            if l_Counter > 1
                l_SQLCommand += [,]
            endif
            l_SQLCommand += ::ExpressionToPostgreSQL(::p_GroupBy[l_Counter])
        endfor
    endif
        
    do case
    case l_NumberOfHavings = 1
        l_SQLCommand += [ HAVING ]+::ExpressionToPostgreSQL(::p_Having[1])
    case l_NumberOfHavings > 1
        l_SQLCommand += [ HAVING (]
        for l_Counter = 1 to l_NumberOfHavings
            if l_Counter > 1
                l_SQLCommand += [ AND ]
            endif
            l_SQLCommand += [(]+::ExpressionToPostgreSQL(::p_Having[l_Counter])+[)]
        endfor
        l_SQLCommand += [)]
    endcase
        
    if l_NumberOfOrderBys > 0
        l_SQLCommand += [ ORDER BY ]
        for l_Counter = 1 to l_NumberOfOrderBys
            if l_Counter > 1
                l_SQLCommand += [ , ]
            endif
            l_SQLCommand += ::ExpressionToPostgreSQL(::p_OrderBy[l_Counter,1])
            if ::p_OrderBy[l_Counter,2]
                l_SQLCommand += [ ASC]
            else
                l_SQLCommand += [ DESC]
            endif
        endfor
    endif
    
    if ::p_Limit > 0
        l_SQLCommand += [ LIMIT ]+trans(::p_Limit)+[ ]
    endif
    
    l_SQLCommand := strtran(l_SQLCommand,[->],[.])

otherwise
    l_SQLCommand := ""
    
endcase

return l_SQLCommand
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
local l_SQLCommand
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
    
case pcount() == 1
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
        
        l_SQLCommand := ::BuildSQL()
        
        ::p_LastSQLCommand := l_SQLCommand
        
        l_ErrorOccured := .t.   //Assumed it failed
        
        do case
        case ::p_ExplainMode > 0
            l_OutputType := 0  // will behave as no output but l_result will be the explain text.

            l_CursorTempName := "c_DB_Temp"
            
            do case
            case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
                do case
                case ::p_ExplainMode == 1
                    l_SQLCommand := "EXPLAIN " + l_SQLCommand
                case ::p_ExplainMode == 2
                    l_SQLCommand := "ANALYZE " + l_SQLCommand
                endcase
            case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
                do case
                case ::p_ExplainMode == 1
                    l_SQLCommand := "EXPLAIN " + l_SQLCommand
                case ::p_ExplainMode == 2
                    l_SQLCommand := "EXPLAIN ANALYZE " + l_SQLCommand
                endcase
            endcase

            l_TimeStart := seconds()
            l_SQLResult := ::p_oSQLConnection:SQLExec(l_SQLCommand,l_CursorTempName)
            l_TimeEnd := seconds()
            ::p_LastRunTime := l_TimeEnd-l_TimeStart+0.0000
            
            if !l_SQLResult
                hb_orm_SendToDebugView("Failed SQLExec. SQLId="+trans(l_SQLID)+"  Error Text="+::p_oSQLConnection:GetSQLExecErrorMessage())
            else
                l_result := ""

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
            l_SQLResult := ::p_oSQLConnection:SQLExec(l_SQLCommand,l_CursorTempName)
            l_TimeEnd := seconds()
            ::p_LastRunTime := l_TimeEnd-l_TimeStart+0.0000
            
            if !l_SQLResult
                hb_orm_SendToDebugView("Failed SQLExec. SQLId="+trans(l_SQLID)+"  Error Text="+::p_oSQLConnection:GetSQLExecErrorMessage())
            else
                //  _M_
                // if (l_TimeEnd - l_TimeStart + 0.0000 >= ::p_MaxTimeForSlowWarning)
                    // ::SQLSendPerformanceIssueToMonitoringSystem(l_SQLID,2,::p_MaxTimeForSlowWarning,l_TimeStart,l_TimeEnd,l_SQLPerformanceInfo,l_SQLCommand)
                // endif
                
                l_ErrorOccured := .f.
                ::Tally        := (l_CursorTempName)->(reccount())
                
            endif
            CloseAlias(l_CursorTempName)
            
        case l_OutputType == 1 // cursor
            
            l_TimeStart := seconds()
            l_SQLResult := ::p_oSQLConnection:SQLExec(l_SQLCommand,::p_CursorName)
            l_TimeEnd := seconds()
            ::p_LastRunTime := l_TimeEnd-l_TimeStart+0.0000
            
            if !l_SQLResult
                hb_orm_SendToDebugView("Failed SQLExec. SQLId="+trans(l_SQLID)+"  Error Text="+::p_oSQLConnection:GetSQLExecErrorMessage())
            else
                select (::p_CursorName)
                //_M_
                // if (l_TimeEnd - l_TimeStart + 0.0000 >= ::p_MaxTimeForSlowWarning)
                    // ::SQLSendPerformanceIssueToMonitoringSystem(l_SQLID,2,::p_MaxTimeForSlowWarning,l_TimeStart,l_TimeEnd,l_SQLPerformanceInfo,l_SQLCommand)
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
            l_SQLResult := ::p_oSQLConnection:SQLExec(l_SQLCommand,l_CursorTempName)
            l_TimeEnd := seconds()
            ::p_LastRunTime := l_TimeEnd-l_TimeStart+0.0000
            
            if !l_SQLResult
                hb_orm_SendToDebugView("Failed SQLExec. SQLId="+trans(l_SQLID)+"  Error Text="+::p_oSQLConnection:GetSQLExecErrorMessage())
            else
                // if (l_TimeEnd - l_TimeStart + 0.0000 >= ::p_MaxTimeForSlowWarning)
                // 	// ::SQLSendPerformanceIssueToMonitoringSystem(l_SQLID,2,::p_MaxTimeForSlowWarning,l_TimeStart,l_TimeEnd,l_SQLPerformanceInfo,l_SQLCommand)
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
            l_SQLResult = ::p_oSQLConnection:SQLExec(l_SQLCommand,l_CursorTempName)
            l_TimeEnd = seconds()
            ::p_LastRunTime := l_TimeEnd-l_TimeStart+0.0000
            
            if !l_SQLResult
                hb_orm_SendToDebugView("Failed SQLExec. SQLId="+trans(l_SQLID)+"  Error Text="+::p_oSQLConnection:GetSQLExecErrorMessage())
            else
                select (l_CursorTempName)

                // if (l_TimeEnd - l_TimeStart + 0.0000 >= ::p_MaxTimeForSlowWarning)
                // 	::SQLSendPerformanceIssueToMonitoringSystem(l_SQLID,2,::p_MaxTimeForSlowWarning,l_TimeStart,l_TimeEnd,l_SQLPerformanceInfo,l_SQLCommand)
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
            
            // ::SQLSendToLogFileAndMonitoringSystem(l_SQLID,1,l_SQLCommand+[ -> ]+::p_ErrorMessage)
            
        else
            if l_OutputType == 1   //Into Cursor
                select (::p_CursorName)
            else
                select (l_select)
            endif
            
            // ::SQLSendToLogFileAndMonitoringSystem(l_SQLID,0,l_SQLCommand+[ -> Reccount = ]+trans(::Tally))
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
local l_SQLCommand
local l_ErrorOccured

//_M_ enhance to allow joins, as long as only one related record.

if pcount() == 2
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
        l_SQLCommand := [SELECT ]
        
        if empty(len(::p_FieldToReturn))
            l_SQLCommand += [ *]
        else
            for l_Counter = 1 to len(::p_FieldToReturn)
                if l_Counter > 1
                    l_SQLCommand += [,]
                endif
                l_SQLCommand +=  ::ExpressionToMYSQL(::p_FieldToReturn[l_Counter,1])
                
                if !empty(::p_FieldToReturn[l_Counter,2])
                    l_SQLCommand += [ AS `]+::p_FieldToReturn[l_Counter,2]+[`]
                else
                    l_SQLCommand += [ AS `]+strtran(::p_FieldToReturn[l_Counter,1],[.],[_])+[`]
                endif
                
            endfor
        endif
        
        l_SQLCommand += [ FROM ]+::p_oSQLConnection:FormatIdentifier(::p_SchemaAndTableName)+[ AS ]+::p_oSQLConnection:FormatIdentifier(::p_TableAlias)
        l_SQLCommand += [ WHERE (]+::p_oSQLConnection:FormatIdentifier(::p_PKFN)+[ = ]+trans(::p_KEY)+[)]
        
        l_SQLCommand := strtran(l_SQLCommand,[->],[.])
        ::p_LastSQLCommand := l_SQLCommand
        
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL	
        l_SQLCommand := [SELECT ]
        
        if empty(len(::p_FieldToReturn))
            l_SQLCommand += [ *]
        else
            for l_Counter = 1 to len(::p_FieldToReturn)
                if l_Counter > 1
                    l_SQLCommand += [,]
                endif
                l_SQLCommand +=  ::ExpressionToPostgreSQL(::p_FieldToReturn[l_Counter,1])
                
                if !empty(::p_FieldToReturn[l_Counter,2])
                    l_SQLCommand += [ AS "]+::p_FieldToReturn[l_Counter,2]+["]
                else
                    l_SQLCommand += [ AS "]+strtran(::p_FieldToReturn[l_Counter,1],[.],[_])+["]
                endif
                
            endfor
        endif
        
        l_SQLCommand += [ FROM ]+::p_oSQLConnection:FormatIdentifier(::p_SchemaAndTableName)+[ AS ]+::p_oSQLConnection:FormatIdentifier(::p_TableAlias)
        l_SQLCommand += [ WHERE (]+::p_oSQLConnection:FormatIdentifier(::p_PKFN)+[ = ]+trans(::p_KEY)+[)]
        
        l_SQLCommand := strtran(l_SQLCommand,[->],[.])
        ::p_LastSQLCommand := l_SQLCommand
        
    endcase

    l_ErrorOccured := .t.   // Assumed it failed
    
    l_CursorTempName := "c_DB_Temp"

    if ::p_oSQLConnection:SQLExec(l_SQLCommand,l_CursorTempName)
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
        ::p_ErrorMessage := ::p_oSQLConnection:GetSQLExecErrorMessage()
        hb_orm_SendToDebugView("Error in method get()",::p_ErrorMessage)
    endif
    
    CloseAlias(l_CursorTempName)
    
    if l_ErrorOccured
        ::Tally = -1
        select (l_select)
        
        // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQLCommand+[ -> ]+::p_ErrorMessage)
        
    else
        select (l_select)
        
        // ::SQLSendToLogFileAndMonitoringSystem(0,0,l_SQLCommand+[ -> Reccount = ]+trans(::Tally))
    endif

endcase

return l_result
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
method FormatDateTimeForSQLUpdate(par_Dati,par_nPrecision) class hb_orm_SQLData

local l_result
local l_nPrecision := min(hb_defaultValue(par_nPrecision,0),4)  //Harbour can only handle up to 4 precision
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
        l_result := [']+hb_TtoC(par_Dati,"YYYY-MM-DD","hh:mm:ss"+iif(l_nPrecision=0,"","."+replicate("f",l_nPrecision)))+[']
        
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        l_result := [']+hb_TtoC(par_Dati,"YYYY-MM-DD","hh:mm:ss"+iif(l_nPrecision=0,"","."+replicate("f",l_nPrecision)))+[']
        
    // case inlist(v_SQLServerType,"MSSQL2000","MSSQL2005","MSSQL2008")
    // 	l_result := [']+hb_TtoC(par_Dati,"YYYY-MM-DD","hh:mm:ss")+[']
        
    otherwise
        l_result := [']+hb_TtoC(par_Dati,"YYYY-MM-DD","hh:mm:ss"+iif(l_nPrecision=0,"","."+replicate("f",l_nPrecision)))+[']
        
    endcase
    
endif
return l_result
//-----------------------------------------------------------------------------------------------------------------
method PrepValueForMySQL(par_cAction,par_xValue,par_cTableName,par_nKey,par_cFieldName,par_aFieldInfo,l_aAutoTrimmedFields,l_aErrors) class hb_orm_SQLData
local l_result := .t.
local l_Value  := NIL
local l_FieldType := par_aFieldInfo[HB_ORM_SCHEMA_FIELD_TYPE]
local l_ValueType := Valtype(par_xValue)                       //See https://github.com/Petewg/harbour-core/wiki/V
local l_FieldLen,l_FieldDec
local l_nMaxValue
local l_UnsignedLength,l_Decimals

if hb_IsNIL(par_xValue)
    l_Value  := "NULL"
else
    switch l_FieldType
    case  "I" // Integer
        if l_ValueType == "N"
            if par_xValue < -2147483648 .or. par_xValue > 2147483647
                AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not in Integer range'})
                l_result := .f.
            else
                l_Value := hb_ntoc(par_xValue)
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not an Integer'})
            l_result := .f.
        endif
        exit
    case "IB" // Big Integer
        if l_ValueType == "N"
            // Not Testing if in range
            l_Value := hb_ntoc(par_xValue)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not an Big Integer'})
            l_result := .f.
        endif
        exit
    case  "Y" // Money  (4 decimals)
        if l_ValueType == "N"
            // Not Testing if in range Yet
            l_Value := hb_ntoc(par_xValue)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Numeric / Money'})
            l_result := .f.
        endif
        exit
    case  "N" // numeric
        do case
        case l_ValueType == "N"
            l_FieldLen := par_aFieldInfo[HB_ORM_SCHEMA_FIELD_LENGTH]
            l_FieldDec := par_aFieldInfo[HB_ORM_SCHEMA_FIELD_DECIMALS]
            if l_FieldLen > 15
                AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Numeric with more than 15 digits.'})
                l_result := .f.
            else
                l_nMaxValue := ((10**l_FieldLen)-1)/(10**l_FieldDec)
                if abs(par_xValue) <= l_nMaxValue
                    if round(abs(par_xValue),l_FieldDec) == abs(par_xValue)  // Test if decimal is larger than allowed
                        l_Value := hb_ntoc(par_xValue)
                    else
                        AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" Numeric Decimals Overflow: '+alltrim(str(par_xValue))})
                        l_result := .f.
                    endif
                else
                    AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" Numeric Overflow: '+alltrim(str(par_xValue))})
                    l_result := .f.
                endif
            endif
        case l_ValueType == "C"
            l_UnsignedLength := l_Decimals := 0
            if el_AUnpack(IsStringANumber(par_xValue),,@l_UnsignedLength,@l_Decimals)
                l_FieldLen := par_aFieldInfo[HB_ORM_SCHEMA_FIELD_LENGTH]
                l_FieldDec := par_aFieldInfo[HB_ORM_SCHEMA_FIELD_DECIMALS]
                if l_UnsignedLength <= l_FieldLen .and. l_Decimals <= l_FieldDec
                    l_Value := par_xValue
                else
                    AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" Numeric String Overflow: '+par_xValue})
                    l_result := .f.
                endif
            else
                AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Numeric String'})
                l_result := .f.
            endif
        otherwise
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Numeric'})
            l_result := .f.
        endcase
        exit
    case  "C" // char                                                      https://dev.mysql.com/doc/refman/8.0/en/string-literals.html
    case "CV" // variable length char (with option max length value)
    case  "B" // binary
    case "BV" // variable length binary (with option max length value)
        if l_ValueType == "C"
            l_FieldLen := par_aFieldInfo[HB_ORM_SCHEMA_FIELD_LENGTH]
            if len(par_xValue) <= l_FieldLen
                l_Value := "x'"+hb_StrToHex(par_xValue)+"'"
            else
                AAdd(l_aAutoTrimmedFields,{par_cFieldName,par_xValue,l_FieldType,l_FieldLen})
                l_Value := "x'"+hb_StrToHex(left(par_xValue,l_FieldLen))+"'"
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Character'})
            l_result := .f.
        endif
        exit
    case  "M" // longtext
    case  "R" // long blob (binary)
        if l_ValueType == "C"
            if len(par_xValue) == 0   //_M_ Test if this logic makes senses for MySQL
                l_Value := "''"
            else
                l_Value := "x'"+hb_StrToHex(par_xValue)+"'"
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Character/Binary'})
            l_result := .f.
        endif
        exit
    case  "L" // Logical
        if l_ValueType == "L"
            l_Value := iif(par_xValue,"TRUE","FALSE")
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Logical'})
            l_result := .f.
        endif
        exit
    case  "D" // Date   
        if l_ValueType == "D"
            // l_Value := '"'+hb_DtoC(par_xValue,"YYYY-MM-DD")+'"'           //_M_  Test on 1753-01-01  Test integrity in MySQL
            l_Value := ::FormatDateForSQLUpdate(par_xValue)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Date'})
            l_result := .f.
        endif
        exit

    case"TOZ" // Time with time zone               'hh:mm:ss[.fraction]'
    case "TO" // Time without time zone
        if l_ValueType == "C"
            l_FieldDec := par_aFieldInfo[HB_ORM_SCHEMA_FIELD_DECIMALS]
            if hb_orm_CheckTimeFormatValidity(par_xValue)
                if len(par_xValue) > 9 + l_FieldDec
                    AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" Time String precision Overflow: '+alltrim(par_xValue)})
                    l_result := .f.
                else
                    l_Value := '"'+par_xValue+'"'
                endif
            else
                AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a valid Time String'})
                l_result := .f.
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Time String'})
            l_result := .f.
        endif
        exit

    case"DTZ" // Date Time with time zone           https://dev.mysql.com/doc/refman/8.0/en/datetime.html  _M_ Support for Time fractions and test for precision.
    case "DT" // Date Time without time zone
    case  "T" // Date Time without time zone
        if l_ValueType == "T"
            // l_Value := '"'+hb_TtoC(l_Value,"YYYY-MM-DD","hh:mm:ss")+'"'           //_M_  Test on 1753-01-01
            l_Value := ::FormatDateTimeForSQLUpdate(par_xValue,3)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Datetime'})
            l_result := .f.
        endif
        exit
    otherwise // "?" Unknown
        hb_orm_SendToDebugView("Skipped "+par_cAction+" unknown value type: "+l_ValueType)
        AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" of Unknown type'})
        l_result := .f.
        exit
    endcase
endif

return {l_result,l_Value}
//-----------------------------------------------------------------------------------------------------------------
method PrepValueForPostgreSQL(par_cAction,par_xValue,par_cTableName,par_nKey,par_cFieldName,par_aFieldInfo,l_aAutoTrimmedFields,l_aErrors) class hb_orm_SQLData
local l_result := .t.
local l_Value  := NIL
local l_FieldType := par_aFieldInfo[HB_ORM_SCHEMA_FIELD_TYPE]
local l_ValueType := Valtype(par_xValue)                       //See https://github.com/Petewg/harbour-core/wiki/V
local l_FieldLen,l_FieldDec
local l_nMaxValue
local l_UnsignedLength,l_Decimals

if hb_IsNIL(par_xValue)
    l_Value  := "NULL"
else
    switch l_FieldType
    case  "I" // Integer
        if l_ValueType == "N"
            if par_xValue < -2147483648 .or. par_xValue > 2147483647
                AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not in Integer range'})
                l_result := .f.
            else
                l_Value := hb_ntoc(par_xValue)
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not an Integer'})
            l_result := .f.
        endif
        exit
    case "IB" // Big Integer
        if l_ValueType == "N"
            // Not Testing if in range
            l_Value := hb_ntoc(par_xValue)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not an Big Integer'})
            l_result := .f.
        endif
        exit
    case  "Y" // Money  (4 decimals)
        if l_ValueType == "N"
            // Not Testing if in range Yet
            l_Value := hb_ntoc(par_xValue)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Numeric / Money'})
            l_result := .f.
        endif
        exit
    case  "N" // numeric
        do case
        case l_ValueType == "N"
            l_FieldLen := par_aFieldInfo[HB_ORM_SCHEMA_FIELD_LENGTH]
            l_FieldDec := par_aFieldInfo[HB_ORM_SCHEMA_FIELD_DECIMALS]
            if l_FieldLen > 15
                AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Numeric with more than 15 digits.'})
                l_result := .f.
            else
                l_nMaxValue := ((10**l_FieldLen)-1)/(10**l_FieldDec)
                if abs(par_xValue) <= l_nMaxValue
                    if round(abs(par_xValue),l_FieldDec) == abs(par_xValue)  // Test if decimal is larger than allowed
                        l_Value := hb_ntoc(par_xValue)
                    else
                        AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" Numeric Decimals Overflow: '+alltrim(str(par_xValue))})
                        l_result := .f.
                    endif
                else
                    AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" Numeric Overflow: '+alltrim(str(par_xValue))})
                    l_result := .f.
                endif
            endif
        case l_ValueType == "C"
            l_UnsignedLength := l_Decimals := 0
            if el_AUnpack(IsStringANumber(par_xValue),,@l_UnsignedLength,@l_Decimals)
                l_FieldLen := par_aFieldInfo[HB_ORM_SCHEMA_FIELD_LENGTH]
                l_FieldDec := par_aFieldInfo[HB_ORM_SCHEMA_FIELD_DECIMALS]
                if l_UnsignedLength <= l_FieldLen .and. l_Decimals <= l_FieldDec
                    l_Value := par_xValue
                else
                    AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" Numeric String Overflow: '+par_xValue})
                    l_result := .f.
                endif
            else
                AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Numeric String'})
                l_result := .f.
            endif
        otherwise
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Numeric'})
            l_result := .f.
        endcase
        exit
    case  "C" // char 
    case "CV" // variable length char (with option max length value)
    case  "B" // binary
    case "BV" // variable length binary (with option max length value)
        if l_ValueType == "C"
            l_FieldLen := par_aFieldInfo[HB_ORM_SCHEMA_FIELD_LENGTH]
            if len(par_xValue) <= l_FieldLen
                l_Value := "E'\x"+hb_StrToHex(par_xValue,"\x")+"'"
            else
                AAdd(l_aAutoTrimmedFields,{par_cFieldName,par_xValue,l_FieldType,l_FieldLen})
                l_Value := "E'\x"+hb_StrToHex(left(par_xValue,l_FieldLen),"\x")+"'"
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Character'})
            l_result := .f.
        endif
        exit
    case  "M" // longtext
    case  "R" // long blob (binary)
        if l_ValueType == "C"
            if len(par_xValue) == 0
                l_Value := "''"
            else
                l_Value := "E'\x"+hb_StrToHex(par_xValue,"\x")+"'"
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Character/Binary'})
            l_result := .f.
        endif
        exit
    case  "L" // Logical
        if l_ValueType == "L"
            l_Value := iif(par_xValue,"TRUE","FALSE")
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Logical'})
            l_result := .f.
        endif
        exit
    case  "D" // Date 
        if l_ValueType == "D"
            // l_Value := '"'+hb_DtoC(par_xValue,"YYYY-MM-DD")+'"'           //_M_  Test integrity in MySQL
            l_Value := ::FormatDateForSQLUpdate(par_xValue)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Date'})
            l_result := .f.
        endif
        exit

    case"TOZ" // Time with time zone               'hh:mm:ss[.fraction]'
    case "TO" // Time without time zone
        if l_ValueType == "C"
            //if (SecToTime(TimeToSec(par_xValue),len(par_xValue)=11) == par_xValue)   //_M_ Verify format validity
            l_FieldDec := par_aFieldInfo[HB_ORM_SCHEMA_FIELD_DECIMALS]
            if hb_orm_CheckTimeFormatValidity(par_xValue)
                if len(par_xValue) > 9 + l_FieldDec
                    AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" Time String precision Overflow: '+alltrim(par_xValue)})
                    l_result := .f.
                else
                    l_Value := "'"+par_xValue+"'"
                endif
            else
                AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a valid Time String'})
                l_result := .f.
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Time String'})
            l_result := .f.
        endif
        exit

    case"DTZ" // Date Time with time zone           _M_ Support for Time fractions and test for precision.
    case "DT" // Date Time without time zone
    case  "T" // Date Time without time zone
        if l_ValueType == "T"
            l_Value := ::FormatDateTimeForSQLUpdate(par_xValue,3)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Datetime'})
            l_result := .f.
        endif
        exit
    otherwise // "?" Unknown
        hb_orm_SendToDebugView("Skipped "+par_cAction+" unknown value type: "+l_ValueType)
        AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" of Unknown type'})
        l_result := .f.
        exit
    endcase
endif

return {l_result,l_Value}
//-----------------------------------------------------------------------------------------------------------------
static function IsStringANumber(par_cNumber)
local l_Result := .t.
local l_nPos
local l_char
local l_FoundPeriod := .f.
local l_UnsignedLength  := 0
local l_decimal := 0

if empty(par_cNumber)
    l_Result := .f.
else
    l_char := left(par_cNumber,1)
    do case
    case l_char == "-"
    case l_char $ "0123456789"
        l_UnsignedLength += 1
    otherwise
        l_Result := .f.
    endcase

    if l_Result
        for l_nPos := 2 to Len(par_cNumber)
            l_char := substr(par_cNumber,l_nPos,1)
            do case
            case l_char $ "0123456789"
                l_UnsignedLength += 1
                if l_FoundPeriod
                    l_decimal += 1
                endif
            case l_char == "."
                if l_FoundPeriod
                    //More than 1 period
                    l_Result := .f.
                    exit
                else
                    l_FoundPeriod := .t.
                endif
            otherwise
                l_Result := .f.
                exit
            endcase
        endfor
    endif
endif
return {l_Result,l_UnsignedLength,l_decimal}

//-----------------------------------------------------------------------------------------------------------------
function hb_orm_CheckTimeFormatValidity(par_cTime)
local l_Result := .t.
local l_nPos

//Max 23:59:59.999999
do case
case !(substr(par_cTime,1,1) $ "012")
    l_Result := .f.
case !(substr(par_cTime,2,1) $ "0123456789")
    l_Result := .f.
case val(substr(par_CTime,1,2)) > 23
    l_Result := .f.
case !(substr(par_cTime,3,1) == ":")
    l_Result := .f.
case !(substr(par_cTime,4,1) $ "012345")
    l_Result := .f.
case !(substr(par_cTime,5,1) $ "0123456789")
    l_Result := .f.
case val(substr(par_CTime,4,2)) > 59
    l_Result := .f.
case !(substr(par_cTime,6,1) == ":")
    l_Result := .f.
case !(substr(par_cTime,7,1) $ "012345")
    l_Result := .f.
case !(substr(par_cTime,8,1) $ "0123456789")
    l_Result := .f.
case val(substr(par_CTime,7,2)) > 59
    l_Result := .f.
case len(par_CTime) = 8
    //Done Testing is valid
case len(par_CTime) = 9  //would need some decimal values
    l_Result := .f.
case len(par_CTime) > 15
    l_Result := .f. // More than 6 decimals
case len(par_CTime) > 8
    if !(substr(par_CTime,9,1) == ".")
        l_Result := .f.
    else
        for l_nPos := 10 to len(par_CTime)
            if !(substr(par_cTime,l_nPos,1) $ "0123456789")
                l_Result := .f.
                exit
            endif
        endfor
    endif
endcase

return l_Result

//-----------------------------------------------------------------------------------------------------------------

//#include "hb_orm_schema.prg"

//-----------------------------------------------------------------------------------------------------------------
