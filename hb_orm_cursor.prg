//Copyright (c) 2021 Eric Lendvai MIT License

#include "hb_vfp.ch"
#include "hb_orm.ch"

#include "dbinfo.ch"

REQUEST HB_CODEPAGE_UTF8

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
        data p_Fields                 init {=>}   //Key is the FieldName, {cFieldType,nFieldLen,nFieldDec,lAllowNull,lIsAutoIncrement,lBinary,lTrimmed,lUnicode,lCompressed}
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

        method Field(par_cName,par_Type,par_Length,par_Decimal,par_Flags)                 //Add or update a field definition. Should be used before calling :CreateCursor()
                                                                                          //Flags can be "N" for AllowNul,"+" for IsAutoIncrement,"B" for Binary,"T" for Trimmed,"U" for Unicode, "Z" or "C" for Compressed. Will not support "Encrypted" since in memory.
        method RemoveField(par_cName)                                                     //Remove a field definition. To be used before calling :CreateCursor()
        method CreateCursor(par_cName)
        
        method Index(par_cName,par_Expression,par_Unique)                                 //Add or update an index definition. Should be used before calling :CreateIndexes()
        //  Future  (par_cName,par_Expression,par_Direction,par_Unique,par_ForExpression)  //Currently SQLMix does not seems to support ordCondSet()

        method RemoveIndex(par_cName)                                                     //Remove a index definition. To be used before calling :CreateIndexes()
        method CreateIndexes()                                                           //Create the index tags after the :Index() were called
        method SetOrder(par_cName)                                                        //Set the Tax(index) on the cursor
        
        method AppendBlank()                                                             //Add a blank record and respect autoincrement and Set Null Values
        method SetFieldValue(par_cFieldName,par_Value)
        method SetFieldValues(par_HashFieldValues)
        method GetFieldValue(par_cFieldName)
        method InsertRecord(par_HashFieldValues)                                         //Returns 0 or the last AutoIncrement value
        // method Insert()                                                               //Add an complete record with all the values. Return the last AutoIncrement Value if at least one field was used.
        method Close()                                                                   //Close the Cursor and removes all field definitions
        method Zap()                                                                     //Remove All the records, while maintaining the structure and indexes
        data p_RecordCount init 0 READONLY                                               //Places as a public Attribute

        method Associate(par_CursorName)                                                 //Called by hb_orm_sqldata when the result is a cursor

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
method Field(par_cName,par_Type,par_Length,par_Decimal,par_Flags) class hb_orm_Cursor    //Add a field definition
local l_AllowNull,l_IsAutoIncrement,l_Binary,l_Trimmed,l_Unicode,l_Compressed
local l_Flags := upper(hb_DefaultValue(par_flags,""))

l_AllowNull       := ("N" $ l_Flags)
l_IsAutoIncrement := ("+" $ l_Flags)
l_Binary          := ("B" $ l_Flags)
l_Trimmed         := ("T" $ l_Flags) .and. (par_Type $ "C" .or. par_Type $ "CV")
l_Unicode         := ("U" $ l_Flags)
l_Compressed      := (("Z" $ l_Flags) .or. ("C" $ l_Flags))

::p_Fields[par_cName] := {0,par_Type,par_Length,par_Decimal,l_AllowNull,l_IsAutoIncrement,l_Binary,l_Trimmed,l_Unicode,l_Compressed}

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
local l_Structure := {}
local l_FieldStructure
local l_FieldType
local l_FieldFlags
local l_FieldName
local l_FieldPos := 0

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
for each l_FieldStructure in ::p_Fields
    l_FieldName := l_FieldStructure:__enumKey()
    
    ::p_Fields[l_FieldName][HB_ORM_CURSOR_STRUCTURE_POS] := ++l_FieldPos

    l_FieldFlags := iif(l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_NULL]    ,"N","") +;
                    iif(l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_AUTOINC] ,"+","") +;
                    iif(l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_BINARY]  ,"B","") +;
                    iif(l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_UNICODE] ,"U","") +;
                    iif(l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_COMPRESS],"Z","")

    if empty(l_FieldFlags)
        l_FieldType  := l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_TYPE]
    else
        l_FieldType  := l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_TYPE]+":"+l_FieldFlags
        // AAdd(::p_FieldsForAppend,hb_HClone(l_FieldStructure:__enumValue()))   //Have to clone, since otherwise passed by reference
    endif
    if l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_AUTOINC] .or. ;
       l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_NULL] .or. ;
       l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_BINARY] .or. ;
       l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_TRIM]
           
        AAdd(::p_FieldsForAppend,{l_FieldStructure[1],;
                                  l_FieldStructure[2],;
                                  l_FieldStructure[3],;
                                  l_FieldStructure[4],;
                                  l_FieldStructure[5],;
                                  l_FieldStructure[6],;
                                  l_FieldStructure[7],;
                                  l_FieldStructure[8],;
                                  l_FieldStructure[9],;
                                  l_FieldStructure[10];
                                  })
    endif

    AAdd(l_Structure,{l_FieldName,l_FieldType,l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_LEN],l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_DEC]})
    
endfor

DbCreate(::p_CursorName,l_Structure,'SQLMIX',.T.,::p_CursorName,,"UTF8")

return NIL
//-----------------------------------------------------------------------------------------------------------------
//method Index(par_cName,par_Expression,par_Direction,par_Unique,par_ForExpression) class hb_orm_Cursor
// ::p_Indexes[par_cName] := {par_Expression,;
//                           iif(hb_IsNil(par_Unique),.f.,par_Unique),;
//                           iif(hb_IsNil(par_Direction),"A",upper(left(par_Direction,1))),;
//                           iif(hb_IsNil(par_ForExpression),.f.,par_ForExpression)}

method Index(par_cName,par_Expression,par_Unique) class hb_orm_Cursor
::p_Indexes[par_cName] := {par_Expression,iif(hb_IsNil(par_Unique),.f.,par_Unique)}
return NIL
//-----------------------------------------------------------------------------------------------------------------
method RemoveIndex(par_cName) class hb_orm_Cursor
hb_hDel(::p_Indexes,par_cName)
return NIL
//-----------------------------------------------------------------------------------------------------------------
method CreateIndexes() class hb_orm_Cursor
local l_TagName
local l_IndexStructure
//altd()
for each l_IndexStructure in ::p_Indexes
    l_TagName := l_IndexStructure:__enumKey()
    //Currently {par_Expression 1,par_Unique 2}
    //OrdCreate( cBagName, cTagName, cIndexExpression, /* bIndexExpression */, lUnique )
    OrdCreate( ::p_CursorName, l_TagName, l_IndexStructure[1], /* bIndexExpression */, l_IndexStructure[2] )
    //Idea: To support Descending and other filters, could create an extra physical column that would hold and integer like 999999-<x> where <x> is created while traversing the records the ascending way, then indexing on that column.
    //      The problem is that system could not work for added/updated records.
endfor
return NIL
//-----------------------------------------------------------------------------------------------------------------
method AppendBlank() class hb_orm_Cursor
local l_select := iif(used(),select(),0)
local l_FieldStructure
select (::p_CursorName)
dbAppend()
::p_RecordCount++

for each l_FieldStructure in ::p_FieldsForAppend
    do case
    case l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_AUTOINC]
        FieldPut(l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_POS],++::p_AutoIncrementLastValue)
    case l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_NULL]
        FieldPutAllowNull(l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_POS],NIL)
    case l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_BINARY]
        FieldPutAllowNull(l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_POS],'')
    case l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_TRIM]
        FieldPutAllowNull(l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_POS],'')
    endcase
endfor

select (l_select)
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetFieldValue(par_cFieldName,par_Value) class hb_orm_Cursor
local l_FieldPos := FieldPos(par_cFieldName)
local l_FieldStructure
local l_ValueLen
if l_FieldPos > 0
    l_FieldStructure := ::p_Fields[par_cFieldName]
    if !l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_AUTOINC]        //Prevent Overwritting AutoIncrement Field
        if par_Value == NIL
            if l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_NULL]   //Ensure the field is nullable
                FieldPutAllowNull(l_FieldPos,NIL)
            endif
        else
            switch l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_TYPE]
            case "C"
                //_M_ Test if par_Value is of matching Type

                l_ValueLen := len(par_Value)
                if l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_TRIM]
                    //Field does not store trailing blanks
                    if l_ValueLen <= l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_LEN]
                        FieldPut(l_FieldPos,par_Value)   //Fits in the field
                    else
                        FieldPut(l_FieldPos,Trim(left(par_Value,l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_LEN])))   //Value has to be cut, than trimmed.
                    endif
                else
                    //Field must have trailing blanks (classic DBF Character field)
                    do case
                    case l_ValueLen == l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_LEN]
                        FieldPut(l_FieldPos,par_Value)   //Exact match
                    case l_ValueLen < l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_LEN]
                        FieldPut(l_FieldPos,padr(par_Value,l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_LEN]))   //Add missing blanks possibly
                    otherwise
                        FieldPut(l_FieldPos,left(par_Value,l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_LEN]))   //Value has to be cut
                    endcase
                endif

                exit
            otherwise
                FieldPut(l_FieldPos,par_Value) 
            endswitch
        endif
    endif
endif
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetFieldValues(par_HashFieldValues) class hb_orm_Cursor
local l_FieldValue
for each l_FieldValue in par_HashFieldValues
    ::SetFieldValue(l_FieldValue:__enumKey,l_FieldValue)
endfor
return NIL
//-----------------------------------------------------------------------------------------------------------------
method GetFieldValue(par_cFieldName) class hb_orm_Cursor
return FieldGet(FieldPos(par_cFieldName))
//-----------------------------------------------------------------------------------------------------------------
method InsertRecord(par_HashFieldValues) class hb_orm_Cursor
local l_CurrentAutoIncrementValue := ::p_AutoIncrementLastValue
//_M_ Later could optimize by not setting default values for field in par_HashFieldValues, but getting this from a schema definition
::AppendBlank()
::SetFieldValues(par_HashFieldValues)
return iif(l_CurrentAutoIncrementValue == ::p_AutoIncrementLastValue,0,::p_AutoIncrementLastValue)
//-----------------------------------------------------------------------------------------------------------------
method Zap() class hb_orm_Cursor
local l_select
if !empty(::p_CursorName)
    l_select := iif(used(),select(),0)
    select (::p_CursorName)
    //Since Zap and Pack are not supported, simply have to recreate the cursor. Hopefully the user did not call RemoveField() before
    ::CreateCursor(::p_CursorName)
    ::CreateIndexes()
    select (l_select)
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

altd()
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
method Associate(par_CursorName) class hb_orm_Cursor
local l_select := iif(used(),select(),0)
local l_NumberOfFields
local l_FieldCounter
local l_AllowNull,l_IsAutoIncrement,l_Binary,l_Trimmed,l_Unicode,l_Compressed
local l_pos
local l_FieldName
local l_FieldType
local l_FieldFlags
local l_FieldStructure

::p_CursorName  := par_CursorName
::UpdateRecordCount()

hb_HClear(::p_Fields)
hb_HClear(::p_Indexes)
ASize(::p_FieldsForAppend,0)
::p_AutoIncrementLastValue := 0    //_M_ Not certain how to initialize this property

//Load the ListOfFields
select (par_CursorName)
l_NumberOfFields := FCount()
for l_FieldCounter := 1 to l_NumberOfFields
    l_FieldName := FieldName(l_FieldCounter)
    l_FieldType := hb_FieldType(l_FieldCounter)

    // hb_orm_SendToDebugView("Field Type",l_FieldType)

    l_pos := at(":",l_FieldType)
    if empty(l_pos)
        l_FieldFlags := ""
    else
        l_FieldFlags := substr(l_FieldType,l_pos+1)
        l_FieldType  := left(l_FieldType,l_pos-1)
    endif

    l_AllowNull       := ("N" $ l_FieldFlags)
    l_IsAutoIncrement := ("+" $ l_FieldFlags)
    l_Binary          := ("B" $ l_FieldFlags)
    l_Trimmed         := .t.    // Since this is a coming back from SQL backend, Usually trims Character Fields
    l_Unicode         := ("U" $ l_FieldFlags)
    l_Compressed      := (("Z" $ l_FieldFlags) .or. ("C" $ l_FieldFlags))

    l_FieldStructure := {l_FieldCounter,l_FieldType,hb_FieldLen(l_FieldCounter),hb_FieldDec(l_FieldCounter),l_AllowNull,l_IsAutoIncrement,l_Binary,l_Trimmed,l_Unicode,l_Compressed}

    if l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_AUTOINC] .or. ;
       l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_NULL] .or. ;
       l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_BINARY] .or. ;
       l_FieldStructure[HB_ORM_CURSOR_STRUCTURE_TRIM]
           
        AAdd(::p_FieldsForAppend,{l_FieldStructure[1],;
                                     l_FieldStructure[2],;
                                     l_FieldStructure[3],;
                                     l_FieldStructure[4],;
                                     l_FieldStructure[5],;
                                     l_FieldStructure[6],;
                                     l_FieldStructure[7],;
                                     l_FieldStructure[8],;
                                     l_FieldStructure[9],;
                                     l_FieldStructure[10];
                                     })
    endif

    ::p_Fields[l_FieldName] := l_FieldStructure

endfor

select (l_select)
return Self
//-----------------------------------------------------------------------------------------------------------------
