//Copyright (c) 2020 Eric Lendvai MIT License

#include "hb_orm.ch"

//=================================================================================================================
//Class Constructors
function hb_SQLConnect(par_BackendType,par_Driver,par_Server,par_Port,par_User,par_Password,par_Database,par_Schema)
return hb_orm_SQLConnect():SetAllSettings(par_BackendType,par_Driver,par_Server,par_Port,par_User,par_Password,par_Database,par_Schema)
//----------------------------------------
function hb_SQLData()
return hb_orm_SQLData():Init()   //Trick to ensure call a class construtor
//----------------------------------------
function hb_Cursor()
return hb_orm_Cursor():Init()   //Trick to ensure call a class construtor
//=================================================================================================================
class hb_orm_Data
    data  p_FieldValues init {=>}
    method AddField(par_Name,par_Value)
    method ClearFields()
    error handler OnError( ... )
endclass
//-----------------------------------------------------------------------------------------------------------------
method OnError(...) class hb_orm_Data
// local aParams  := HB_AParams()
local cMsg := __GetMessage()
return hb_hGetDef( ::p_FieldValues, cMsg, NIL )
//-----------------------------------------------------------------------------------------------------------------
method ClearFields() class hb_orm_Data
hb_HClear(::p_FieldValues)
return NIL
//-----------------------------------------------------------------------------------------------------------------
method AddField(par_Name,par_Value) class hb_orm_Data
::p_FieldValues[par_Name] := par_Value
return NIL

//=================================================================================================================
function hb_orm_TestDebugger()
    // local icrash
    // icrash++
    // altd()
return NIL

//=================================================================================================================
function hb_orm_SendToDebugView(cStep,xValue)
    local cTypeOfxValue
    local cValue := "Unknown Value"
    
    cTypeOfxValue := ValType(xValue)
    
    do case
    case pcount() < 2
        cValue := ""
    case cTypeOfxValue $ "AH" // Array or Hash
        cValue := hb_ValToExp(xValue)
    case cTypeOfxValue == "B" // Block
        //Not coded yet
    case cTypeOfxValue == "C" // Character (string)
        cValue := xValue
        //Not coded yet
    case cTypeOfxValue == "D" // Date
        cValue := DTOC(xValue)
    case cTypeOfxValue == "L" // Logical
        cValue := IIF(xValue,"True","False")
    case cTypeOfxValue == "M" // Memo
        //Not coded yet
    case cTypeOfxValue == "N" // Numeric
        cValue := alltrim(str(xValue))
    case cTypeOfxValue == "O" // Object
        //Not coded yet
    case cTypeOfxValue == "P" // Pointer
        //Not coded yet
    case cTypeOfxValue == "S" // Symbol
        //Not coded yet
    case cTypeOfxValue == "U" // NIL
        cValue := "Null"
    endcase
    
    if empty(cValue)
        hb_orm_OutputDebugString("[Harbour] ORM "+cStep)
    else
        hb_orm_OutputDebugString("[Harbour] ORM "+cStep+" - "+cValue)
    endif
    
return .T.
//=================================================================================================================
