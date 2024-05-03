//Copyright (c) 2024 Eric Lendvai MIT License

#include "hb_orm.ch"

#define INVALUEWITCH              chr(1)
#define INPOSSIBLEZERONULLEQUAL   chr(2)
#define INPOSSIBLEZERONULLGREATER chr(3)

//=================================================================================================================
#include "hb_orm_sqldata_class_definition.prg"
//-----------------------------------------------------------------------------------------------------------------
method Init() class hb_orm_SQLData
// hb_HCaseMatch(::QueryString,.f.)
return Self
//-----------------------------------------------------------------------------------------------------------------
method IsConnected() class hb_orm_SQLData    //Return .t. if has a connection

return (::p_oSQLConnection != NIL .and.  ::p_oSQLConnection:GetHandle() > 0)
//-----------------------------------------------------------------------------------------------------------------
method UseConnection(par_oSQLConnection) class hb_orm_SQLData
::p_oSQLConnection            := par_oSQLConnection
::p_BackendType               := ::p_oSQLConnection:GetBackendType()
::p_SQLEngineType             := ::p_oSQLConnection:GetSQLEngineType()
::p_ConnectionNumber          := ::p_oSQLConnection:GetConnectionNumber()
::p_Database                  := ::p_oSQLConnection:GetDatabase()
::p_NamespaceName             := ::p_oSQLConnection:GetCurrentNamespaceName()   // Will "Freeze" the current connection p_NamespaceName
::p_CreationTimeFieldName     := ::p_oSQLConnection:GetCreationTimeFieldName()
::p_ModificationTimeFieldName := ::p_oSQLConnection:GetModificationTimeFieldName()
return Self
//-----------------------------------------------------------------------------------------------------------------
//---------------------------------------------------------------------------------------------------------------
method Echo(par_cText) class hb_orm_SQLData
// return par_cText+trans(::p_SQLEngineType)

// local l_aArray := {{1,2},{3,4},{5,6},{7,8},{9,10}}
// local l_aSubArray
// local l_i

// for each l_aSubArray in l_aArray
//     altd()
//     l_i := l_aSubArray
// endfor

//Bogus call to force the linker
//el_GetVersion()

return par_cText
//-----------------------------------------------------------------------------------------------------------------
method destroy() class hb_orm_SQLData
// hb_orm_SendToDebugView("hb_orm_sqldata destroy")
::p_oSQLConnection := NIL
return .t.
//-----------------------------------------------------------------------------------------------------------------
method Table(par_xEventId,par_cNamespaceAndTableName,par_cAlias) class hb_orm_SQLData
local l_nPos
local l_aErrors := {}
local l_cNonTableAlias
local l_cNamespaceAndTableName

if pcount() > 0 .and. !empty(::p_oSQLConnection:p_hWharfConfig)
    ::SetEventId(par_xEventId)

    // hb_HCaseMatch(::p_AliasToNamespaceAndTableNames,.f.)     No Need to make it case insensitive since Aliases are always converted to lower case
    hb_HClear(::p_AliasToNamespaceAndTableNames)

    hb_HClear(::p_FieldsAndValues)
    
    asize(::p_Join,0)
    asize(::p_ColumnToReturn,0)
    asize(::p_Where,0)
    asize(::p_GroupBy,0)
    asize(::p_Having,0)
    asize(::p_OrderBy,0)
    
    ::Tally             := 0
    
    ::p_TableFullPath                 := ""
    ::p_CursorName                    := ""
    ::p_CursorUpdatable               := .f.
    ::p_LastSQLCommand                := ""
    ::p_LastRunTime                   := 0
    ::p_LastUpdateChangedData         := .f.
    ::p_LastDateTimeOfChangeFieldName := ""
    ::p_AddLeadingBlankRecord         := .f.
    ::p_AddLeadingRecordsCursorName   := ""
    ::p_DistinctMode                  := 0
    ::p_Limit                         := 0
    
    ::p_NumberOfFetchedFields := 0          //  Used on Select *
    asize(::p_FetchedFieldsNames,0)
    
    ::p_MaxTimeForSlowWarning := 2.000  //  number of seconds
    
    ::p_ExplainMode := 0

    l_cNonTableAlias := hb_HGetDef(::p_NonTableAliases,lower(par_cNamespaceAndTableName),"")
    if !empty(l_cNonTableAlias)
        ::p_NamespaceAndTableName := l_cNonTableAlias   // Will have the correct casing
        if pcount() >= 3 .and. !empty(par_cAlias)
            ::p_TableAlias := lower(par_cAlias)
        else
            ::p_TableAlias := l_cNonTableAlias
        endif
    else
        // if ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL   //empty(::p_NamespaceName)   // Meaning not on HB_ORM_ENGINETYPE_POSTGRESQL
        //     ::p_NamespaceAndTableName = ::p_oSQLConnection:CaseTableName(par_cNamespaceAndTableName)
        //     if pcount() >= 3 .and. !empty(par_cAlias)
        //         ::p_TableAlias := lower(par_cAlias)
        //     else
        //         ::p_TableAlias := lower(::p_NamespaceAndTableName)
        //     endif
        // else
        //     l_nPos = at(".",par_cNamespaceAndTableName)
        //     if empty(l_nPos)
        //         ::p_NamespaceAndTableName := ::p_oSQLConnection:CaseTableName(::p_NamespaceName+"."+par_cNamespaceAndTableName)
        //         l_nPos = at(".",::p_NamespaceAndTableName)
        //     else
        //         ::p_NamespaceAndTableName := ::p_oSQLConnection:CaseTableName(par_cNamespaceAndTableName)
        //     endif
        //     if pcount() >= 3 .and. !empty(par_cAlias)
        //         ::p_TableAlias := lower(par_cAlias)
        //     else
        //         ::p_TableAlias := lower(substr(::p_NamespaceAndTableName,l_nPos+1))
        //     endif
        // endif

        l_cNamespaceAndTableName  := ::p_oSQLConnection:NormalizeTableNameInternal(par_cNamespaceAndTableName)
        ::p_NamespaceAndTableName := ::p_oSQLConnection:CaseTableName(l_cNamespaceAndTableName)

        if empty(::p_NamespaceAndTableName)
            AAdd(l_aErrors,{par_cNamespaceAndTableName,NIL,[Auto-Casing Error: Failed To find table "]+par_cNamespaceAndTableName+[".],hb_orm_GetApplicationStack()})
            ::p_oSQLConnection:LogErrorEvent(::p_cEventId,l_aErrors)
            ::p_TableAlias := ""   // To ensure will crash later on.
        else
            if pcount() >= 3 .and. !empty(par_cAlias)
                ::p_TableAlias := lower(par_cAlias)
            else
                l_nPos = at(".",::p_NamespaceAndTableName)
                ::p_TableAlias := lower(substr(::p_NamespaceAndTableName,l_nPos+1))
            endif

            ::p_AliasToNamespaceAndTableNames[::p_TableAlias] := ::p_NamespaceAndTableName
            
        endif
    endif
    
    ::p_Key     := 0
else
    ::p_NamespaceAndTableName := ""
endif

return ::p_NamespaceAndTableName
//-----------------------------------------------------------------------------------------------------------------
method SetEventId(par_xId) class hb_orm_SQLData
if ValType(par_xId) == "N"
    ::p_cEventId := trans(par_xId)
else
    ::p_cEventId := left(AllTrim(par_xId),HB_ORM_MAX_EVENTID_SIZE)
endif
return NIL
//-----------------------------------------------------------------------------------------------------------------
method Distinct(par_lMode) class hb_orm_SQLData
::p_DistinctMode := iif(par_lMode,1,0)
return NIL
//-----------------------------------------------------------------------------------------------------------------
method Limit(par_Limit) class hb_orm_SQLData
::p_Limit := par_Limit
return NIL
//-----------------------------------------------------------------------------------------------------------------
method Key(par_iKey) class hb_orm_SQLData                                     //Set the key or retrieve the last used key
if pcount() == 1
    ::p_Key := par_iKey
else
    return ::p_Key
endif
return NIL
//-----------------------------------------------------------------------------------------------------------------
method FieldSet(par_cName,par_nType,par_xValue) class hb_orm_SQLData                         // Called by all other Field* methods. par_nType 1 = Regular Value, 2 = Server Side Expression, 3 = Array
local l_xResult := NIL

local l_cFieldName
local l_aErrors := {}
local l_nPos
local l_hColumnDefinition

if !empty(par_cName)
    // Due to handling NamespaceName+TableName or only TableName, the simplest is to ignore table names info in par_cName.
    l_cFieldName := Strtran(allt(par_cName),"->",".")  // in case Harbour field notification was used instead of SQL notification.
    l_nPos := rat(".",l_cFieldName)
    if l_nPos > 0
        l_cFieldName := substr(l_cFieldName,l_nPos+1)
    endif

    l_cFieldName := ::p_oSQLConnection:CaseFieldName(::p_NamespaceAndTableName,l_cFieldName)
    if empty(l_cFieldName)
        AAdd(l_aErrors,{::p_NamespaceAndTableName,NIL,[Auto-Casing Error: Failed To find Field "]+par_cName+["],hb_orm_GetApplicationStack()})
        ::p_oSQLConnection:LogErrorEvent(::p_cEventId,l_aErrors)
    else
        l_hColumnDefinition := ::p_oSQLConnection:GetColumnConfiguration(::p_NamespaceAndTableName,l_cFieldName)

        if pcount() == 3
           if l_hColumnDefinition["NullZeroEquivalent"] .and. (ValType(par_xValue) == "N") .and. (par_xValue == 0)
                ::p_FieldsAndValues[l_cFieldName] := {par_nType,nil}
            else
                ::p_FieldsAndValues[l_cFieldName] := {par_nType,par_xValue}
            endif
        else
            l_xResult := hb_HGetDef(::p_FieldsAndValues, l_cFieldName, NIL)
            l_xResult := l_xResult[2]

            if hb_IsNil(l_xResult) .and. l_hColumnDefinition["NullZeroEquivalent"]
                l_xResult := 0
            endif
        endif
    endif

endif

return l_xResult
//-----------------------------------------------------------------------------------------------------------------
//The following method existed before the new FieldValue(), FieldExpression and FieldArray() methods. 
method Field(par_cName,par_xValue) class hb_orm_SQLData                        //To set a field (par_cName) in the Table() to the value (par_xValue). If par_xValue is not provided, will return the value from previous set field value
local l_xResult
if pcount() == 1
    l_xResult := ::FieldSet(par_cName)
else
    if ValType( par_xValue ) == "A" .and. par_xValue[1] == "S"
        l_xResult := ::FieldSet(par_cName,2,par_xValue[2])
    else
        l_xResult := ::FieldSet(par_cName,1,par_xValue)
    endif
endif
return l_xResult
//-----------------------------------------------------------------------------------------------------------------
method FieldValue(par_cName,par_xValue) class hb_orm_SQLData                        //To set a field (par_cName) in the Table() to the value (par_xValue). If par_xValue is not provided, will return the value from previous set field value
local l_xResult
if pcount() == 1
    l_xResult := ::FieldSet(par_cName) 
else
    l_xResult := ::FieldSet(par_cName,1,par_xValue) 
endif
return l_xResult
//-----------------------------------------------------------------------------------------------------------------
method FieldExpression(par_cName,par_cValue) class hb_orm_SQLData                        //To set a field (par_cName) in the Table() to the value (par_xValue). If par_xValue is not provided, will return the value from previous set field value
local l_xResult := NIL
local l_cValue := par_cValue
local l_hFieldInfo
local l_nFieldDec
local l_aErrors := {}

do case
case pcount() == 1
    l_xResult := ::FieldSet(par_cName)
    l_cValue := ""

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    do case
    case el_IsInlist(upper(par_cValue),"NOW()","NOW")
        // Auto-determine the precision parameter of current_timestamp()

        l_hFieldInfo := ::p_oSQLConnection:GetFieldInfo(::p_NamespaceAndTableName,par_cName)
        if empty(l_hFieldInfo)
            AAdd(l_aErrors,{::p_NamespaceAndTableName,NIL,[Auto-Casing Error: Failed To find Field "]+par_cName+["],hb_orm_GetApplicationStack()})
            ::p_oSQLConnection:LogErrorEvent(::p_cEventId,l_aErrors)
            l_cValue := ""
        else
            l_nFieldDec := hb_HGetDef(l_hFieldInfo,HB_ORM_GETFIELDINFO_FIELDDECIMALS,0)
            if l_nFieldDec > 0
                l_cValue := "current_timestamp("+alltrim(str(l_nFieldDec))+")"
            else
                l_cValue := "current_timestamp()"
            endif
        endif

    otherwise
    endcase

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    do case
    case el_IsInlist(upper(par_cValue),"NOW()","NOW")
        l_cValue := "now()"
    endcase
endcase

if !empty(l_cValue)
    l_xResult := ::FieldSet(par_cName,2,l_cValue)
endif

return l_xResult
//-----------------------------------------------------------------------------------------------------------------
method FieldArray(par_cName,par_xValue) class hb_orm_SQLData                        //To set a field (par_cName) in the Table() to the value (par_xValue). If par_xValue is not provided, will return the value from previous set field value
local l_xResult

//Arrays are only supported in PostgreSQL
do case
case pcount() == 1
    l_xResult := ::FieldSet(par_cName) 
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_xResult := NIL
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_xResult := ::FieldSet(par_cName,3,par_xValue) 
endcase

return l_xResult
//-----------------------------------------------------------------------------------------------------------------
method ErrorMessage() class hb_orm_SQLData                                   //Retrieve the error text of the last call to :SQL(), :Get(), :Count(), :Add() :Update()  :Delete()
local l_cErrorMessage

if ValType(::p_ErrorMessage) == "A"
    l_cErrorMessage := hb_jsonEncode(::p_ErrorMessage)
else
    l_cErrorMessage := ::p_ErrorMessage
endif
return l_cErrorMessage
//-----------------------------------------------------------------------------------------------------------------
// method GetFormattedErrorMessage() class hb_orm_SQLData                       //Retrieve the error text of the last call to .SQL() or .Get()  in an HTML formatted Fasion  (ELS)
// return iif(empty(::p_ErrorMessage),[],g_OneCellTable(0,0,o_cw.p_Form_Label_Font_Start+[<font color="#FF0000">]+::p_ErrorMessage))
//-----------------------------------------------------------------------------------------------------------------
method Add(par_iKey) class hb_orm_SQLData                                     //Adds a record. par_iKey is optional and can only be used with table with non auto-increment key field
local l_cFields
local l_nSelect
local l_cSQLCommand
local l_cFieldName,l_hFieldInfo
local l_aValue
local l_xValue
local l_cValues
local l_cFieldValue
local l_cArrayValue
local l_oField
local l_aAutoTrimmedFields := {}
local l_aErrors := {}
local l_xKeyFieldValue
local l_nPos
local l_aPrimaryKeyInfo
local l_cPrimaryKeyFieldName

::p_ErrorMessage := ""
::Tally          := 0
::p_Key          := 0

do case
case !::IsConnected()
    ::p_ErrorMessage := [Missing SQL Connection]
case  empty(::p_oSQLConnection:p_hWharfConfig)
    ::p_ErrorMessage := [WharfConfig structure required]
endcase

if empty(::p_ErrorMessage)
    do case
    case len(::p_FieldsAndValues) == 0
        ::p_ErrorMessage = [Missing Fields]
        
    case empty(::p_NamespaceAndTableName)
        ::p_ErrorMessage = [Missing Table]
        
    otherwise
        l_aPrimaryKeyInfo      := hb_HGetDef(::p_oSQLConnection:p_hTablePrimaryKeyInfo,::p_NamespaceAndTableName,{"",""})
        l_cPrimaryKeyFieldName := l_aPrimaryKeyInfo[PRIMARY_KEY_INFO_NAME]

        if empty(l_cPrimaryKeyFieldName)
            ::p_ErrorMessage = [Failed to find Primary Field Name.]
        else
            l_nSelect := iif(used(),select(),0)
            
            do case
            case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
                if pcount() == 1
                    //Used in case the KEY field is not auto-increment
                    l_cFields := ::p_oSQLConnection:FormatIdentifier(l_cPrimaryKeyFieldName)
                    l_cValues := Trans(par_iKey)
                else
                    l_cFields := ""
                    l_cValues := ""
                endif
                
                //Check if a CreationTimeFieldName exists and if yes, set it to now()
                if !empty(::p_CreationTimeFieldName) .and. hb_HGetRef(::p_oSQLConnection:p_hMetadataTable[::p_NamespaceAndTableName][HB_ORM_SCHEMA_FIELD],::p_CreationTimeFieldName)
                    if !empty(l_cFields)
                        l_cFields += ","
                        l_cValues += ","
                    endif
                    l_cFields += ::p_oSQLConnection:FormatIdentifier(::p_CreationTimeFieldName)
                    l_cValues += "current_timestamp()"
                endif
                
                //Check if a ModificationTimeFieldName exists and if yes, set it to now()
                if !empty(::p_ModificationTimeFieldName) .and. hb_HGetRef(::p_oSQLConnection:p_hMetadataTable[::p_NamespaceAndTableName][HB_ORM_SCHEMA_FIELD],::p_ModificationTimeFieldName)
                    if !empty(l_cFields)
                        l_cFields += ","
                        l_cValues += ","
                    endif
                    l_cFields += ::p_oSQLConnection:FormatIdentifier(::p_ModificationTimeFieldName)
                    l_cValues += "current_timestamp()"
                endif
                
                for each l_oField in ::p_FieldsAndValues
                    l_cFieldName := l_oField:__enumKey()  // Will not fix Field name casing since this was already done in the method Field()
                    l_hFieldInfo := ::p_oSQLConnection:p_hMetadataTable[::p_NamespaceAndTableName][HB_ORM_SCHEMA_FIELD][l_cFieldName]
                    l_aValue     := l_oField:__enumValue()

                    switch l_aValue[1]
                    case 1  // Value
                        l_cFieldValue := ""
                        if !el_AUnpack(::PrepValueForMySQL("adding",l_aValue[2],::p_NamespaceAndTableName,0,l_cFieldName,l_hFieldInfo,@l_aAutoTrimmedFields,@l_aErrors),,@l_cFieldValue)
                            loop
                        endif
                        exit
                    case 2  // Expression
                        l_cFieldValue := l_aValue[2]
                        exit
                    otherwise
                        loop
                    endswitch

                    if !empty(l_cFields)
                        l_cFields += ","
                        l_cValues += ","
                    endif
                    l_cFields += ::p_oSQLConnection:FormatIdentifier(l_cFieldName)
                    l_cValues += l_cFieldValue

                endfor
                l_cSQLCommand := [INSERT INTO ]+::p_oSQLConnection:FormatIdentifier(::p_oSQLConnection:NormalizeTableNamePhysical(::p_NamespaceAndTableName))+[ (]+l_cFields+[) VALUES (]+l_cValues+[)]
                
                // l_cSQLCommand := strtran(l_cSQLCommand,"->",".")  // Harbour can use  "table->field" instead of "table.field"

                ::p_LastSQLCommand = l_cSQLCommand

                if ::p_oSQLConnection:SQLExec(::p_cEventId,l_cSQLCommand)
                    do case
                    case pcount() == 1
                        ::p_Key = par_iKey
                        
                    otherwise
                        // LastInsertedID := hb_RDDInfo(RDDI_INSERTID,,"SQLMIX",::p_oSQLConnection:GetHandle())
                        if ::p_oSQLConnection:SQLExec(::p_cEventId,[SELECT LAST_INSERT_ID() as result],"c_DB_Result")
                            ::Tally := 1
                            if Valtype(c_DB_Result->result) == "C"
                                ::p_Key := val(c_DB_Result->result)
                            else
                                ::p_Key := c_DB_Result->result
                            endif
                            // ::SQLSendToLogFileAndMonitoringSystem(0,0,l_cSQLCommand+[ -> Key = ]+trans(::p_Key))
                        else
                            // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_cSQLCommand+[ -> Failed Get Added Key])
                            ::p_ErrorMessage = [Failed To Get Added KEY]
                        endif
                        CloseAlias("c_DB_Result")
                        
                    endcase
                    
                else
                    //Failed To Add
                    // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_cSQLCommand+[ -> ]+::p_ErrorMessage)
                    ::p_ErrorMessage := ::p_oSQLConnection:GetSQLExecErrorMessage()
                    // hb_orm_SendToDebugView(::p_ErrorMessage)

                endif
    
            case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
                if pcount() == 1
                    //Used in case the KEY field is not auto-increment
                    l_cFields := ::p_oSQLConnection:FormatIdentifier(l_cPrimaryKeyFieldName)
                    l_cValues := Trans(par_iKey)
                else
                    l_cFields := ""
                    l_cValues := ""
                endif
                
                //Check if a CreationTimeFieldName exists and if yes, set it to now()
                if !empty(::p_CreationTimeFieldName) .and. hb_HGetRef(::p_oSQLConnection:p_hMetadataTable[::p_NamespaceAndTableName][HB_ORM_SCHEMA_FIELD],::p_CreationTimeFieldName)
                    if !empty(l_cFields)
                        l_cFields += ","
                        l_cValues += ","
                    endif
                    l_cFields += ::p_oSQLConnection:FormatIdentifier(::p_CreationTimeFieldName)
                    l_cValues += "now()"
                endif
                
                //Check if a ModificationTimeFieldName exists and if yes, set it to now()
                if !empty(::p_ModificationTimeFieldName) .and. hb_HGetRef(::p_oSQLConnection:p_hMetadataTable[::p_NamespaceAndTableName][HB_ORM_SCHEMA_FIELD],::p_ModificationTimeFieldName)
                    if !empty(l_cFields)
                        l_cFields += ","
                        l_cValues += ","
                    endif
                    l_cFields += ::p_oSQLConnection:FormatIdentifier(::p_ModificationTimeFieldName)
                    l_cValues += "now()"
                endif

                for each l_oField in ::p_FieldsAndValues
                    l_cFieldName := l_oField:__enumKey()  // Will not fix Field name casing since this was already done in the method Field()
                    l_hFieldInfo := ::p_oSQLConnection:p_hMetadataTable[::p_NamespaceAndTableName][HB_ORM_SCHEMA_FIELD][l_cFieldName]
                    l_aValue     := l_oField:__enumValue()

                    switch l_aValue[1]
                    case 1  // Value
                        l_cFieldValue := ""
                        if !el_AUnpack(::PrepValueForPostgreSQL("adding",l_aValue[2],::p_NamespaceAndTableName,0,l_cFieldName,l_hFieldInfo,@l_aAutoTrimmedFields,@l_aErrors),,@l_cFieldValue)
                            loop
                        endif
                        exit
                    case 2  // Expression
                        l_cFieldValue := l_aValue[2]
                        exit
                    case 3  // Array
                        //Example: array['614417fb-9aec-4a6a-961a-12c9b3f58985','11111111-2222-3333-4444-000000000001']::uuid[]
                        l_cFieldValue := "array["
                        for each l_xValue in l_aValue[2]
                            l_cArrayValue := ""
                            if el_AUnpack(::PrepValueForPostgreSQL("adding",l_xValue,::p_NamespaceAndTableName,0,l_cFieldName,l_hFieldInfo,@l_aAutoTrimmedFields,@l_aErrors),,@l_cArrayValue)
                                if l_xValue:__enumindex > 1
                                    l_cFieldValue += ","
                                endif
                                //Will be casting the entire array afterwards, will remove any casting in l_cFieldValue
                                l_nPos := at("::",l_cArrayValue)
                                if l_nPos > 0
                                    l_cArrayValue := left(l_cArrayValue,l_nPos-1)
                                endif
                                l_cFieldValue += l_cArrayValue
                            else
                                loop
                            endif
                        endfor
                        l_cFieldValue += "]::"+::GetPostgreSQLCastForFieldType(l_hFieldInfo[HB_ORM_SCHEMA_FIELD_TYPE],;
                                                                            hb_HGetDef(l_hFieldInfo,HB_ORM_SCHEMA_FIELD_LENGTH,0),;
                                                                            hb_HGetDef(l_hFieldInfo,HB_ORM_SCHEMA_FIELD_DECIMALS,0))+"[]"
                        exit
                    otherwise
                        loop
                    endswitch

                    if !empty(l_cFields)
                        l_cFields += ","
                        l_cValues += ","
                    endif
                    l_cFields += ::p_oSQLConnection:FormatIdentifier(l_cFieldName)
                    l_cValues += l_cFieldValue

                endfor

                l_cSQLCommand := [INSERT INTO ]+::p_oSQLConnection:FormatIdentifier(::p_oSQLConnection:NormalizeTableNamePhysical(::p_NamespaceAndTableName))+[ (]+l_cFields+[) VALUES (]+l_cValues+[) RETURNING ]+::p_oSQLConnection:FormatIdentifier(l_cPrimaryKeyFieldName)
                
                // l_cSQLCommand := strtran(l_cSQLCommand,"->",".")  // Harbour can use  "table->field" instead of "table.field"

                ::p_LastSQLCommand = l_cSQLCommand
                if ::p_oSQLConnection:SQLExec(::p_cEventId,l_cSQLCommand,"c_DB_Result")
                    do case
                    case pcount() == 1
                        ::p_Key = par_iKey
                        
                    otherwise
                        ::Tally := 1
                        l_xKeyFieldValue := c_DB_Result->(FieldGet(FieldPos(l_cPrimaryKeyFieldName)))
                        if Valtype(l_xKeyFieldValue) == "C"
                            ::p_Key := val(l_xKeyFieldValue)
                        else
                            ::p_Key := l_xKeyFieldValue
                        endif
                        // ::SQLSendToLogFileAndMonitoringSystem(0,0,l_cSQLCommand+[ -> Key = ]+trans(::p_Key))
                        
                    endcase
                    
                else
                    //Failed To Add
                    ::p_ErrorMessage := ::p_oSQLConnection:GetSQLExecErrorMessage()

                endif
                CloseAlias("c_DB_Result")

            endcase
            select (l_nSelect)
        endif
        
    endcase
endif

if empty(::p_ErrorMessage)
    if len(l_aAutoTrimmedFields) > 0
        ::p_oSQLConnection:LogAutoTrimEvent(::p_cEventId,::p_NamespaceAndTableName,::p_KEY,l_aAutoTrimmedFields)
    endif
else
    ::p_Key = -1
    ::Tally = -1
endif

if len(l_aErrors) > 0
    ::p_ErrorMessage := l_aErrors
    ::p_oSQLConnection:LogErrorEvent(::p_cEventId,l_aErrors)
endif

return (::p_Key > 0)
//-----------------------------------------------------------------------------------------------------------------
method Delete(par_xEventId,par_cNamespaceAndTableName,par_iKey) class hb_orm_SQLData                              //Delete record. Should be called as .Delete(Key) or .Delete(TableName,Key). The first form require a previous call to .Table(TableName)

local l_nSelect
local l_cSQLCommand
local l_cNonTableAlias
local l_cNamespaceAndTableName
local l_aPrimaryKeyInfo
local l_cPrimaryKeyFieldName

::p_ErrorMessage := ""
::Tally          := 0

if pcount() != 3
    ::p_ErrorMessage := [Invalid number of parameters when calling :Delete()]
endif

if empty(::p_ErrorMessage)
    do case
    case !::IsConnected()
        ::p_ErrorMessage := [Missing SQL Connection]
    case  empty(::p_oSQLConnection:p_hWharfConfig)
        ::p_ErrorMessage := [WharfConfig structure required]
    endcase
endif

if empty(::p_ErrorMessage)

    l_cNonTableAlias := hb_HGetDef(::p_NonTableAliases,lower(par_cNamespaceAndTableName),"")
    if !empty(l_cNonTableAlias)
        l_cNamespaceAndTableName := l_cNonTableAlias   // Will have the correct casing
    else
        // if ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL   //empty(::p_NamespaceName)   // Meaning not on HB_ORM_ENGINETYPE_POSTGRESQL
        //     l_cNamespaceAndTableName = ::p_oSQLConnection:CaseTableName(par_cNamespaceAndTableName)
        // else
        //     l_nPos = at(".",par_cNamespaceAndTableName)
        //     if empty(l_nPos)
        //         l_cNamespaceAndTableName := ::p_oSQLConnection:CaseTableName(::p_NamespaceName+"."+par_cNamespaceAndTableName)
        //         // l_nPos = at(".",l_cNamespaceAndTableName)
        //     else
        //         l_cNamespaceAndTableName := ::p_oSQLConnection:CaseTableName(par_cNamespaceAndTableName)
        //     endif
        // endif
        // if empty(l_cNamespaceAndTableName)
        //     ::p_ErrorMessage := [Auto-Casing Error: Failed To find table "]+par_cNamespaceAndTableName+[".]
        // else
        //     // ::p_AliasToNamespaceAndTableNames[::p_TableAlias] := l_cNamespaceAndTableName
        // endif

        l_cNamespaceAndTableName  := ::p_oSQLConnection:NormalizeTableNameInternal(par_cNamespaceAndTableName)
        l_cNamespaceAndTableName  := ::p_oSQLConnection:CaseTableName(l_cNamespaceAndTableName)

        if empty(l_cNamespaceAndTableName)
            ::p_ErrorMessage := [Auto-Casing Error: Failed To find table "]+par_cNamespaceAndTableName+[".]
        endif

    endif
    
    if empty(::p_ErrorMessage) .and. !empty(l_cNamespaceAndTableName)
        l_aPrimaryKeyInfo      := hb_HGetDef(::p_oSQLConnection:p_hTablePrimaryKeyInfo,l_cNamespaceAndTableName,{"",""})
        l_cPrimaryKeyFieldName := l_aPrimaryKeyInfo[PRIMARY_KEY_INFO_NAME]
        if empty(l_cPrimaryKeyFieldName)
            ::p_ErrorMessage := [Failed to find Primary Field Name.]
        endif
    endif

    do case
    case !empty(::p_ErrorMessage)
    case empty(l_cNamespaceAndTableName)
        ::p_ErrorMessage := [Missing Table]
        
    case empty(par_iKey)
        ::p_ErrorMessage := [Missing ]+upper(l_cPrimaryKeyFieldName)
        
    otherwise
        l_nSelect := iif(used(),select(),0)
        
        l_cSQLCommand := [DELETE FROM ]+::p_oSQLConnection:FormatIdentifier(::p_oSQLConnection:NormalizeTableNamePhysical(l_cNamespaceAndTableName))+[ WHERE ]+::p_oSQLConnection:FormatIdentifier(l_cPrimaryKeyFieldName)+[=]+trans(par_iKey)
        ::p_LastSQLCommand = l_cSQLCommand

        if empty(::p_ErrorMessage)
            if ::p_oSQLConnection:SQLExec(par_xEventId,l_cSQLCommand)
                // ::SQLSendToLogFileAndMonitoringSystem(0,0,l_cSQLCommand)
                ::Tally = 1
            else
                ::p_ErrorMessage := ::p_oSQLConnection:GetSQLExecErrorMessage()
                // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_cSQLCommand+[ -> ]+::p_ErrorMessage)
            endif
        endif

        select (l_nSelect)
        
    endcase
endif

if !empty(::p_ErrorMessage)
    ::Tally = -1
endif

return empty(::p_ErrorMessage)
//-----------------------------------------------------------------------------------------------------------------
method Update(par_iKey) class hb_orm_SQLData                                  //Update a record in .Table(TableName)  where .Field(...) was called first

local l_nSelect
local l_cSQLCommand
local l_cFieldName
local l_hFieldInfo
local l_aValue
local l_xValue
local l_cFieldValue
local l_cArrayValue
local l_oField
local l_aAutoTrimmedFields := {}
local l_aErrors := {}
local l_nPos
local l_aPrimaryKeyInfo
local l_cPrimaryKeyFieldName

if pcount() == 1
    ::p_KEY = par_iKey
endif

::p_ErrorMessage := ""
::Tally          := 0
::p_LastUpdateChangedData := .f.
*::p_LastDateTimeOfChangeFieldName := ""

do case
case !::IsConnected()
    ::p_ErrorMessage := [Missing SQL Connection]
case  empty(::p_oSQLConnection:p_hWharfConfig)
    ::p_ErrorMessage := [WharfConfig structure required]
endcase

if empty(::p_ErrorMessage) .and. !empty(::p_NamespaceAndTableName)
    l_aPrimaryKeyInfo      := hb_HGetDef(::p_oSQLConnection:p_hTablePrimaryKeyInfo,::p_NamespaceAndTableName,{"",""})
    l_cPrimaryKeyFieldName := l_aPrimaryKeyInfo[PRIMARY_KEY_INFO_NAME]
    if empty(l_cPrimaryKeyFieldName)
        ::p_ErrorMessage := [Failed to find Primary Field Name.]
    endif
endif

if empty(::p_ErrorMessage)
    do case
    case len(::p_FieldsAndValues) == 0
        ::p_ErrorMessage = [Missing Fields]
        
    case empty(::p_NamespaceAndTableName)
        ::p_ErrorMessage = [Missing Table]
        
    case empty(::p_KEY)
        ::p_ErrorMessage = [Missing ]+l_cPrimaryKeyFieldName
        
    otherwise
        l_nSelect = iif(used(),select(),0)
        
        do case
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
            l_cSQLCommand := ""
            
            //Check if a ModificationTimeFieldName exists and if yes, set it to now()
            if !empty(::p_ModificationTimeFieldName) .and. hb_HGetRef(::p_oSQLConnection:p_hMetadataTable[::p_NamespaceAndTableName][HB_ORM_SCHEMA_FIELD],::p_ModificationTimeFieldName)
                if !empty(l_cSQLCommand)
                    l_cSQLCommand += ","
                endif
                l_cSQLCommand += ::p_oSQLConnection:FormatIdentifier(::p_ModificationTimeFieldName)+[ = current_timestamp()]
            endif
            
            for each l_oField in ::p_FieldsAndValues
                l_cFieldName := l_oField:__enumKey()  // Will not fix Field name casing since this was already done in the method Field()
                l_hFieldInfo := ::p_oSQLConnection:p_hMetadataTable[::p_NamespaceAndTableName][HB_ORM_SCHEMA_FIELD][l_cFieldName]
                l_aValue     := l_oField:__enumValue()

                switch l_aValue[1]
                case 1  // Value
                    l_cFieldValue := ""
                    if !el_AUnpack(::PrepValueForMySQL("adding",l_aValue[2],::p_NamespaceAndTableName,0,l_cFieldName,l_hFieldInfo,@l_aAutoTrimmedFields,@l_aErrors),,@l_cFieldValue)
                        loop
                    endif
                    exit
                case 2  // Expression
                    l_cFieldValue := l_aValue[2]
                    exit
                otherwise
                    loop
                endswitch
                
                if !empty(l_cSQLCommand)
                    l_cSQLCommand += ","
                endif
                l_cSQLCommand += ::p_oSQLConnection:FormatIdentifier(l_cFieldName)+[ = ]+l_cFieldValue

            endfor

            l_cSQLCommand := [UPDATE ]+::p_oSQLConnection:FormatIdentifier(::p_oSQLConnection:NormalizeTableNamePhysical(::p_NamespaceAndTableName))+[ SET ]+l_cSQLCommand+[ WHERE ]+::p_oSQLConnection:FormatIdentifier(l_cPrimaryKeyFieldName)+[ = ]+trans(::p_KEY)
            ::p_LastSQLCommand = l_cSQLCommand
            
            if ::p_oSQLConnection:SQLExec(::p_cEventId,l_cSQLCommand)
                ::Tally = 1
                // ::SQLSendToLogFileAndMonitoringSystem(0,0,l_cSQLCommand)
                ::p_LastUpdateChangedData := .t.   // _M_ For now I am assuming the record changed. Later on create a generic Store Procedure that will do these data changes.
            else
                ::p_ErrorMessage = [Failed SQL Update.]
                // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_cSQLCommand+[ -> ]+::p_ErrorMessage)
            endif

        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
            // M_ find a way to integrate the same concept as the code below. Should the update be a stored Procedure ?
            *if !empty(::p_LastDateTimeOfChangeFieldName)
            *	replace (::p_NamespaceAndTableName+"->"+::p_LastDateTimeOfChangeFieldName) with v_LocalTime
            *endif
                        
            l_cSQLCommand := ""
            
            //Check if a ModificationTimeFieldName exists and if yes, set it to now()
            if !empty(::p_ModificationTimeFieldName) .and. hb_HGetRef(::p_oSQLConnection:p_hMetadataTable[::p_NamespaceAndTableName][HB_ORM_SCHEMA_FIELD],::p_ModificationTimeFieldName)
                if !empty(l_cSQLCommand)
                    l_cSQLCommand += ","
                endif
                l_cSQLCommand += ::p_oSQLConnection:FormatIdentifier(::p_ModificationTimeFieldName)+[ = now()]
            endif
            
            for each l_oField in ::p_FieldsAndValues
                l_cFieldName := l_oField:__enumKey()  // Will not fix Field name casing since this was already done in the method Field()
                l_hFieldInfo := ::p_oSQLConnection:p_hMetadataTable[::p_NamespaceAndTableName][HB_ORM_SCHEMA_FIELD][l_cFieldName]
                l_aValue     := l_oField:__enumValue()

                switch l_aValue[1]
                case 1  // Value
                    l_cFieldValue := ""
                    if !el_AUnpack(::PrepValueForPostgreSQL("adding",l_aValue[2],::p_NamespaceAndTableName,0,l_cFieldName,l_hFieldInfo,@l_aAutoTrimmedFields,@l_aErrors),,@l_cFieldValue)
                        loop
                    endif
                    exit
                case 2  // Expression
                    l_cFieldValue := l_aValue[2]
                    exit
                case 3  // Array
                //array['614417fb-9aec-4a6a-961a-12c9b3f58985','11111111-2222-3333-4444-000000000001']::uuid[]
                    l_cFieldValue := "array["
                    for each l_xValue in l_aValue[2]
                        l_cArrayValue := ""
                        if el_AUnpack(::PrepValueForPostgreSQL("adding",l_xValue,::p_NamespaceAndTableName,0,l_cFieldName,l_hFieldInfo,@l_aAutoTrimmedFields,@l_aErrors),,@l_cArrayValue)
                            if l_xValue:__enumindex > 1
                                l_cFieldValue += ","
                            endif
                            //Will be casting the entire array afterwards, will remove any casting in l_cFieldValue
                            l_nPos := at("::",l_cArrayValue)
                            if l_nPos > 0
                                l_cArrayValue := left(l_cArrayValue,l_nPos-1)
                            endif
                            l_cFieldValue += l_cArrayValue
                        else
                            loop
                        endif
                    endfor
                    l_cFieldValue += "]::"+::GetPostgreSQLCastForFieldType(l_hFieldInfo[HB_ORM_SCHEMA_FIELD_TYPE],;
                                                                           hb_HGetDef(l_hFieldInfo,HB_ORM_SCHEMA_FIELD_LENGTH,0),;
                                                                           hb_HGetDef(l_hFieldInfo,HB_ORM_SCHEMA_FIELD_DECIMALS,0))+"[]"
                    exit
                otherwise
                    loop
                endswitch

                if !empty(l_cSQLCommand)
                    l_cSQLCommand += ","
                endif
                l_cSQLCommand += ::p_oSQLConnection:FormatIdentifier(l_cFieldName)+[ = ]+l_cFieldValue

            endfor

            l_cSQLCommand := [UPDATE ]+::p_oSQLConnection:FormatIdentifier(::p_oSQLConnection:NormalizeTableNamePhysical(::p_NamespaceAndTableName))+[ SET ]+l_cSQLCommand+[ WHERE ]+::p_oSQLConnection:FormatIdentifier(l_cPrimaryKeyFieldName)+[ = ]+trans(::p_KEY)

            ::p_LastSQLCommand = l_cSQLCommand
            
            if ::p_oSQLConnection:SQLExec(::p_cEventId,l_cSQLCommand)
                ::Tally = 1
                // ::SQLSendToLogFileAndMonitoringSystem(0,0,l_cSQLCommand)
                ::p_LastUpdateChangedData := .t.   // _M_ For now I am assuming the record changed. Later on create a generic Store Procedure that will do these data changes.
            else
                ::p_ErrorMessage = [Failed SQL Update.]
                // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_cSQLCommand+[ -> ]+::p_ErrorMessage)
            endif

        endcase
        
        select (l_nSelect)
        
    endcase
endif

if empty(::p_ErrorMessage)
    if len(l_aAutoTrimmedFields) > 0
        ::p_oSQLConnection:LogAutoTrimEvent(::p_cEventId,::p_NamespaceAndTableName,::p_KEY,l_aAutoTrimmedFields)
    endif
else
    ::Tally = -1
endif

if len(l_aErrors) > 0
    ::p_ErrorMessage := l_aErrors
    ::p_oSQLConnection:LogErrorEvent(::p_cEventId,l_aErrors)
endif

return empty(::p_ErrorMessage)
//-----------------------------------------------------------------------------------------------------------------
method PrepExpression(par_cExpression,...) class hb_orm_SQLData   //Used to convert from Source Language syntax to MySQL, and to make parameter static

local l_aParams := { ... }
local l_cChar
local l_nMergeCodeNumber
local l_nPos
local l_cResult
local l_xValue
local l_aErrors := {}

if pcount() > 1 .and. "^" $ par_cExpression
    l_cResult := ""
    l_nMergeCodeNumber := 0
    
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        for l_nPos := 1 to len(par_cExpression)
            l_cChar := substr(par_cExpression,l_nPos,1)
            //l_cChar := par_cExpression[l_nPos]
            if l_cChar == "^"
                l_nMergeCodeNumber += 1
                l_xValue = l_aParams[l_nMergeCodeNumber]

                switch valtype(l_xValue)
                case "C"  // Character string   https://dev.mysql.com/doc/refman/8.0/en/string-literals.html
                case "M"  // Memo field
                    l_cResult += INVALUEWITCH+'"'+hb_StrReplace( l_xValue, {'\' => '\\',;
                                                                            '"' => '\"',;
                                                                            "'" => "\'"} )+'"'+INVALUEWITCH
                    exit

                case "N"  // Numeric
                    l_cResult += INVALUEWITCH+hb_ntoc(l_xValue)+INVALUEWITCH
                    exit

                case "D"  // Date   https://dev.mysql.com/doc/refman/8.0/en/datetime.html
                    // l_xValue := '"'+hb_DtoC(l_xValue,"YYYY-MM-DD")+'"'           //_M_  Test on 1753-01-01
                    l_cResult += INVALUEWITCH+::FormatDateForSQLUpdate(l_xValue)+INVALUEWITCH
                    exit

                case "T"  // TimeStamp (*)   https://dev.mysql.com/doc/refman/8.0/en/datetime.html
                    // l_xValue := '"'+hb_TtoC(l_xValue,"YYYY-MM-DD","hh:mm:ss")+'"'           //_M_  Test on 1753-01-01
                    l_cResult += INVALUEWITCH+::FormatDateTimeForSQLUpdate(l_xValue)+INVALUEWITCH
                    exit

                case "L"  // Boolean (logical)   https://dev.mysql.com/doc/refman/8.0/en/boolean-literals.html
                    l_cResult += INVALUEWITCH+iif(l_xValue,"TRUE","FALSE")+INVALUEWITCH
                    exit

                case "U"  // Undefined (NIL)
                    l_cResult += INVALUEWITCH+"NULL"+INVALUEWITCH
                    exit

                // case "A"  // Array
                // case "B"  // Code-Block
                // case "O"  // Object
                // case "H"  // Hash table (*)
                // case "P"  // Pointer to function, procedure or method (*)
                // case "S"  // Symbolic name (*)
                otherwise
                    AAdd(l_aErrors,{::p_NamespaceAndTableName,NIL,[Wrong Parameter Type in PrepExpression()],hb_orm_GetApplicationStack()})
                    ::p_oSQLConnection:LogErrorEvent(::p_cEventId,l_aErrors)
                endswitch
            else
                l_cResult += l_cChar
                
            endif
        endfor

    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
// if par_cExpression == "LinkedEntity.fk_Entity1 = ^ OR LinkedEntity.fk_Entity2 = ^"
//     altd()
// endif

        for l_nPos := 1 to len(par_cExpression)
            l_cChar := substr(par_cExpression,l_nPos,1)
            // l_cChar := par_cExpression[l_nPos]
            if l_cChar == "^"
                l_nMergeCodeNumber += 1
                l_xValue = l_aParams[l_nMergeCodeNumber]

                switch valtype(l_xValue)
                case "C"  // Character string   https://dev.mysql.com/doc/refman/8.0/en/string-literals.html
                case "M"  // Memo field
                    l_cResult += INVALUEWITCH+"'"+hb_StrReplace( l_xValue, {'\' => '\\',;
                                                                            '"' => '\"',;
                                                                            "'" => "\'"} )+"'"+INVALUEWITCH
                    exit

                case "N"  // Numeric
                    l_cResult += INVALUEWITCH+hb_ntoc(l_xValue)+INVALUEWITCH
                    exit

                case "D"  // Date   https://dev.mysql.com/doc/refman/8.0/en/datetime.html
                    // l_xValue := "'"+hb_DtoC(l_xValue,"YYYY-MM-DD")+"'"          //_M_  Test on 1753-01-01
                    l_cResult += INVALUEWITCH+::FormatDateForSQLUpdate(l_xValue)+INVALUEWITCH
                    exit

                case "T"  // TimeStamp (*)   https://dev.mysql.com/doc/refman/8.0/en/datetime.html
                    // l_xValue := "'" +hb_TtoC(l_xValue,"YYYY-MM-DD","hh:mm:ss")+"'"            //_M_  Test on 1753-01-01
                    l_cResult += INVALUEWITCH+::FormatDateTimeForSQLUpdate(l_xValue)+INVALUEWITCH
                    exit

                case "L"  // Boolean (logical)   https://dev.mysql.com/doc/refman/8.0/en/boolean-literals.html
                    l_cResult += INVALUEWITCH+iif(l_xValue,"TRUE","FALSE")+INVALUEWITCH
                    exit

                case "U"  // Undefined (NIL)
                    l_cResult += INVALUEWITCH+"NULL"+INVALUEWITCH
                    exit

                // case "A"  // Array
                // case "B"  // Code-Block
                // case "O"  // Object
                // case "H"  // Hash table (*)
                // case "P"  // Pointer to function, procedure or method (*)
                // case "S"  // Symbolic name (*)
                otherwise
                    AAdd(l_aErrors,{::p_NamespaceAndTableName,NIL,[Wrong Parameter Type in PrepExpression()],hb_orm_GetApplicationStack()})
                    ::p_oSQLConnection:LogErrorEvent(::p_cEventId,l_aErrors)
                endswitch
            else
                l_cResult += l_cChar
                
            endif
        endfor
            
    endcase
        
else
    l_cResult = par_cExpression
    
endif

return l_cResult
//-----------------------------------------------------------------------------------------------------------------
method Column(par_cExpression,par_cColumnsAlias,...) class hb_orm_SQLData     //Used with the .SQL() or .Get() to specify the fields/expressions to retrieve

if !empty(par_cExpression)
    if pcount() < 2
        AAdd(::p_ColumnToReturn,{::PrepExpression(par_cExpression,...), allt(strtran(strtran(allt(par_cExpression),[->],[_]),[.],[_]))})
    else
        AAdd(::p_ColumnToReturn,{::PrepExpression(par_cExpression,...), allt(par_cColumnsAlias)})
    endif
endif

return NIL
//-----------------------------------------------------------------------------------------------------------------
method Join(par_cType,par_cNamespaceAndTableName,par_cAlias,par_cExpression,...) class hb_orm_SQLData    // Join Tables. Will return a handle that can be used later by ReplaceJoin()
local l_cNamespaceAndTableName
local l_cAlias
local l_nPos
local l_aErrors := {}
local l_cNonTableAlias

if empty(par_cType)
    //Used to reserve a Join Position
    AAdd(::p_Join,{})
else
    l_cNonTableAlias := hb_HGetDef(::p_NonTableAliases,lower(par_cNamespaceAndTableName),"")
    if !empty(l_cNonTableAlias)
        l_cNamespaceAndTableName := l_cNonTableAlias
        if pcount() >= 3 .and. !empty(par_cAlias)
            l_cAlias := lower(par_cAlias)
        else
            l_cAlias := l_cNamespaceAndTableName
        endif
        ::p_AliasToNamespaceAndTableNames[l_cAlias] := l_cNamespaceAndTableName

    else
        l_cNamespaceAndTableName := ::p_oSQLConnection:NormalizeTableNameInternal(par_cNamespaceAndTableName)
        l_cNamespaceAndTableName := ::p_oSQLConnection:CaseTableName(l_cNamespaceAndTableName)

        if empty(l_cNamespaceAndTableName)
            AAdd(l_aErrors,{par_cNamespaceAndTableName,NIL,[Auto-Casing Error: Failed To find table "]+par_cNamespaceAndTableName+[".],hb_orm_GetApplicationStack()})
            ::p_oSQLConnection:LogErrorEvent(::p_cEventId,l_aErrors)
            l_cAlias := ""   // To ensure will crash later on.
        else
            if pcount() >= 3 .and. !empty(par_cAlias)
                l_cAlias := lower(par_cAlias)
            else
                l_nPos = at(".",l_cNamespaceAndTableName)
                l_cAlias := lower(substr(l_cNamespaceAndTableName,l_nPos+1))
            endif

            ::p_AliasToNamespaceAndTableNames[l_cAlias] := l_cNamespaceAndTableName
            
        endif

    endif

    AAdd(::p_Join,{upper(allt(par_cType)),l_cNamespaceAndTableName,l_cAlias,allt(::PrepExpression(par_cExpression,...))})
endif

return len(::p_Join)
//-----------------------------------------------------------------------------------------------------------------
method ReplaceJoin(par_nJoinNumber,par_cType,par_cNamespaceAndTableName,par_cAlias,par_cExpression,...) class hb_orm_SQLData      // Replace a Join tables definition
local l_cNamespaceAndTableName
local l_cAlias
local l_nPos
local l_aErrors := {}
local l_cNonTableAlias

if empty(par_cType)
    ::p_Join[par_nJoinNumber] := {}
else
    l_cNonTableAlias := hb_HGetDef(::p_NonTableAliases,lower(par_cNamespaceAndTableName),"")
    if !empty(l_cNonTableAlias)
        l_cNamespaceAndTableName := l_cNonTableAlias
        if pcount() >= 4 .and. !empty(par_cAlias)
            l_cAlias := lower(par_cAlias)
        else
            l_cAlias := l_cNamespaceAndTableName
        endif
        ::p_AliasToNamespaceAndTableNames[l_cAlias] := l_cNamespaceAndTableName

    else
        l_cNamespaceAndTableName := ::p_oSQLConnection:NormalizeTableNameInternal(par_cNamespaceAndTableName)
        l_cNamespaceAndTableName := ::p_oSQLConnection:CaseTableName(l_cNamespaceAndTableName)

        if empty(l_cNamespaceAndTableName)
            AAdd(l_aErrors,{par_cNamespaceAndTableName,NIL,[Auto-Casing Error: Failed To find table "]+par_cNamespaceAndTableName+[".],hb_orm_GetApplicationStack()})
            ::p_oSQLConnection:LogErrorEvent(::p_cEventId,l_aErrors)
            l_cAlias := ""   // To ensure will crash later on.
        else
            if pcount() >= 4 .and. !empty(par_cAlias)
                l_cAlias := lower(par_cAlias)
            else
                l_nPos   = at(".",l_cNamespaceAndTableName)
                l_cAlias := lower(substr(l_cNamespaceAndTableName,l_nPos+1))
            endif

            ::p_AliasToNamespaceAndTableNames[l_cAlias] := l_cNamespaceAndTableName
            
        endif

    endif

    ::p_Join[par_nJoinNumber] := {upper(allt(par_cType)),l_cNamespaceAndTableName,l_cAlias,allt(::PrepExpression(par_cExpression,...))}
endif

return par_nJoinNumber
//-----------------------------------------------------------------------------------------------------------------
method Where(par_cExpression,...) class hb_orm_SQLData   // Adds Where condition. Will return a handle that can be used later by ReplaceWhere()

if empty(par_cExpression)
    AAdd(::p_Where,{})
else
    AAdd(::p_Where,allt(::PrepExpression(par_cExpression,...)))
endif

return len(::p_Where)
//-----------------------------------------------------------------------------------------------------------------
method ReplaceWhere(par_nWhereNumber,par_cExpression,...) class hb_orm_SQLData   // Replace a Where definition

if !empty(par_cExpression)
    ::p_Where[par_nWhereNumber] = allt(::PrepExpression(par_cExpression,...))
endif

return par_nWhereNumber
//-----------------------------------------------------------------------------------------------------------------
method Having(par_cExpression,...) class hb_orm_SQLData   // Adds Having condition. Will return a handle that can be used later by ReplaceHaving()

if empty(par_cExpression)
    AAdd(::p_Having,{})
else
    AAdd(::p_Having,allt(::PrepExpression(par_cExpression,...)))
endif

return len(::p_Having)
//-----------------------------------------------------------------------------------------------------------------
method ReplaceHaving(par_nHavingNumber,par_cExpression,...) class hb_orm_SQLData   // Replace a Having definition

if !empty(par_cExpression)
    ::p_Having[par_nHavingNumber] = allt(::PrepExpression(par_cExpression,...))
endif

return par_nHavingNumber
//-----------------------------------------------------------------------------------------------------------------
method KeywordCondition(par_cKeywords,par_cFieldToSearchFor,par_cOperand,par_lAsHaving) class hb_orm_SQLData     // Creates Where or Having conditions as multi text search in fields.

local l_lAsHaving
local l_cChar
local l_cCharPos
local l_cCondi
local l_cCondiOperand
local l_lContainsStrings
local l_cKeywords
local l_cLine
local l_cNewKeyWords
local l_nPos
local l_lStringMode
local l_nConditionNumber
local l_cWord

l_nConditionNumber := 0
if !empty(par_cKeywords)
    
    l_cKeywords := upper(allt(par_cKeywords))
    l_cKeywords := strtran(l_cKeywords,"[","")
    l_cKeywords := strtran(l_cKeywords,"]","")
    
    l_lContainsStrings := (["] $ par_cKeywords)
    
    if pcount() >= 3 .and. !empty(par_cOperand)
        l_cCondiOperand := [ ]+padr(allt(par_cOperand),3)+[ ]
    else
        l_cCondiOperand := [ and ]
    endif
    
    l_lAsHaving := (pcount() >= 4 .and. par_lAsHaving)
    
    if l_lContainsStrings
        l_cNewKeyWords := ""
        l_lStringMode  := .f.
        for l_cCharPos := 1 to len(l_cKeywords)
            l_cChar := substr(l_cKeywords,l_cCharPos,1)
            do case
            case l_cChar == ["]
                l_lStringMode := !l_lStringMode
                l_cNewKeyWords += [ ]
            case l_cChar == [ ]
                if l_lStringMode
                    l_cNewKeyWords += chr(1)
                else
                    l_cNewKeyWords += [ ]
                endif
            case l_cChar == [,]
                if l_lStringMode
                    l_cNewKeyWords += chr(2)
                else
                    l_cNewKeyWords += [ ]
                endif
            otherwise
                l_cNewKeyWords += l_cChar
            endcase
        endfor
        l_cKeywords := l_cNewKeyWords
    else
        l_cKeywords := strtran(l_cKeywords,","," ")
    endif
    
    do while "  " $ l_cKeywords
        l_cKeywords := strtran(l_cKeywords,"  "," ")
    enddo
    
    l_cLine  := allt(l_cKeywords)+" "
    l_cCondi := ""
    do while .t. // !empty(l_cLine)   //Work around needed to avoid error 62 in DLL Mode
        l_nPos   := at(" ",l_cLine)
        l_cWord  := upper(left(l_cLine,l_nPos-1))
        
        l_cWord := strtran(l_cWord,"[","")  // To Prevent Injections
        l_cWord := strtran(l_cWord,"]","")  // To Prevent Injections
        l_cWord := left(l_cWord,250)        // To Ensure it is not too long.
        
        //The following is the "VFP" way
        // l_cCondi += l_cCondiOperand + "["+l_cWord+"] $ g_upper("+par_cFieldToSearchFor+")"

        l_cWord := strtran(l_cWord,"_","\_")

        do case
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
            //_M_  Needs testing
            l_cCondi += l_cCondiOperand + [(lower(]+ par_cFieldToSearchFor +[) LIKE '%]+lower(l_cWord)+[%')]

        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
            // l_cCondi += l_cCondiOperand + [(lower(]+ par_cFieldToSearchFor +[) LIKE '%]+lower(l_cWord)+[%')]
            l_cCondi += l_cCondiOperand + [(]+ par_cFieldToSearchFor +[ ILIKE '%]+l_cWord+[%')]

        endcase

        if l_nPos+1 > len(l_cLine)   //Work around needed to avoid error 62 in DLL Mode
            exit
        else
            l_cLine := substr(l_cLine,l_nPos+1)
        endif
    enddo
    
    l_cCondi := substr(l_cCondi,6)
    
    if l_lContainsStrings
        l_cCondi := strtran(l_cCondi,chr(1)," ")
        l_cCondi := strtran(l_cCondi,chr(2),",")
    endif
    
    *	if l_NumberOfConditions > 1
    *		l_cCondi = "("+l_cCondi+")"
    *	endif

    if l_lAsHaving
        AAdd(::p_Having,l_cCondi)
        l_nConditionNumber := len(::p_Having)
    else
        AAdd(::p_Where,l_cCondi)         //_M_  later make this code other backend ready
        l_nConditionNumber := len(::p_Where)
    endif
    
endif

return l_nConditionNumber
//-----------------------------------------------------------------------------------------------------------------
method GroupBy(par_cExpression) class hb_orm_SQLData       // Add a Group By definition

if !empty(par_cExpression)
    AAdd(::p_GroupBy,allt(par_cExpression))
endif

return NIL
//-----------------------------------------------------------------------------------------------------------------
method OrderBy(par_cExpression,par_cDirection) class hb_orm_SQLData       // Add an Order By definition    par_cDirection = "A"scending or "D"escending

if !empty(par_cExpression)
    if pcount() == 2
        AAdd(::p_OrderBy,{allt(par_cExpression),(upper(left(par_cDirection,1)) == "A"),.f.})
    else
        AAdd(::p_OrderBy,{allt(par_cExpression),.t.,.f.})
    endif
endif

return NIL
//-----------------------------------------------------------------------------------------------------------------
method DistinctOn(par_cExpression,par_cDirection) class hb_orm_SQLData       // PostgreSQL ONLY. Will use the "distinct on ()" feature and Add an Order By definition    par_cDirection = "A"scending or "D"escending

if !empty(par_cExpression)
    ::p_DistinctMode := 2
    if pcount() == 2
        AAdd(::p_OrderBy,{allt(par_cExpression),(upper(left(par_cDirection,1)) == "A"),.t.})
    else
        AAdd(::p_OrderBy,{allt(par_cExpression),.t.,.t.})
    endif
endif

return NIL
//-----------------------------------------------------------------------------------------------------------------
method ResetOrderBy() class hb_orm_SQLData       // Delete all OrderBy definitions

asize(::p_OrderBy,0)

return NIL
//-----------------------------------------------------------------------------------------------------------------
method ReadWrite(par_lValue) class hb_orm_SQLData            // Was used in VFP ORM, not the Harbour version, since the result cursors are always ReadWriteable

if pcount() == 0 .or. par_lValue
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
method AddLeadingRecords(par_cCursorName) class hb_orm_SQLData    // Specify to add records from par_cCursorName as leading record to the future result cursor

if !empty(par_cCursorName)
    ::p_AddLeadingRecordsCursorName := par_cCursorName
    ::p_AddLeadingBlankRecord       := .t.
endif

return NIL
//-----------------------------------------------------------------------------------------------------------------
method ExpressionToMYSQL(par_cSource,par_cExpression) class hb_orm_SQLData    //_M_  to generalize UDF translation to backend
//_M_
return ::FixAliasAndFieldNameCasingInExpression(par_cSource,par_cExpression)
//-----------------------------------------------------------------------------------------------------------------
method ExpressionToPostgreSQL(par_cSource,par_cExpression) class hb_orm_SQLData    //_M_  to generalize UDF translation to backend
//_M_
return ::FixAliasAndFieldNameCasingInExpression(par_cSource,par_cExpression)
//-----------------------------------------------------------------------------------------------------------------
method FixAliasAndFieldNameCasingInExpression(par_cSource,par_cExpression) class hb_orm_SQLData   //_M_
local l_nHashPos
local l_cResult := ""
local l_cAliasName,l_cFieldName
local l_cNamespaceAndTableName
local l_cTokenDelimiterLeft,l_cTokenDelimiterRight
local l_cByte
local l_lByteIsToken
local l_nTableFieldDetection := 0
local l_cStreamBuffer        := ""
local l_lValueMode := .f.

local l_nColumnTypeDetectCount := 0  // to detect the type of returned field.
local l_hFieldInfo
local l_cColumnTypeDetectExpression
local l_cColumnTypeDetectType
local l_lColumnTypeDetectArray := .f.

local l_cNonTableAlias

local l_hColumnDefinition
local l_lLastFieldWasAForeignKeyZeroNullConversion := .f.  // Only used if par_cSource <> "column", since in column mode we are using a COALESCE() to deal with NULLs
local l_lLastFieldWasAForeignKeyZeroNullFoundOperator
// if par_cExpression == "table.pk"
//     altd()
// endif

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cTokenDelimiterLeft  := [`]
    l_cTokenDelimiterRight := [`]
    //l_SchemaPrefix        := ""
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cTokenDelimiterLeft  := ["]
    l_cTokenDelimiterRight := ["]
    //l_SchemaPrefix        := ::p_NamespaceName+"."  // ::p_oSQLConnection:GetCurrentNamespaceName()+"."
endcase

for each l_cByte in @par_cExpression

    if l_cByte == INVALUEWITCH
        l_lValueMode := !l_lValueMode

        if !l_lValueMode   // Finished to merge the text, so we should not remove blanks anymore
            l_lLastFieldWasAForeignKeyZeroNullFoundOperator := .f.
        endif

        loop
    endif
    if l_lValueMode
        l_cResult += l_cByte
        loop
    endif

    if l_nTableFieldDetection == 0  //Token may not start with a numeric
        l_lByteIsToken := (l_cByte $ "_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    else
        l_lByteIsToken := (l_cByte $ "0123456789_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    endif

    do case
    case l_nTableFieldDetection == 0  // Not in <AliasName>.<FieldName> pattern
        if l_lByteIsToken
            l_nTableFieldDetection := 1
            l_cStreamBuffer        := l_cByte
            l_cAliasName           := l_cByte
            l_cFieldName           := ""
            l_lLastFieldWasAForeignKeyZeroNullConversion := .f.
        else
            // Logic to deal with "= 0" and "> 0" that should be converted to "IS NULL" or "IS NOT NULL"
            if l_lLastFieldWasAForeignKeyZeroNullConversion
                do case
                case l_cByte == " "
                    if !l_lLastFieldWasAForeignKeyZeroNullFoundOperator  //Don't add extra blanks
                        l_cResult += " "
                    endif
                case l_cByte == "="
                    l_cResult += INPOSSIBLEZERONULLEQUAL+" "   // Also add a blank after the operator
                    l_lLastFieldWasAForeignKeyZeroNullFoundOperator := .t.
                case l_cByte == ">"
                    l_cResult += INPOSSIBLEZERONULLGREATER+" "   // Also add a blank after the operator
                    l_lLastFieldWasAForeignKeyZeroNullFoundOperator := .t.
                otherwise
                    l_cResult += l_cByte
                    l_lLastFieldWasAForeignKeyZeroNullConversion := .f.
                endcase
            else
                l_cResult += l_cByte
            endif

        endif
    case l_nTableFieldDetection == 1 // in <AliasName>
        do case
        case l_lByteIsToken
            l_cStreamBuffer        += l_cByte
            l_cAliasName           += l_cByte
        case l_cByte == "."
            l_nTableFieldDetection := 2
            l_cStreamBuffer        += l_cByte
        otherwise
            // Not a <AliasName>.<FieldName> pattern
            l_nTableFieldDetection := 0
            l_cResult              += l_cStreamBuffer+l_cByte
            l_cStreamBuffer        := ""
        endcase
    case l_nTableFieldDetection == 2   //Beyond "."
        if l_lByteIsToken  // at least one IsTokenByte is needed
            l_nTableFieldDetection := 3
            l_cStreamBuffer        += l_cByte
            l_cFieldName           += l_cByte
        else  // Invalid pattern
            l_nTableFieldDetection := 0
            l_cResult              += l_cStreamBuffer+l_cByte
            l_cStreamBuffer        := ""
        endif
    case l_nTableFieldDetection == 3   //Beyond ".?"
        do case
        case l_lByteIsToken
            l_cStreamBuffer       += l_cByte
            l_cFieldName          += l_cByte
        case l_cByte == "."  // Invalid pattern
            l_nTableFieldDetection := 0
            l_cResult              += l_cStreamBuffer+l_cByte
            l_cStreamBuffer        := ""
        otherwise // End of pattern
            l_nTableFieldDetection := 0
            l_cAliasName := lower(l_cAliasName)   //Alias are always converted to lowercase.

            l_cNonTableAlias := hb_HGetDef(::p_NonTableAliases,l_cAliasName,"")
            if !empty(l_cNonTableAlias)   // If the alias is probably from a CTE statement
                l_cResult += l_cTokenDelimiterLeft+l_cNonTableAlias+l_cTokenDelimiterRight+"."+l_cTokenDelimiterLeft+l_cFieldName+l_cTokenDelimiterRight+l_cByte
            else

                // Fix The Casing of l_cAliasName and l_cFieldName based on the actual on file tables.

                l_nHashPos := hb_hPos(::p_oSQLConnection:p_hMetadataTable,hb_HGetDef(::p_AliasToNamespaceAndTableNames,l_cAliasName,l_cAliasName))
                if l_nHashPos > 0
                    l_cNamespaceAndTableName := hb_hKeyAt(::p_oSQLConnection:p_hMetadataTable,l_nHashPos)
                    l_nHashPos := hb_hPos(::p_oSQLConnection:p_hMetadataTable[l_cNamespaceAndTableName][HB_ORM_SCHEMA_FIELD],l_cFieldName)
                    if l_nHashPos > 0
                        l_cFieldName := hb_hKeyAt(::p_oSQLConnection:p_hMetadataTable[l_cNamespaceAndTableName][HB_ORM_SCHEMA_FIELD],l_nHashPos)

                        l_hColumnDefinition := ::p_oSQLConnection:GetColumnConfiguration(l_cNamespaceAndTableName,l_cFieldName)
                        if par_cSource == "column"
                            if l_hColumnDefinition["NullZeroEquivalent"]
                                l_cResult += "COALESCE("+l_cTokenDelimiterLeft+l_cAliasName+l_cTokenDelimiterRight+"."+l_cTokenDelimiterLeft+l_cFieldName+l_cTokenDelimiterRight+",0)"
                            else
                                l_cResult += l_cTokenDelimiterLeft+l_cAliasName+l_cTokenDelimiterRight+"."+l_cTokenDelimiterLeft+l_cFieldName+l_cTokenDelimiterRight
                            endif
                            l_cResult += l_cByte
                        else
                            l_cResult += l_cTokenDelimiterLeft+l_cAliasName+l_cTokenDelimiterRight+"."+l_cTokenDelimiterLeft+l_cFieldName+l_cTokenDelimiterRight
                            l_lLastFieldWasAForeignKeyZeroNullConversion := l_hColumnDefinition["NullZeroEquivalent"]
                            if l_lLastFieldWasAForeignKeyZeroNullConversion
                                do case
                                case l_cByte == " "
                                    l_cResult += " "
                                    l_lLastFieldWasAForeignKeyZeroNullFoundOperator := .f.
                                case l_cByte == "="   //There was no blanls 
                                    l_cResult += INPOSSIBLEZERONULLEQUAL+" "   // Also add a blank after the operator
                                    l_lLastFieldWasAForeignKeyZeroNullFoundOperator := .t.
                                case l_cByte == ">"
                                    l_cResult += INPOSSIBLEZERONULLGREATER+" "   // Also add a blank after the operator
                                    l_lLastFieldWasAForeignKeyZeroNullFoundOperator := .t.
                                otherwise
                                    l_cResult += l_cByte
                                    l_lLastFieldWasAForeignKeyZeroNullConversion := .f.   // Actually we are not in a scenario that could warrant IS NULL or IS NOT NULL
                                endcase
                            else
                                l_cResult += l_cByte
                            endif
                        endif
                        // l_cResult += l_cTokenDelimiterLeft+l_cAliasName+l_cTokenDelimiterRight+"."+l_cTokenDelimiterLeft+l_cFieldName+l_cTokenDelimiterRight+l_cByte
                        
                        // Detect the field type if only 1 field is used in the expression
                        if l_nColumnTypeDetectCount == 0
                            l_nColumnTypeDetectCount      := 1
                            l_hFieldInfo                  := hb_HValueAt(::p_oSQLConnection:p_hMetadataTable[l_cNamespaceAndTableName][HB_ORM_SCHEMA_FIELD],l_nHashPos)
                            l_cColumnTypeDetectExpression := l_cAliasName+"."+l_cFieldName
                            l_cColumnTypeDetectType       := l_hFieldInfo[HB_ORM_SCHEMA_FIELD_TYPE]
                            l_lColumnTypeDetectArray      := hb_HGetDef(l_hFieldInfo,HB_ORM_SCHEMA_FIELD_ARRAY,.f.)
                        else
                            l_nColumnTypeDetectCount += 1
                        endif

                    else
                        l_cResult += l_cStreamBuffer+l_cByte
                        hb_orm_SendToDebugView([Auto-Casing Error: Failed To find Field "]+l_cFieldName+[" in alias "]+l_cAliasName+[".])
                    endif
                else
                    l_cResult += l_cStreamBuffer+l_cByte
                    hb_orm_SendToDebugView([Auto-Casing Error: Failed To find alias "]+l_cAliasName+[".])
                endif
            endif

            l_cStreamBuffer := ""

        endcase
    endcase
    
endfor

l_cResult := strtran(l_cResult," "+INPOSSIBLEZERONULLEQUAL+" 0"," IS NULL ")   //Logic to replace with a blank before the operator. A potential extra blank after "NULL" to avoid concatenating with a literal.
l_cResult := strtran(l_cResult,    INPOSSIBLEZERONULLEQUAL+" 0"," IS NULL ")   //In case there was no blank before the operator
l_cResult := strtran(l_cResult,INPOSSIBLEZERONULLEQUAL,"=")

l_cResult := strtran(l_cResult," "+INPOSSIBLEZERONULLGREATER+" 0"," IS NOT NULL ")   //Logic to replace with a blank before the operator
l_cResult := strtran(l_cResult,    INPOSSIBLEZERONULLGREATER+" 0"," IS NOT NULL ")   //In case there was no blank before the operator
l_cResult := strtran(l_cResult,INPOSSIBLEZERONULLGREATER,">")

l_lLastFieldWasAForeignKeyZeroNullConversion := .f.  //No more space of a right side expression.

if l_nTableFieldDetection == 3
    // Fix The Casing of l_cAliasName and l_cFieldName based on the actual on-file tables.
    l_cAliasName := lower(l_cAliasName)   //Alias are always converted to lowercase.

    l_cNonTableAlias := hb_HGetDef(::p_NonTableAliases,l_cAliasName,"")
    if !empty(l_cNonTableAlias)   // If the alias is probably from a CTE statement
        l_cResult += l_cTokenDelimiterLeft+l_cNonTableAlias+l_cTokenDelimiterRight+"."+l_cTokenDelimiterLeft+l_cFieldName+l_cTokenDelimiterRight
    else
        l_nHashPos := hb_hPos(::p_oSQLConnection:p_hMetadataTable,hb_HGetDef(::p_AliasToNamespaceAndTableNames,l_cAliasName,l_cAliasName))
        if l_nHashPos > 0
            l_cNamespaceAndTableName := hb_hKeyAt(::p_oSQLConnection:p_hMetadataTable,l_nHashPos) 
            // l_nPos := at(".",l_cNamespaceAndTableName)
            // if !empty(l_nPos)
            //     l_cAliasName := substr(l_cNamespaceAndTableName,l_nPos+1)
            // endif
            l_nHashPos := hb_hPos(::p_oSQLConnection:p_hMetadataTable[l_cNamespaceAndTableName][HB_ORM_SCHEMA_FIELD],l_cFieldName)
            if l_nHashPos > 0
                l_cFieldName := hb_hKeyAt(::p_oSQLConnection:p_hMetadataTable[l_cNamespaceAndTableName][HB_ORM_SCHEMA_FIELD],l_nHashPos)

                if par_cSource == "column"
                    l_hColumnDefinition := ::p_oSQLConnection:GetColumnConfiguration(l_cNamespaceAndTableName,l_cFieldName)
                    if l_hColumnDefinition["NullZeroEquivalent"]
                        l_cResult += "COALESCE("+l_cTokenDelimiterLeft+l_cAliasName+l_cTokenDelimiterRight+"."+l_cTokenDelimiterLeft+l_cFieldName+l_cTokenDelimiterRight+",0)"
                    else
                        l_cResult += l_cTokenDelimiterLeft+l_cAliasName+l_cTokenDelimiterRight+"."+l_cTokenDelimiterLeft+l_cFieldName+l_cTokenDelimiterRight
                    endif
                else
                    l_cResult += l_cTokenDelimiterLeft+l_cAliasName+l_cTokenDelimiterRight+"."+l_cTokenDelimiterLeft+l_cFieldName+l_cTokenDelimiterRight
                endif
                
                // Detect the field type if only 1 field is used in the expression
                if l_nColumnTypeDetectCount == 0
                    l_nColumnTypeDetectCount      := 1
                    l_hFieldInfo                  := hb_HValueAt(::p_oSQLConnection:p_hMetadataTable[l_cNamespaceAndTableName][HB_ORM_SCHEMA_FIELD],l_nHashPos)
                    l_cColumnTypeDetectExpression := l_cAliasName+"."+l_cFieldName
                    l_cColumnTypeDetectType       := l_hFieldInfo[HB_ORM_SCHEMA_FIELD_TYPE]
                    l_lColumnTypeDetectArray      := hb_HGetDef(l_hFieldInfo,HB_ORM_SCHEMA_FIELD_ARRAY,.f.)
                else
                    l_nColumnTypeDetectCount += 1
                endif
                
            else
                //_M_ Report Failed to Find Field
                l_cResult += l_cStreamBuffer
            endif
        else
            //_M_ Report Failed to find Table
            l_cResult += l_cStreamBuffer
        endif
    endif
else
    l_cResult += l_cStreamBuffer
endif

if l_nColumnTypeDetectCount == 1
    if lower(hb_StrReplace(par_cExpression,{' ' => '','"' => '',"'" => ""})) == lower(hb_StrReplace(l_cColumnTypeDetectExpression,{' ' => '','"' => '',"'" => ""}))
        do case
        case l_lColumnTypeDetectArray
            l_cResult := "array_to_json("+l_cResult+")::text"
        case l_cColumnTypeDetectType == "UUI"
            // l_cResult := "("+l_cResult+")::character varying(36)"
            l_cResult := "("+l_cResult+")::character(36)"
        case l_cColumnTypeDetectType == "JSB"
            l_cResult := "("+l_cResult+")::text"
        case l_cColumnTypeDetectType == "JS"
            l_cResult := "("+l_cResult+")::text"
        endcase
    endif
endif

return l_cResult
//-----------------------------------------------------------------------------------------------------------------
method SetExplainMode(par_nMode) class hb_orm_SQLData                                          // Used to get explain information. 0 = Explain off, 1 = Explain with no run, 2 = Explain with run
::p_ExplainMode := par_nMode
return NIL
//-----------------------------------------------------------------------------------------------------------------
method BuildSQL(par_cAction) class hb_orm_SQLData   // Used internally. par_cAction can be "Count" or "Fetch".

local l_nCounter
local l_nCounterColumns
local l_cSQLCommand
local l_nNumberOfOrderBys        := len(::p_OrderBy)
local l_nNumberOfHavings         := len(::p_Having)
local l_nNumberOfGroupBys        := len(::p_GroupBy)
local l_nNumberOfWheres          := len(::p_Where)
local l_nNumberOfJoins           := len(::p_Join)
local l_nNumberOfColumnsToReturn := len(::p_ColumnToReturn)
local l_cOrderByColumn
local l_cOrderByColumnUpper
local l_lFirstOrderBy
local l_nMaxTextLength1
local l_nMaxTextLength2
local l_nMaxTextLength3

local l_cEndOfLine    := CRLF
local l_cColumnIndent := replicate(chr(1),7)

local l_aPrimaryKeyInfo
local l_cPrimaryKeyFieldName


if !empty(::p_NamespaceAndTableName)
    l_aPrimaryKeyInfo      := hb_HGetDef(::p_oSQLConnection:p_hTablePrimaryKeyInfo,::p_NamespaceAndTableName,{"",""})
    l_cPrimaryKeyFieldName := l_aPrimaryKeyInfo[PRIMARY_KEY_INFO_NAME]
endif


do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cSQLCommand := [SELECT ]
    
    if ::p_DistinctMode == 1
        l_cSQLCommand += [DISTINCT ]
    endif

    l_cSQLCommand += l_cEndOfLine
    
    do case
    case "Count" $ par_cAction
        l_cSQLCommand += [ COUNT(*) AS ]+::p_oSQLConnection:FormatIdentifier("count") + l_cEndOfLine

    case empty(l_nNumberOfColumnsToReturn)
        l_cSQLCommand += [ ]+::p_oSQLConnection:FormatIdentifier(::p_TableAlias)+[.]+::p_oSQLConnection:FormatIdentifier(l_cPrimaryKeyFieldName)+[ AS ]+::p_oSQLConnection:FormatIdentifier(l_cPrimaryKeyFieldName) + l_cEndOfLine

    otherwise
        //Precompute the max length of the Column Expression
        l_nMaxTextLength1 := 0
        for l_nCounter := 1 to l_nNumberOfColumnsToReturn
            l_nMaxTextLength1 := max(l_nMaxTextLength1,len(::ExpressionToMYSQL("column",::p_ColumnToReturn[l_nCounter,1])))
        endfor

        // _M_ add support to "*"
        for l_nCounter := 1 to l_nNumberOfColumnsToReturn
            if l_nCounter > 1
                l_cSQLCommand += [,]+l_cEndOfLine
            endif
            if l_cSQLCommand == [SELECT ]+l_cEndOfLine
                l_cSQLCommand := [SELECT ]+padr(::ExpressionToMYSQL("column",::p_ColumnToReturn[l_nCounter,1]),l_nMaxTextLength1,chr(1))
            else
                l_cSQLCommand += l_cColumnIndent + padr(::ExpressionToMYSQL("column",::p_ColumnToReturn[l_nCounter,1]),l_nMaxTextLength1,chr(1))
            endif
            
            if !empty(::p_ColumnToReturn[l_nCounter,2])
                l_cSQLCommand += [ AS `]+::p_ColumnToReturn[l_nCounter,2]+[`]
            else
                l_cSQLCommand += [ AS `]+strtran(::p_ColumnToReturn[l_nCounter,1],[.],[_])+[`]
            endif
        endfor
        l_cSQLCommand += l_cEndOfLine

    endcase
    
    if ::p_NamespaceAndTableName == ::p_TableAlias
        l_cSQLCommand += [ FROM ]+::p_oSQLConnection:FormatIdentifier(::p_oSQLConnection:NormalizeTableNamePhysical(::p_NamespaceAndTableName))+l_cEndOfLine
    else
        l_cSQLCommand += [ FROM ]+::p_oSQLConnection:FormatIdentifier(::p_oSQLConnection:NormalizeTableNamePhysical(::p_NamespaceAndTableName))+[ AS ]+::p_oSQLConnection:FormatIdentifier(::p_TableAlias)+l_cEndOfLine
    endif
    
    l_nMaxTextLength1 := 0
    l_nMaxTextLength2 := 0
    l_nMaxTextLength3 := 0

    for l_nCounter = 1 to l_nNumberOfJoins
        do case
        case left(::p_Join[l_nCounter,1],1) == "I"  //Inner Join
            l_nMaxTextLength1 := max(l_nMaxTextLength1,len([ INNER JOIN]))
        case left(::p_Join[l_nCounter,1],1) == "L"  //Left Outer
            l_nMaxTextLength1 := max(l_nMaxTextLength1,len([ LEFT OUTER JOIN]))
        case left(::p_Join[l_nCounter,1],1) == "R"  //Right Outer
            l_nMaxTextLength1 := max(l_nMaxTextLength1,len([ RIGHT OUTER JOIN]))
        case left(::p_Join[l_nCounter,1],1) == "F"  //Full Outer
            l_nMaxTextLength1 := max(l_nMaxTextLength1,len([ FULL OUTER JOIN]))
        otherwise
            loop
        endcase

        l_nMaxTextLength2 := max(l_nMaxTextLength2,len( [ ]+::p_oSQLConnection:FormatIdentifier(::p_oSQLConnection:NormalizeTableNamePhysical(::p_Join[l_nCounter,2])) ))

        l_nMaxTextLength3 := max(l_nMaxTextLength3,len( ::p_oSQLConnection:FormatIdentifier(lower(::p_Join[l_nCounter,3])) ))

    endfor

    for l_nCounter = 1 to l_nNumberOfJoins
        do case
        case left(::p_Join[l_nCounter,1],1) == "I"  //Inner Join
            l_cSQLCommand += padr([ INNER JOIN],l_nMaxTextLength1,chr(1))
        case left(::p_Join[l_nCounter,1],1) == "L"  //Left Outer
            l_cSQLCommand += padr([ LEFT OUTER JOIN],l_nMaxTextLength1,chr(1))
        case left(::p_Join[l_nCounter,1],1) == "R"  //Right Outer
            l_cSQLCommand += padr([ RIGHT OUTER JOIN],l_nMaxTextLength1,chr(1))
        case left(::p_Join[l_nCounter,1],1) == "F"  //Full Outer
            l_cSQLCommand += padr([ FULL OUTER JOIN],l_nMaxTextLength1,chr(1))
        otherwise
            loop
        endcase
        
        l_cSQLCommand += padr([ ]+::p_oSQLConnection:FormatIdentifier(::p_oSQLConnection:NormalizeTableNamePhysical(::p_Join[l_nCounter,2])),l_nMaxTextLength2,chr(1))
        
        l_cSQLCommand += [ AS ] + padr(::p_oSQLConnection:FormatIdentifier(::p_Join[l_nCounter,3]),l_nMaxTextLength3,chr(1))

        l_cSQLCommand += [ ON ] + ::ExpressionToMYSQL("join",::p_Join[l_nCounter,4])+l_cEndOfLine
        
    endfor
    
    do case
    case l_nNumberOfWheres = 1
        l_cSQLCommand += [ WHERE (]+::ExpressionToMYSQL("where",::p_Where[1])+[)]+l_cEndOfLine
    case l_nNumberOfWheres > 1
        l_cSQLCommand += [ WHERE (]
        for l_nCounter = 1 to l_nNumberOfWheres
            if l_nCounter > 1
                l_cSQLCommand += l_cEndOfLine+ padl([ AND ],7,chr(1))
            endif
            l_cSQLCommand += [(]+::ExpressionToMYSQL("where",::p_Where[l_nCounter])+[)]
        endfor
        l_cSQLCommand += [)]+l_cEndOfLine
    endcase
        
    if l_nNumberOfGroupBys > 0
        l_cSQLCommand += [ GROUP BY ]
        for l_nCounter = 1 to l_nNumberOfGroupBys
            if l_nCounter > 1
                l_cSQLCommand += [,]+l_cEndOfLine+replicate(chr(1),len([ GROUP BY ]))
            endif
            // l_cSQLCommand += ::ExpressionToMYSQL("groupby",::p_GroupBy[l_nCounter])  //_M_ not an expression
            l_cSQLCommand += ::p_oSQLConnection:FormatIdentifier(::p_GroupBy[l_nCounter])
        endfor
        l_cSQLCommand += l_cEndOfLine
    endif
        
    do case
    case l_nNumberOfHavings = 1
        l_cSQLCommand += [ HAVING ]+::ExpressionToMYSQL("having",::p_Having[1])+l_cEndOfLine
    case l_nNumberOfHavings > 1
        l_cSQLCommand += [ HAVING (]
        for l_nCounter = 1 to l_nNumberOfHavings
            if l_nCounter > 1
                l_cSQLCommand += l_cEndOfLine+padl([ AND ],8,chr(1))
            endif
            l_cSQLCommand += [(]+::ExpressionToMYSQL("having",::p_Having[l_nCounter])+[)]
        endfor
        l_cSQLCommand += [)]+l_cEndOfLine
    endcase

    if l_nNumberOfOrderBys > 0 .and. "Fetch" $ par_cAction .and. !("NoOrderBy" $ par_cAction)
        l_lFirstOrderBy := .t.
        for l_nCounter = 1 to l_nNumberOfOrderBys

            //Find the column we are referring to, so to ensure we use the same casing and expression and expression. That is the reason to compare using the upper() functions.
            l_cOrderByColumn := ""
            l_cOrderByColumnUpper := upper(::p_OrderBy[l_nCounter,1])
            for l_nCounterColumns := 1 to l_nNumberOfColumnsToReturn
                if !empty(::p_ColumnToReturn[l_nCounterColumns,2])
                    if upper(::p_ColumnToReturn[l_nCounterColumns,2]) == l_cOrderByColumnUpper
                        l_cOrderByColumn := ::p_ColumnToReturn[l_nCounterColumns,2]
                        exit
                    endif
                else
                    if upper(strtran(::p_ColumnToReturn[l_nCounterColumns,1],[.],[_])) == l_cOrderByColumnUpper
                        l_cOrderByColumn := strtran(::p_ColumnToReturn[l_nCounterColumns,1],[.],[_])
                    endif
                endif
            endfor

            if empty(l_cOrderByColumn)
                ::p_oSQLConnection:LogErrorEvent(::p_cEventId,{{,,"Failed to match OrderBy Column - "+::p_OrderBy[l_nCounter,1],hb_orm_GetApplicationStack()}})
            else
                if l_lFirstOrderBy
                    l_cSQLCommand += [ ORDER BY ]
                    l_lFirstOrderBy := .f.
                else
                    l_cSQLCommand += [,]
                    l_cSQLCommand += l_cEndOfLine + replicate(chr(1),len([ ORDER BY ]))
                endif
                l_cSQLCommand += [`]+l_cOrderByColumn+[`]
                if ::p_OrderBy[l_nCounter,2]
                    l_cSQLCommand += [ ASC]
                else
                    l_cSQLCommand += [ DESC]
                endif
            endif
        endfor
        l_cSQLCommand += l_cEndOfLine
    endif
    
    if ::p_Limit > 0 .and. "Fetch" $ par_cAction
        l_cSQLCommand += [ LIMIT ]+trans(::p_Limit)+[ ]+l_cEndOfLine
    endif
    
    l_cSQLCommand := strtran(l_cSQLCommand,[->],[.])
    
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cSQLCommand := [SELECT ]
    
    do case
    case ::p_DistinctMode == 1
        l_cSQLCommand += [DISTINCT ]+l_cEndOfLine

    case ::p_DistinctMode == 2
        l_cSQLCommand += [DISTINCT ON (]

        if l_nNumberOfOrderBys > 0
            l_lFirstOrderBy := .t.
            for l_nCounter = 1 to l_nNumberOfOrderBys
                if ::p_OrderBy[l_nCounter,3]   // Only care about the OrderBy set from calling the DistinctOn() method

                    //Find the column we are referring to, so to ensure we use the same casing and expression. That is the reason to compare using the upper() functions.
                    l_cOrderByColumn := ""
                    l_cOrderByColumnUpper := upper(::p_OrderBy[l_nCounter,1])
                    for l_nCounterColumns := 1 to l_nNumberOfColumnsToReturn
                        //Use the column alias for the distinct on to deal with casing issues
                        do case
                        case upper(::p_ColumnToReturn[l_nCounterColumns,1]) == l_cOrderByColumnUpper   // Test if the Distinct On is the column expression. If yes use it to ensure the casing will work
                            if empty(::p_ColumnToReturn[l_nCounterColumns,2])
                                l_cOrderByColumn := strtran(::p_ColumnToReturn[l_nCounterColumns,1],[.],[_])
                            else
                                l_cOrderByColumn := ::p_ColumnToReturn[l_nCounterColumns,2]
                            endif
                            exit
                        case !empty(::p_ColumnToReturn[l_nCounterColumns,2]) .and. upper(::p_ColumnToReturn[l_nCounterColumns,2]) == l_cOrderByColumnUpper   // Test if the Distinct On is the column alias. If yes use it to ensure the casing will work
                            l_cOrderByColumn := ::p_ColumnToReturn[l_nCounterColumns,2]
                            exit
                        endcase
                    endfor

                    if empty(l_cOrderByColumn)
                        ::p_oSQLConnection:LogErrorEvent(::p_cEventId,{{,,"Failed to match Distinct On Column - "+::p_OrderBy[l_nCounter,1],hb_orm_GetApplicationStack()}})
                    else
                        if l_lFirstOrderBy
                            l_lFirstOrderBy := .f.
                        else
                            l_cSQLCommand += [,]
                        endif
                        l_cSQLCommand += ["]+l_cOrderByColumn+["]  // Since we are using the column alias we can use the " .
                    endif

                endif
            endfor
        endif

        l_cSQLCommand += [)]+l_cEndOfLine
    otherwise
        l_cSQLCommand += l_cEndOfLine
    endcase
    
    do case
    case "Count" $ par_cAction
        l_cSQLCommand += [ COUNT(*) AS ]+::p_oSQLConnection:FormatIdentifier("count")+l_cEndOfLine

    case empty(l_nNumberOfColumnsToReturn)
        l_cSQLCommand += [ ]+::p_oSQLConnection:FormatIdentifier(::p_TableAlias)+[.]+::p_oSQLConnection:FormatIdentifier(l_cPrimaryKeyFieldName)+[ AS ]+::p_oSQLConnection:FormatIdentifier(l_cPrimaryKeyFieldName)+l_cEndOfLine

    otherwise
        //Precompute the max length of the Column Expression
        l_nMaxTextLength1 := 0
        for l_nCounter := 1 to l_nNumberOfColumnsToReturn
            l_nMaxTextLength1 := max(l_nMaxTextLength1,len(::ExpressionToPostgreSQL("column",::p_ColumnToReturn[l_nCounter,1])))
        endfor
        
        // _M_ add support to "*"
        for l_nCounter := 1 to l_nNumberOfColumnsToReturn
            if l_nCounter > 1
                l_cSQLCommand += [,]+l_cEndOfLine
            endif
            if l_cSQLCommand == [SELECT ]+l_cEndOfLine
                l_cSQLCommand := [SELECT ]+padr(::ExpressionToPostgreSQL("column",::p_ColumnToReturn[l_nCounter,1]),l_nMaxTextLength1,chr(1))
            else
                l_cSQLCommand += l_cColumnIndent + padr(::ExpressionToPostgreSQL("column",::p_ColumnToReturn[l_nCounter,1]),l_nMaxTextLength1,chr(1))
            endif
            
            if !empty(::p_ColumnToReturn[l_nCounter,2])
                l_cSQLCommand += [ AS "]+::p_ColumnToReturn[l_nCounter,2]+["]
            else
                l_cSQLCommand += [ AS "]+strtran(::p_ColumnToReturn[l_nCounter,1],[.],[_])+["]
            endif
        endfor
        l_cSQLCommand += l_cEndOfLine

    endcase
    
    if ::p_NamespaceAndTableName == ::p_TableAlias
        l_cSQLCommand += [ FROM ]+::p_oSQLConnection:FormatIdentifier(::p_oSQLConnection:NormalizeTableNamePhysical(::p_NamespaceAndTableName))+l_cEndOfLine
    else
        l_cSQLCommand += [ FROM ]+::p_oSQLConnection:FormatIdentifier(::p_oSQLConnection:NormalizeTableNamePhysical(::p_NamespaceAndTableName))+[ AS ]+::p_oSQLConnection:FormatIdentifier(::p_TableAlias)+l_cEndOfLine
    endif
    
    l_nMaxTextLength1 := 0
    l_nMaxTextLength2 := 0
    l_nMaxTextLength3 := 0

    for l_nCounter = 1 to l_nNumberOfJoins
        do case
        case left(::p_Join[l_nCounter,1],1) == "I"  //Inner Join
            l_nMaxTextLength1 := max(l_nMaxTextLength1,len([ INNER JOIN]))
        case left(::p_Join[l_nCounter,1],1) == "L"  //Left Outer
            l_nMaxTextLength1 := max(l_nMaxTextLength1,len([ LEFT OUTER JOIN]))
        case left(::p_Join[l_nCounter,1],1) == "R"  //Right Outer
            l_nMaxTextLength1 := max(l_nMaxTextLength1,len([ RIGHT OUTER JOIN]))
        case left(::p_Join[l_nCounter,1],1) == "F"  //Full Outer
            l_nMaxTextLength1 := max(l_nMaxTextLength1,len([ FULL OUTER JOIN]))
        otherwise
            loop
        endcase

        l_nMaxTextLength2 := max(l_nMaxTextLength2,len( [ ]+::p_oSQLConnection:FormatIdentifier(::p_oSQLConnection:NormalizeTableNamePhysical(::p_Join[l_nCounter,2])) ))

        l_nMaxTextLength3 := max(l_nMaxTextLength3,len( ::p_oSQLConnection:FormatIdentifier(lower(::p_Join[l_nCounter,3])) ))

    endfor

    for l_nCounter = 1 to l_nNumberOfJoins
        do case
        case left(::p_Join[l_nCounter,1],1) == "I"  //Inner Join
            l_cSQLCommand += padr([ INNER JOIN],l_nMaxTextLength1,chr(1))
        case left(::p_Join[l_nCounter,1],1) == "L"  //Left Outer
            l_cSQLCommand += padr([ LEFT OUTER JOIN],l_nMaxTextLength1,chr(1))
        case left(::p_Join[l_nCounter,1],1) == "R"  //Right Outer
            l_cSQLCommand += padr([ RIGHT OUTER JOIN],l_nMaxTextLength1,chr(1))
        case left(::p_Join[l_nCounter,1],1) == "F"  //Full Outer
            l_cSQLCommand += padr([ FULL OUTER JOIN],l_nMaxTextLength1,chr(1))
        otherwise
            loop
        endcase
        
        l_cSQLCommand += padr([ ]+::p_oSQLConnection:FormatIdentifier(::p_oSQLConnection:NormalizeTableNamePhysical(::p_Join[l_nCounter,2])),l_nMaxTextLength2,chr(1))

        l_cSQLCommand += [ AS ] + padr(::p_oSQLConnection:FormatIdentifier(::p_Join[l_nCounter,3]),l_nMaxTextLength3,chr(1))
        
        l_cSQLCommand += [ ON ] +  ::ExpressionToPostgreSQL("join",::p_Join[l_nCounter,4])+l_cEndOfLine
        
    endfor
    
    do case
    case l_nNumberOfWheres = 1
        l_cSQLCommand += [ WHERE (]+::ExpressionToPostgreSQL("where",::p_Where[1])+[)]+l_cEndOfLine
    case l_nNumberOfWheres > 1
        l_cSQLCommand += [ WHERE (]
        for l_nCounter = 1 to l_nNumberOfWheres
            if l_nCounter > 1
                l_cSQLCommand += l_cEndOfLine+padl([ AND ],7,chr(1))
            endif
            l_cSQLCommand += [(]+::ExpressionToPostgreSQL("where",::p_Where[l_nCounter])+[)]
        endfor
        l_cSQLCommand += [)]+l_cEndOfLine
    endcase
        
    if l_nNumberOfGroupBys > 0
        l_cSQLCommand += [ GROUP BY ]
        for l_nCounter = 1 to l_nNumberOfGroupBys
            if l_nCounter > 1
                l_cSQLCommand += [,]+l_cEndOfLine+replicate(chr(1),len([ GROUP BY ]))
            endif
            // l_cSQLCommand += ::ExpressionToPostgreSQL("groupby",::p_GroupBy[l_nCounter])
            l_cSQLCommand += ::p_oSQLConnection:FormatIdentifier(::p_GroupBy[l_nCounter])
        endfor
        l_cSQLCommand += l_cEndOfLine
    endif
        
    do case
    case l_nNumberOfHavings = 1
        l_cSQLCommand += [ HAVING ]+::ExpressionToPostgreSQL("having",::p_Having[1])+l_cEndOfLine
    case l_nNumberOfHavings > 1
        l_cSQLCommand += [ HAVING (]
        for l_nCounter = 1 to l_nNumberOfHavings
            if l_nCounter > 1
                l_cSQLCommand += l_cEndOfLine+padl([ AND ],8,chr(1))
            endif
            l_cSQLCommand += [(]+::ExpressionToPostgreSQL("having",::p_Having[l_nCounter])+[)]
        endfor
        l_cSQLCommand += [)]+l_cEndOfLine
    endcase
        
    if l_nNumberOfOrderBys > 0 .and. "Fetch" $ par_cAction .and. !("NoOrderBy" $ par_cAction)
        l_lFirstOrderBy := .t.
        for l_nCounter = 1 to l_nNumberOfOrderBys

            //Find the column we are referring to, so to ensure we use the same casing and expression. That is the reason to compare using the upper() functions.
            //Then use the column alias for the order by.
            l_cOrderByColumn := ""
            l_cOrderByColumnUpper := upper(::p_OrderBy[l_nCounter,1])
            for l_nCounterColumns := 1 to l_nNumberOfColumnsToReturn
                if !empty(::p_ColumnToReturn[l_nCounterColumns,2])
                    if upper(::p_ColumnToReturn[l_nCounterColumns,2]) == l_cOrderByColumnUpper
                        l_cOrderByColumn := ::p_ColumnToReturn[l_nCounterColumns,2]
                        exit
                    endif
                else
                    if upper(strtran(::p_ColumnToReturn[l_nCounterColumns,1],[.],[_])) == l_cOrderByColumnUpper
                        l_cOrderByColumn := strtran(::p_ColumnToReturn[l_nCounterColumns,1],[.],[_])
                    endif
                endif
            endfor

            if empty(l_cOrderByColumn)
                ::p_oSQLConnection:LogErrorEvent(::p_cEventId,{{,,"Failed to match OrderBy Column - "+::p_OrderBy[l_nCounter,1],hb_orm_GetApplicationStack()}})
            else
                if l_lFirstOrderBy
                    l_cSQLCommand += [ ORDER BY ]
                    l_lFirstOrderBy := .f.
                else
                    l_cSQLCommand += [,]
                    l_cSQLCommand += l_cEndOfLine + replicate(chr(1),len([ ORDER BY ]))
                endif
                l_cSQLCommand += ["]+l_cOrderByColumn+["]
                if ::p_OrderBy[l_nCounter,2]
                    l_cSQLCommand += [ ASC]
                else
                    l_cSQLCommand += [ DESC]
                endif
            endif
        endfor
        l_cSQLCommand += l_cEndOfLine
    endif
    
    if ::p_Limit > 0 .and. "Fetch" $ par_cAction
        l_cSQLCommand += [ LIMIT ]+trans(::p_Limit)+[ ]+l_cEndOfLine
    endif
    
    l_cSQLCommand := strtran(l_cSQLCommand,[->],[.])

otherwise
    l_cSQLCommand := ""
    
endcase

::p_LastSQLCommand := strtran(l_cSQLCommand,chr(1)," ")

if "KeepLeadingSpaces" $ par_cAction
    l_cSQLCommand := ::p_LastSQLCommand
else
    l_cSQLCommand := strtran(l_cSQLCommand,chr(1),"")
endif

return l_cSQLCommand
//-----------------------------------------------------------------------------------------------------------------
method SQL(par_1) class hb_orm_SQLData                                          // Assemble and Run SQL command

local l_cCursorTempName
local l_nFieldCounter
local l_cFieldName
local l_xFieldValue
local l_cValueType
local l_cValue
local l_nOutputType
local l_aParameterHoldingTheReferenceToTheArray
local l_xResult
local l_oRecord
local l_nSelect := iif(used(),select(),0)
local l_lSQLResult
local l_cSQLCommand
local l_nTimeEnd
local l_nTimeStart
local l_lErrorOccurred
local l_nNumberOfFields
local l_aRecordFieldValues := {}
local l_aErrors := {}
// local v_InELSOffice := .f.

l_xResult := NIL

::Tally          := 0
::p_ErrorMessage := ""

*!*	l_nOutputType
*!*	 0 = none Only useful for :tally       // No parameters are provided and no fields where defined
*!*	 1 = cursor                            // The parameter is a string
*!*	 2 = array                             // The parameter is a reference to an array
*!*	 3 = object                            // No parameter is provided and at least one field was defined.

l_aParameterHoldingTheReferenceToTheArray := {}   // To reserve memory space.

do case
case pcount() == 1
    do case
    case valtype(par_1) == "A"   // Have to test first if it is an array, because if the first element is an array valtype(par_1) will be "N"
        l_nOutputType := 2
        l_aParameterHoldingTheReferenceToTheArray := par_1    //Assignment of arrays are always only their reference.
        
    case valtype(par_1) == "C"
        ::p_TableFullPath := ""
        ::p_CursorName    := par_1
        l_nOutputType     := 1
        ::p_oCursor       := NIL
        CloseAlias(::p_CursorName)

    otherwise
        ::p_ErrorMessage := "Invalid .SQL parameters"
    endcase
    
otherwise
    // No parameters
    ::p_CursorName := ""
    if empty(len(::p_ColumnToReturn))
        l_nOutputType := 0
    else
        l_nOutputType := 3
    endif
    
endcase

if !empty(::p_ErrorMessage)
    AAdd(l_aErrors,{::p_NamespaceAndTableName,NIL,::p_ErrorMessage,hb_orm_GetApplicationStack()})
    ::Tally := -1
    
else
    //_M_ Add support to ::p_AddLeadingBlankRecord
    
    l_cSQLCommand := ::BuildSQL("Fetch")
    
    l_lErrorOccurred := .t.   //Assumed it failed
    
    do case
    case ::p_ExplainMode > 0
        l_nOutputType := 0  // will behave as no output but l_xResult will be the explain text.

        l_cCursorTempName := "c_DB_Temp"
        
        do case
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
            do case
            case ::p_ExplainMode == 1
                l_cSQLCommand := "EXPLAIN " + l_cSQLCommand
            case ::p_ExplainMode == 2
                l_cSQLCommand := "ANALYZE " + l_cSQLCommand
            endcase
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
            do case
            case ::p_ExplainMode == 1
                l_cSQLCommand := "EXPLAIN " + l_cSQLCommand
            case ::p_ExplainMode == 2
                l_cSQLCommand := "EXPLAIN ANALYZE " + l_cSQLCommand
            endcase
        endcase

        l_nTimeStart := seconds()
        l_lSQLResult := ::p_oSQLConnection:SQLExec(::p_cEventId,l_cSQLCommand,l_cCursorTempName)
        l_nTimeEnd   := seconds()
        ::p_LastRunTime := l_nTimeEnd-l_nTimeStart+0.0000
        
        if !l_lSQLResult
            AAdd(l_aErrors,{::p_NamespaceAndTableName,NIL,"Failed SQLExec. Error Text="+::p_oSQLConnection:GetSQLExecErrorMessage(),hb_orm_GetApplicationStack()})
        else
            l_xResult := ""

            select (l_cCursorTempName)
            l_nNumberOfFields := fcount()
            dbGoTop()
            do while !eof()
                l_xResult += trans(recno())+chr(13)+chr(10)
                for l_nFieldCounter := 1 to l_nNumberOfFields
                    l_xFieldValue := FieldGet(l_nFieldCounter)
                    l_cValueType  := ValType(l_xFieldValue)
                    switch l_cValueType
                    case "C"  // Character string   https://dev.mysql.com/doc/refman/8.0/en/string-literals.html
                    case "M"  // Memo field
                        l_cValue := l_xFieldValue
                        exit
                    case "N"  // Numeric
                        l_cValue := hb_ntoc(l_xFieldValue)
                        exit
                    case "D"  // Date
                        l_cValue := hb_DtoC(l_xFieldValue,"YYYY-MM-DD")
                        exit
                    case "T"  // TimeStamp
                        l_cValue := hb_TtoC(l_xFieldValue,"YYYY-MM-DD","hh:mm:ss")
                        exit
                    case "L"  // Boolean (logical)
                        l_cValue := iif(l_xFieldValue,"TRUE","FALSE")
                        exit
                    case "U"  // Undefined (NIL)
                        l_cValue := ""
                        exit
                    // case "A"  // Array
                    // case "B"  // Code-Block
                    // case "O"  // Object
                    // case "H"  // Hash table (*)
                    // case "P"  // Pointer to function, procedure or method (*)
                    // case "S"  // Symbolic name (*)
                    otherwise
                    endswitch                   
                    if !empty(l_cValue)
                        l_xResult += "   "+FieldName(l_nFieldCounter)+": "+l_cValue+chr(13)+chr(10)
                    endif
                endfor
                dbSkip()
            enddo

            l_lErrorOccurred := .f.
            ::Tally          := (l_cCursorTempName)->(reccount())
        endif
        CloseAlias(l_cCursorTempName)
        
    case l_nOutputType == 0 // none
        l_cCursorTempName := "c_DB_Temp"
        
        l_nTimeStart := seconds()
        l_lSQLResult := ::p_oSQLConnection:SQLExec(::p_cEventId,l_cSQLCommand,l_cCursorTempName)
        l_nTimeEnd   := seconds()
        ::p_LastRunTime := l_nTimeEnd-l_nTimeStart+0.0000
        
        if !l_lSQLResult
            AAdd(l_aErrors,{::p_NamespaceAndTableName,NIL,"Failed SQLExec. Error Text="+::p_oSQLConnection:GetSQLExecErrorMessage(),hb_orm_GetApplicationStack()})
        else
            //  _M_
            // if (l_nTimeEnd - l_nTimeStart + 0.0000 >= ::p_MaxTimeForSlowWarning)
                // ::SQLSendPerformanceIssueToMonitoringSystem(::p_cEventId,2,::p_MaxTimeForSlowWarning,l_nTimeStart,l_nTimeEnd,l_SQLPerformanceInfo,l_cSQLCommand)
            // endif
            
            l_lErrorOccurred := .f.
            ::Tally          := (l_cCursorTempName)->(reccount())
            
        endif
        CloseAlias(l_cCursorTempName)
        
    case l_nOutputType == 1 // cursor
        
        l_nTimeStart := seconds()
        l_lSQLResult := ::p_oSQLConnection:SQLExec(::p_cEventId,l_cSQLCommand,::p_CursorName)
        l_nTimeEnd := seconds()
        ::p_LastRunTime := l_nTimeEnd-l_nTimeStart+0.0000
        
        if !l_lSQLResult
            AAdd(l_aErrors,{::p_NamespaceAndTableName,NIL,"Failed SQLExec. Error Text="+::p_oSQLConnection:GetSQLExecErrorMessage(),hb_orm_GetApplicationStack()})
        else
            select (::p_CursorName)
            //_M_
            // if (l_nTimeEnd - l_nTimeStart + 0.0000 >= ::p_MaxTimeForSlowWarning)
                // ::SQLSendPerformanceIssueToMonitoringSystem(::p_cEventId,2,::p_MaxTimeForSlowWarning,l_nTimeStart,l_nTimeEnd,l_SQLPerformanceInfo,l_cSQLCommand)
            // endif
            
            l_lErrorOccurred := .f.
            ::Tally          := (::p_CursorName)->(reccount())
            
            ::p_oCursor := hb_orm_Cursor():Init():Associate(::p_CursorName)

            // Can not use the following logic, since this would force to call :SQL(...) to have a variable assignment, to avoid loosing scope
            // l_xResult := hb_orm_Cursor():Init()
            // l_xResult:Associate(::p_CursorName)
            // or the following compressed version, since Init() returns Self
            // l_xResult := hb_orm_Cursor():Init():Associate(::p_CursorName)

        endif
        
    case l_nOutputType == 2 // array

        asize(l_aParameterHoldingTheReferenceToTheArray,0)

        l_cCursorTempName := "c_DB_Temp"
                    
        l_nTimeStart := seconds()
        l_lSQLResult := ::p_oSQLConnection:SQLExec(::p_cEventId,l_cSQLCommand,l_cCursorTempName)
        l_nTimeEnd   := seconds()
        ::p_LastRunTime := l_nTimeEnd-l_nTimeStart+0.0000
        
        if !l_lSQLResult
            AAdd(l_aErrors,{::p_NamespaceAndTableName,NIL,"Failed SQLExec. Error Text="+::p_oSQLConnection:GetSQLExecErrorMessage(),hb_orm_GetApplicationStack()})
        else
            // if (l_nTimeEnd - l_nTimeStart + 0.0000 >= ::p_MaxTimeForSlowWarning)
            // 	// ::SQLSendPerformanceIssueToMonitoringSystem(::p_cEventId,2,::p_MaxTimeForSlowWarning,l_nTimeStart,l_nTimeEnd,l_SQLPerformanceInfo,l_cSQLCommand)
            // endif
            
            l_lErrorOccurred := .f.
            ::Tally          := (l_cCursorTempName)->(reccount())
            
            if ::Tally > 0
                select (l_cCursorTempName)
                l_nNumberOfFields := fcount()
                asize(l_aRecordFieldValues,l_nNumberOfFields)

                dbGoTop()
                do while !eof()
                    for l_nFieldCounter := 1 to l_nNumberOfFields
                        l_aRecordFieldValues[l_nFieldCounter] := FieldGet(l_nFieldCounter)
                    endfor
                    AAdd(l_aParameterHoldingTheReferenceToTheArray,AClone(l_aRecordFieldValues))
                    dbSkip()
                endwhile
            endif

        endif
        
        CloseAlias(l_cCursorTempName)
        
    case l_nOutputType = 3 // object
        l_cCursorTempName := "c_DB_Temp"
        
        l_nTimeStart = seconds()
        l_lSQLResult = ::p_oSQLConnection:SQLExec(::p_cEventId,l_cSQLCommand,l_cCursorTempName)
        l_nTimeEnd = seconds()
        ::p_LastRunTime := l_nTimeEnd-l_nTimeStart+0.0000
        
        if !l_lSQLResult
            AAdd(l_aErrors,{::p_NamespaceAndTableName,NIL,"Failed SQLExec. Error Text="+::p_oSQLConnection:GetSQLExecErrorMessage(),hb_orm_GetApplicationStack()})
        else
            select (l_cCursorTempName)

            // if (l_nTimeEnd - l_nTimeStart + 0.0000 >= ::p_MaxTimeForSlowWarning)
            // 	::SQLSendPerformanceIssueToMonitoringSystem(::p_cEventId,2,::p_MaxTimeForSlowWarning,l_nTimeStart,l_nTimeEnd,l_SQLPerformanceInfo,l_cSQLCommand)
            // endif
            
            ::Tally           := reccount()
            l_lErrorOccurred  := .f.
            l_nNumberOfFields := fcount()
            
            do case
            case ::Tally == 0
            case ::Tally == 1
                l_xResult := hb_orm_Data()
                for l_nFieldCounter := 1 to l_nNumberOfFields
                    l_cFieldName  := FieldName(l_nFieldCounter)
                    l_xFieldValue := FieldGet(l_nFieldCounter)
                    l_xResult:AddField(l_cFieldName,l_xFieldValue)
                endfor
                
            otherwise
                //Create an array of objects
                l_xResult := {}   //Initialize to an empty array.
                dbGoTop()
                do while !eof()
                    l_oRecord := hb_orm_Data()
                    for l_nFieldCounter := 1 to l_nNumberOfFields
                        l_cFieldName  := FieldName(l_nFieldCounter)
                        l_xFieldValue := FieldGet(l_nFieldCounter)
                        l_oRecord:AddField(l_cFieldName,l_xFieldValue)
                    endfor
                    AAdd(l_xResult,l_oRecord)  //Should we use a copy object ?

                    dbSkip()
                endwhile

            endcase
        endif
        
        CloseAlias(l_cCursorTempName)
        
    endcase
    
    if l_lErrorOccurred
        ::Tally := -1
        
        if l_nOutputType == 1   //Into Cursor
            select 0  //Move away from any areas on purpose
        else
            select (l_nSelect)
        endif
        
        // ::SQLSendToLogFileAndMonitoringSystem(::p_cEventId,1,l_cSQLCommand+[ -> ]+::p_ErrorMessage)
        
    else
        if l_nOutputType == 1   //Into Cursor
            select (::p_CursorName)
        else
            select (l_nSelect)
        endif
        
        // ::SQLSendToLogFileAndMonitoringSystem(::p_cEventId,0,l_cSQLCommand+[ -> Reccount = ]+trans(::Tally))
    endif
endif

if len(l_aErrors) > 0
    ::p_ErrorMessage := l_aErrors
    ::p_oSQLConnection:LogErrorEvent(::p_cEventId,l_aErrors)
endif

return l_xResult
//-----------------------------------------------------------------------------------------------------------------
method Count() class hb_orm_SQLData                                          // Similar to SQL() but will not get the list of Column() and return a numeric, the number or records found. Will return -1 in case of error.

local l_cCursorTempName
local l_nSelect := iif(used(),select(),0)
local l_cSQLCommand
local l_nTimeEnd
local l_nTimeStart
local l_lSQLResult
local l_aErrors := {}

::Tally          := -1
::p_ErrorMessage := ""

l_cSQLCommand := ::BuildSQL("Count")

l_cCursorTempName := "c_DB_Temp"

l_nTimeStart := seconds()
l_lSQLResult := ::p_oSQLConnection:SQLExec(::p_cEventId,l_cSQLCommand,l_cCursorTempName)
l_nTimeEnd   := seconds()
::p_LastRunTime := l_nTimeEnd-l_nTimeStart+0.0000

if !l_lSQLResult
    AAdd(l_aErrors,{::p_NamespaceAndTableName,NIL,[Failed SQLExec in :Count().],hb_orm_GetApplicationStack()})

else
    if (l_cCursorTempName)->(reccount()) == 1
        ::Tally := (l_cCursorTempName)->(FieldGet(1))
    else
        AAdd(l_aErrors,{::p_NamespaceAndTableName,NIL,[Did not return a single row in :Count().],hb_orm_GetApplicationStack()})
    endif
endif
CloseAlias(l_cCursorTempName)

select (l_nSelect)

if len(l_aErrors) > 0
    ::p_ErrorMessage := l_aErrors
    ::p_oSQLConnection:LogErrorEvent(::p_cEventId,l_aErrors)
endif

return ::Tally
//-----------------------------------------------------------------------------------------------------------------
method Get(par_iKey) class hb_orm_SQLData             // Returns an Object with properties matching a record referred by primary key

local l_nNumberOfJoins           := len(::p_Join)
local l_nNumberOfHavings         := len(::p_Having)
local l_nNumberOfGroupBys        := len(::p_GroupBy)
local l_nNumberOfWheres          := len(::p_Where)
local l_nNumberOfColumnsToReturn := len(::p_ColumnToReturn)

local l_nCounter
local l_cCursorTempName
local l_nFieldCounter
local l_cFieldName
local l_xFieldValue
local l_oResult
local l_nSelect
local l_cSQLCommand
local l_lErrorOccurred := .f.
local l_aErrors := {}

local l_cEndOfLine    := CRLF
local l_cColumnIndent := replicate(chr(1),7)
local l_nMaxTextLength1
local l_nMaxTextLength2
local l_nMaxTextLength3

local l_aPrimaryKeyInfo
local l_cPrimaryKeyFieldName

::p_Key = par_iKey

::Tally          = 0
::p_ErrorMessage = ""

l_oResult := NIL

l_aPrimaryKeyInfo      := hb_HGetDef(::p_oSQLConnection:p_hTablePrimaryKeyInfo,::p_NamespaceAndTableName,{"",""})
l_cPrimaryKeyFieldName := l_aPrimaryKeyInfo[PRIMARY_KEY_INFO_NAME]

do case
case len(::p_FieldsAndValues) > 0
    ::p_ErrorMessage = [Called Get() while using Fields()!]
    AAdd(l_aErrors,{::p_NamespaceAndTableName,::p_KEY,::p_ErrorMessage,hb_orm_GetApplicationStack()})
    
otherwise
    l_nSelect = iif(used(),select(),0)
    
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_cSQLCommand := [SELECT ]
        
        if ::p_DistinctMode == 1
            l_cSQLCommand += [DISTINCT ]
        endif

        l_cSQLCommand += l_cEndOfLine

        if empty(l_nNumberOfColumnsToReturn)
            //Only allowed when no joins are done
            if empty(l_nNumberOfJoins)
                l_cSQLCommand += [ *]
            else
                l_lErrorOccurred := .t.
                ::p_ErrorMessage := "May not get all field when using joins."
                AAdd(l_aErrors,{::p_NamespaceAndTableName,::p_KEY,::p_ErrorMessage,hb_orm_GetApplicationStack()})
            endif
        else
            //Precompute the max length of the Column Expression
            l_nMaxTextLength1 := 0
            for l_nCounter := 1 to l_nNumberOfColumnsToReturn
                l_nMaxTextLength1 := max(l_nMaxTextLength1,len(::ExpressionToMYSQL("column",::p_ColumnToReturn[l_nCounter,1])))
            endfor

            for l_nCounter = 1 to l_nNumberOfColumnsToReturn
                if l_nCounter > 1
                    l_cSQLCommand += [,]+l_cEndOfLine
                endif

                if l_cSQLCommand == [SELECT ]+l_cEndOfLine
                    l_cSQLCommand :=  [SELECT ]+padr(::ExpressionToMYSQL("column",::p_ColumnToReturn[l_nCounter,1]),l_nMaxTextLength1,chr(1))
                else
                    l_cSQLCommand += l_cColumnIndent + padr(::ExpressionToMYSQL("column",::p_ColumnToReturn[l_nCounter,1]),l_nMaxTextLength1,chr(1))
                endif

                if !empty(::p_ColumnToReturn[l_nCounter,2])
                    l_cSQLCommand += [ AS `]+::p_ColumnToReturn[l_nCounter,2]+[`]
                else
                    l_cSQLCommand += [ AS `]+strtran(::p_ColumnToReturn[l_nCounter,1],[.],[_])+[`]
                endif
                
            endfor
            l_cSQLCommand += l_cEndOfLine
        endif
        
        l_cSQLCommand += [ FROM ]+::p_oSQLConnection:FormatIdentifier(::p_oSQLConnection:NormalizeTableNamePhysical(::p_NamespaceAndTableName))+[ AS ]+::p_oSQLConnection:FormatIdentifier(::p_TableAlias)+l_cEndOfLine

        l_nMaxTextLength1 := 0
        l_nMaxTextLength2 := 0
        l_nMaxTextLength3 := 0

        for l_nCounter = 1 to l_nNumberOfJoins
            do case
            case left(::p_Join[l_nCounter,1],1) == "I"  //Inner Join
                l_nMaxTextLength1 := max(l_nMaxTextLength1,len([ INNER JOIN]))
            case left(::p_Join[l_nCounter,1],1) == "L"  //Left Outer
                l_nMaxTextLength1 := max(l_nMaxTextLength1,len([ LEFT OUTER JOIN]))
            case left(::p_Join[l_nCounter,1],1) == "R"  //Right Outer
                l_nMaxTextLength1 := max(l_nMaxTextLength1,len([ RIGHT OUTER JOIN]))
            case left(::p_Join[l_nCounter,1],1) == "F"  //Full Outer
                l_nMaxTextLength1 := max(l_nMaxTextLength1,len([ FULL OUTER JOIN]))
            otherwise
                loop
            endcase

            l_nMaxTextLength2 := max(l_nMaxTextLength2,len( [ ]+::p_oSQLConnection:FormatIdentifier(::p_oSQLConnection:NormalizeTableNamePhysical(::p_Join[l_nCounter,2])) ))

            l_nMaxTextLength3 := max(l_nMaxTextLength3,len( ::p_oSQLConnection:FormatIdentifier(lower(::p_Join[l_nCounter,3])) ))

        endfor


        for l_nCounter = 1 to l_nNumberOfJoins
            do case
            case left(::p_Join[l_nCounter,1],1) == "I"  //Inner Join
                l_cSQLCommand += padr([ INNER JOIN],l_nMaxTextLength1,chr(1))
            case left(::p_Join[l_nCounter,1],1) == "L"  //Left Outer
                l_cSQLCommand += padr([ LEFT OUTER JOIN],l_nMaxTextLength1,chr(1))
            case left(::p_Join[l_nCounter,1],1) == "R"  //Right Outer
                l_cSQLCommand += padr([ RIGHT OUTER JOIN],l_nMaxTextLength1,chr(1))
            case left(::p_Join[l_nCounter,1],1) == "F"  //Full Outer
                l_cSQLCommand += padr([ FULL OUTER JOIN],l_nMaxTextLength1,chr(1))
            otherwise
                loop
            endcase
            
            l_cSQLCommand += padr([ ] + ::p_oSQLConnection:FormatIdentifier(::p_oSQLConnection:NormalizeTableNamePhysical(::p_Join[l_nCounter,2])),l_nMaxTextLength2,chr(1))
            l_cSQLCommand += [ AS ] + padr(::p_oSQLConnection:FormatIdentifier(lower(::p_Join[l_nCounter,3])),l_nMaxTextLength3,chr(1))
            l_cSQLCommand += [ ON ] + ::ExpressionToMYSQL("join",::p_Join[l_nCounter,4])+l_cEndOfLine
            
        endfor
        
        if l_nNumberOfWheres == 0
            l_cSQLCommand += [ WHERE (]+::p_oSQLConnection:FormatIdentifier(::p_TableAlias)+[.]+::p_oSQLConnection:FormatIdentifier(l_cPrimaryKeyFieldName)+[ = ]+trans(::p_KEY)+[)]+l_cEndOfLine
        else
            l_cSQLCommand += [ WHERE (]+::p_oSQLConnection:FormatIdentifier(::p_TableAlias)+[.]+::p_oSQLConnection:FormatIdentifier(l_cPrimaryKeyFieldName)+[ = ]+trans(::p_KEY)+l_cEndOfLine
            for l_nCounter = 1 to l_nNumberOfWheres
                l_cSQLCommand += l_cEndOfLine+ padl([ AND ],7,chr(1))
                l_cSQLCommand += [(]+::ExpressionToMYSQL("where",::p_Where[l_nCounter])+[)]
            endfor
            l_cSQLCommand += [)]+l_cEndOfLine
        endif

        if l_nNumberOfGroupBys > 0
            l_cSQLCommand += [ GROUP BY ]
            for l_nCounter = 1 to l_nNumberOfGroupBys
                if l_nCounter > 1
                    l_cSQLCommand += [,]+l_cEndOfLine+replicate(chr(1),len([ GROUP BY ]))
                endif
                l_cSQLCommand += ::ExpressionToMYSQL("groupby",::p_GroupBy[l_nCounter])
            endfor
            l_cSQLCommand += l_cEndOfLine
        endif

        do case
        case l_nNumberOfHavings = 1
            l_cSQLCommand += [ HAVING ]+::ExpressionToMYSQL("having",::p_Having[1])+l_cEndOfLine
        case l_nNumberOfHavings > 1
            l_cSQLCommand += [ HAVING (]
            for l_nCounter = 1 to l_nNumberOfHavings
                if l_nCounter > 1
                    l_cSQLCommand += l_cEndOfLine+padl([ AND ],8,chr(1))
                endif
                l_cSQLCommand += [(]+::ExpressionToMYSQL("having",::p_Having[l_nCounter])+[)]
            endfor
            l_cSQLCommand += [)]+l_cEndOfLine
        endcase

        l_cSQLCommand := strtran(l_cSQLCommand,[->],[.])

        ::p_LastSQLCommand := strtran(l_cSQLCommand,chr(1)," ")
        l_cSQLCommand      := strtran(l_cSQLCommand,chr(1),"")

    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL	
        l_cSQLCommand := [SELECT ]
        
        do case
        case ::p_DistinctMode == 1
            l_cSQLCommand += [DISTINCT ]
        case ::p_DistinctMode == 2
            // l_cSQLCommand += [DISTINCT ON ()]   Not Implemented for the :Get()
        endcase

        l_cSQLCommand += l_cEndOfLine

        if empty(l_nNumberOfColumnsToReturn)
            //Only allowed when no joins are done
            if empty(l_nNumberOfJoins)
                l_cSQLCommand += [ *]
            else
                l_lErrorOccurred := .t.
                ::p_ErrorMessage := "May not get all field when using joins."
                AAdd(l_aErrors,{::p_NamespaceAndTableName,::p_KEY,::p_ErrorMessage,hb_orm_GetApplicationStack()})
            endif
        else
            //Precompute the max length of the Column Expression
            l_nMaxTextLength1 := 0
            for l_nCounter := 1 to l_nNumberOfColumnsToReturn
                l_nMaxTextLength1 := max(l_nMaxTextLength1,len(::ExpressionToPostgreSQL("column",::p_ColumnToReturn[l_nCounter,1])))
            endfor

            for l_nCounter = 1 to l_nNumberOfColumnsToReturn
                if l_nCounter > 1
                    l_cSQLCommand += [,]+l_cEndOfLine
                endif

                if l_cSQLCommand == [SELECT ]+l_cEndOfLine
                    l_cSQLCommand :=  [SELECT ]+padr(::ExpressionToPostgreSQL("column",::p_ColumnToReturn[l_nCounter,1]),l_nMaxTextLength1,chr(1))
                else
                    l_cSQLCommand += l_cColumnIndent + padr(::ExpressionToPostgreSQL("column",::p_ColumnToReturn[l_nCounter,1]),l_nMaxTextLength1,chr(1))
                endif
                
                if !empty(::p_ColumnToReturn[l_nCounter,2])
                    l_cSQLCommand += [ AS "]+::p_ColumnToReturn[l_nCounter,2]+["]
                else
                    l_cSQLCommand += [ AS "]+strtran(::p_ColumnToReturn[l_nCounter,1],[.],[_])+["]
                endif
                
            endfor
            l_cSQLCommand += l_cEndOfLine
        endif
        
        l_cSQLCommand += [ FROM ]+::p_oSQLConnection:FormatIdentifier(::p_oSQLConnection:NormalizeTableNamePhysical(::p_NamespaceAndTableName))+[ AS ]+::p_oSQLConnection:FormatIdentifier(::p_TableAlias)+l_cEndOfLine

        l_nMaxTextLength1 := 0
        l_nMaxTextLength2 := 0
        l_nMaxTextLength3 := 0

        for l_nCounter = 1 to l_nNumberOfJoins
            do case
            case left(::p_Join[l_nCounter,1],1) == "I"  //Inner Join
                l_nMaxTextLength1 := max(l_nMaxTextLength1,len([ INNER JOIN]))
            case left(::p_Join[l_nCounter,1],1) == "L"  //Left Outer
                l_nMaxTextLength1 := max(l_nMaxTextLength1,len([ LEFT OUTER JOIN]))
            case left(::p_Join[l_nCounter,1],1) == "R"  //Right Outer
                l_nMaxTextLength1 := max(l_nMaxTextLength1,len([ RIGHT OUTER JOIN]))
            case left(::p_Join[l_nCounter,1],1) == "F"  //Full Outer
                l_nMaxTextLength1 := max(l_nMaxTextLength1,len([ FULL OUTER JOIN]))
            otherwise
                loop
            endcase

            l_nMaxTextLength2 := max(l_nMaxTextLength2,len( [ ]+::p_oSQLConnection:FormatIdentifier(::p_oSQLConnection:NormalizeTableNamePhysical(::p_Join[l_nCounter,2])) ))

            l_nMaxTextLength3 := max(l_nMaxTextLength3,len( ::p_oSQLConnection:FormatIdentifier(lower(::p_Join[l_nCounter,3])) ))

        endfor

        for l_nCounter = 1 to l_nNumberOfJoins
            do case
            case left(::p_Join[l_nCounter,1],1) == "I"  //Inner Join
                l_cSQLCommand += padr([ INNER JOIN],l_nMaxTextLength1,chr(1))
            case left(::p_Join[l_nCounter,1],1) == "L"  //Left Outer
                l_cSQLCommand += padr([ LEFT OUTER JOIN],l_nMaxTextLength1,chr(1))
            case left(::p_Join[l_nCounter,1],1) == "R"  //Right Outer
                l_cSQLCommand += padr([ RIGHT OUTER JOIN],l_nMaxTextLength1,chr(1))
            case left(::p_Join[l_nCounter,1],1) == "F"  //Full Outer
                l_cSQLCommand += padr([ FULL OUTER JOIN],l_nMaxTextLength1,chr(1))
            otherwise
                loop
            endcase
            
            l_cSQLCommand += padr([ ]+::p_oSQLConnection:FormatIdentifier(::p_oSQLConnection:NormalizeTableNamePhysical(::p_Join[l_nCounter,2])),l_nMaxTextLength2,chr(1))
            l_cSQLCommand += [ AS ] + padr(::p_oSQLConnection:FormatIdentifier(lower(::p_Join[l_nCounter,3])),l_nMaxTextLength3,chr(1))
            l_cSQLCommand += [ ON ] +  ::ExpressionToPostgreSQL("join",::p_Join[l_nCounter,4])+l_cEndOfLine
            
        endfor

        if l_nNumberOfWheres == 0
            l_cSQLCommand += [ WHERE (]+::p_oSQLConnection:FormatIdentifier(::p_TableAlias)+[.]+::p_oSQLConnection:FormatIdentifier(l_cPrimaryKeyFieldName)+[ = ]+trans(::p_KEY)+[)]+l_cEndOfLine
        else
            l_cSQLCommand += [ WHERE (]+::p_oSQLConnection:FormatIdentifier(::p_TableAlias)+[.]+::p_oSQLConnection:FormatIdentifier(l_cPrimaryKeyFieldName)+[ = ]+trans(::p_KEY)+l_cEndOfLine
            for l_nCounter = 1 to l_nNumberOfWheres
                l_cSQLCommand += l_cEndOfLine+ padl([ AND ],7,chr(1))
                l_cSQLCommand += [(]+::ExpressionToPostgreSQL("where",::p_Where[l_nCounter])+[)]
            endfor
            l_cSQLCommand += [)]+l_cEndOfLine
        endif

        if l_nNumberOfGroupBys > 0
            l_cSQLCommand += [ GROUP BY ]
            for l_nCounter = 1 to l_nNumberOfGroupBys
                if l_nCounter > 1
                    l_cSQLCommand += [,]+l_cEndOfLine+replicate(chr(1),len([ GROUP BY ]))
                endif
                l_cSQLCommand += ::ExpressionToPostgreSQL("groupby",::p_GroupBy[l_nCounter])
            endfor
            l_cSQLCommand += l_cEndOfLine
        endif
            
        do case
        case l_nNumberOfHavings = 1
            l_cSQLCommand += [ HAVING ]+::ExpressionToPostgreSQL("having",::p_Having[1])+l_cEndOfLine
        case l_nNumberOfHavings > 1
            l_cSQLCommand += [ HAVING (]
            for l_nCounter = 1 to l_nNumberOfHavings
                if l_nCounter > 1
                    l_cSQLCommand += l_cEndOfLine+padl([ AND ],8,chr(1))
                endif
                l_cSQLCommand += [(]+::ExpressionToPostgreSQL("having",::p_Having[l_nCounter])+[)]
            endfor
            l_cSQLCommand += [)]+l_cEndOfLine
        endcase

        l_cSQLCommand := strtran(l_cSQLCommand,[->],[.])
        
        ::p_LastSQLCommand := strtran(l_cSQLCommand,chr(1)," ")
        l_cSQLCommand      := strtran(l_cSQLCommand,chr(1),"")
        
    endcase

    if !l_lErrorOccurred
        l_lErrorOccurred := .t.   // Assumed it failed
        
        l_cCursorTempName := "c_DB_Temp"

        if ::p_oSQLConnection:SQLExec(::p_cEventId,l_cSQLCommand,l_cCursorTempName)
            select (l_cCursorTempName)
            ::Tally        := reccount()
            l_lErrorOccurred := .f.
            
            do case
            case ::Tally == 0
                AAdd(l_aErrors,{::p_NamespaceAndTableName,::p_KEY,"Error in method get() did not find record."+CRLF+::LastSQL(),hb_orm_GetApplicationStack()})
            case ::Tally == 1
                //Build an object to return
                l_oResult := hb_orm_Data()
                
                for l_nFieldCounter := 1 to fcount()
                    l_cFieldName  := FieldName(l_nFieldCounter)
                    l_xFieldValue := FieldGet(l_nFieldCounter)
                    l_oResult:AddField(l_cFieldName,l_xFieldValue)
                endfor
            otherwise
                //Should not happen. Returned more than 1 record.
                AAdd(l_aErrors,{::p_NamespaceAndTableName,::p_KEY,"Error in method get() more than 1 record."+CRLF+::LastSQL(),hb_orm_GetApplicationStack()})
            endcase
        else
            ::Tally = -1
            AAdd(l_aErrors,{::p_NamespaceAndTableName,::p_KEY,"Error in method get() "+::p_ErrorMessage,hb_orm_GetApplicationStack()})
        endif
        
        CloseAlias(l_cCursorTempName)
    endif
    
    if l_lErrorOccurred
        ::Tally = -1
        select (l_nSelect)
    else
        select (l_nSelect)
    endif

endcase

if len(l_aErrors) > 0
    ::p_ErrorMessage := l_aErrors
    ::p_oSQLConnection:LogErrorEvent(::p_cEventId,l_aErrors)
endif

return l_oResult
//-----------------------------------------------------------------------------------------------------------------
method FormatDateForSQLUpdate(par_dDate) class hb_orm_SQLData
local l_cResult

if empty(par_dDate)
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_cResult := ['0000-00-00']
        
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        l_cResult := [NULL]
        
    // case inlist(v_SQLServerType,"MSSQL2000","MSSQL2005","MSSQL2008")
    // 	l_cResult := [NULL]
        
    otherwise
        l_cResult := [NULL]
        
    endcase
else
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_cResult := [']+hb_DtoC(par_dDate,"YYYY-MM-DD")+[']
        
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        l_cResult := [']+hb_DtoC(par_dDate,"YYYY-MM-DD")+[']
        
    // case inlist(v_SQLServerType,"MSSQL2000","MSSQL2005","MSSQL2008")
    // 	l_cResult := [']+hb_DtoC(par_dDate,"YYYY-MM-DD")+[']
        
    otherwise
        l_cResult := [']+hb_DtoC(par_dDate,"YYYY-MM-DD")+[']
        
    endcase
    
endif
return l_cResult
//-----------------------------------------------------------------------------------------------------------------
method FormatDateTimeForSQLUpdate(par_tDati,par_nPrecision) class hb_orm_SQLData
local l_cResult
local l_nPrecision := min(hb_defaultValue(par_nPrecision,0),4)  //Harbour can only handle up to 4 precision

if empty(par_tDati)
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_cResult := ['0000-00-00 00:00:00']
        
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        l_cResult := [NULL]
        
    // case inlist(v_SQLServerType,"MSSQL2000","MSSQL2005","MSSQL2008")
    // 	l_cResult := [NULL]
        
    otherwise
        l_cResult := [NULL]
        
    endcase
    
else
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_cResult := [']+hb_TtoC(par_tDati,"YYYY-MM-DD","hh:mm:ss"+iif(l_nPrecision=0,"","."+replicate("f",l_nPrecision)))+[']
        
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        l_cResult := [']+hb_TtoC(par_tDati,"YYYY-MM-DD","hh:mm:ss"+iif(l_nPrecision=0,"","."+replicate("f",l_nPrecision)))+[']
        
    // case inlist(v_SQLServerType,"MSSQL2000","MSSQL2005","MSSQL2008")
    // 	l_cResult := [']+hb_TtoC(par_tDati,"YYYY-MM-DD","hh:mm:ss")+[']
        
    otherwise
        l_cResult := [']+hb_TtoC(par_tDati,"YYYY-MM-DD","hh:mm:ss"+iif(l_nPrecision=0,"","."+replicate("f",l_nPrecision)))+[']
        
    endcase
    
endif
return l_cResult
//-----------------------------------------------------------------------------------------------------------------
method PrepValueForMySQL(par_cAction,par_xValue,par_cTableName,par_nKey,par_cFieldName,par_hFieldInfo,l_aAutoTrimmedFields,l_aErrors) class hb_orm_SQLData
local l_lResult := .t.
local l_cValue  := NIL
local l_cFieldType := par_hFieldInfo[HB_ORM_SCHEMA_FIELD_TYPE]
local l_cValueType := Valtype(par_xValue)                       //See https://github.com/Petewg/harbour-core/wiki/V
local l_nFieldLen,l_nFieldDec
local l_nMaxValue
local l_nUnsignedLength,l_nDecimals

if hb_IsNIL(par_xValue)
    if hb_HGetDef(par_hFieldInfo,HB_ORM_SCHEMA_FIELD_NULLABLE,.f.)
        l_cValue  := "NULL"
    else
        AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" NULL is not allowed',hb_orm_GetApplicationStack()})
        l_lResult := .f.
    endif
else
    switch l_cFieldType
    case  "I" // Integer
        if l_cValueType == "N"
            if par_xValue < -2147483648 .or. par_xValue > 2147483647
                AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not in Integer range',hb_orm_GetApplicationStack()})
                l_lResult := .f.
            else
                l_cValue := hb_ntoc(par_xValue)
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not an Integer',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    case "IB" // Big Integer
        if l_cValueType == "N"
            // Not Testing if in range
            l_cValue := hb_ntoc(par_xValue)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not an Big Integer',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    case "IS" // Small Integer
        if l_cValueType == "N"
            // Not Testing if in range
            l_cValue := hb_ntoc(par_xValue)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not an Small Integer',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    case  "Y" // Money  (4 decimals)
        if l_cValueType == "N"
            // Not Testing if in range Yet
            l_cValue := hb_ntoc(par_xValue)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Numeric / Money',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    case  "N" // numeric
        do case
        case l_cValueType == "N"
            l_nFieldLen := hb_HGetDef(par_hFieldInfo,HB_ORM_SCHEMA_FIELD_LENGTH,0)
            l_nFieldDec := hb_HGetDef(par_hFieldInfo,HB_ORM_SCHEMA_FIELD_DECIMALS,0)
            if l_nFieldLen > 15
                AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Numeric with more than 15 digits.',hb_orm_GetApplicationStack()})
                l_lResult := .f.
            else
                l_nMaxValue := ((10**l_nFieldLen)-1)/(10**l_nFieldDec)
                if abs(par_xValue) <= l_nMaxValue
                    if round(abs(par_xValue),l_nFieldDec) == abs(par_xValue)  // Test if decimal is larger than allowed
                        l_cValue := hb_ntoc(par_xValue)
                    else
                        AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" Numeric Decimals Overflow: '+alltrim(str(par_xValue)),hb_orm_GetApplicationStack()})
                        l_lResult := .f.
                    endif
                else
                    AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" Numeric Overflow: '+alltrim(str(par_xValue)),hb_orm_GetApplicationStack()})
                    l_lResult := .f.
                endif
            endif
        case l_cValueType == "C"
            l_nUnsignedLength := l_nDecimals := 0
            if el_AUnpack(IsStringANumber(par_xValue),,@l_nUnsignedLength,@l_nDecimals)
                l_nFieldLen := hb_HGetDef(par_hFieldInfo,HB_ORM_SCHEMA_FIELD_LENGTH,0)
                l_nFieldDec := hb_HGetDef(par_hFieldInfo,HB_ORM_SCHEMA_FIELD_DECIMALS,0)
                if l_nUnsignedLength <= l_nFieldLen .and. l_nDecimals <= l_nFieldDec
                    l_cValue := par_xValue
                else
                    AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" Numeric String Overflow: '+par_xValue,hb_orm_GetApplicationStack()})
                    l_lResult := .f.
                endif
            else
                AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Numeric String',hb_orm_GetApplicationStack()})
                l_lResult := .f.
            endif
        otherwise
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Numeric',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endcase
        exit
    case  "C" // char                                                      https://dev.mysql.com/doc/refman/8.0/en/string-literals.html
    case "CV" // variable length char (with option max length value)
    case  "B" // binary
    case "BV" // variable length binary (with option max length value)
        if l_cValueType == "C"
            if empty(par_xValue)  // At this point we already know it is not null
                l_cValue := "''"
            else
                l_nFieldLen := hb_HGetDef(par_hFieldInfo,HB_ORM_SCHEMA_FIELD_LENGTH,0)
                if len(par_xValue) <= l_nFieldLen
                    l_cValue := "x'"+hb_StrToHex(par_xValue)+"'"
                else
                    AAdd(l_aAutoTrimmedFields,{par_cFieldName,par_xValue,l_cFieldType,l_nFieldLen})
                    l_cValue := "x'"+hb_StrToHex(left(par_xValue,l_nFieldLen))+"'"
                endif
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Character',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    case  "M" // longtext
    case  "R" // long blob (binary)
        if l_cValueType == "C"
            if len(par_xValue) == 0   //_M_ Test if this logic makes senses for MySQL
                l_cValue := "''"
            else
                l_cValue := "x'"+hb_StrToHex(par_xValue)+"'"
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Character/Binary',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    case  "L" // Logical
        if l_cValueType == "L"
            l_cValue := iif(par_xValue,"TRUE","FALSE")
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Logical',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    case  "D" // Date   
        if l_cValueType == "D"
            // l_cValue := '"'+hb_DtoC(par_xValue,"YYYY-MM-DD")+'"'           //_M_  Test on 1753-01-01  Test integrity in MySQL
            l_cValue := ::FormatDateForSQLUpdate(par_xValue)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Date',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit

    case"TOZ" // Time with time zone               'hh:mm:ss[.fraction]'
    case "TO" // Time without time zone
        if l_cValueType == "C"
            l_nFieldDec := hb_HGetDef(par_hFieldInfo,HB_ORM_SCHEMA_FIELD_DECIMALS,0)
            if hb_orm_CheckTimeFormatValidity(par_xValue)
                if len(par_xValue) > 9 + l_nFieldDec
                    AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" Time String precision Overflow: '+alltrim(par_xValue),hb_orm_GetApplicationStack()})
                    l_lResult := .f.
                else
                    l_cValue := '"'+par_xValue+'"'
                endif
            else
                AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a valid Time String',hb_orm_GetApplicationStack()})
                l_lResult := .f.
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Time String',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit

    case"DTZ" // Date Time with time zone           https://dev.mysql.com/doc/refman/8.0/en/datetime.html  _M_ Support for Time fractions and test for precision.
    case "DT" // Date Time without time zone
    case  "T" // Date Time without time zone
        if l_cValueType == "T"
            // l_cValue := '"'+hb_TtoC(l_cValue,"YYYY-MM-DD","hh:mm:ss")+'"'           //_M_  Test on 1753-01-01
            l_cValue := ::FormatDateTimeForSQLUpdate(par_xValue,3)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Datetime',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    case "JSB" // jsonb string
    case "JS"  // json string
        if l_cValueType == "C"
            if len(par_xValue) == 0   //_M_ Test if this logic makes senses for MySQL
                l_cValue := "''"
            else
                l_cValue := "x'"+hb_StrToHex(par_xValue)+"'"
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" a string',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    case "UUI" // uuid string
        if l_cValueType == "C"
            if len(par_xValue) == 0   //_M_ Test if this logic makes senses for MySQL
                l_cValue := "''"
            else
                l_cValue := "'"+lower(par_xValue)+"'"
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" a string',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    case "OID" // oid
        if l_cValueType == "N"
            // Not Testing if in range
            l_cValue := hb_ntoc(par_xValue)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not an oid',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    otherwise // "?" Unknown
        AAdd(l_aErrors,{par_cTableName,par_nKey,"Skipped "+par_cAction+" unknown value type: "+l_cValueType+' Field "'+par_cFieldName+'" of Unknown type',hb_orm_GetApplicationStack()})
        l_lResult := .f.
        exit
    endcase
endif

return {l_lResult,l_cValue}
//-----------------------------------------------------------------------------------------------------------------
method PrepValueForPostgreSQL(par_cAction,par_xValue,par_cTableName,par_nKey,par_cFieldName,par_hFieldInfo,l_aAutoTrimmedFields,l_aErrors) class hb_orm_SQLData
local l_lResult := .t.
local l_cValue  := NIL
local l_xValue
local l_cFieldType := par_hFieldInfo[HB_ORM_SCHEMA_FIELD_TYPE]
local l_cValueType := Valtype(par_xValue)                       //See https://github.com/Petewg/harbour-core/wiki/V
local l_nFieldLen,l_nFieldDec
local l_nMaxValue
local l_nUnsignedLength,l_nDecimals

if hb_IsNIL(par_xValue)
    if hb_HGetDef(par_hFieldInfo,HB_ORM_SCHEMA_FIELD_NULLABLE,.f.)
        l_cValue  := "NULL"
    else
        AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" NULL is not allowed',hb_orm_GetApplicationStack()})
        l_lResult := .f.
    endif
else
    switch l_cFieldType
    case  "I" // Integer
        if l_cValueType == "N"
            if par_xValue < -2147483648 .or. par_xValue > 2147483647
                AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not in Integer range',hb_orm_GetApplicationStack()})
                l_lResult := .f.
            else
                l_cValue := hb_ntoc(par_xValue)
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not an Integer',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    case "IB" // Big Integer
        if l_cValueType == "N"
            // Not Testing if in range
            l_cValue := hb_ntoc(par_xValue)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not an Big Integer',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    case "IS" // Small Integer
        if l_cValueType == "N"
            // Not Testing if in range
            l_cValue := hb_ntoc(par_xValue)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not an Small Integer',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    case  "Y" // Money  (4 decimals)
        if l_cValueType == "N"
            // Not Testing if in range Yet
            l_cValue := hb_ntoc(par_xValue)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Numeric / Money',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    case  "N" // numeric
        do case
        case l_cValueType == "N"
            l_nFieldLen := hb_HGetDef(par_hFieldInfo,HB_ORM_SCHEMA_FIELD_LENGTH,0)
            l_nFieldDec := hb_HGetDef(par_hFieldInfo,HB_ORM_SCHEMA_FIELD_DECIMALS,0)
            if l_nFieldLen > 15
                AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Numeric with more than 15 digits.',hb_orm_GetApplicationStack()})
                l_lResult := .f.
            else
                l_nMaxValue := ((10**l_nFieldLen)-1)/(10**l_nFieldDec)
                if abs(par_xValue) <= l_nMaxValue
                    if round(abs(par_xValue),l_nFieldDec) == abs(par_xValue)  // Test if decimal is larger than allowed
                        l_cValue := hb_ntoc(par_xValue)
                    else
                        AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" Numeric Decimals Overflow: '+alltrim(str(par_xValue)),hb_orm_GetApplicationStack()})
                        l_lResult := .f.
                    endif
                else
                    AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" Numeric Overflow: '+alltrim(str(par_xValue)),hb_orm_GetApplicationStack()})
                    l_lResult := .f.
                endif
            endif
        case l_cValueType == "C"
            l_nUnsignedLength := l_nDecimals := 0
            if el_AUnpack(IsStringANumber(par_xValue),,@l_nUnsignedLength,@l_nDecimals)
                l_nFieldLen := hb_HGetDef(par_hFieldInfo,HB_ORM_SCHEMA_FIELD_LENGTH,0)
                l_nFieldDec := hb_HGetDef(par_hFieldInfo,HB_ORM_SCHEMA_FIELD_DECIMALS,0)
                if l_nUnsignedLength <= l_nFieldLen .and. l_nDecimals <= l_nFieldDec
                    l_cValue := par_xValue
                else
                    AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" Numeric String Overflow: '+par_xValue,hb_orm_GetApplicationStack()})
                    l_lResult := .f.
                endif
            else
                AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Numeric String',hb_orm_GetApplicationStack()})
                l_lResult := .f.
            endif
        otherwise
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Numeric',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endcase
        exit
    case  "C" // char 
    case "CV" // variable length char (with option max length value)
    case  "B" // binary
    case "BV" // variable length binary (with option max length value)
        if l_cValueType == "C"
            if empty(par_xValue)  // At this point we already know it is not null
                l_cValue := "''"
            else
                l_nFieldLen := hb_HGetDef(par_hFieldInfo,HB_ORM_SCHEMA_FIELD_LENGTH,0)
                if len(par_xValue) <= l_nFieldLen
                    // l_cValue := "E'\x"+hb_StrToHex(par_xValue,"\x")+"'"
                    if "B" $ l_cFieldType
                        l_cValue := hb_orm_PostgresqlEncodeBinary(par_xValue)
                    else
                        l_cValue := hb_orm_PostgresqlEncodeUTF8String(par_xValue)
                    endif
                else
                    AAdd(l_aAutoTrimmedFields,{par_cFieldName,par_xValue,l_cFieldType,l_nFieldLen})
                    // l_cValue := "E'\x"+hb_StrToHex(left(par_xValue,l_nFieldLen),"\x")+"'"
                    if "B" $ l_cFieldType
                        l_cValue := hb_orm_PostgresqlEncodeBinary(left(par_xValue,l_nFieldLen))
                    else
                        l_cValue := hb_orm_PostgresqlEncodeUTF8String(left(par_xValue,l_nFieldLen))
                    endif
                endif
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Character',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    case  "M" // longtext
    case  "R" // long blob (binary)
        if l_cValueType == "C"
            if len(par_xValue) == 0
                l_cValue := "''"
            else
                // l_cValue := "E'\x"+hb_StrToHex(par_xValue,"\x")+"'"
                if l_cFieldType == "M"
                    l_cValue := hb_orm_PostgresqlEncodeUTF8String(par_xValue)
                else
                    l_cValue := hb_orm_PostgresqlEncodeBinary(par_xValue)
                endif
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Character/Binary',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    case  "L" // Logical
        if l_cValueType == "L"
            l_cValue := iif(par_xValue,"TRUE","FALSE")
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Logical',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    case  "D" // Date 
        if l_cValueType == "D"
            // l_cValue := '"'+hb_DtoC(par_xValue,"YYYY-MM-DD")+'"'           //_M_  Test integrity in MySQL
            l_cValue := ::FormatDateForSQLUpdate(par_xValue)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Date',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit

    case"TOZ" // Time with time zone               'hh:mm:ss[.fraction]'
    case "TO" // Time without time zone
        if l_cValueType == "C"
            //if (SecToTime(TimeToSec(par_xValue),len(par_xValue)=11) == par_xValue)   //_M_ Verify format validity
            l_nFieldDec := hb_HGetDef(par_hFieldInfo,HB_ORM_SCHEMA_FIELD_DECIMALS,0)
            if hb_orm_CheckTimeFormatValidity(par_xValue)
                if len(par_xValue) > 9 + l_nFieldDec
                    AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" Time String precision Overflow: '+alltrim(par_xValue),hb_orm_GetApplicationStack()})
                    l_lResult := .f.
                else
                    l_cValue := "'"+par_xValue+"'"
                endif
            else
                AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a valid Time String',hb_orm_GetApplicationStack()})
                l_lResult := .f.
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Time String',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit

    case"DTZ" // Date Time with time zone           _M_ Support for Time fractions and test for precision.
    case "DT" // Date Time without time zone
    case  "T" // Date Time without time zone
        if l_cValueType == "T"
            l_cValue := ::FormatDateTimeForSQLUpdate(par_xValue,3)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Datetime',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    case "JSB" // jsonb string
        if l_cValueType == "C"
            l_xValue := el_StrTran(par_xValue,"::jsonb","",-1,-1,1)
            if len(l_xValue) == 0
                l_cValue := "{}::jsonb"
            else
                l_cValue := hb_orm_PostgresqlEncodeUTF8String(l_xValue)+"::jsonb"
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a string',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif

        exit
    case "JS" // json string
        if l_cValueType == "C"
            l_xValue := el_StrTran(par_xValue,"::json","",-1,-1,1)
            if len(l_xValue) == 0
                l_cValue := "{}::json"
            else
                l_cValue := hb_orm_PostgresqlEncodeUTF8String(l_xValue)+"::json"
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a string',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif

        exit
    case "UUI" // uuid
        if l_cValueType == "C"
            l_xValue := el_StrTran(par_xValue,"::uuid","",-1,-1,1)
            if len(l_xValue) == 0
                l_cValue := "''::uuid"
            else
                l_cValue := "'"+lower(alltrim(l_xValue))+"'::uuid"
            endif
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a string',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif

        exit
    case  "OID" // oid
        if l_cValueType == "N"
            l_cValue := hb_ntoc(par_xValue)
        else
            AAdd(l_aErrors,{par_cTableName,par_nKey,'Field "'+par_cFieldName+'" not a Numeric',hb_orm_GetApplicationStack()})
            l_lResult := .f.
        endif
        exit
    otherwise // "?" Unknown
        AAdd(l_aErrors,{par_cTableName,par_nKey,"Skipped "+par_cAction+" unknown value type: "+l_cValueType+' Field "'+par_cFieldName+'" of Unknown type',hb_orm_GetApplicationStack()})
        l_lResult := .f.
        exit
    endcase
endif

return {l_lResult,l_cValue}
//-----------------------------------------------------------------------------------------------------------------
method GetPostgreSQLCastForFieldType(par_cFieldType,par_nFieldLen,par_nFieldDec) class hb_orm_SQLData
local l_cCast

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    do case
    case par_cFieldType == "I"
        l_cCast := [integer]
    case par_cFieldType == "IB"
        l_cCast := [bigint]
    case par_cFieldType == "IS"
        l_cCast := [smallint]
    case par_cFieldType == "N"
        l_cCast := [numeric(]+trans(par_nFieldLen)+[,]+trans(par_nFieldDec)+[)]
    case par_cFieldType == "C"
        l_cCast := [character(]+trans(par_nFieldLen)+[)]
    case par_cFieldType == "CV"
        l_cCast := [character varying]+iif(empty(par_nFieldLen),[],[(]+trans(par_nFieldLen)+[)])
    case par_cFieldType == "B"
        l_cCast := [bytea]
    case par_cFieldType == "BV"
        l_cCast := [bytea]
    case par_cFieldType == "M"
        l_cCast := [text]
    case par_cFieldType == "R"
        l_cCast := [bytea]
    case par_cFieldType == "L"
        l_cCast := [boolean]
    case par_cFieldType == "D"
        l_cCast := [date]
    case par_cFieldType == "TOZ"
        if el_between(par_nFieldDec,0,6)
            l_cCast := [time(]+trans(par_nFieldDec)+[) with time zone]
        else
            l_cCast := [time with time zone]
        endif
    case par_cFieldType == "TO"
        if el_between(par_nFieldDec,0,6)
            l_cCast := [time(]+trans(par_nFieldDec)+[) without time zone]
        else
            l_cCast := [time without time zone]
        endif
    case par_cFieldType == "DTZ"
        if el_between(par_nFieldDec,0,6)
            l_cCast := [timestamp(]+trans(par_nFieldDec)+[) with time zone]
        else
            l_cCast := [timestamp with time zone]
        endif
    case par_cFieldType == "DT" .or. par_cFieldType == "T"
        if el_between(par_nFieldDec,0,6)
            l_cCast := [timestamp(]+trans(par_nFieldDec)+[) without time zone]
        else
            l_cCast := [timestamp without time zone]
        endif
    case par_cFieldType == "Y"
        l_cCast := [money]
    case par_cFieldType == "UUI"
        l_cCast := [uuid]
    case par_cFieldType == "JSB"
        l_cCast := [jsonb]
    case par_cFieldType == "JS"
        l_cCast := [json]
    case par_cFieldType == "OID"
        l_cCast := [oid]
    otherwise
        l_cCast := ""
    endcase

endcase

return l_cCast
//-----------------------------------------------------------------------------------------------------------------
static function IsStringANumber(par_cNumber)
local l_lResult := .t.
local l_nPos
local l_cChar
local l_lFoundPeriod := .f.
local l_nUnsignedLength  := 0
local l_nDecimal := 0

if empty(par_cNumber)
    l_lResult := .f.
else
    l_cChar := left(par_cNumber,1)
    do case
    case l_cChar == "-"
    case l_cChar $ "0123456789"
        l_nUnsignedLength += 1
    otherwise
        l_lResult := .f.
    endcase

    if l_lResult
        for l_nPos := 2 to Len(par_cNumber)
            l_cChar := substr(par_cNumber,l_nPos,1)
            do case
            case l_cChar $ "0123456789"
                l_nUnsignedLength += 1
                if l_lFoundPeriod
                    l_nDecimal += 1
                endif
            case l_cChar == "."
                if l_lFoundPeriod
                    //More than 1 period
                    l_lResult := .f.
                    exit
                else
                    l_lFoundPeriod := .t.
                endif
            otherwise
                l_lResult := .f.
                exit
            endcase
        endfor
    endif
endif
return {l_lResult,l_nUnsignedLength,l_nDecimal}

//-----------------------------------------------------------------------------------------------------------------
function hb_orm_CheckTimeFormatValidity(par_cTime)
local l_lResult := .t.
local l_nPos

//Max 23:59:59.999999
do case
case !(substr(par_cTime,1,1) $ "012")
    l_lResult := .f.
case !(substr(par_cTime,2,1) $ "0123456789")
    l_lResult := .f.
case val(substr(par_CTime,1,2)) > 23
    l_lResult := .f.
case !(substr(par_cTime,3,1) == ":")
    l_lResult := .f.
case !(substr(par_cTime,4,1) $ "012345")
    l_lResult := .f.
case !(substr(par_cTime,5,1) $ "0123456789")
    l_lResult := .f.
case val(substr(par_CTime,4,2)) > 59
    l_lResult := .f.
case !(substr(par_cTime,6,1) == ":")
    l_lResult := .f.
case !(substr(par_cTime,7,1) $ "012345")
    l_lResult := .f.
case !(substr(par_cTime,8,1) $ "0123456789")
    l_lResult := .f.
case val(substr(par_CTime,7,2)) > 59
    l_lResult := .f.
case len(par_CTime) = 8
    //Done Testing is valid
case len(par_CTime) = 9  //would need some decimal values
    l_lResult := .f.
case len(par_CTime) > 15
    l_lResult := .f. // More than 6 decimals
case len(par_CTime) > 8
    if !(substr(par_CTime,9,1) == ".")
        l_lResult := .f.
    else
        for l_nPos := 10 to len(par_CTime)
            if !(substr(par_cTime,l_nPos,1) $ "0123456789")
                l_lResult := .f.
                exit
            endif
        endfor
    endif
endcase

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
method SaveFile(par_xEventId,par_cNamespaceAndTableName,par_iKey,par_cOidFieldName,par_cFullPathFileName) class hb_orm_SQLData   // Where par_cFieldName must be of type OID. Will store in PostgreSQL a file using Large Objects
local l_lResult := .t.                                                                                                        // return true of false. If false call ::ErrorMessage() to get more information
local l_oData
local l_cSQLCommand
::p_ErrorMessage := ""

do case
case pcount() < 5
    l_lResult := .f.
    ::p_ErrorMessage := [Missing Parameter.]
case empty(par_cFullPathFileName)
    l_lResult := .f.
    ::p_ErrorMessage := [Empty File Name.]
case !hb_FileExists(par_cFullPathFileName)
    l_lResult := .f.
    ::p_ErrorMessage := [File is not present.]
otherwise
    ::Table(par_xEventId,par_cNamespaceAndTableName)
    ::Column(par_cOidFieldName,"oid")
    l_oData := ::Get(par_iKey)
    if hb_IsNil(l_oData)
        //The :Get will already set an error message
        l_lResult := .f.
    else
        if !(hb_IsNil(l_oData:oid) .or. l_oData:oid == 0)  // Delete the previous file
            l_cSQLCommand := [select lo_unlink(]+trans(l_oData:oid)+[);]
            if ::p_oSQLConnection:SQLExec(::p_cEventId,l_cSQLCommand,"TempCursorSaveFile")
                if TempCursorSaveFile->(reccount()) == 1 .and. TempCursorSaveFile->lo_unlink == 1
                    ::Table(par_xEventId,par_cNamespaceAndTableName)
                    ::Field(par_cOidFieldName,nil)
                    if !::Update(par_iKey)
                        //The :Update will already set an error message
                        l_lResult := .f.
                    endif
                else
                    ::p_ErrorMessage := [Failed to delete previous version of the file.]
                    l_lResult := .f.
                endif
            else
                l_lResult := .f.
            endif
            CloseAlias("TempCursorSaveFile")
        endif
        if l_lResult
            // Save the file now.
            ::Table(par_xEventId,par_cNamespaceAndTableName)
            ::FieldExpression(par_cOidFieldName,[lo_import(']+par_cFullPathFileName+[')])
            if !::Update(par_iKey)
                //The :Update will already set an error message
                l_lResult := .f.
            endif
        endif
    endif
endcase

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method GetFile(par_xEventId,par_cNamespaceAndTableName,par_iKey,par_cOidFieldName,par_cFullPathFileName) class hb_orm_SQLData    // Will create a file at par_cFullPathFileName from the content previously saved
local l_lResult   // := .t.                                                                                                        // return true of false. If false call ::ErrorMessage() to get more information
local l_oData
local l_cSQLCommand
::p_ErrorMessage := ""

//Example: select lo_export(178171, 'd:\LastExport_restored1.Zip');

do case
case pcount() < 5
    l_lResult := .f.
    ::p_ErrorMessage := [Missing Parameter.]
case empty(par_cFullPathFileName)
    l_lResult := .f.
    ::p_ErrorMessage := [Empty File Name.]
case hb_FileExists(par_cFullPathFileName)
    l_lResult := .f.
    ::p_ErrorMessage := [File already present. May not overwrite file.]
otherwise
    ::Table(par_xEventId,par_cNamespaceAndTableName)
    ::Column(par_cOidFieldName,"oid")
    l_oData := ::Get(par_iKey)
    if hb_IsNil(l_oData)
        //The :Get will already set an error message
        l_lResult := .f.
    else
        if !(hb_IsNil(l_oData:oid) .or. l_oData:oid == 0)
            l_cSQLCommand := [select lo_export(]+trans(l_oData:oid)+[,']+par_cFullPathFileName+[');]
            if ::p_oSQLConnection:SQLExec(::p_cEventId,l_cSQLCommand,"TempCursorSaveFile")
                if TempCursorSaveFile->(reccount()) == 1 .and. TempCursorSaveFile->lo_export == 1
                    l_lResult := .t.
                else
                    ::p_ErrorMessage := [Failed to get file.]
                    l_lResult := .f.
                endif
            else
                l_lResult := .f.
            endif
            CloseAlias("TempCursorSaveFile")
        else
            ::p_ErrorMessage := [No file to get.]
            l_lResult := .f.
        endif
    endif
endcase

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method DeleteFile(par_xEventId,par_cNamespaceAndTableName,par_iKey,par_cOidFieldName) class hb_orm_SQLData                       // To remove the file from the table and nullify par_cFieldName
local l_lResult := .t.                                                                                                        // return true of false. If false call ::ErrorMessage() to get more information
local l_oData
local l_cSQLCommand
::p_ErrorMessage := ""

do case
case pcount() < 4
    l_lResult := .f.
    ::p_ErrorMessage := [Missing Parameter.]
otherwise
    ::Table(par_xEventId,par_cNamespaceAndTableName)
    ::Column(par_cOidFieldName,"oid")
    l_oData := ::Get(par_iKey)
    if hb_IsNil(l_oData)
        //The :Get will already set an error message
        l_lResult := .f.
    else
        if !(hb_IsNil(l_oData:oid) .or. l_oData:oid == 0)  // Delete the file
            l_cSQLCommand := [select lo_unlink(]+trans(l_oData:oid)+[);]
            if ::p_oSQLConnection:SQLExec(::p_cEventId,l_cSQLCommand,"TempCursorSaveFile")
                if TempCursorSaveFile->(reccount()) == 1 .and. TempCursorSaveFile->lo_unlink == 1
                    ::Table(par_xEventId,par_cNamespaceAndTableName)
                    ::Field(par_cOidFieldName,nil)
                    if !::Update(par_iKey)
                        //The :Update will already set an error message
                        l_lResult := .f.
                    endif
                else
                    ::p_ErrorMessage := [Failed to delete previous version of the file.]
                    l_lResult := .f.
                endif
            else
                l_lResult := .f.
            endif
            CloseAlias("TempCursorSaveFile")
        endif
    endif
endcase

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method AddNonTableAliases(par_aAliases) class hb_orm_SQLData  // Used to add an alias to :p_NonTableAliases to prevent casing the aliases and columns.
::p_NonTableAliases[lower(par_aAliases)] := par_aAliases
return nil
//-----------------------------------------------------------------------------------------------------------------
method ClearNonTableAliases() class hb_orm_SQLData  // Used clear :p_NonTableAliases since calling :Table() will not do so, since its own source table might be a CTE alias.
hb_HClear(::p_NonTableAliases)
return nil
//-----------------------------------------------------------------------------------------------------------------
