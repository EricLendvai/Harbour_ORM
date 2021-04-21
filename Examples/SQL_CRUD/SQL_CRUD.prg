//Copyright (c) 2021 Eric Lendvai MIT License

REQUEST HB_CODEPAGE_UTF8

#include "hb_orm.ch"
#include "hb_vfp.ch"

//=================================================================================================================
Function Main()
local l_iSQLHandle
local l_oSQLConnection1
local l_oSQLConnection2
local o_DB1
local o_DB2
local l_nKey

local l_w1

local l_o_data

local l_o_Cursor

local l_SchemaDefinition1
local l_SchemaDefinition2

local l_SQLScript
local l_LastError

local l_Version

local l_cPreviousSchemaName
local l_LastSQL

local l_oCursorTable003Records


hb_cdpSelect("UTF8") 

//===========================================================================================================================
?"------------------------------------------------------"
//===========================================================================================================================

l_oSQLConnection1 := hb_SQLConnect()
with object l_oSQLConnection1
    :MySQLEngineConvertIdentifierToLowerCase := .f.
    :SetDriver("MariaDB ODBC 3.1 Driver")
    :SetBackendType("MariaDB")
    :SetUser("root")
    :SetPassword("rndrnd")
    :SetDatabase("test001")
    // :SetServer("127.0.0.1")
    :SetPrimaryKeyFieldName("key")
    l_iSQLHandle := :Connect()
    do case
    case l_iSQLHandle == 0
        ?"Already Connected"
    case l_iSQLHandle < 0
        ? :GetErrorMessage()
    otherwise
        ?"connection is",l_iSQLHandle
    endcase

    ?"MariaDB Get last Handle",:GetHandle()  // This function is only needed if l_iSQLHandle was set to 0.
end


l_oSQLConnection2 := hb_SQLConnect("PostgreSQL",,,,"postgres","rndrnd","test001","set001")

with object l_oSQLConnection2
   :PostgreSQLIdentifierCasing := HB_ORM_POSTGRESQL_CASE_SENSITIVE
   :PostgreSQLHBORMSchemaName := "MyDataDic"
    l_iSQLHandle := :Connect()
    do case
    case l_iSQLHandle == 0
        ?"Already Connected"
    case l_iSQLHandle < 0
        ? :GetErrorMessage()
    otherwise
        ?"connection is",l_iSQLHandle
    endcase

    ?"PostgreSQL Get last Handle",:GetHandle()  // This function is only needed if l_iSQLHandle was set to 0.
end
//===========================================================================================================================

if l_oSQLConnection1:Connected
    hb_orm_SendToDebugView("MariaDB table001 exists ",l_oSQLConnection1:TableExists("table001"))
endif
if l_oSQLConnection2:Connected
    hb_orm_SendToDebugView("PostgreSQL table001 exists ",l_oSQLConnection2:TableExists("table001"))
    hb_orm_SendToDebugView("PostgreSQL bogus.table001 exists ",l_oSQLConnection2:TableExists("bogus.table001"))
endif

hb_orm_SendToDebugView("Will Initialize l_SchemaDefinition1")

l_SchemaDefinition1 := ;
{"dbf001"=>{;   //Field Definition
   {"key"          =>{,  "I",   0,  0,"+"};
   ,"customer_name"=>{,  "C",  50,  0,}};
   ,;   //Index Definition
   NIL};
,"dbf002"=>{;   //Field Definition
   {"key"     =>{,  "I",   0,  0,"+"};
   ,"p_dbf001"=>{,  "I",   0,  0,}};
   ,;   //Index Definition
   NIL};
,"noindextesttable"=>{;   //Field Definition
   {"KeY" =>{,  "I",   0,  0,"+"};
   ,"Code"=>{,  "C",   3,  0,"N"}};
   ,;   //Index Definition
   NIL};
,"table001"=>{;   //Field Definition
   {"key"     =>{   ,  "I",   0,  0,"+"};
   ,"LnAme"   =>{   ,  "C",  50,  0,};
   ,"fname"   =>{   ,  "C",  53,  0,};
   ,"minitial"=>{   ,  "C",   1,  0,};
   ,"age"     =>{   ,  "N",   3,  0,};
   ,"dob"     =>{   ,  "D",   0,  0,};
   ,"dati"    =>{   ,"DTZ",   0,  0,};
   ,"logical1"=>{"P",  "L",   0,  0,};
   ,"numdec2" =>{   ,  "N",   6,  1,};
   ,"bigint"  =>{"M", "IB",   0,  0,};
   ,"varchar" =>{   , "CV", 203,  0,}};
   ,;   //Index Definition
   {"lname"=>{   ,"LnAme",.f.,"BTREE"};
   ,"tag1" =>{"P","upper((lname)::text)",.f.,"BTREE"};
   ,"tag2" =>{"P","upper((fname)::text)",.f.,"BTREE"}}};
,"table002"=>{;   //Field Definition
   {"key"       =>{,  "I",   0,  0,"+"};
   ,"p_table001"=>{,  "I",   0,  0,"N"};
   ,"children"  =>{, "CV", 200,  0,"N"};
   ,"Cars"      =>{, "CV", 300,  0,}};
   ,;   //Index Definition
   NIL};
,"table003"=>{;   //Field Definition
   {"key"        =>{,  "I",   0,  0,"+"};
   ,"p_table001" =>{,  "I",   0,  0,};
   ,"char50"     =>{,  "C",  50,  0,};
   ,"bigint"     =>{, "IB",   0,  0,"N"};
   ,"Bit"        =>{,  "R",   0,  0,"N"};
   ,"Decimal5_2" =>{,  "N",   5,  2,"N"};
   ,"Decimal25_7"=>{,  "N",  25,  7,"N"};
   ,"VarChar51"  =>{, "CV",  50,  0,"N"};
   ,"Text"       =>{,  "M",   0,  0,"N"};
   ,"Binary"     =>{,  "R",   0,  0,"N"};
   ,"Date"       =>{,  "D",   0,  0,"N"};
   ,"DateTime"   =>{, "DT",   0,  4,"N"};
   ,"time"       =>{, "TO",   0,  4,"N"};
   ,"Boolean"    =>{,  "L",   0,  0,"N"}};
   ,;   //Index Definition
   NIL};
,"table004"=>{;   //Field Definition
   {"id"    =>{,  "I",   0,  0,};
   ,"street"=>{,  "C",  50,  0,"N"};
   ,"zip"   =>{,  "C",   5,  0,"N"};
   ,"state" =>{,  "C",   2,  0,"N"}};
   ,;   //Index Definition
   {"pkey"=>{,"id",.t.,"BTREE"}}};
,"alltypes"=>{;   //Field Definition
   {"key"                =>{,  "I",   0,  0,"+"};
   ,"integer"            =>{,  "I",   0,  0,"N"};
   ,"big_integer"        =>{, "IB",   0,  0,"N"};
   ,"money"              =>{,  "Y",   0,  0,"N"};
   ,"char10"             =>{,  "C",  10,  0,"N"};
   ,"varchar10"          =>{, "CV",  10,  0,"N"};
   ,"binary10"           =>{,  "B",  10,  0,"N"};
   ,"varbinary10"        =>{, "BV",  10,  0,"N"};
   ,"memo"               =>{,  "M",   0,  0,"N"};
   ,"raw"                =>{,  "R",   0,  0,"N"};
   ,"logical"            =>{,  "L",   0,  0,"N"};
   ,"date"               =>{,  "D",   0,  0,"N"};
   ,"time_with_zone"     =>{,"TOZ",   0,  0,"N"};
   ,"time_no_zone"       =>{, "TO",   0,  0,"N"};
   ,"datetime_with_zone" =>{,"DTZ",   0,  0,"N"};
   ,"datetime_no_zone"   =>{, "DT",   0,  0,"N"}};
   ,;   //Index Definition
   NIL};
,"zipcodes"=>{;   //Field Definition
   {"key"    =>{, "IB",   0,  0,"+"};
   ,"zipcode"=>{,  "C",   5,  0,"N"};
   ,"city"   =>{,  "C",  45,  0,"N"}};
   ,;   //Index Definition
   NIL};
}

hb_orm_SendToDebugView("Initialized l_SchemaDefinition1")

hb_orm_SendToDebugView("Will Initialize l_SchemaDefinition2")


l_SchemaDefinition2 := ;
{"dbf001"=>{;   //Field Definition
   {"key"          =>{,  "I",   0,  0,"+"};
   ,"customer_name"=>{,  "C",  50,  0,}};
   ,;   //Index Definition
   NIL};
,"dbf002"=>{;   //Field Definition
   {"key"     =>{,  "I",   0,  0,"+"};
   ,"p_dbf001"=>{,  "I",   0,  0,}};
   ,;   //Index Definition
   NIL};
,"set003.cust001"=>{;   //Field Definition
   {"KeY" =>{,  "I",   0,  0,"+"};
   ,"Code"=>{,  "C",   3,  0,"N"}};
   ,;   //Index Definition
   NIL};
,"set003.form001"=>{;   //Field Definition
   {"key"     =>{   ,  "I",   0,  0,"+"};
   ,"LnAme"   =>{   ,  "C",  50,  0,};
   ,"fname"   =>{   ,  "C",  53,  0,};
   ,"minitial"=>{   ,  "C",   1,  0,};
   ,"age"     =>{   ,  "N",   3,  0,};
   ,"dob"     =>{   ,  "D",   0,  0,};
   ,"dati"    =>{   ,"DTZ",   0,  0,};
   ,"logical1"=>{"P",  "L",   0,  0,};
   ,"numdec2" =>{   ,  "N",   6,  1,};
   ,"bigint"  =>{"M", "IB",   0,  0,};
   ,"varchar" =>{   , "CV", 203,  0,}};
   ,;   //Index Definition
   {"lname"=>{   ,"LnAme",.f.,"BTREE"};
   ,"tag1" =>{"P","upper((lname)::text)",.f.,"BTREE"};
   ,"tag2" =>{"P","upper((fname)::text)",.f.,"BTREE"}}};
,"form002"=>{;   //Field Definition
   {"key"       =>{,  "I",   0,  0,"+"};
   ,"p_table001"=>{,  "I",   0,  0,"N"};
   ,"children"  =>{, "CV", 200,  0,"N"};
   ,"Cars"      =>{, "CV", 300,  0,}};
   ,;   //Index Definition
   NIL};
}

if l_oSQLConnection1:Connected
    l_Version := l_oSQLConnection1:GetSchemaDefinitionVersion("AllMySQL v1")
    l_oSQLConnection1:SetSchemaDefinitionVersion("AllMySQL v1"      ,l_Version+1)
endif

if l_oSQLConnection2:Connected
    l_Version := l_oSQLConnection2:GetSchemaDefinitionVersion("AllPostgreSQL v1")
    l_oSQLConnection2:SetSchemaDefinitionVersion("AllPostgreSQL v1" ,l_Version+1)
endif
// altd()

hb_orm_SendToDebugView("Initialized l_SchemaDefinition2")

//===========================================================================================================================
if l_oSQLConnection1:Connected
    hb_orm_SendToDebugView("MariaDB - Will GenerateCurrentSchemaHarbourCode")
    l_oSQLConnection1:GenerateCurrentSchemaHarbourCode("d:\CurrentSchema_MariaDB_"+l_oSQLConnection1:GetDatabase()+"_.txt")
    hb_orm_SendToDebugView("MariaDB - Done d:\CurrentSchema_PostgreSQL_...text")

    // altd()
    // l_SQLScript := l_LastError := ""
    if el_AUnpack(l_oSQLConnection1:MigrateSchema(l_SchemaDefinition1),,@l_SQLScript,@l_LastError) > 0
        hb_orm_SendToDebugView("MariaDB - Updated d:\MigrationSqlScript_MariaDB_....txt")
    else
        if !empty(l_LastError)
            hb_orm_SendToDebugView("MariaDB - Failed Migrate d:\MigrationSqlScript_MariaDB_....txt")
            hb_MemoWrit("d:\MigrationSqlScript_MariaDB_LastError_"+l_oSQLConnection1:GetDatabase()+".txt",l_LastError)
        endif
    endif
    // altd()
    hb_MemoWrit("d:\MigrationSqlScript_MariaDB_"+l_oSQLConnection1:GetDatabase()+".txt",l_SQLScript)

endif

//===========================================================================================================================
if l_oSQLConnection2:Connected

    l_oSQLConnection2:SetCurrentSchemaName("set001")

    hb_orm_SendToDebugView("PostgreSQL - Will GenerateCurrentSchemaHarbourCode")
    l_oSQLConnection2:GenerateCurrentSchemaHarbourCode("d:\CurrentSchema_PostgreSQL_"+l_oSQLConnection2:GetDatabase()+"_.txt")
    hb_orm_SendToDebugView("PostgreSQL - Done d:\CurrentSchema_PostgreSQL_...text")

    l_SQLScript := ""
    if el_AUnpack(l_oSQLConnection2:MigrateSchema(l_SchemaDefinition1),,@l_SQLScript,@l_LastError) > 0
        hb_orm_SendToDebugView("PostgreSQL - Updated d:\MigrationSqlScript_PostgreSQL_set001....txt")
    else
        if !empty(l_LastError)
            hb_orm_SendToDebugView("PostgreSQL - Failed Migrate d:\MigrationSqlScript_PostgreSQL_set001_....txt")
            hb_MemoWrit("d:\MigrationSqlScript_PostgreSQL_set001_LastError_"+l_oSQLConnection2:GetDatabase()+".txt",l_LastError)
        endif
    endif
    hb_MemoWrit("d:\MigrationSqlScript_PostgreSQL_set001_"+l_oSQLConnection2:GetDatabase()+".txt",l_SQLScript)


    l_cPreviousSchemaName := l_oSQLConnection2:SetCurrentSchemaName("set002")

    l_SQLScript := ""
    if el_AUnpack(l_oSQLConnection2:MigrateSchema(l_SchemaDefinition2),,@l_SQLScript,@l_LastError) > 0
        hb_orm_SendToDebugView("PostgreSQL - Updated d:\MigrationSqlScript_PostgreSQL_set002....txt")
    else
        if !empty(l_LastError)
            hb_orm_SendToDebugView("PostgreSQL - Failed Migrate d:\MigrationSqlScript_PostgreSQL_set002_....txt")
            hb_MemoWrit("d:\MigrationSqlScript_PostgreSQL_set002_LastError_"+l_oSQLConnection2:GetDatabase()+".txt",l_LastError)
        endif
    endif
    hb_MemoWrit("d:\MigrationSqlScript_PostgreSQL_set002_"+l_oSQLConnection2:GetDatabase()+".txt",l_SQLScript)




    l_oSQLConnection2:SetCurrentSchemaName(l_cPreviousSchemaName)
    

    l_oSQLConnection2:Lock("set001.table001",1000)
    l_oSQLConnection2:Lock("set001.table001",1000)
    l_oSQLConnection2:Lock("set001.table001",1000)
    l_oSQLConnection2:Lock("set001.table001",1001)
    l_oSQLConnection2:Lock("set001.table001",1002)
    l_oSQLConnection2:Unlock("set001.table001",1000)

endif

//===========================================================================================================================
?"Done"

if l_oSQLConnection1:Connected
    o_DB1 := hb_SQLData(l_oSQLConnection1)
    with object o_DB1

        :Table("alltypes")
        :SetEventId("MySQLAddAllTypes")
        :Field("integer"           ,123)
        :Field("big_integer"       ,10**15)
        :Field("money"             ,123456.1245)
        :Field("char10"            ,"Hello World Hello World Hello World")
        :Field("varchar10"         ,"Hello World Hello World Hello World")
        :Field("binary10"          ,"01010")
        :Field("varbinary10"       ,"0101010101010")
        :Field("memo"              ,"Test")
        :Field("raw"               ,"Test")
        :Field("logical"           ,.t.)
        :Field("date"              ,hb_ctod("02/24/2021"))
        :Field("time_with_zone"    ,"11:12:13")
        :Field("time_no_zone"      ,"11:12:13")
        :Field("datetime_with_zone",hb_ctot("02/24/2021 11:12:13"))
        :Field("datetime_no_zone"  ,hb_ctot("02/24/2021 11:12:13"))
        :Add()



        :Table("table003")
        :SetEventId("MySQLDecimalTest")
        :Field("Decimal5_2","523.35")   //To trigger new SchemaAndDataErrorLog
        :Field("Decimal25_7","-1111567890123456.1234567")
        // :Field("DateTime",hb_ctot("02/25/2021 07:24:03:234 pm","mm/dd/yyyy", "hh:mm:ss:fff pp"))
        :Field("DateTime",hb_ctot("02/25/2021 07:24:04:1234","mm/dd/yyyy", "hh:mm:ss:ffff"))
        :Add()


        // :UseConnection(l_oSQLConnection1)

        :Table("table003")
        :SetEventId("mysql 1")
        :Column("table003.key"        ,"table003_key")
        :Column("table003.char50"     ,"table003_char50")
        :Column("table003.Bigint"     ,"table003_Bigint")
        :Column("table003.Bit"        ,"table003_Bit")
        :Column("table003.Decimal5_2" ,"table003_Decimal5_2")
        :Column("table003.Varchar51"  ,"table003_Varchar51")
        :Column("table003.Text"       ,"table003_Text")
        :Column("table003.Binary"     ,"table003_Binary")
        :Column("table003.Date"       ,"table003_Date")
        :Column("table003.DateTime"   ,"table003_DateTime")
        :Column("table003.Time"       ,"table003_Time")
        :Column("table003.Boolean"    ,"table003_Boolean")

        :SQL(10000,"Table003Records")

        //Example of adding a record and adding a local index in activating it
        l_o_Cursor := o_DB1:p_oCursor

        l_o_Cursor:AppendBlank() //Blank Record
        l_o_Cursor:SetFieldValue("TABLE003_CHAR50","Bogus")

        l_o_Cursor:InsertRecord({"TABLE003_CHAR50" => "Fabulous",;
                                "TABLE003_BIGINT" => 1234})

        l_o_Cursor:Index("tag1","TABLE003_CHAR50")
        l_o_Cursor:CreateIndexes()
        l_o_Cursor:SetOrder("tag1")
        
        // l_Tally        := :tally
        // l_LastSQLError := :ErrorMessage()
        // l_LastSQL      := :LastSQL()
        // l_TestResult   := l_oSQLConnection1:p_Schema["table003"][1]

        ExportTableToHtmlFile("Table003Records","MySQL_Table003Records","From MySQL",,,.t.)


        :Table("table001")
        :SetEventId(2)
        :Field("age","5")   //To trigger new SchemaAndDataErrorLog
        :Field("dob",date())
        :Field("dati",hb_datetime())
        :Field("fname","Michael"+' "excetera2" 0123456789012345678901234567890123456789012345678901234567890123456789')
        :Field("lname","O'Hara 123")
        // :Field("logical1",NIL)
        if :Add()
            l_nKey := :Key()

            :Table("table001")
            :SetEventId(3)
            :Field("fname"   ,"Ingrid2")
            :Field("lname","1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890")
            :Field("minitial","aBBA2")
            :Update(l_nKey)
        
            :Table("table001")
            :SetEventId(4)
            :Column("table001.fname","table001_fname")
            l_o_data := :Get(l_nKey)

            l_o_data:GetFieldInfo(0,"hello")

            :Table("table001")
            :Column("table001.fname","table001_fname")
            :SetEventId(5)
            l_o_data := :Get(l_nKey)

            ?"Add record with key = "+Trans(l_nKey)+" First Name = "+l_o_data:table001_fname

        endif

        :Table("table001")
        :SetEventId(6)
        // :Join("inner","table002","","table002.p_table001 = table001 and key = ^",5)
        l_w1 := :Join("inner","table002","","table002.p_table001 = table001")
        :ReplaceJoin(l_w1,"inner","table002","","table002.p_table001 = table001.key")

        l_w1 := :Where("table001.fname = ^","Jodie")
        :Where("table001.lname = ^","Foster")
        :ReplaceWhere(l_w1,"table001.fname = ^","Harrison")

        l_w1 := :Having("table001.fname = ^","Jodie")
        :Having("table001.lname = ^","Foster")
        :ReplaceHaving(l_w1,"table001.fname = ^","Harrison")

        //:KeywordCondition("Jodie","fname+lname","or",.t.)
        
        ?"----------------------------------------------"
        :Table("table001")
        :SetEventId(7)
        :Column("table001.key"  ,"key")
        :Column("table001.fname","table001_fname")
        :Column("table001.lname","table001_lname")
        :Column("table002.children","table002_children")
        :Where("table001.key < 4")
        :Join("inner","table002","","table002.p_table001 = table001.key")
        :SQL(10001,"AllRecords")
        
        ?"Will use scan/endscan"
        select AllRecords
        index on upper(field->table001_fname) tag ufname to AllRecords

        scan all
            ?"MySQL "+trans(AllRecords->key)+" - "+allt(AllRecords->table001_fname)+" "+allt(AllRecords->table001_lname)+" "+allt(AllRecords->table002_children)
        endscan
        
        ExportTableToHtmlFile("AllRecords","MySQL_Table001_Join_Table002","From MySQL",,,.t.)

        ?"----------------------------------------------"


        :SetExplainMode(2)
        :SQL(10004)
        l_o_Cursor:Close()


    endwith
endif

if l_oSQLConnection2:Connected
    o_DB2 := hb_SQLData()
    with object o_DB2
        :UseConnection(l_oSQLConnection2)

        :Table("table003")
        :SetEventId("PostgreSQLDecimalTest")
        :Field("Decimal5_2","523.35")   //To trigger new SchemaAndDataErrorLog
        :Field("Decimal25_7","-1111567890123456.1234567")
        // :Field("DateTime",hb_ctot("02/25/2021 07:24:03:234 pm","mm/dd/yyyy", "hh:mm:ss:fff pp"))
        :Field("DateTime",hb_ctot("02/25/2021 07:24:04:1234","mm/dd/yyyy", "hh:mm:ss:ffff"))
        :Field("time","07:24:05.1234")
        :Add()


        :Table("table003")
        :SetEventId(8)
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
        l_oCursorTable003Records := :p_oCursor  //Will Allow to keep a reference to the cursor and keep it open, even when o_DB2:SQL() would be called

        // l_Tally        := :tally
        // l_LastSQLError := :ErrorMessage()
        // l_LastSQL      := :LastSQL()
        ExportTableToHtmlFile("Table003Records","PostgreSQL_Table003Records.html","From PostgreSQL",,25,.t.)

        :Table("table001")
        :SetEventId("Postgres 9")
        :Field("age","a6")
        :Field("dob",date())
        :Field("dati",hb_datetime())
        :Field("fname","Michael"+' "excetera" 0123456789012345678901234567890123456789012345678901234567890123456789')
        :Field("lname","O'Hara 123")
        :Field("logical1",.t.)
        if :Add()
            l_nKey := :Key()


            :Table("table001")
            :SetEventId(10)
            :Field("fname","Ingrid")
            :Field("lname","1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890")
            :Field("minitial","aBBA2")
            :Update(l_nKey)
        
        endif

        ?"----------------------------------------------"
        :Table("table001")
        :SetEventId(13)
        :Column("table001.key"  ,"key")
        :Column("table001.fname","table001_fname")
        :Column("table001.lname","table001_lname")
        :Column("table002.children","table002_children")
        :Where("table001.key < 4")
        :Where("table001.fname = ^","Ingrid")
        // :Where("table002.children = ^","bbbb")
        :Where("table002.children = ^","127.0.0.1")
        :Join("inner","table002","","table002.p_table001 = table001.key")
        :SQL(10002,"AllRecords")

// altd()  //l_oCursorTable003Records

        // l_LastSQL := :LastSQL()
        // altd()

        if :Tally < 0
            ? :ErrorMessage()
            altd()
        else
            select AllRecords
            scan all
                ?"PostgreSQL "+trans(AllRecords->key)+" - "+allt(AllRecords->table001_fname)+" "+allt(AllRecords->table001_lname)+" "+allt(AllRecords->table002_children)
            endscan
        endif
        ?"----------------------------------------------"

        :SetExplainMode(2)
        :SQL(10007)

    end
endif

l_oSQLConnection1:Disconnect()
?"MariaDB Get last Handle",l_oSQLConnection1:GetHandle()
l_oSQLConnection2:Disconnect()
?"PostgreSQL Get last Handle",l_oSQLConnection2:GetHandle()
altd()
return nil
//=================================================================================================================
//=================================================================================================================
//=================================================================================================================
//=================================================================================================================
