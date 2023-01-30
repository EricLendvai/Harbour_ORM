//Copyright (c) 2023 Eric Lendvai MIT License

#include "hb_orm.ch"
#include "dbinfo.ch"   // for hb_orm_isnull

//=================================================================================================================
//Class Constructors
function hb_SQLConnect(par_cBackendType,par_cDriver,par_Server,par_nPort,par_cUser,par_cPassword,par_cDatabase,par_cSchema)
return hb_orm_SQLConnect():SetAllSettings(par_cBackendType,par_cDriver,par_Server,par_nPort,par_cUser,par_cPassword,par_cDatabase,par_cSchema)
//----------------------------------------
function hb_SQLData(par_oConnection)
local l_oResult

l_oResult := hb_orm_SQLData():Init()   //Trick to ensure call a class construtor
if ValType(par_oConnection) == "O"
    l_oResult:UseConnection(par_oConnection)
endif
return l_oResult
//----------------------------------------
function hb_Cursor()
return hb_orm_Cursor():Init()   //Trick to ensure call a class construtor
//=================================================================================================================
class hb_orm_Data
    data  p_FieldValues init {=>}      // Named with leading "p_" since used internally
    method AddField(par_cName,par_xValue)
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
method AddField(par_cName,par_xValue) class hb_orm_Data
::p_FieldValues[par_cName] := par_xValue
return NIL



//=================================================================================================================
function hb_orm_PostgresqlEncodeUTF8String(par_cString,par_cAdditionalCharactersToEscape)
//https://www.postgresql.org/docs/current/sql-syntax-lexical.html    4.1.2.2. String Constants with C-Style Escapes

local l_cEncodedText
local l_cUTFEncoding
local l_nPos
local l_nUTF8Value := 0
local l_nNumberOfBytesOfTheCharacter := 0
local l_cAdditionalCharactersToEscape := hb_DefaultValue(par_cAdditionalCharactersToEscape,"")

if empty(par_cString)
    l_cEncodedText := []
else
    l_cEncodedText := [E']

    l_nPos := 1
    do while (l_nPos <= len(par_cString)) 
        if hb_UTF8FastPeek(par_cString,l_nPos,@l_nUTF8Value,@l_nNumberOfBytesOfTheCharacter)
            if l_nNumberOfBytesOfTheCharacter > 0  // UTF Character
                l_nPos += l_nNumberOfBytesOfTheCharacter
            else
                l_nPos++
            endif

            // 92 = \, 39 = ', 34 = ", 63 = ?

            if l_nUTF8Value < 31 .or. l_nUTF8Value > 126 .or. l_nUTF8Value == 92 .or. l_nUTF8Value == 39 .or. l_nUTF8Value == 34 .or. l_nUTF8Value == 63 ;
               .or. (l_nUTF8Value < 127 .and. !empty(l_cAdditionalCharactersToEscape) .and. (chr(l_nUTF8Value) $ l_cAdditionalCharactersToEscape))
                l_cUTFEncoding := hb_NumToHex(l_nUTF8Value,8)
                do case
                case l_cUTFEncoding == [00000000]
                    //To clean up bad data
                    exit
                case left(l_cUTFEncoding,4) == [0000]
                    l_cEncodedText += [\u]+right(l_cUTFEncoding,4)
                otherwise
                    l_cEncodedText += [\U]+l_cUTFEncoding
                endcase
            else
                l_cEncodedText += chr(l_nUTF8Value)
            endif

        else
            //Skip the bad character
            l_nPos++
        endif
    enddo
    l_cEncodedText += [']

endif

return l_cEncodedText
//=================================================================================================================
// function hb_orm_PostgresqlEncodeUTF8String_ToSlow(par_cString)
// //https://www.postgresql.org/docs/current/sql-syntax-lexical.html    4.1.2.2. String Constants with C-Style Escapes
// local l_cResult := ""
// local l_nPos
// local l_nChar
// local l_cUTFEncoding


// local l_cInputString := par_cString
// local l_nInputStringLength := hb_utf8Len(par_cString)
// local l_nSliceSize := 1000  // the value seems to be a good balance for speed.
// local l_nNumberOfSegments  := ceiling(l_nInputStringLength/l_nSliceSize)
// local l_nSliceNumber
// local l_nCurrentSliceSize
// local l_cSlice

// // hb_orm_SendToDebugView("hb_orm_PostgresqlEncodeUTF8String begin "+trans(len(par_cString))+" "+par_cString)
// // hb_orm_SendToDebugView("New Version orm 3")

// if !empty(par_cString)

//     l_cResult += [E']

//     //Slowest Method
//     // for l_nPos := 1 to hb_utf8Len(par_cString)
//     //     l_nChar := hb_utf8Peek(par_cString,l_nPos)
//     //     if l_nChar < 31 .or. l_nChar > 126 .or. l_nChar == 92 .or. l_nChar == 39 .or. l_nChar == 34 .or. l_nChar == 63
//     //         l_cUTFEncoding := hb_NumToHex(l_nChar,8)
//     //         do case
//     //         case l_cUTFEncoding == [00000000]
//     //             //To clean up bad data
//     //             exit
//     //         case left(l_cUTFEncoding,4) == [0000]
//     //             l_cResult += [\u]+right(l_cUTFEncoding,4)
//     //         otherwise
//     //             l_cResult += [\U]+l_cUTFEncoding
//     //         endcase
//     //     else
//     //         l_cResult += chr(l_nChar)
//     //     endif
//     // endfor


//     //New logic to process slices ot string at a time. This will help speed performance due to the performance issue with hb_utf8Peek
//     for l_nSliceNumber := 1 to l_nNumberOfSegments
//         if l_nSliceNumber < l_nNumberOfSegments
//             l_cSlice            := hb_utf8Left(l_cInputString,l_nSliceSize)
//             l_cInputString      := hb_utf8SubStr(l_cInputString,l_nSliceSize+1)
//             l_nCurrentSliceSize := l_nSliceSize
//         else
//             l_cSlice            := l_cInputString
//             l_nCurrentSliceSize := hb_utf8Len(l_cSlice)
//         endif
        
//         for l_nPos := 1 to l_nCurrentSliceSize
//             l_nChar := hb_utf8Peek(l_cSlice,l_nPos)
//             if l_nChar < 31 .or. l_nChar > 126 .or. l_nChar == 92 .or. l_nChar == 39 .or. l_nChar == 34 .or. l_nChar == 63
//                 l_cUTFEncoding := hb_NumToHex(l_nChar,8)
//                 do case
//                 case l_cUTFEncoding == [00000000]
//                     //To clean up bad data
//                     exit
//                 case left(l_cUTFEncoding,4) == [0000]
//                     l_cResult += [\u]+right(l_cUTFEncoding,4)
//                 otherwise
//                     l_cResult += [\U]+l_cUTFEncoding
//                 endcase
//             else
//                 l_cResult += chr(l_nChar)
//             endif
//         endfor
//     endfor

//     l_cResult += [']

// endif

// // hb_orm_SendToDebugView("hb_orm_PostgresqlEncodeUTF8String end")
// //hb_orm_SendToDebugView("hb_orm_PostgresqlEncodeUTF8String "+par_cString+" = ",l_cResult)

// return l_cResult
//=================================================================================================================
function hb_orm_PostgresqlEncodeBinary(par_cString)
local l_cResult

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

    l_cValue := strtran(l_cValue,chr(13)+chr(10),[<br>])
    l_cValue := strtran(l_cValue,chr(10),[<br>])
    l_cValue := strtran(l_cValue,chr(13),[<br>])

    if empty(l_cValue)
        hb_orm_OutputDebugString("[Harbour] ORM "+par_cStep)
    else
        hb_orm_OutputDebugString("[Harbour] ORM "+par_cStep+" - "+l_cValue)
    endif
#endif

return .T.
//=================================================================================================================
function hb_orm_isnull(par_cAliasName,par_cFieldName)
local l_lResult := .f.
local l_xFieldValue
local l_nFieldCounter
local l_xFieldNilInfo

if ((select(par_cAliasName)>0)) //Alias is in use.
    l_nFieldCounter := (par_cAliasName)->(FieldPos(par_cFieldName))
    if l_nFieldCounter > 0
        l_xFieldValue   := (par_cAliasName)->(FieldGet(l_nFieldCounter))
        l_xFieldNilInfo := (par_cAliasName)->(DBFieldInfo( DBS_ISNULL, l_nFieldCounter ))
        l_lResult := ((!hb_IsNIL(l_xFieldNilInfo) .and. l_xFieldNilInfo) .or. hb_IsNIL(l_xFieldValue))   //Method to handle mem:tables and SQLMIX tables
    endif
endif

return l_lResult
//=================================================================================================================
function hb_orm_buildinfo()
#include "BuildInfo.txt"
return l_cBuildInfo
//=================================================================================================================
