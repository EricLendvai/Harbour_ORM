//Copyright (c) 2021 Eric Lendvai MIT License

#include "hb_orm.ch"

//=================================================================================================================
//Class Constructors
function hb_SQLConnect(par_BackendType,par_Driver,par_Server,par_Port,par_User,par_Password,par_Database,par_Schema)
return hb_orm_SQLConnect():SetAllSettings(par_BackendType,par_Driver,par_Server,par_Port,par_User,par_Password,par_Database,par_Schema)
//----------------------------------------
function hb_SQLData(par_oConnection)
local l_o_result
l_o_result := hb_orm_SQLData():Init()   //Trick to ensure call a class construtor
if ValType(par_oConnection) == "O"
    l_o_result:UseConnection(par_oConnection)
endif
return l_o_result
//----------------------------------------
function hb_Cursor()
return hb_orm_Cursor():Init()   //Trick to ensure call a class construtor
//=================================================================================================================
class hb_orm_Data
    data  p_FieldValues init {=>}      // Named with leading "p_" since used internally
    method AddField(par_cName,par_Value)
    method ClearFields()
    error handler OnError( ... )
endclass
//-----------------------------------------------------------------------------------------------------------------
method OnError(...) class hb_orm_Data
local l_cMsg := __GetMessage()
return hb_hGetDef( ::p_FieldValues, l_cMsg, NIL )
//-----------------------------------------------------------------------------------------------------------------
method ClearFields() class hb_orm_Data
hb_HClear(::p_FieldValues)
return NIL
//-----------------------------------------------------------------------------------------------------------------
method AddField(par_cName,par_Value) class hb_orm_Data
::p_FieldValues[par_cName] := par_Value
return NIL

//=================================================================================================================
function hb_orm_TestDebugger()
// local icrash
// icrash++
// altd()
return NIL

//=================================================================================================================
function hb_orm_SendToDebugView(par_cStep,par_xValue)
local l_cTypeOfxValue
local l_cValue := "Unknown Value"

l_cTypeOfxValue := ValType(par_xValue)

do case
case pcount() < 2
    l_cValue := ""
case l_cTypeOfxValue $ "AH" // Array or Hash
    l_cValue := hb_ValToExp(par_xValue)
case l_cTypeOfxValue == "B" // Block
    //Not coded yet
case l_cTypeOfxValue == "C" // Character (string)
    l_cValue := par_xValue
    //Not coded yet
case l_cTypeOfxValue == "D" // Date
    l_cValue := DTOC(par_xValue)
case l_cTypeOfxValue == "L" // Logical
    l_cValue := IIF(par_xValue,"True","False")
case l_cTypeOfxValue == "M" // Memo
    //Not coded yet
case l_cTypeOfxValue == "N" // Numeric
    l_cValue := alltrim(str(par_xValue))
case l_cTypeOfxValue == "O" // Object
    //Not coded yet
case l_cTypeOfxValue == "P" // Pointer
    //Not coded yet
case l_cTypeOfxValue == "S" // Symbol
    //Not coded yet
case l_cTypeOfxValue == "U" // NIL
    l_cValue := "Null"
endcase

if empty(l_cValue)
    hb_orm_OutputDebugString("[Harbour] ORM "+par_cStep)
else
    hb_orm_OutputDebugString("[Harbour] ORM "+par_cStep+" - "+l_cValue)
endif
    
return .T.
//=================================================================================================================
function hb_orm_buildinfo()
#include "BuildInfo.txt"
return l_cBuildInfo
//=================================================================================================================
