//Copyright (c) 2023 Eric Lendvai MIT License

#include "hb_orm.ch"

#define INVALUEWITCH chr(1)

// List of future enhancements:
//    Somehow initialize  ::p_ColumnToReturn
//    Support for more than 2 combined queries (like for example "unions")
//    instead of "~"  use chr(1)
//    Add support to a "Count()" method.
//    Add support to ::p_AddLeadingBlankRecord    Also to be done in hb_orm_sqldata.prg

//=================================================================================================================
#include "hb_orm_sqlCompoundQuery_class_definition.prg"

//-----------------------------------------------------------------------------------------------------------------
method Init() class hb_orm_SQLCompoundQuery
hb_HCaseMatch(::p_hSQLDataQueries,.f.)
return Self
//-----------------------------------------------------------------------------------------------------------------
method IsConnected() class hb_orm_SQLCompoundQuery    //Return .t. if has a connection

return (::p_oSQLConnection != NIL .and.  ::p_oSQLConnection:GetHandle() > 0)
//-----------------------------------------------------------------------------------------------------------------
method UseConnection(par_oSQLConnection) class hb_orm_SQLCompoundQuery
::p_oSQLConnection            := par_oSQLConnection
::p_SQLEngineType             := ::p_oSQLConnection:GetSQLEngineType()
::p_ConnectionNumber          := ::p_oSQLConnection:GetConnectionNumber()
::p_Database                  := ::p_oSQLConnection:GetDatabase()
::p_SchemaName                := ::p_oSQLConnection:GetCurrentSchemaName()   // Will "Freeze" the current connection p_SchemaName
::p_PrimaryKeyFieldName       := ::p_oSQLConnection:GetPrimaryKeyFieldName()
::p_CreationTimeFieldName     := ::p_oSQLConnection:GetCreationTimeFieldName()
::p_ModificationTimeFieldName := ::p_oSQLConnection:GetModificationTimeFieldName()
return Self
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
method destroy() class hb_orm_SQLCompoundQuery
// hb_orm_SendToDebugView("hb_orm_SQLCompoundQuery destroy")
::p_oSQLConnection := NIL
return .t.
//-----------------------------------------------------------------------------------------------------------------
method SetEventId(par_xId) class hb_orm_SQLCompoundQuery
if ValType(par_xId) == "N"
    ::p_EventId := trans(par_xId)
else
    ::p_EventId := left(AllTrim(par_xId),HB_ORM_MAX_EVENTID_SIZE)
endif
return NIL
//-----------------------------------------------------------------------------------------------------------------
method ErrorMessage() class hb_orm_SQLCompoundQuery                                   //Retrieve the error text of the last call to :SQL(), :Get(), :Count(), :Add() :Update()  :Delete()
local l_cErrorMessage

if ValType(::p_ErrorMessage) == "A"
    l_cErrorMessage := hb_jsonEncode(::p_ErrorMessage)
else
    l_cErrorMessage := ::p_ErrorMessage
endif
return l_cErrorMessage
//-----------------------------------------------------------------------------------------------------------------
method ReadWrite(par_lValue) class hb_orm_SQLCompoundQuery            // Was used in VFP ORM, not the Harbour version, since the result cursors are always ReadWriteable

if pcount() == 0 .or. par_lValue
    ::p_CursorUpdatable := .t.
else
    ::p_CursorUpdatable := .f.
endif

return NIL
//-----------------------------------------------------------------------------------------------------------------
method AddLeadingBlankRecord() class hb_orm_SQLCompoundQuery            // If the result cursor should have a leading blank record, used mainly to create the concept of "not-selected" row
::p_AddLeadingBlankRecord := .t.
return NIL
//-----------------------------------------------------------------------------------------------------------------
method AddLeadingRecords(par_cCursorName) class hb_orm_SQLCompoundQuery    // Specify to add records from par_cCursorName as leading record to the future result cursor

if !empty(par_cCursorName)
    ::p_AddLeadingRecordsCursorName := par_cCursorName
    ::p_AddLeadingBlankRecord       := .t.
endif

return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetExplainMode(par_nMode) class hb_orm_SQLCompoundQuery                                          // Used to get explain information. 0 = Explain off, 1 = Explain with no run, 2 = Explain with run
::p_ExplainMode := par_nMode
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SQL(par_1) class hb_orm_SQLCompoundQuery                                          // Assemble and Run SQL command

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

local l_aCombineQuery
local l_aCombine
local l_lFoundAQueryReference
local l_nReplaceCounter := 0
local l_cSubstituteString
local l_cSQLCTQuery
local l_oSQLData
local l_cAlias

local l_cEndOfLine    := CRLF

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
    AAdd(l_aErrors,{::p_cAnchorAlias,NIL,::p_ErrorMessage,hb_orm_GetApplicationStack()})
    ::Tally := -1
    
else
    if len(::p_aSQLCTQueries) > 0
        l_cSQLCommand := "WITH "
        for each l_cSQLCTQuery in ::p_aSQLCTQueries
            if l_cSQLCTQuery:__enumindex > 1
                l_cSQLCommand += ", "
            endif

            l_cSQLCommand += ::p_oSQLConnection:FormatIdentifier(l_cSQLCTQuery)+" AS ("+l_cEndOfLine
            l_cSQLCommand += "~"+lower(l_cSQLCTQuery)+"~"
            l_cSQLCommand += [)]
        endfor
        l_cSQLCommand += l_cEndOfLine
    else
        l_cSQLCommand := ""
    endif

    l_cSQLCommand += "~"+lower(::p_cAnchorAlias)+"~"

    l_aCombineQuery := AClone(::p_aCombineQuery)
    l_lFoundAQueryReference := .t.

    do while l_lFoundAQueryReference .and. len(l_aCombineQuery) > 0
        l_lFoundAQueryReference := .f.
        for each l_aCombine in l_aCombineQuery
            if "~"+lower(l_aCombine[2])+"~" $ l_cSQLCommand
                l_lFoundAQueryReference := .t.
                l_nReplaceCounter++

                do case
                case l_aCombine[1] == COMBINE_ACTION_UNION
                    l_cSubstituteString := "~"+lower(l_aCombine[4])+"~ "+"UNION "    +iif(l_aCombine[3],"ALL ","")+l_cEndOfLine+"~"+lower(l_aCombine[5])+"~"
                case l_aCombine[1] == COMBINE_ACTION_EXCEPT
                    l_cSubstituteString := "~"+lower(l_aCombine[4])+"~ "+"EXCEPT "   +iif(l_aCombine[3],"ALL ","")+l_cEndOfLine+"~"+lower(l_aCombine[5])+"~"
                case l_aCombine[1] == COMBINE_ACTION_INTERSECT
                    l_cSubstituteString := "~"+lower(l_aCombine[4])+"~ "+"INTERSECT "+iif(l_aCombine[3],"ALL ","")+l_cEndOfLine+"~"+lower(l_aCombine[5])+"~"
                otherwise
                    l_cSubstituteString := ""
                endcase

                if l_nReplaceCounter > 1
                    l_cSQLCommand := strtran(l_cSQLCommand,"~"+lower(l_aCombine[2])+"~","("+l_cEndOfLine+l_cSubstituteString+")")
                else
                    l_cSQLCommand := strtran(l_cSQLCommand,"~"+lower(l_aCombine[2])+"~",l_cSubstituteString)
                endif

                hb_Adel(l_aCombineQuery,l_aCombine:__enumindex,.t.)

                loop
            endif
        endfor
    enddo

    //Replace the alias references with the actual query
    for each l_oSQLData in ::p_hSQLDataQueries
        l_cAlias := lower(l_oSQLData:__enumkey)

        if hb_HGetDef(::p_hAliasWithoutOrderBy,l_cAlias,.f.)
            l_cSQLCommand := strtran(l_cSQLCommand,"~"+l_cAlias+"~",l_oSQLData:BuildSQL("Fetch KeepLeadingSpaces NoOrderBy"))
        else
            l_cSQLCommand := strtran(l_cSQLCommand,"~"+l_cAlias+"~",l_oSQLData:BuildSQL("Fetch KeepLeadingSpaces"))
        endif
    endfor

    ::p_LastSQLCommand := l_cSQLCommand

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
        l_lSQLResult := ::p_oSQLConnection:SQLExec(l_cSQLCommand,l_cCursorTempName)
        l_nTimeEnd := seconds()
        ::p_LastRunTime := l_nTimeEnd-l_nTimeStart+0.0000
        
        if !l_lSQLResult
            AAdd(l_aErrors,{::p_cAnchorAlias,NIL,"Failed SQLExec. Error Text="+::p_oSQLConnection:GetSQLExecErrorMessage(),hb_orm_GetApplicationStack()})
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
            ::Tally        := (l_cCursorTempName)->(reccount())
        endif
        CloseAlias(l_cCursorTempName)
        
    case l_nOutputType == 0 // none
        l_cCursorTempName := "c_DB_Temp"
        
        l_nTimeStart := seconds()
        l_lSQLResult := ::p_oSQLConnection:SQLExec(l_cSQLCommand,l_cCursorTempName)
        l_nTimeEnd := seconds()
        ::p_LastRunTime := l_nTimeEnd-l_nTimeStart+0.0000
        
        if !l_lSQLResult
            AAdd(l_aErrors,{::p_cAnchorAlias,NIL,"Failed SQLExec. Error Text="+::p_oSQLConnection:GetSQLExecErrorMessage(),hb_orm_GetApplicationStack()})
        else
            //  _M_
            // if (l_nTimeEnd - l_nTimeStart + 0.0000 >= ::p_MaxTimeForSlowWarning)
                // ::SQLSendPerformanceIssueToMonitoringSystem(::p_EventId,2,::p_MaxTimeForSlowWarning,l_nTimeStart,l_nTimeEnd,l_SQLPerformanceInfo,l_cSQLCommand)
            // endif
            
            l_lErrorOccurred := .f.
            ::Tally        := (l_cCursorTempName)->(reccount())
            
        endif
        CloseAlias(l_cCursorTempName)
        
    case l_nOutputType == 1 // cursor
        
        l_nTimeStart := seconds()
        l_lSQLResult := ::p_oSQLConnection:SQLExec(l_cSQLCommand,::p_CursorName)
        l_nTimeEnd := seconds()
        ::p_LastRunTime := l_nTimeEnd-l_nTimeStart+0.0000
        
        if !l_lSQLResult
            AAdd(l_aErrors,{::p_cAnchorAlias,NIL,"Failed SQLExec. Error Text="+::p_oSQLConnection:GetSQLExecErrorMessage(),hb_orm_GetApplicationStack()})
        else
            select (::p_CursorName)
            //_M_
            // if (l_nTimeEnd - l_nTimeStart + 0.0000 >= ::p_MaxTimeForSlowWarning)
                // ::SQLSendPerformanceIssueToMonitoringSystem(::p_EventId,2,::p_MaxTimeForSlowWarning,l_nTimeStart,l_nTimeEnd,l_SQLPerformanceInfo,l_cSQLCommand)
            // endif
            
            l_lErrorOccurred := .f.
            ::Tally        := (::p_CursorName)->(reccount())
            
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
        l_lSQLResult := ::p_oSQLConnection:SQLExec(l_cSQLCommand,l_cCursorTempName)
        l_nTimeEnd := seconds()
        ::p_LastRunTime := l_nTimeEnd-l_nTimeStart+0.0000
        
        if !l_lSQLResult
            AAdd(l_aErrors,{::p_cAnchorAlias,NIL,"Failed SQLExec. Error Text="+::p_oSQLConnection:GetSQLExecErrorMessage(),hb_orm_GetApplicationStack()})
        else
            // if (l_nTimeEnd - l_nTimeStart + 0.0000 >= ::p_MaxTimeForSlowWarning)
            // 	// ::SQLSendPerformanceIssueToMonitoringSystem(::p_EventId,2,::p_MaxTimeForSlowWarning,l_nTimeStart,l_nTimeEnd,l_SQLPerformanceInfo,l_cSQLCommand)
            // endif
            
            l_lErrorOccurred := .f.
            ::Tally        := (l_cCursorTempName)->(reccount())
            
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
        l_lSQLResult = ::p_oSQLConnection:SQLExec(l_cSQLCommand,l_cCursorTempName)
        l_nTimeEnd = seconds()
        ::p_LastRunTime := l_nTimeEnd-l_nTimeStart+0.0000
        
        if !l_lSQLResult
            AAdd(l_aErrors,{::p_cAnchorAlias,NIL,"Failed SQLExec. Error Text="+::p_oSQLConnection:GetSQLExecErrorMessage(),hb_orm_GetApplicationStack()})
        else
            select (l_cCursorTempName)

            // if (l_nTimeEnd - l_nTimeStart + 0.0000 >= ::p_MaxTimeForSlowWarning)
            // 	::SQLSendPerformanceIssueToMonitoringSystem(::p_EventId,2,::p_MaxTimeForSlowWarning,l_nTimeStart,l_nTimeEnd,l_SQLPerformanceInfo,l_cSQLCommand)
            // endif
            
            ::Tally          := reccount()
            l_lErrorOccurred   := .f.
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
                    AAdd(l_xResult,l_oRecord)

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
        
        // ::SQLSendToLogFileAndMonitoringSystem(::p_EventId,1,l_cSQLCommand+[ -> ]+::p_ErrorMessage)
        
    else
        if l_nOutputType == 1   //Into Cursor
            select (::p_CursorName)
        else
            select (l_nSelect)
        endif
        
        // ::SQLSendToLogFileAndMonitoringSystem(::p_EventId,0,l_cSQLCommand+[ -> Reccount = ]+trans(::Tally))
    endif
        
endif

if len(l_aErrors) > 0
    ::p_ErrorMessage := l_aErrors
    ::p_oSQLConnection:LogErrorEvent(::p_EventId,l_aErrors)
endif

return l_xResult
//-----------------------------------------------------------------------------------------------------------------
// method Count() class hb_orm_SQLCompoundQuery                                          // Similar to SQL() but will not get the list of Column() and return a numeric, the number or records found. Will return -1 in case of error.

// local l_cCursorTempName
// local l_nSelect := iif(used(),select(),0)
// local l_cSQLCommand
// local l_nTimeEnd
// local l_nTimeStart
// local l_lSQLResult
// local l_aErrors := {}

// ::Tally          := -1
// ::p_ErrorMessage := ""

// l_cSQLCommand := ::BuildSQL("Count")  //_M_ 

// l_cCursorTempName := "c_DB_Temp"

// l_nTimeStart := seconds()
// l_lSQLResult := ::p_oSQLConnection:SQLExec(l_cSQLCommand,l_cCursorTempName)
// l_nTimeEnd := seconds()
// ::p_LastRunTime := l_nTimeEnd-l_nTimeStart+0.0000

// if !l_lSQLResult
//     AAdd(l_aErrors,{::p_cAnchorAlias,NIL,[Failed SQLExec in :Count().],hb_orm_GetApplicationStack()})

// else
//     if (l_cCursorTempName)->(reccount()) == 1
//         ::Tally := (l_cCursorTempName)->(FieldGet(1))
//     else
//         AAdd(l_aErrors,{::p_cAnchorAlias,NIL,[Did not return a single row in :Count().],hb_orm_GetApplicationStack()})
//     endif
// endif
// CloseAlias(l_cCursorTempName)

// select (l_nSelect)

// if len(l_aErrors) > 0
//     ::p_ErrorMessage := l_aErrors
//     ::p_oSQLConnection:LogErrorEvent(::p_EventId,l_aErrors)
// endif

// return ::Tally
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
method AnchorAlias(par_xEventId,par_cAlias) class hb_orm_SQLCompoundQuery

if pcount() > 0
    ::SetEventId(par_xEventId)
    ::p_cAnchorAlias := par_cAlias

    hb_HClear(::p_hSQLDataQueries)
    hb_HClear(::p_hAliasWithoutOrderBy)
    asize(::p_aSQLCTQueries,0)
    asize(::p_aCombineQuery,0)
    
    ::Tally             := 0
    
    ::p_TableFullPath   := ""
    ::p_CursorName      := ""
    ::p_CursorUpdatable := .f.
    ::p_LastSQLCommand  := ""
    ::p_LastRunTime     := 0
    ::p_AddLeadingBlankRecord := .f.
    ::p_AddLeadingRecordsCursorName := ""
    
    ::p_MaxTimeForSlowWarning := 2.000  //  number of seconds
    
    ::p_ExplainMode := 0

endif

return nil
//-----------------------------------------------------------------------------------------------------------------
method AddSQLDataQuery(par_cAlias,par_oSQLData) class hb_orm_SQLCompoundQuery         // Add a hb_orm_sqldata to the list of queries to combine
::p_hSQLDataQueries[par_cAlias] := par_oSQLData
return nil
//-----------------------------------------------------------------------------------------------------------------
method AddSQLCTEQuery(par_cAlias,par_oSQLData) class hb_orm_SQLCompoundQuery          // Add a hb_orm_sqldata To be used as a Common Table in CTEs
AAdd(::p_aSQLCTQueries,par_cAlias)
::p_hSQLDataQueries[par_cAlias] := par_oSQLData
return nil
//-----------------------------------------------------------------------------------------------------------------
method CombineQueries(par_nCombineAction,par_cGeneratedAlias,par_lAll,par_cAlias1,par_cAlias2,...) class hb_orm_SQLCompoundQuery //par_nCombineAction can be one of COMBINE_ACTION_*
AAdd(::p_aCombineQuery,{par_nCombineAction,par_cGeneratedAlias,par_lAll,par_cAlias1,par_cAlias2,...})
::p_hAliasWithoutOrderBy[lower(par_cAlias1)] := .t.    //The OrderBy should only be used on the last alias in combined SQL
                                                       //_M_ to be enhanced if more than 2 par_cAlias
return nil
//-----------------------------------------------------------------------------------------------------------------
