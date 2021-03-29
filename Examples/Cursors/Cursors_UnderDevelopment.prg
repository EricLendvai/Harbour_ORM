//Copyright (c) 2021 Eric Lendvai MIT License

#include "hbmemory.ch"
#include "inkey.ch"

#include "hb_orm.ch"
#include "hb_vfp.ch"

#include "dbinfo.ch"   // for the export to html file

//Needed for table004 and table005 example
REQUEST VFPCDX
REQUEST DBFCDX
REQUEST HB_MEMIO

REQUEST HB_CODEPAGE_UTF8

//=================================================================================================================
Function Main()

local oCursor1
local l_aStructure := {}
local l_RunStartTime
local l_loop
local l_result
local l_memory_from
local l_memory_to
local l_MemoryOption := HB_MEM_USED

hb_orm_SendToDebugView("[Harbour] Main")
?VFP_GetCompatibilityPackVersion()

//?"------------------------------------------------------"

hb_cdpSelect("UTF8") 

AAdd(l_aStructure,{"KEY","I:+",4,0})
AAdd(l_aStructure,{"FNAME","C",20,0})
AAdd(l_aStructure,{"LNAME","C",20,0})
AAdd(l_aStructure,{"INFO","C:N",100,0})
AAdd(l_aStructure,{"DOB","D:N",0,0})
AAdd(l_aStructure,{"Binary","C:BN",50,0})
AAdd(l_aStructure,{"Long_field_name_extra_text","N:N",5,2})

//=====================================================================================

// ?"Before table004. Press Enter"
// do while inkey(0) <> K_ENTER
// enddo
// ?"Pressed Enter"
// DbCreate("mem:table004.dbf",l_aStructure,'DBFCDX',.T.,"table004",,"UTF8")
// select table004
// AppendData(.f.)
// ?"After table004"
// ExportTableToHtmlFile("table004","Cursor_Table004Records","mem dbf",10,10,.t.)
// ?"After table004. Press Enter"
// do while inkey(0) <> K_ENTER
// enddo
// ?"Pressed Enter"

//=====================================================================================

// DbCreate("mem:table005.dbf",l_aStructure,'VFPCDX',.T.,"table005",,"UTF8")
// select table005
// AppendData(.f.)
//ExportTableToHtmlFile("table005","Cursor_Table005Records","mem vfp",10,10,.t.)

//=====================================================================================

// ?"Before table006. Press Enter"
// do while inkey(0) <> K_ENTER
// enddo
// ?"Pressed Enter"
// DbCreate("table006",l_aStructure,'SQLMIX',.T.,"table006",,"UTF8")
// select table006
// AppendData(.t.)
// ?"After table006"
// ExportTableToHtmlFile("table006","Cursor_table006Records","SQLMix",10,10,.t.)
// ?"After table006. Press Enter"
// do while inkey(0) <> K_ENTER
// enddo
// ?"Pressed Enter"

//=====================================================================================
oCursor1 := hb_Cursor()
with object oCursor1

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

    // altd()
    // dbUseArea(.t.,"SQLMIX","table007","table007bis",.t.,"UTF8")
    // select table007bis
    
    select table007
    :AppendBlank()
    Field->DOB := ctod("05/02/2020")
    :SetFieldValue("dob",ctod("05/03/2020"))
    :SetFieldValue("fname","Eric")
    :SetFieldValue("lname","Lendvai")
    :SetFieldValue("info",replicate("?",100000))

    :AppendBlank()
    :SetFieldValues({"fname"=>"Maria","lname"=>"Smith"})

    l_result := :InsertRecord({"fname"=>"AHercules","lname"=>"Lendvai","dob"=>date(),"info"=>"hero"})
    if !hb_isNil(l_result)
        ?"New Key = "+trans(l_result)
    endif

    :InsertRecord({"fname"=>"John","lname"=>"Bonjovi"})
// AltD()
    ?":p_RecordCount = "+allt(Str(:p_RecordCount))

    // l_memory_from := memory(l_MemoryOption)
    // l_RunStartTime := DateTime()
    // for l_loop :=1 to 10000  //00
    //     :AppendBlank()
    // endfor
    // ?"Milliseconds To Add 1000000 records = "+Trans(GetTimeDeltaInMs(l_RunStartTime,hb_DateTime()))


    // l_memory_To   := memory(l_MemoryOption)
    // ?"Memory Consumed = "+trans(l_memory_To-l_memory_From)
    // :Zap()
    // l_memory_To   := memory(l_MemoryOption)
    // ?"Memory Consumed = "+trans(l_memory_To-l_memory_From)
    
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
    :InsertRecord({"fname"=>"Hercules","lname"=>"Lendvai","dob"=>date(),"info"=>"Hero"})
    ExportTableToHtmlFile("table008","Cursor_table008Records","SQLMix",10,20,.t.)


endwith

//=====================================================================================

return nil
//=================================================================================================================
init procedure hello()
hb_orm_SendToDebugView("[Harbour] Init Procedure")
return
//=================================================================================================================
static function AppendData(par_ApplyNull)

local l_loop
local l_memory_from
local l_memory_to
local l_MemoryOption := HB_MEM_USED //HB_MEM_USED
local l_TimeStamp1,l_TimeStamp2

l_memory_from := memory(l_MemoryOption)
l_TimeStamp1  := hb_DateTime()

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

for l_loop := 1 to 1000
    dbAppend()
    field->info := replicate('.',10)   // hb_RandStr(1000)
endfor

l_memory_To   := memory(l_MemoryOption)

l_TimeStamp2  := hb_DateTime()


hb_orm_SendToDebugView("[Harbour] "+alias()+" Memory Consumed = "+trans(l_memory_To-l_memory_From))

?"Reccount in alias "+alias()+" ="+trans(reccount())
?"Run Time in alias "+alias()+" = "+alltrim( str((l_TimeStamp2-l_TimeStamp1)*(24*3600*1000),10) )+" (ms)"

return NIL
//=================================================================================================================
