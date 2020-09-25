//Copyright (c) 2020 Eric Lendvai MIT License

// #include "hb_fcgi.ch"
// #include "fileio.ch"
// #include "dbinfo.ch"

// request DBFCDX
// request DBFFPT
// request HB_CODEPAGE_EN
//request HB_CODEPAGE_UTF8
// memvar v_hPP

//request hb_vfp

REQUEST HB_CODEPAGE_UTF8

#include "hb_orm.ch"
#include "hb_VFP.ch"

// #include "dbinfo.ch"   // for the export to html file

// #include "inkey.ch"
// #include "button.ch"
// #include "setcurs.ch"
// #include "box.ch"

// #define _DRAW_1 hb_UTF8ToStr( "├" )
// #define _DRAW_2 hb_UTF8ToStr( "┤" )
// #define _DRAW_3 hb_UTF8ToStrBox( "┐ ┌─" )
// #define _DRAW_4 hb_UTF8ToStrBox( "┘ └─" )
// #define _DRAW_5 hb_UTF8ToStrBox( "│ │" )
// #define _DRAW_6 hb_UTF8ToStrBox( "┐ ┌─┤HIDE├─" )
// #define _DRAW_7 hb_UTF8ToStrBox( "╖ ╓─┤HIDE├─" )
// #define _DRAW_8 hb_UTF8ToStrBox( "╜ ╙─" )
// #define _DRAW_9 hb_UTF8ToStrBox( "║ ║" )

//=================================================================================================================
Function Main()
local iSQLHandle
local oSQLConnection1
local oSQLConnection2
local o_DB1
local o_DB2
local nKey
local l_result

local l_w1
local l_LastSQL

local l_o_data
local l_a_array := {}

local l_aStructure

local l_Tally
local l_LastSQLError
local l_loop

local l_table_003
local l_table_003_key
local l_table_003_keyB
local l_hash_Key
local l_TestResult

local l_o_Cursor

// public v_hPP
// v_hPP := nil

// SendToDebugView("Starting ORM Example SQL_CRUD")

// //hb_cdpSelect("UTF8")
// hb_cdpSelect("EN")

// // oFcgi := hb_Fcgi():New()
// oFcgi := MyFcgi():New()    // Used a subclass of hb_Fcgi
// do while oFcgi:Wait()
//     oFcgi:OnRequest()
// enddo

hb_cdpSelect("UTF8") 

?"-----"+vfp_strtran("Hello","HEL","Bye",-1,-1,1)+"-----"
// altd()
?VFP_GetCompatibilityPackVersion()

?"------------------------------------------------------"
TestCode()

oSQLConnection1 := hb_SQLConnect()
with object oSQLConnection1
    :SetBackendType("MariaDB")
    :SetUser("root")
    :SetPassword("rndrnd")
    :SetDatabase("test001")
    // :SetServer("127.0.0.1")
    iSQLHandle := :Connect()
    do case
    case iSQLHandle == 0
        ?"Already Connected"
    case iSQLHandle < 0
        ? :GetLastErrorMessage()
    otherwise
        ?"connection is",iSQLHandle
    endcase

    ?"MariaDB Get last Handle",:GetHandle()


    //:LoadSchema()
    //altd()


    // if !:Lock("hbwarti",123)
    //     ?"Failed to lock"
    // endif
    // altd()
    // :Unlock("hbwarti",123)
    // altd()
    // ?"Paused"
end


oSQLConnection2 := hb_SQLConnect("PostgreSQL",,,,"postgres","rndrnd","test002","public")
with object oSQLConnection2
    iSQLHandle := :Connect()
    do case
    case iSQLHandle == 0
        ?"Already Connected"
    case iSQLHandle < 0
        ? :GetLastErrorMessage()
    otherwise
        ?"connection is",iSQLHandle
    endcase

    ?"PostgreSQL Get last Handle",:GetHandle()

    // if !:Lock("hbwarti",123)
    //     ?"Failed to lock"
    // endif
    // altd()
    // :Unlock("hbwarti",123)
    // altd()
    // ?"Paused"

    l_table_003      := :p_Schema["table003"]
    l_table_003_key  := l_table_003["varchar51"]
    l_table_003_keyB := :p_Schema["table003"]["varchar51"]


// nPosition := hb_hPos( aHash, Key ) 
// Key := hb_hKeyAt( aHash, nPosition )

//To get the 
l_hash_Key := hb_hKeyAt( :p_Schema["table003"], hb_hPos( :p_Schema["table003"], "varchar51" )  ) 

//    altd()


end

//hb_orm_TestDebugger()


// Field Types
// "C"  = Character - C  / String - Textbox
// "M"  = Memo - M / Text (No Limit Of Length) - Text Area
// "N"  = Numeric - N / Numeric - Textbox
// "D"  = Date - D / Date - Textbox
// "T"  = DateTime - T / Date and Time - Textbox
// "TS" = Timestamp
// "L"  = Logical - L / Logical (Yes/No) - Checkbox
// "I"  = Integer - I / List Of Values
	

//l_FieldType,l_FieldLen,l_FieldDec,l_Fie5ldAllowNull,l_FieldAutoIncrement

l_aStructure := {=>}
l_aStructure["key"]        := {"I",,,,.t.}
l_aStructure["p_table001"] := {"I"}
l_aStructure["city"]       := {"C",50,0}


o_DB1 := hb_SQLData()
with object o_DB1

    // :Echo()

    :SetPrimaryKeyFieldName("key")
    :UseConnection(oSQLConnection1)

    // l_aStructure := :LoadTableStructure("table001")
// altd()
//     l_aStructure := :LoadTableStructure("table002")
// altd()
    // l_aStructure := :LoadTableStructure("table003")
// altd()


// altd()
//     l_TestResult := :FixTableAndFieldNameCasingInExpression("table001.fname")
//     l_TestResult := :FixTableAndFieldNameCasingInExpression("table001.fname < 5")
//     l_TestResult := :FixTableAndFieldNameCasingInExpression("table001>fname")
//     l_TestResult := :FixTableAndFieldNameCasingInExpression("table001 .fname")
//     l_TestResult := :FixTableAndFieldNameCasingInExpression("table001..fname")
//     l_TestResult := :FixTableAndFieldNameCasingInExpression("table001.()")
//     l_TestResult := :FixTableAndFieldNameCasingInExpression("upper(table001.fName) $ taBle001.LName")

    :Table("table003")
    :Column("table003.key"        ,"table003_key")
    :Column("table003.char50"     ,"table003_char50")
    :Column("table003.Bigint33"   ,"table003_Bigint33")
    :Column("table003.BIT"        ,"table003_Bit")
    :Column("table003.Decimal5_2" ,"table003_Decimal5_2")
    :Column("table003.Varchar51"  ,"table003_Varchar51")
    :Column("table003.Text"       ,"table003_Text")
    :Column("table003.Binary52"   ,"table003_Binary52")
    :Column("table003.Varbinary55","table003_Varbinary55")
    :Column("table003.Date"       ,"table003_Date")
    :Column("table003.DateTime"   ,"table003_DateTime")
    :Column("table003.Time"       ,"table003_Time")
    :Column("table003.Boolean"    ,"table003_Boolean")

    :SQL(10000,"Table003Records")

    //Example of adding a record and adding a local index in activating it
    l_o_Cursor := o_DB1:p_oCursor

    l_o_Cursor:AppendBlank() //Blank Record
    l_o_Cursor:SetFieldValue("TABLE003_CHAR50","Bogus")

    l_o_Cursor:InsertRecord({"TABLE003_CHAR50"   => "Fabulous",;
                             "TABLE003_BIGINT33" => 1234})

    l_o_Cursor:Index("tag1","TABLE003_CHAR50")
    l_o_Cursor:CreateIndexes()
    l_o_Cursor:SetOrder("tag1")
    

// select Table003Records
// dbGoBottom()
// altd()
// dbGoTop()

    l_Tally        := :tally
    l_LastSQLError := :ErrorMessage()
    l_LastSQL      := :LastSQL()
    l_TestResult   := oSQLConnection1:p_Schema["table003"]
// altd()
//function ExportTableToHtmlFile(par_alias,par_html_file,par_MaxKBSize,par_HeaderRepeatFrequency)

//ExportTableToHtmlFile("Table003Records","R:\Harbour_ORM\Examples\SQL_CRUD\Table003Records.html")
ExportTableToHtmlFile("Table003Records","MySQL_Table003Records","From MySQL",,,.t.)

// ?"Will Get DBF name:"
// ?VFP_dbf("Table003Records")   //Will be NIL

//     // :Table("table003")
//     // :Field("table003.char50"   ,"Eric Lendvai")
//     // :Field("table003.Bigint33" ,1)
//     // :Field("table003.Decimal5_2" ,12.34)
//     // :Add()

//     select Table003Records

//     l_Tally := :tally
//     l_LastSQLError := :ErrorMessage()


// hb_orm_SendToDebugView(replicate("-",60))
// hb_orm_SendToDebugView("Alias",alias())
// hb_orm_SendToDebugView("Record Number",recno())
// for l_loop := 1 to FCount()
//     hb_orm_SendToDebugView(FieldName(l_loop)+" - "+hb_FieldType(l_loop)+" - "+trans(hb_FieldLen())+" - "+trans(hb_FieldDec()))
//     hb_orm_SendToDebugView("Value",FieldGet(l_loop))
// endfor
// hb_orm_SendToDebugView(replicate("-",60))

// // altd()
//     :UpdateTableStructure("table003",l_aStructure,.f.)

    select Table003Records


hb_orm_SendToDebugView(replicate("-",60))
hb_orm_SendToDebugView("Alias",alias())
hb_orm_SendToDebugView("Record Number",recno())
for l_loop := 1 to FCount()
    hb_orm_SendToDebugView("MySQL "+trans(l_loop)+") "+FieldName(l_loop)+" - "+hb_FieldType(l_loop)+" - "+trans(hb_FieldLen())+" - "+trans(hb_FieldDec()))

// altd()
// l_TestResult := StrTran(FieldName(l_loop),"TABLE003_","")
// l_TestResult := oSQLConnection1:p_Schema["table003"][StrTran(FieldName(l_loop),"TABLE003_","")]

    hb_orm_SendToDebugView("SQLField Type: ",oSQLConnection1:p_Schema["table003"][StrTran(FieldName(l_loop),"TABLE003_","")][6])
    hb_orm_SendToDebugView("Value: ",FieldGet(l_loop))
endfor
hb_orm_SendToDebugView(replicate("-",60))


// altd()
    :Table("table001")
    :Field("age",5)
    :Field("dob",date())
    :Field("dati",hb_datetime())
    :Field("fname","Michael"+' "excetera"')
    :Field("lname","O'Hara 123")
    :Field("logical1",NIL)
    if :Add()
        nKey := :Key()

        :Table("table001")
        :Field("fname","Ingrid")
        :Update(nKey)
    

// altd()
        :Table("table001")
        :Column("table001.fname","table001_fname")
        l_o_data := :Get(nKey)
// altd()
        l_w1 := l_o_data:table001_fname
        // AltD()

        l_w1 := l_o_data:GetFieldInfo(0,"hello")
        // AltD()

        :Table("table001")
        l_o_data := :Get(nKey)
// AltD()

        // ?"Add record with key = "+AllTrim(str(nKey))
        ?"Add record with key = "+Trans(nKey)


        :Delete(nKey)

    endif

// altd()
    :Table("table001")
    // :Join("inner","table002","","table002.p_table001 = table001 and key = ^",5)
    l_w1 := :Join("inner","table002","","table002.p_table001 = table001")
    :ReplaceJoin(l_w1,"inner","table002","","table002.p_table001 = table001.key")

    l_w1 := :Where("table001.fname = ^","eric")
    :Where("table001.lname = ^","lendvai")
    :ReplaceWhere(l_w1,"table001.fname = ^","liam")

    l_w1 := :Having("table001.fname = ^","eric")
    :Having("table001.lname = ^","lendvai")
    :ReplaceHaving(l_w1,"table001.fname = ^","liam")

    //:KeywordCondition("eric","fname+lname","or",.t.)
    

    // altd()

    ?"----------------------------------------------"
    :Table("table001")
    :Column("table001.key"  ,"key")
    :Column("table001.fname","table001_fname")
    :Column("table001.lname","table001_lname")
    :Column("table002.children","table002_children")
    :Where("table001.key < 4")
    :Join("inner","table002","","table002.p_table001 = table001.key")
    :SQL(10001,"AllRecords")
    
    l_LastSQLError := :ErrorMessage()

    l_LastSQL := :LastSQL()
    hb_orm_SendToDebugView("LastSQL",l_LastSQL)
    hb_orm_SendToDebugView("LastRunTime",:LastRunTime())

    ?"Will use scan/endscan"
    select AllRecords
    index on upper(field->table001_fname) tag ufname to AllRecords

    // do while !eof()
    scan all
        ?"MySQL "+trans(AllRecords->key)+" - "+allt(AllRecords->table001_fname)+" "+allt(AllRecords->table001_lname)+" "+allt(AllRecords->table002_children)
    endscan
    // enddo

// dbGoTop()
// browse()   //Would require to use gtwin in the hbp file

    // l_w1 := :SQL(10005)
    // l_w1 := :SQL(10006,l_a_array)

    ?"----------------------------------------------"




    :SetExplainMode(2)
    l_result := :SQL(10004)
    // altd()

    //altd()
    l_o_Cursor:Close()


end

o_DB2 := hb_SQLData()
with object o_DB2
    :SetPrimaryKeyFieldName("key")
    :UseConnection(oSQLConnection2)

//     l_aStructure := :LoadTableStructure("table001")
// altd()
//     l_aStructure := :LoadTableStructure("table002")
// altd()
//     l_aStructure := :LoadTableStructure("table003")
// altd()
//     l_aStructure := :LoadTableStructure("table004")
// altd()





    // l_aStructure := :LoadTableStructure("table003")
// altd()
    :Table("table003")
    :Column("table003.key"        ,"table003_key")
    :Column("table003.char50"     ,"table003_char50")
    :Column("table003.bigint"     ,"table003_Bigint")
    :Column("table003.Bit"        ,"table003_Bit")
    :Column("table003.Decimal5_2" ,"table003_Decimal5_2")
    :Column("table003.Varchar51"  ,"table003_Varchar51")
    :Column("table003.Text"       ,"table003_Text")
    :Column("table003.BInary"     ,"table003_Binary")
    // :Column("table003.Varbinary55","table003_Varbinary55")
    :Column("table003.Date"       ,"table003_Date")
    :Column("table003.DateTime"   ,"table003_DateTime")
    :Column("table003.time"       ,"table003_Time")
    :Column("table003.Boolean"    ,"table003_Boolean")
    :SQL(10010,"Table003Records")

    l_Tally        := :tally
    l_LastSQLError := :ErrorMessage()
    l_LastSQL      := :LastSQL()

// altd()
ExportTableToHtmlFile("Table003Records","PostgreSQL_Table003Records.html","From PostgreSQL",,25,.t.)

    select Table003Records


hb_orm_SendToDebugView(replicate("-",60))
hb_orm_SendToDebugView("Alias",alias())
hb_orm_SendToDebugView("Record Number",recno())
for l_loop := 1 to FCount()
    hb_orm_SendToDebugView("PostgreSQL "+trans(l_loop)+") "+FieldName(l_loop)+" - "+hb_FieldType(l_loop)+" - "+trans(hb_FieldLen())+" - "+trans(hb_FieldDec()))
    hb_orm_SendToDebugView("Value",FieldGet(l_loop))
endfor
hb_orm_SendToDebugView(replicate("-",60))






    // :UpdateTableStructure("table003",l_aStructure,.f.)

    :Table("table001")
    :Field("age",6)
    :Field("dob",date())
    :Field("dati",hb_datetime())
    :Field("fname","Michael"+' "excetera"')
    :Field("lname","O'Hara 123")
    :Field("logical1",.t.)
    // :Field("fname","Eric")
    // :Field("lname","lebeaux")
    if :Add()
        nKey := :Key()


        :Table("table001")
        :Field("fname","Ingrid")
        :Update(nKey)
    


        :Table("table001")
        :Column("table001.fname","table001_fname")
        l_o_data := :Get(nKey)

        l_w1 := l_o_data:table001_fname
        // AltD()

        l_w1 := l_o_data:GetFieldInfo(0,"hello")
        // AltD()

        :Table("table001")
        l_o_data := :Get(nKey)
// AltD()

        // ?"Add record with key = "+AllTrim(str(nKey))
        ?"Add record with key = "+Trans(nKey)

        :Delete(nKey)


// l_result := :PrepExpression("Hello World ^ ^ ^ ^",date(),hb_datetime(),5,"testing")
// altd()

    endif

    ?"----------------------------------------------"
    :Table("table001")
    :Column("table001.key"  ,"key")
    :Column("table001.fname","table001_fname")
    :Column("table001.lname","table001_lname")
    :Column("table002.children","table002_children")
    :Where("table001.key < 4")
    :Join("inner","table002","","table002.p_table001 = table001.key")
    :SQL(10002,"AllRecords")

    l_LastSQL := :LastSQL()
    hb_orm_SendToDebugView("LastSQL",l_LastSQL)
    hb_orm_SendToDebugView("LastRunTime",:LastRunTime())

    select AllRecords
    do while !eof()
        ?"PostgreSQL "+trans(AllRecords->key)+" - "+allt(AllRecords->table001_fname)+" "+allt(AllRecords->table001_lname)+" "+allt(AllRecords->table002_children)
        dbSkip()
    enddo
    ?"----------------------------------------------"

    // altd()

    :SetExplainMode(2)
    l_result := :SQL(10007)
    // altd()

end

/*
o_DB1 := hb_orm()
o_DB1:UseConnection(oSQLConnection1)

with object o_DB1
    :Table("table001")
end

// Altd()
// ?o_DB1:Echo("The SQL Engine is ")

*/

oSQLConnection1:Disconnect()
?"MariaDB Get last Handle",oSQLConnection1:GetHandle()


oSQLConnection2:Disconnect()
?"PostgreSQL Get last Handle",oSQLConnection2:GetHandle()



// o_DB = hb_orm()  //:New()

// altd()

// ??o_DB:Echo("Hello")
// //??GetMessage()

// hb_orm_SendToDebugView("test001")

// altd()
// SendToDebugView("Done")

return nil
//=================================================================================================================
//=================================================================================================================
//=================================================================================================================
//=================================================================================================================

function TestCode()
local aArray2Dim := {}
local cTextToSearch
local iRow

AAdd(aArray2Dim,{1,"Hello"})
AAdd(aArray2Dim,{2,"World"})

?aArray2Dim[1][1]
?aArray2Dim[1][2]
?aArray2Dim[2][1]
?aArray2Dim[2][2]

//Will the following work
?aArray2Dim[2,2]

//Search for row where "World" is in the second column
cTextToSearch = upper("world")

iRow = AScan( aArray2Dim, {|aRow|upper(aRow[2]) == cTextToSearch } )
//iRow will be 0 if not found
?"Row Key",aArray2Dim[iRow][1]

aadd(aArray2Dim,"New Item 1")
// hb_ains(aArray2Dim,-1,"Hello",.t.)
// altd()

return NIL
//=================================================================================================================
