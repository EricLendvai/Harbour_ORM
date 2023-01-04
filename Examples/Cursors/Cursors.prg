//Copyright (c) 2023 Eric Lendvai MIT License

#include "hbmemory.ch"

//#include "inkey.ch"     // not needed since not using function inkey()

#include "hb_orm.ch"
#include "hb_vfp.ch"

//REQUEST HB_CODEPAGE_UTF8EX  // not needed. The hb_orm already loads it.

//=================================================================================================================
Function Main()

local l_oCursor1
local l_nLoop
local l_iResult
local l_nMemoryFrom
local l_nMemoryTo
local l_MemoryOption := HB_MEM_USED
local l_tTimeStamp1,l_tTimeStamp2

hb_orm_SendToDebugView("[Harbour] Main")
?VFP_GetCompatibilityPackVersion()

 altd()
//?"------------------------------------------------------"

hb_cdpSelect("UTF8EX") 

//=====================================================================================
l_oCursor1 := hb_Cursor()
with object l_oCursor1
// Altd()
    :Field("KEY"                       ,"I",  4,0,"+")
    :Field("ID"                        ,"C", 10,0)
    :Field("FNAME"                     ,"C", 20,0,"T")
    :Field("LNAME"                     ,"C", 20,0)
    :Field("INFO"                      ,"C", 50,0,"BN")
    :Field("DOB"                       ,"D",  0,0,"N")
    :Field("Binary"                    ,"C", 50,0,"B")
    :Field("Long_field_name_extra_text","N",  5,2,"N")

    :CreateCursor("table007")
    ?":p_RecordCount = "+allt(Str(:p_RecordCount))

    select 0  // To prove the ORM handles not being on the created alias

    :AppendBlank()
    table007->DOB := ctod("01/01/2020")
    :SetFieldValue("dob",ctod("01/03/2020"))
    :SetFieldValue("fname","Roger")
    :SetFieldValue("lname","Moore")
    :SetFieldValue("info",replicate("?",100000))

    :AppendBlank()
    :SetFieldValues({"fname"=>"Maria","lname"=>"Smith"})

    l_iResult := :InsertRecord({"fname"=>"AHercules","lname"=>"Moore","dob"=>date(),"info"=>"hero"})
    if !hb_isNil(l_iResult)
        ?"New Key = "+trans(l_iResult)
    endif

    :InsertRecord({"fname"=>"John","lname"=>"Bonjovi"})
    ?":p_RecordCount = "+allt(Str(:p_RecordCount))
    
    :Index("upperfname","upper(fname)")
    :Index("upperlname","upper(lname)")
    :Index("upperlnameandfname","upper(lname+fname)")
    :CreateIndexes()
    

    :SetOrder("upperfname")
    ExportTableToHtmlFile("table007","Cursor_table007Records_fname","SQLMix",10,20,.t.)
    
    :SetOrder("upperlnameandfname")  //upperlname
    ExportTableToHtmlFile("table007","Cursor_table007Records_lname","SQLMix",10,20,.t.)

    //:Close()
    :RemoveField("Key")
    :RemoveField("id")
    :RemoveField("id")
    :RemoveField("bogus")
    :Field("KEY2"                       ,"I",  4,0,"+")
    :CreateCursor("table008")
    :AppendBlank()
    :InsertRecord({"fname"=>"Toni","lname"=>"Curtis","dob"=>date(),"info"=>"Hero"})
    :InsertRecord({"fname"=>"Albert","lname"=>"Einstein","dob"=>{^ 1879-03-14},"info"=>"Genius"})
    ExportTableToHtmlFile("table008","Cursor_table008Records","SQLMix",10,20,.t.)

    l_tTimeStamp1  := hb_DateTime()
    for l_nLoop :=1 to 1000    //000
        :AppendBlank()  // instead of using direct record function dbAppend()
    endfor
    l_tTimeStamp2  := hb_DateTime()

    ?"Reccount in alias "+alias()+" ="+trans(reccount())
    ?"Run Time in alias "+alias()+" = "+alltrim( str((l_tTimeStamp2-l_tTimeStamp1)*(24*3600*1000),10) )+" (ms)"
    ExportTableToHtmlFile("table008","Cursor_table008ExtraRecords","SQLMix With Extra Records",10,20,.t.)


endwith

//=====================================================================================

return nil
//=================================================================================================================
init procedure hello()
hb_orm_SendToDebugView("[Harbour] Init Procedure")
return
//=================================================================================================================
static function AppendData(par_ApplyNull)  // This function is no used but left as an example of non ORM data updates

local l_nLoop
local l_nMemoryFrom
local l_nMemoryTo
local l_MemoryOption := HB_MEM_USED //HB_MEM_USED
local l_tTimeStamp1,l_tTimeStamp2

l_nMemoryFrom := memory(l_MemoryOption)
l_tTimeStamp1  := hb_DateTime()

dbAppend()
field->fname  := "Eric"
field->lname  := "Lendvai"
field->info   := replicate('x',2)+'z'
if par_ApplyNull
    field->binary := NIL
endif

dbAppend()
field->fname  := "Hercules"
field->lname  := "Lendvai"
if par_ApplyNull
    field->dob    := NIL
endif

dbAppend()
field->fname  := "Oscar"
field->lname  := "Lendvai"
field->info   := "élève Français"

dbAppend()
if par_ApplyNull
    field->fname  := NIL
    field->lname  := NIL
    field->dob    := NIL
    field->info   := NIL
endif

for l_nLoop := 1 to 1000
    dbAppend()
    field->info := replicate('.',10)   // hb_RandStr(1000)
endfor

l_nMemoryTo   := memory(l_MemoryOption)

l_tTimeStamp2  := hb_DateTime()


hb_orm_SendToDebugView("[Harbour] "+alias()+" Memory Consumed = "+trans(l_nMemoryTo-l_nMemoryFrom))

?"Reccount in alias "+alias()+" ="+trans(reccount())
?"Run Time in alias "+alias()+" = "+alltrim( str((l_tTimeStamp2-l_tTimeStamp1)*(24*3600*1000),10) )+" (ms)"

return NIL
//=================================================================================================================
