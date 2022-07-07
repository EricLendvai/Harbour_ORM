//Copyright (c) 2022 Eric Lendvai MIT License

#include "hb_orm.ch"
#include "dbinfo.ch"   // for hb_orm_isnull

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
function hb_orm_PostgresqlEncodeUTFString(par_cString)
//https://www.postgresql.org/docs/current/sql-syntax-lexical.html    4.1.2.2. String Constants with C-Style Escapes
local l_cResult := ""
local l_nPos
local l_nChar
local l_cUTFEncoding
if !empty(par_cString)
    l_cResult += [E']
    for l_nPos := 1 to hb_utf8Len(par_cString)
        l_nChar := hb_utf8Peek(par_cString,l_nPos)
        if l_nChar < 31 .or. l_nChar > 126 .or. l_nChar == 92 .or. l_nChar == 39 .or. l_nChar == 34 .or. l_nChar == 63
            l_cUTFEncoding := hb_NumToHex(l_nChar,8)
            do case
            case l_cUTFEncoding == [00000000]
                //To clean up bad data
                exit
            case left(l_cUTFEncoding,4) == [0000]
                l_cResult += [\u]+right(l_cUTFEncoding,4)
            otherwise
                l_cResult += [\U]+l_cUTFEncoding
            endcase
        else
            l_cResult += chr(l_nChar)
        endif
    endfor
    l_cResult += [']
endif

//hb_orm_SendToDebugView("hb_orm_PostgresqlEncodeUTFString "+par_cString+" = ",l_cResult)

return l_cResult
//=================================================================================================================
function hb_orm_PostgresqlEncodeBinary(par_cString)
local l_cResult
local l_nPos
if empty(par_cString)
    l_cResult := ""
else
    l_cResult := [E'\x]+hb_StrToHex(par_cString,"\x")+[']
    //         l_cResult := [E']
    //         for l_nPos := 1 to hb_utf8Len(par_cString)
    //             l_cResult += [\U]+hb_NumToHex(hb_utf8Peek(par_cString,l_nPos),8) //,[<nHexDigits>])
    // //_M_ see if can remove first 4 leading zeros
    // //https://www.postgresql.org/docs/current/sql-syntax-lexical.html    4.1.2.2. String Constants with C-Style Escapes
    //         endfor
    //         l_cResult += [']
endif
return l_cResult
//=================================================================================================================
function hb_orm_TestDebugger()
// local icrash
// icrash++
// altd()
return NIL
//=================================================================================================================
function hb_orm_SendToDebugView(par_cStep,par_xValue)

#ifdef DEBUGVIEW
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
#endif

return .T.
//=================================================================================================================
function hb_orm_isnull(par_cAliasName,par_cFieldName)
local l_l_result := .f.
local l_FieldValue
local l_FieldCounter
local l_FieldNilInfo

if ((select(par_cAliasName)>0)) //Alias is in use.
    l_FieldCounter := (par_cAliasName)->(FieldPos(par_cFieldName))
    if l_FieldCounter > 0
        l_FieldValue   := (par_cAliasName)->(FieldGet(l_FieldCounter))
        l_FieldNilInfo := (par_cAliasName)->(DBFieldInfo( DBS_ISNULL, l_FieldCounter ))
        l_l_result := ((!hb_IsNIL(l_FieldNilInfo) .and. l_FieldNilInfo) .or. hb_IsNIL(l_FieldValue))   //Method to handle mem:tables and SQLMIX tables
    endif
endif

return l_l_result
//=================================================================================================================
function hb_orm_buildinfo()
#include "BuildInfo.txt"
return l_cBuildInfo
//=================================================================================================================
