//Copyright (c) 2024 Eric Lendvai MIT License

#include "hb_el.ch"
#include "hb_orm.ch"

#include "dbinfo.ch"

REQUEST HB_CODEPAGE_UTF8EX

REQUEST SQLMIX , SDDODBC

#define HB_ORM_CURSOR_STRUCTURE_POS      1
#define HB_ORM_CURSOR_STRUCTURE_TYPE     2
#define HB_ORM_CURSOR_STRUCTURE_LEN      3
#define HB_ORM_CURSOR_STRUCTURE_DEC      4
#define HB_ORM_CURSOR_STRUCTURE_NULL     5
#define HB_ORM_CURSOR_STRUCTURE_AUTOINC  6
#define HB_ORM_CURSOR_STRUCTURE_BINARY   7
#define HB_ORM_CURSOR_STRUCTURE_TRIM     8
#define HB_ORM_CURSOR_STRUCTURE_UNICODE  9
#define HB_ORM_CURSOR_STRUCTURE_COMPRESS 10

//=================================================================================================================
class hb_orm_Cursor
    hidden:
        data p_CursorName             init ""
        data p_Fields                 init {=>}   //Key is the FieldName, {cFieldType,nFieldLen,nFieldDec,lNullable,lIsAutoIncrement,lBinary,lTrimmed,lUnicode,lCompressed}
                                                  //Using flags for the extended attributes for performance reason mainly
        data p_AutoIncrementLastValue init 0      //If more than one field is marked as AutoIncrement, the value will be unique across all of them.
        data p_FieldsForAppend        init {}     //To make it faster during AppendBlank(), since only care to process certain fields
        data p_Indexes                init {=>}   //Key is the TagName, {cExpression,lUnique}
                                                  //      Future plans: {cExpression,lUnique,cDirection ("A"scending/"D"esending),cForExpression}

        method UpdateRecordCount()                //Will update :p_RecordCount
        //method CreateIndex( cTagName, cIndexExpression, lUnique, lDescend, cForExpression, cWhileExpression, lUseCurrent, lAdditive, cBagName )  Due to bug in SQLMix related to ordCondSet(), will not use this method
        
    exported:
        method Init()
        method GetName()                inline ::p_CursorName

        method Field(par_cName,par_cType,par_nLength,par_nDecimal,par_cFlags)                 //Add or update a field definition. Should be used before calling :CreateCursor()
                                                                                              //Flags can be "N" for Nullable,"+" for IsAutoIncrement,"B" for Binary,"T" for Trimmed,"U" for Unicode, "Z" or "C" for Compressed. Will not support "Encrypted" since in memory.
        method RemoveField(par_cName)                                                         //Remove a field definition. To be used before calling :CreateCursor()
        method CreateCursor(par_cName)
        
        method Index(par_cName,par_cExpression,par_lUnique)                                   //Add or update an index definition. Should be used before calling :CreateIndexes()
        //  Future  (par_cName,par_cExpression,par_cDirection,par_lUnique,par_ForExpression)  //Currently SQLMix does not seems to support ordCondSet()

        method RemoveIndex(par_cName)                                                     //Remove a index definition. To be used before calling :CreateIndexes()
        method CreateIndexes()                                                            //Create the index tags after the :Index() were called
        method SetOrder(par_cName)                                                        //Set the Tax(index) on the cursor
        
        method AppendBlank()                                                              //Add a blank record and respect autoincrement and Set Null Values
        method SetFieldValue(par_cFieldName,par_xValue)
        method SetFieldValues(par_hFieldValues)
        method GetFieldValue(par_cFieldName)
        method InsertRecord(par_hFieldValues)                                             //Returns 0 or the last AutoIncrement value
        // method Insert()                                                                //Add an complete record with all the values. Return the last AutoIncrement Value if at least one field was used.
        method Close()                                                                    //Close the Cursor and removes all field definitions
        method Zap()                                                                      //Remove All the records, while maintaining the structure and indexes
        data p_RecordCount init 0 READONLY                                                //Places as a public Attribute

        method Associate(par_cCursorName)                                                 //Called by hb_orm_sqldata when the result is a cursor

    DESTRUCTOR destroy()
endclass
//-----------------------------------------------------------------------------------------------------------------
method destroy() class hb_orm_Cursor
::Close()
return .t.
//-----------------------------------------------------------------------------------------------------------------
method Init() class hb_orm_Cursor
hb_HCaseMatch(::p_Fields ,.f.)
hb_HCaseMatch(::p_Indexes,.f.)
return Self
//-----------------------------------------------------------------------------------------------------------------
method Close() class hb_orm_Cursor

CloseAlias(::p_CursorName)
::p_CursorName  := ""
::p_RecordCount := 0
hb_HClear(::p_Fields)
ASize(::p_FieldsForAppend,0)
hb_HClear(::p_Indexes)

return NIL
//-----------------------------------------------------------------------------------------------------------------
method Field(par_cName,par_cType,par_nLength,par_nDecimal,par_cFlags) class hb_orm_Cursor    //Add a field definition
local l_lNullable,l_lIsAutoIncrement,l_lBinary,l_lTrimmed,l_lUnicode,l_lCompressed
local l_cFlags := upper(hb_DefaultValue(par_cFlags,""))

l_lNullable        := ("N" $ l_cFlags)
l_lIsAutoIncrement := ("+" $ l_cFlags)
l_lBinary          := ("B" $ l_cFlags)
l_lTrimmed         := ("T" $ l_cFlags) .and. (par_cType $ "C" .or. par_cType $ "CV")
l_lUnicode         := ("U" $ l_cFlags)
l_lCompressed      := (("Z" $ l_cFlags) .or. ("C" $ l_cFlags))

::p_Fields[par_cName] := {0,par_cType,par_nLength,par_nDecimal,l_lNullable,l_lIsAutoIncrement,l_lBinary,l_lTrimmed,l_lUnicode,l_lCompressed}

return NIL
//-----------------------------------------------------------------------------------------------------------------
method RemoveField(par_cName) class hb_orm_Cursor
hb_hDel(::p_Fields,par_cName)
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetOrder(par_cName) class hb_orm_Cursor
//_M_ extra test to see if cursor and index exists
(::p_CursorName)->(ordSetFocus(par_cName))
return NIL
//-----------------------------------------------------------------------------------------------------------------
method CreateCursor(par_cName) class hb_orm_Cursor
local l_aStructure := {}
local l_hFieldDefinition
local l_cFieldType
local l_cFieldFlags
local l_cFieldName
local l_nFieldPos := 0

if !empty(::p_CursorName)
    CloseAlias(::p_CursorName)
    ::p_CursorName  := ""
    ::p_RecordCount := 0
    // hb_HClear(::p_Fields) Do not remove the field definitions since we may have just defined them
    ASize(::p_FieldsForAppend,0)
endif

CloseAlias(par_cName)

::p_CursorName             := par_cName
::p_RecordCount            := 0
::p_AutoIncrementLastValue := 0

//Will create an array that is compatible with DbCreate()
for each l_hFieldDefinition in ::p_Fields
    l_cFieldName := l_hFieldDefinition:__enumKey()
    
    ::p_Fields[l_cFieldName][HB_ORM_CURSOR_STRUCTURE_POS] := ++l_nFieldPos

    l_cFieldFlags := iif(l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_NULL]   ,"N","") +;
                    iif(l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_AUTOINC] ,"+","") +;
                    iif(l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_BINARY]  ,"B","") +;
                    iif(l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_UNICODE] ,"U","") +;
                    iif(l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_COMPRESS],"Z","")

    if empty(l_cFieldFlags)
        l_cFieldType  := l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_TYPE]
    else
        l_cFieldType  := l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_TYPE]+":"+l_cFieldFlags
        // AAdd(::p_FieldsForAppend,hb_HClone(l_hFieldDefinition:__enumValue()))   //Have to clone, since otherwise passed by reference
    endif

    if l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_AUTOINC] .or. ;
       l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_NULL] .or. ;
       l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_BINARY] .or. ;
       l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_TRIM]
           
        AAdd(::p_FieldsForAppend,{l_hFieldDefinition[1],;
                                  l_hFieldDefinition[2],;
                                  l_hFieldDefinition[3],;
                                  l_hFieldDefinition[4],;
                                  l_hFieldDefinition[5],;
                                  l_hFieldDefinition[6],;
                                  l_hFieldDefinition[7],;
                                  l_hFieldDefinition[8],;
                                  l_hFieldDefinition[9],;
                                  l_hFieldDefinition[10];
                                  })
    endif

    //Following "do case" will not work yet since timestamp field types not supported in SQLMIX
    // do case
    // case el_IsInlist(l_cFieldType,"DT","DTZ","T")
    //     l_cFieldType := "@"
    //     l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_LEN] := 0
    //     l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_DEC] := 0
    // case el_IsInlist(l_cFieldType,"TOZ","TO")
    //     l_cFieldType := "T"
    //     l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_LEN] := 0
    //     l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_DEC] := 0
    // endcase


    //As of 2024-03-19  DateTime field types don't work

    //SQL MIX does not support all the following field types.
    //    ; Current field type mappings are:
    //        C; Character,n     HB_FT_STRING,n                      ADS_STRING
    //        N; Numeric,n,d     HB_FT_LONG,n,d                      ADS_NUMERIC
    //        D; Date,n          HB_FT_DATE,3 or 4 or 8              ADS_COMPACTDATE; ADS_DATE
    //        ShortDate          HB_FT_DATE,3                        ADS_COMPACTDATE
    //        L; Logical         HB_FT_LOGICAL,1                     ADS_LOGICAL
    //        M; Memo,n          HB_FT_MEMO,4 or 9 or 8              ADS_MEMO
    //        B; Double,,d       HB_FT_DOUBLE,8,d                    ADS_DOUBLE
    //        I; Integer,n       HB_FT_INTEGER, 2 or 4 or 8          ADS_SHORTINT; ADS_INTEGER; ADS_LONGLONG
    //        ShortInt           HB_FT_INTEGER,2                     ADS_SHORTINT
    //        Longlong           HB_FT_INTEGER,8                     ADS_LONGLONG
    //        P; Image           HB_FT_IMAGE,9 or 10                 ADS_IMAGE
    //        W; Binary          HB_FT_BLOB,4 or 9 or 10             ADS_BINARY
    //        Y; Money           HB_FT_CURRENCY,8,4                  ADS_MONEY
    //        Z; CurDouble,,d    HB_FT_CURDOUBLE,8,d                 ADS_CURDOUBLE
    //        T,4; Time          HB_FT_TIME,4                        ADS_TIME
    //        @; T,8; TimeStamp  HB_FT_TIMESTAMP,8                   ADS_TIMESTAMP
    //        +; AutoInc         HB_FT_AUTOINC,4                     ADS_AUTOINC
    //        ^; RowVersion      HB_FT_ROWVER,8                      ADS_ROWVERSION
    //        =; ModTime         HB_FT_MODTIME,8                     ADS_MODTIME
    //        Raw,n              HB_FT_STRING,n (+HB_FF_BINARY)      ADS_RAW
    //        Q; VarChar,n       HB_FT_VARLENGTH,n                   ADS_VARCHAR; ADS_VARCHAR_FOX
    //        VarBinary,n        HB_FT_VARLENGTH,n (+HB_FF_BINARY)   ADS_VARBINARY_FOX; ADS_RAW
    //        CICharacter,n      HB_FT_STRING,n                      ADS_CISTRING

    // /* Field types */
    // #define HB_FT_NONE            0
    // #define HB_FT_STRING          1     /* "C" */
    // #define HB_FT_LOGICAL         2     /* "L" */
    // #define HB_FT_DATE            3     /* "D" */
    // #define HB_FT_LONG            4     /* "N" */
    // #define HB_FT_FLOAT           5     /* "F" */
    // #define HB_FT_INTEGER         6     /* "I" */
    // #define HB_FT_DOUBLE          7     /* "B" */
    // #define HB_FT_TIME            8     /* "T" */
    // #define HB_FT_TIMESTAMP       9     /* "@" */
    // #define HB_FT_MODTIME         10    /* "=" */
    // #define HB_FT_ROWVER          11    /* "^" */
    // #define HB_FT_AUTOINC         12    /* "+" */
    // #define HB_FT_CURRENCY        13    /* "Y" */
    // #define HB_FT_CURDOUBLE       14    /* "Z" */
    // #define HB_FT_VARLENGTH       15    /* "Q" */
    // #define HB_FT_MEMO            16    /* "M" */
    // #define HB_FT_ANY             17    /* "V" */
    // #define HB_FT_IMAGE           18    /* "P" */
    // #define HB_FT_BLOB            19    /* "W" */
    // #define HB_FT_OLE             20    /* "G" */

    AAdd(l_aStructure,{l_cFieldName,l_cFieldType,l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_LEN],l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_DEC]})
    
endfor

DbCreate(::p_CursorName,l_aStructure,'SQLMIX',.T.,::p_CursorName,,"UTF8EX")

return NIL
//-----------------------------------------------------------------------------------------------------------------
//method Index(par_cName,par_cExpression,par_cDirection,par_lUnique,par_ForExpression) class hb_orm_Cursor
// ::p_Indexes[par_cName] := {par_cExpression,;
//                           iif(hb_IsNil(par_lUnique),.f.,par_lUnique),;
//                           iif(hb_IsNil(par_cDirection),"A",upper(left(par_cDirection,1))),;
//                           iif(hb_IsNil(par_ForExpression),.f.,par_ForExpression)}

method Index(par_cName,par_cExpression,par_lUnique) class hb_orm_Cursor
::p_Indexes[par_cName] := {par_cExpression,iif(hb_IsNil(par_lUnique),.f.,par_lUnique)}
return NIL
//-----------------------------------------------------------------------------------------------------------------
method RemoveIndex(par_cName) class hb_orm_Cursor
hb_hDel(::p_Indexes,par_cName)
return NIL
//-----------------------------------------------------------------------------------------------------------------
method CreateIndexes() class hb_orm_Cursor
local l_nSelect := iif(used(),select(),0)
local l_cTagName
local l_aIndexStructure

if !empty(::p_CursorName)
    select (::p_CursorName)
    for each l_aIndexStructure in ::p_Indexes
        l_cTagName := l_aIndexStructure:__enumKey()
        //Currently {par_cExpression 1,par_lUnique 2}
        //OrdCreate( cBagName, cTagName, cIndexExpression, /* bIndexExpression */, lUnique )
        OrdCreate( ::p_CursorName, l_cTagName, l_aIndexStructure[1], /* bIndexExpression */, l_aIndexStructure[2] )
        //Idea: To support Descending and other filters, could create an extra physical column that would hold and integer like 999999-<x> where <x> is created while traversing the records the ascending way, then indexing on that column.
        //      The problem is that system could not work for added/updated records.
    endfor
    select (l_nSelect)
endif
return NIL
//-----------------------------------------------------------------------------------------------------------------
method AppendBlank() class hb_orm_Cursor
local l_nSelect := iif(used(),select(),0)
local l_hFieldDefinition

if !empty(::p_CursorName)
    select (::p_CursorName)
    dbAppend()
    ::p_RecordCount++

    for each l_hFieldDefinition in ::p_FieldsForAppend
        do case
        case l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_AUTOINC]
            FieldPut(l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_POS],++::p_AutoIncrementLastValue)
        case l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_NULL]
            FieldPutNullable(l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_POS],NIL)
        case l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_BINARY]
            FieldPutNullable(l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_POS],'')
        case l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_TRIM]
            FieldPutNullable(l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_POS],'')
        endcase
    endfor
    select (l_nSelect)
endif
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetFieldValue(par_cFieldName,par_xValue) class hb_orm_Cursor
local l_nSelect := iif(used(),select(),0)
local l_nFieldPos
local l_hFieldDefinition
local l_nValueLen

if !empty(::p_CursorName)
    select (::p_CursorName)
    l_nFieldPos := FieldPos(par_cFieldName)
    if l_nFieldPos > 0
        l_hFieldDefinition := ::p_Fields[par_cFieldName]
        if !l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_AUTOINC]        //Prevent Overwritting AutoIncrement Field
            if par_xValue == NIL
                if l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_NULL]    //Ensure the field is nullable
                    FieldPutNullable(l_nFieldPos,NIL)
                endif
            else
                switch l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_TYPE]
                case "C"
                    //_M_ Test if par_xValue is of matching Type

                    l_nValueLen := len(par_xValue)
                    if l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_TRIM]
                        //Field does not store trailing blanks
                        if l_nValueLen <= l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_LEN]
                            FieldPut(l_nFieldPos,par_xValue)   //Fits in the field
                        else
                            FieldPut(l_nFieldPos,Trim(left(par_xValue,l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_LEN])))   //Value has to be cut, than trimmed.
                        endif
                    else
                        //Field must have trailing blanks (classic DBF Character field)
                        do case
                        case l_nValueLen == l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_LEN]
                            FieldPut(l_nFieldPos,par_xValue)   //Exact match
                        case l_nValueLen < l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_LEN]
                            FieldPut(l_nFieldPos,padr(par_xValue,l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_LEN]))   //Add missing blanks possibly
                        otherwise
                            FieldPut(l_nFieldPos,left(par_xValue,l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_LEN]))   //Value has to be cut
                        endcase
                    endif

                    exit
                otherwise
                    FieldPut(l_nFieldPos,par_xValue) 
                endswitch
            endif
        endif
    endif
    select (l_nSelect)
endif
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetFieldValues(par_hFieldValues) class hb_orm_Cursor
local l_xFieldValue

for each l_xFieldValue in par_hFieldValues
    ::SetFieldValue(l_xFieldValue:__enumKey,l_xFieldValue)
endfor
return NIL
//-----------------------------------------------------------------------------------------------------------------
method GetFieldValue(par_cFieldName) class hb_orm_Cursor
return iif(!empty(::p_CursorName),(::p_CursorName)->(FieldGet(FieldPos(par_cFieldName))),nil)
//-----------------------------------------------------------------------------------------------------------------
method InsertRecord(par_hFieldValues) class hb_orm_Cursor
local l_iCurrentAutoIncrementValue := ::p_AutoIncrementLastValue

//_M_ Later could optimize by not setting default values for field in par_hFieldValues, but getting this from a schema definition
::AppendBlank()
::SetFieldValues(par_hFieldValues)
return iif(l_iCurrentAutoIncrementValue == ::p_AutoIncrementLastValue,0,::p_AutoIncrementLastValue)
//-----------------------------------------------------------------------------------------------------------------
method Zap() class hb_orm_Cursor
local l_nSelect

if !empty(::p_CursorName)
    l_nSelect := iif(used(),select(),0)
    select (::p_CursorName)
    //Since Zap and Pack are not supported, simply have to recreate the cursor. Hopefully the user did not call RemoveField() before
    ::CreateCursor(::p_CursorName)
    ::CreateIndexes()
    select (l_nSelect)
endif
return NIL
//-----------------------------------------------------------------------------------------------------------------
method UpdateRecordCount() class hb_orm_Cursor                //Will update :p_RecordCount
::p_RecordCount := (::p_CursorName)->(reccount())
return NIL
//-----------------------------------------------------------------------------------------------------------------

/*
//Original code contributed by Luis Krause   BUT could not be used due to bug in ordCondSet() when against SQLMix cursor.
//Not all parameters will be used, since this is an in-memory table and index

method CreateIndex( cTagName, cIndexExpression, lUnique, lDescend, cForExpression, cWhileExpression, lUseCurrent, lAdditive, cBagName ) class hb_orm_Cursor

local bIndexExpression := if( empty( cIndexExpression ), nil                  , Compile( if( '"' $ cIndexExpression, "'", '"' ) + cIndexExpression + if( '"' $ cIndexExpression, "'", '"' ) ) )
local bForExpression   := if( empty( cForExpression ),   cForExpression := nil, Compile( if( '"' $ cForExpression, "'", '"' )   + cForExpression   + if( '"' $ cForExpression, "'", '"'   ) ) )
local bWhileExpression := if( empty( cWhileExpression ), nil                  , Compile( if( '"' $ cWhileExpression, "'", '"' ) + cWhileExpression + if( '"' $ cWhileExpression, "'", '"' ) ) )

default lUnique := .f., lDescend := .f., lAdditive := .f., lUseCurrent := .f.

//_M_ Similar but as in OrdCreate and the bIndexExpression for the other b...Expression

// OrdCondSet( cForExpression, bForExpression, bWhileExpression,,,,,,,, lDescend,, lAdditive, lUseCurrent,,,, )

//Note: Bug if using the bIndexExpression in SQLMix, must be NIL.

//OrdCreate( cBagName, cTagName, cIndexExpression, bIndexExpression , lUnique )
OrdCreate( cBagName, cTagName, cIndexExpression,, lUnique )

RETURN nil

//the Compile func is just to clean up the macro expansion of text to create the codeblock:
static function Compile( cExp )
return &( "{||" + cExp + "}" )
*/
//-----------------------------------------------------------------------------------------------------------------
method Associate(par_cCursorName) class hb_orm_Cursor
local l_nSelect := iif(used(),select(),0)
local l_nNumberOfFields
local l_nFieldCounter
local l_lNullable,l_lIsAutoIncrement,l_lBinary,l_lTrimmed,l_lUnicode,l_lCompressed
local l_nPos
local l_cFieldName
local l_cFieldType
local l_cFieldFlags
local l_hFieldDefinition

::p_CursorName  := par_cCursorName
::UpdateRecordCount()

hb_HClear(::p_Fields)
hb_HClear(::p_Indexes)
ASize(::p_FieldsForAppend,0)
::p_AutoIncrementLastValue := 0    //_M_ Not certain how to initialize this property

//Load the ListOfFields
select (par_cCursorName)
l_nNumberOfFields := FCount()
for l_nFieldCounter := 1 to l_nNumberOfFields
    l_cFieldName := FieldName(l_nFieldCounter)
    l_cFieldType := hb_FieldType(l_nFieldCounter)

    // hb_orm_SendToDebugView("Field Type",l_cFieldType)

    l_nPos := at(":",l_cFieldType)
    if empty(l_nPos)
        l_cFieldFlags := ""
    else
        l_cFieldFlags := substr(l_cFieldType,l_nPos+1)
        l_cFieldType  := left(l_cFieldType,l_nPos-1)
    endif

    l_lNullable        := ("N" $ l_cFieldFlags)
    l_lIsAutoIncrement := ("+" $ l_cFieldFlags)
    l_lBinary          := ("B" $ l_cFieldFlags)
    l_lTrimmed         := .t.    // Since this is a coming back from SQL backend, Usually trims Character Fields
    l_lUnicode         := ("U" $ l_cFieldFlags)
    l_lCompressed      := (("Z" $ l_cFieldFlags) .or. ("C" $ l_cFieldFlags))

    l_hFieldDefinition := {l_nFieldCounter,l_cFieldType,hb_FieldLen(l_nFieldCounter),hb_FieldDec(l_nFieldCounter),l_lNullable,l_lIsAutoIncrement,l_lBinary,l_lTrimmed,l_lUnicode,l_lCompressed}

    if l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_AUTOINC] .or. ;
       l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_NULL] .or. ;
       l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_BINARY] .or. ;
       l_hFieldDefinition[HB_ORM_CURSOR_STRUCTURE_TRIM]
           
        AAdd(::p_FieldsForAppend,{l_hFieldDefinition[1],;
                                  l_hFieldDefinition[2],;
                                  l_hFieldDefinition[3],;
                                  l_hFieldDefinition[4],;
                                  l_hFieldDefinition[5],;
                                  l_hFieldDefinition[6],;
                                  l_hFieldDefinition[7],;
                                  l_hFieldDefinition[8],;
                                  l_hFieldDefinition[9],;
                                  l_hFieldDefinition[10];
                                  })
    endif

    ::p_Fields[l_cFieldName] := l_hFieldDefinition

endfor

select (l_nSelect)
return Self
//-----------------------------------------------------------------------------------------------------------------
