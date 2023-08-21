//Copyright (c) 2023 Eric Lendvai MIT License

//IMPORTANT Set the l_lAccess* and l_lTest* variables below as needed.

REQUEST HB_CODEPAGE_UTF8EX

#include "hb_orm.ch"
#include "hb_vfp.ch"

//=================================================================================================================
Function Main()

local l_lInDocker := (hb_GetEnv("InDocker","False") == "True") .or. File("/.dockerenv")
local l_cOutputFolder := iif(l_lInDocker,"Output/","Output\")

local l_lAccessPostgresql := .t.
local l_lAccessMariaDB    := .f.

local l_lTestUpdates         := .f.
local l_lTestSimpleQueries   := .f.
local l_lTestCombinedQueries := .t.

local l_iSQLHandle
local l_oSQLConnection1
local l_oSQLConnection2
local l_oDB1
local l_oDB2
local l_oDB3
local l_oDB4
local l_oDB5
local l_oDB6
local l_oDB7
local l_oDB8
local l_nKey

local l_xW1

local l_oData

local l_oCursor

local l_hSchemaDefinitionA
local l_hSchemaDefinitionB

local l_cSQLScript
local l_cLastError
local l_cLastSQLError
local l_cLastSQL

local l_nVersion

local l_cPreviousSchemaName

local l_oCursorTable003Records

local l_iCategoryFruit
local l_iCategoryVegetable
local l_iCategoryLiquid

local l_iFruitApples
local l_iFruitBananas

local l_iVegetableBeans
local l_iVegetableCarrots
local l_iVegetableArtichokes

local l_iLiquidWater
local l_iLiquidOil
local l_iLiquidMilk

local l_cFileName
local l_cFullFileName

local l_oCompoundQuery1
local l_oCompoundQuery2
local l_oCompoundQuery3

// local l_iPID := el_GetProcessId()

altd()
hb_cdpSelect("UTF8EX") 

hb_DirCreate(l_cOutputFolder)

//===========================================================================================================================
?"------------------------------------------------------"
//===========================================================================================================================

if l_lInDocker
    l_lAccessMariaDB := .f.
endif

if l_lAccessMariaDB
    l_oSQLConnection1 := hb_SQLConnect()
    with object l_oSQLConnection1
        ?"MariaDB - ORM version - "+:p_hb_orm_version
        :MySQLEngineConvertIdentifierToLowerCase := .f.
        :SetBackendType("MariaDB")
        :SetDriver("MariaDB ODBC 3.1 Driver")
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
endif

if l_lAccessPostgresql
    if l_lInDocker
        l_oSQLConnection2 := hb_SQLConnect("PostgreSQL","PostgreSQL Unicode","host.docker.internal",5432,"postgres","rndrnd","test001","set001")
    else
        l_oSQLConnection2 := hb_SQLConnect("PostgreSQL","PostgreSQL ODBC Driver(UNICODE)","localhost",5432,"postgres","rndrnd","test001","set001")
    endif

    with object l_oSQLConnection2
        ?"PostgreSQL - ORM version - "+:p_hb_orm_version
        :PostgreSQLIdentifierCasing := HB_ORM_POSTGRESQL_CASE_SENSITIVE
        :PostgreSQLHBORMSchemaName := "MyDataDic"
// altd()
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
endif
//===========================================================================================================================

if l_lAccessMariaDB
    if l_oSQLConnection1:Connected
        hb_orm_SendToDebugView("MariaDB table001 exists ",l_oSQLConnection1:TableExists("table001"))
        hb_orm_SendToDebugView("MariaDB UUID",l_oSQLConnection1:GetUUIDString())
    endif
endif

if l_lAccessPostgresql
    if l_oSQLConnection2:Connected
        hb_orm_SendToDebugView("PostgreSQL table001 exists ",l_oSQLConnection2:TableExists("table001"))
        hb_orm_SendToDebugView("PostgreSQL bogus.table001 exists ",l_oSQLConnection2:TableExists("bogus.table001"))
        hb_orm_SendToDebugView("PostgreSQL UUID",l_oSQLConnection2:GetUUIDString())
    endif
endif

hb_orm_SendToDebugView("Will Initialize l_hSchemaDefinitionA")

l_hSchemaDefinitionA := ;
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
,"sysc"    =>{   ,"DTZ",   0,  0,};
,"sysm"    =>{   ,"DTZ",   0,  0,};
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
,"p_table003" =>{,  "I",   0,  0,};
,"char50"     =>{,  "C",  50,  0,"N","'val1A'"};
,"bigint"     =>{, "IB",   0,  0,"N"};
,"Bit"        =>{,  "R",   0,  0,"N"};
,"Decimal5_2" =>{,  "N",   5,  2,"N"};
,"Decimal25_7"=>{,  "N",  25,  7,"N"};
,"VarChar51"  =>{, "CV",  50,  0,"N"};
,"VarChar52"  =>{, "CV",  50,  0,,"'val1B'"};
,"Text"       =>{,  "M",   0,  0,"N"};
,"Binary"     =>{,  "R",   0,  0,"N"};
,"Date"       =>{,  "D",   0,  0,"N"};
,"DateTime"   =>{, "DT",   0,  4,"N","now"};
,"TOZ"        =>{,"TOZ",   0,  0,"N"};
,"TOZ4"       =>{,"TOZ",   0,  4,"N"};
,"TO"         =>{, "TO",   0,  0,"N"};
,"TO4"        =>{, "TO",   0,  4,"N"};
,"DTZ"        =>{,"DTZ",   0,  0,"N"};
,"DTZ4"       =>{,"DTZ",   0,  4,"N"};
,"DT"         =>{, "DT",   0,  0,"N"};
,"DT4"        =>{, "DT",   0,  4,"N"};
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
{"key"                =>{   ,  "I",   0,  0,"+"};
,"integer"            =>{   ,  "I",   0,  0,"N"};
,"many_int"           =>{"P",  "I",   0,  0,"NA"};
,"many_flags"         =>{"P",  "L",   0,  0,"NA"};
,"uuid1"              =>{   ,"UUI",   0,  0,};
,"uuid2"              =>{   ,"UUI",   0,  0,"N","uuid()"};
,"many_uuid"          =>{"P","UUI",   0,  0,"NA"};
,"json1_without_null" =>{   , "JS",   0,  0,""};
,"json2_with_null"    =>{   , "JS",   0,  0,"N"};
,"big_integer"        =>{   , "IB",   0,  0,"N"};
,"small_integer"      =>{   , "IS",   0,  0,"N"};
,"money"              =>{   ,  "Y",   0,  0,};
,"char10"             =>{   ,  "C",  10,  0,"N"};
,"varchar10"          =>{   , "CV",  10,  0,"N"};
,"binary10"           =>{   ,  "B",  10,  0,"N"};
,"varbinary11"        =>{   , "BV",  11,  0,"N"};
,"memo"               =>{   ,  "M",   0,  0,"N"};
,"raw"                =>{   ,  "R",   0,  0,"N"};
,"logical"            =>{   ,  "L",   0,  0,};
,"date"               =>{   ,  "D",   0,  0,"N"};
,"time_with_zone"     =>{   ,"TOZ",   0,  0,"N"};
,"time_no_zone"       =>{   , "TO",   0,  0,"N"};
,"datetime_with_zone" =>{   ,"DTZ",   0,  0,"N"};
,"datetime_no_zone"   =>{   , "DT",   0,  0,"N"}};
,;   //Index Definition
NIL};
,"item_category"=>{;   //Field Definition
{"key"            =>{   ,  "I",   0,  0,"+"};
,"sysc"           =>{   ,"DTZ",   0,  0,};
,"sysm"           =>{   ,"DTZ",   0,  0,};
,"name"           =>{   , "CV",  50,  0,}};
,;   //Index Definition
NIL};
,"item"=>{;   //Field Definition
{"key"              =>{   ,  "I",   0,  0,"+"};
,"sysc"             =>{   ,"DTZ",   0,  0,};
,"sysm"             =>{   ,"DTZ",   0,  0,};
,"fk_item_category" =>{   ,  "I",   0,  0,};
,"name"             =>{   , "CV",  50,  0,};
,"note"             =>{   , "CV", 100,  0,}};
,;   //Index Definition
{"name"            =>{,"name"     ,.f.,"BTREE"};
,"fk_item_category"=>{,"fk_item_category",.f.,"BTREE"}}};
,"price_history"=>{;   //Field Definition
{"key"            =>{   ,  "I",   0,  0,"+"};
,"sysc"           =>{   ,"DTZ",   0,  0,};
,"sysm"           =>{   ,"DTZ",   0,  0,};
,"fk_item"        =>{   ,  "I",   0,  0,};
,"effective_date" =>{   ,  "D",   0,  0,};
,"price"          =>{   ,  "N",   8,  2,}};
,;   //Index Definition
{"fk_item"       =>{,"fk_item"       ,.f.,"BTREE"};
,"effective_date"=>{,"effective_date",.f.,"BTREE"}}};
,"zipcodes"=>{;   //Field Definition
{"key"    =>{, "IB",   0,  0,"+"};
,"zipcode"=>{,  "C",   5,  0,"N"};
,"city"   =>{,  "C",  45,  0,"N"}};
,;   //Index Definition
NIL};
}

hb_orm_SendToDebugView("Initialized l_hSchemaDefinitionA")


hb_orm_SendToDebugView("Will Initialize l_hSchemaDefinitionB")

l_hSchemaDefinitionB := ;
{"set003.ListOfFiles"=>{;   //Field Definition
{"key"                      =>{   ,  "I",   0,  0,"+"};
,"file_name"                =>{   ,  "C", 120,  0,"N"};
,"reference_to_large_object"=>{   ,"OID",   0,  0,"N"}};
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


if l_lAccessMariaDB
    if l_oSQLConnection1:Connected
        l_nVersion := l_oSQLConnection1:GetSchemaDefinitionVersion("AllMySQL v1")
        l_oSQLConnection1:SetSchemaDefinitionVersion("AllMySQL v1"      ,l_nVersion+1)
    endif
endif

if l_lAccessPostgresql
    if l_oSQLConnection2:Connected
        l_nVersion := l_oSQLConnection2:GetSchemaDefinitionVersion("AllPostgreSQL v1")
        l_oSQLConnection2:SetSchemaDefinitionVersion("AllPostgreSQL v1" ,l_nVersion+1)
    endif
endif

//===========================================================================================================================
if l_lAccessMariaDB
    if l_oSQLConnection1:Connected
        l_cFullFileName := l_cOutputFolder+"BeforeUpdatesSchema_MariaDB_"+l_oSQLConnection1:GetDatabase()+".txt"
        hb_orm_SendToDebugView("MariaDB - Will Generate file: "+l_cFullFileName)
        l_oSQLConnection1:GenerateCurrentSchemaHarbourCode(l_cFullFileName)
        hb_orm_SendToDebugView("MariaDB - Generated file: "+l_cFullFileName)

        // altd()
        // l_cSQLScript := l_cLastError := ""
        if el_AUnpack(l_oSQLConnection1:MigrateSchema(l_hSchemaDefinitionA),,@l_cSQLScript,@l_cLastError) > 0
            hb_orm_SendToDebugView("MariaDB - Updated Schema with Definition A")
        else
            if !empty(l_cLastError)
                l_cFullFileName := l_cOutputFolder+"MigrationSqlScript_MariaDB_LastError_"+l_oSQLConnection1:GetDatabase()+"_A.txt"
                hb_MemoWrit(l_cFullFileName,l_cLastError)
                hb_orm_SendToDebugView("MariaDB - Generated file: "+l_cFullFileName)
            endif
        endif
        l_cFullFileName := l_cOutputFolder+"MigrationSqlScript_MariaDB_"+l_oSQLConnection1:GetDatabase()+"_A.txt"
        hb_MemoWrit(l_cFullFileName,l_cSQLScript)
        hb_orm_SendToDebugView("MariaDB - Generated file: "+l_cFullFileName)


        l_cSQLScript := ""
        if el_AUnpack(l_oSQLConnection1:MigrateSchema(l_hSchemaDefinitionB),,@l_cSQLScript,@l_cLastError) > 0
            hb_orm_SendToDebugView("MariaDB - Updated Schema with Definition A")
        else
            if !empty(l_cLastError)
                l_cFullFileName := l_cOutputFolder+"MigrationSqlScript_MariaDB_LastError_"+l_oSQLConnection1:GetDatabase()+"_B.txt"
                hb_MemoWrit(l_cFullFileName,l_cLastError)
                hb_orm_SendToDebugView("MariaDB - Generated file: "+l_cFullFileName)
            endif
        endif
        l_cFullFileName := l_cOutputFolder+"MigrationSqlScript_MariaDB_"+l_oSQLConnection1:GetDatabase()+"_B.txt"
        hb_MemoWrit(l_cFullFileName,l_cSQLScript)
        hb_orm_SendToDebugView("MariaDB - Generated file: "+l_cFullFileName)

    endif
endif
//===========================================================================================================================
if l_lAccessPostgresql
    if l_oSQLConnection2:Connected

        l_oSQLConnection2:SetCurrentSchemaName("set001")

        hb_orm_SendToDebugView("PostgreSQL - Will GenerateCurrentSchemaHarbourCode")
        l_oSQLConnection2:GenerateCurrentSchemaHarbourCode(l_cOutputFolder+"CurrentSchema_PostgreSQL_"+l_oSQLConnection2:GetDatabase()+".txt")
        hb_orm_SendToDebugView("PostgreSQL - Done CurrentSchema_PostgreSQL_...text")

        l_cSQLScript := ""
        if el_AUnpack(l_oSQLConnection2:MigrateSchema(l_hSchemaDefinitionA),,@l_cSQLScript,@l_cLastError) > 0
            hb_orm_SendToDebugView("PostgreSQL - Updated MigrationSqlScript_PostgreSQL_set001.txt")
        else
            if !empty(l_cLastError)
                hb_orm_SendToDebugView("PostgreSQL - Failed Migrate MigrationSqlScript_PostgreSQL_set001_....txt")
                hb_MemoWrit(l_cOutputFolder+"MigrationSqlScript_PostgreSQL_set001_LastError_"+l_oSQLConnection2:GetDatabase()+".txt",l_cLastError)
            endif
        endif
        hb_MemoWrit(l_cOutputFolder+"MigrationSqlScript_PostgreSQL_set001_"+l_oSQLConnection2:GetDatabase()+".txt",l_cSQLScript)


        l_cPreviousSchemaName := l_oSQLConnection2:SetCurrentSchemaName("set002")

        l_cSQLScript := ""
        if el_AUnpack(l_oSQLConnection2:MigrateSchema(l_hSchemaDefinitionB),,@l_cSQLScript,@l_cLastError) > 0
            hb_orm_SendToDebugView("PostgreSQL - Updated MigrationSqlScript_PostgreSQL_set002....txt")
        else
            if !empty(l_cLastError)
                hb_orm_SendToDebugView("PostgreSQL - Failed Migrate MigrationSqlScript_PostgreSQL_set002_....txt")
                hb_MemoWrit(l_cOutputFolder+"MigrationSqlScript_PostgreSQL_set002_LastError_"+l_oSQLConnection2:GetDatabase()+".txt",l_cLastError)
            endif
        endif
        hb_MemoWrit(l_cOutputFolder+"MigrationSqlScript_PostgreSQL_set002_"+l_oSQLConnection2:GetDatabase()+".txt",l_cSQLScript)








        l_oSQLConnection2:SetCurrentSchemaName(l_cPreviousSchemaName)
        

        l_oSQLConnection2:Lock("set001.table001",1000)
        l_oSQLConnection2:Lock("set001.table001",1000)
        l_oSQLConnection2:Lock("set001.table001",1000)
        l_oSQLConnection2:Lock("set001.table001",1001)
        l_oSQLConnection2:Lock("set001.table001",1002)
        l_oSQLConnection2:Unlock("set001.table001",1000)

    endif
endif
//===========================================================================================================================

//-----------------------------------------------------------------------------------------------------------------------
if l_lTestUpdates
    if l_lAccessMariaDB
        if l_oSQLConnection1:Connected
            l_oDB1 := hb_SQLData(l_oSQLConnection1)
            with object l_oDB1

                :Table("MySQLAddAllTypes","alltypes")
                :Field("integer"            ,123)
                :Field("big_integer"        ,10**15)
                :Field("money"              ,123456.1245)
                :Field("char10"             ,"Hello World Hello World Hello World")
                :Field("varchar10"          ,"Hello World Hello World Hello World")
                :Field("binary10"           ,"01010")
                // :Field("varbinary10"       ,"0101010101010")
                :Field("memo"               ,"Test")
                :Field("raw"                ,"Test")
                :Field("logical"            ,.t.)
                :Field("date"               ,hb_ctod("02/24/2021"))
                :Field("time_with_zone"     ,"11:12:13")
                :Field("time_no_zone"       ,"11:12:13")
                
                // :Field("datetime_with_zone" ,hb_ctot("02/24/2021 11:12:13"))
                :FieldExpression("datetime_with_zone" ,"now()")

                :Field("datetime_no_zone"   ,hb_ctot("02/24/2021 11:12:13"))
                :Field("json1_without_null" ,'{"id": "1234567"}')
                :Field("uuid1"              ,'11111111-2222-3333-4444-555555555555')
                :Add()

                :Table("MySQLDecimalTest","table003")
                :Field("Decimal5_2","523.35")   //To trigger new SchemaAndDataErrorLog
                :Field("Decimal25_7","-1111567890123456.1234567")
                // :Field("DateTime",hb_ctot("02/25/2021 07:24:03:234 pm","mm/dd/yyyy", "hh:mm:ss:fff pp"))
                :Field("DateTime",hb_ctot("02/25/2021 07:24:04:1234","mm/dd/yyyy", "hh:mm:ss:ffff"))
                // :Field("char50","test1")
                :Add()

                // :UseConnection(l_oSQLConnection1)

                :Table("mysql 1","table003")
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

                :SQL("Table003Records")
                ? :LastSQL()

    // altd()
                if hb_orm_isnull("Table003Records","table003_Bigint")
                    ?"table003.bigint is null"
                else
                    ?"table003.bigint is not null"
                endif

                if hb_orm_isnull("Table003Records","table003_Decimal5_2")
                    ?"table003.Decimal5_2 is null"
                else
                    ?"table003.Decimal5_2 is not null"
                endif


                //Example of adding a record and adding a local index in activating it
                l_oCursor := l_oDB1:p_oCursor

                l_oCursor:AppendBlank() //Blank Record
                // l_oCursor:SetFieldValue("TABLE003_CHAR50","Bogus")

                l_oCursor:InsertRecord({"TABLE003_CHAR50" => "Fabulous",;
                                        "TABLE003_BIGINT" => 1234})

                l_oCursor:Index("tag1","TABLE003_CHAR50")
                l_oCursor:CreateIndexes()
                l_oCursor:SetOrder("tag1")
                
                // l_Tally         := :tally
                // l_cLastSQLError := :ErrorMessage()
                // l_cLastSQL      := :LastSQL()
                // l_TestResult   := l_oSQLConnection1:p_Schema["table003"][1]

                ExportTableToHtmlFile("Table003Records",l_cOutputFolder+"MySQL_Table003Records","From MySQL",,,.t.)


                :Table(2,"table001")
                :Field("age","5")   //To trigger new SchemaAndDataErrorLog
                :Field("dob",date())
                :Field("dati",hb_datetime())
                :Field("fname","Michael"+' "excetera2" 0123456789012345678901234567890123456789012345678901234567890123456789')
                :Field("lname","O'Hara 123")
                // :Field("logical1",NIL)
                if :Add()
                    l_nKey := :Key()

                    :Table(3,"table001")
                    :Field("fname"   ,"Ingrid2")
                    :Field("lname","1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890")
                    :Field("minitial","aBBA2")
                    :Update(l_nKey)
                
                    // :Table(4,"table001")
                    // :Column("table001.fname","table001_fname")
                    // :Join("inner","table003","","table001.key = table003.key")
                    // l_oData := :Get(l_nKey) 

                    :Table(5,"table001")
                    :Column("table001.fname","table001_fname")
                    l_oData := :Get(l_nKey)

                    ?"Add record with key = "+Trans(l_nKey)+" First Name = "+l_oData:table001_fname

                endif

                :Table(6,"table001")
                // :Join("inner","table002","","table002.p_table001 = table001 and key = ^",5)
                l_xW1 := :Join("inner","table002","","table002.p_table001 = table001")
                :ReplaceJoin(l_xW1,"inner","table002","","table002.p_table001 = table001.key")

                l_xW1 := :Where("table001.fname = ^","Jodie")
                :Where("table001.lname = ^","Foster")
                :ReplaceWhere(l_xW1,"table001.fname = ^","Harrison")

                l_xW1 := :Having("table001.fname = ^","Jodie")
                :Having("table001.lname = ^","Foster")
                :ReplaceHaving(l_xW1,"table001.fname = ^","Harrison")

                //:KeywordCondition("Jodie","fname+lname","or",.t.)
                
                ?"----------------------------------------------"
                :Table(7,"table001")
                :Column("table001.key"  ,"key")
                :Column("table001.fname","table001_fname")
                :Column("table001.lname","table001_lname")
                :Column("table002.children","table002_children")
                :Where("table001.key < 4")
                :Join("inner","table002","","table002.p_table001 = table001.key")
                :SQL("AllRecords")
                
                ?"Will use scan/endscan"
                select AllRecords
                index on upper(field->table001_fname) tag ufname to AllRecords

                scan all
                    ?"MySQL "+trans(AllRecords->key)+" - "+allt(AllRecords->table001_fname)+" "+allt(AllRecords->table001_lname)+" "+allt(AllRecords->table002_children)
                endscan
                
                ExportTableToHtmlFile("AllRecords",l_cOutputFolder+"MySQL_Table001_Join_Table002","From MySQL",,,.t.)

                ?"----------------------------------------------"


                :SetExplainMode(2)
                :SQL()
                l_oCursor:Close()


            endwith
        endif
    endif

    if l_lAccessPostgresql
        if l_oSQLConnection2:Connected
            l_oDB2 := hb_SQLData()
            with object l_oDB2
                :UseConnection(l_oSQLConnection2)



    //Temporary code used to test SaveFile() .... methods
                // :Table("8086c321-f176-4db9-bb25-6cfcf87c58ba","set003.ListOfFiles")
                // :Field("file_name","LastExport.Zip")
                // if :Add()
                //     l_nKey := :Key()
                //     :SaveFile("f5a83e74-1246-4f91-9db3-7842570a080a","set003.ListOfFiles",l_nKey,"reference_to_large_object","d:\LastExport.Zip")
                // endif

                // l_nKey := 1
                // l_cFileName := "build_harbour.sh"
                // :Table("8086c321-f176-4db9-bb25-6cfcf87c58bb","set003.ListOfFiles")
                // :Field("file_name",l_cFileName)
                // if :Update(l_nKey)
                //     :SaveFile("f5a83e74-1246-4f91-9db3-7842570a080a","set003.ListOfFiles",l_nKey,"reference_to_large_object","d:\"+l_cFileName)
                // endif

                // l_nKey := 1
                // if !:DeleteFile("f5a83e74-1246-4f91-9db3-7842570a080c","set003.ListOfFiles",l_nKey,"reference_to_large_object")  //
                //     ?"1-ERROR "+:ErrorMessage()
                // endif

                // l_nKey := 2
                // if !:GetFile("f5a83e74-1246-4f91-9db3-7842570a080d","set003.ListOfFiles",l_nKey,"reference_to_large_object","d:\Bogus2.Zip")
                //     ?"2-ERROR "+:ErrorMessage()
                // endif


                // // Code to test how index using expression functions and also searching on shorter text
                // :Table("123456","set003.ListOfFiles","ListOfFiles")
                // :Column("ListOfFiles.key","key")
                // :Column("ListOfFiles.file_name","file_name")
                // :SQL("ListOfFiles")
                // with object :p_oCursor
                //     // :Index("tag1","padr(trans(key)+'*'+upper(alltrim(file_name)),240)")
                //     // :Index("tag1","padr('2'+upper(alltrim(file_name)),240)")
                //     // :Index("tag1","padr(alltrim(str(key))+upper(alltrim(file_name)),240)")
                    
                //     :Index("tag1","padr(trans(key)+'*'+upper(alltrim(file_name)),240)")
                //     :Index("tag2","padr(alltrim(str(key))+'*'+upper(alltrim(file_name)),240)")

                //     // :Index("tag1","padr(alltrim(str(key))+'*'+upper(alltrim(file_name)),240)")
                //     // :Index("tag2","alltrim(str(key))+'*'+upper(strtran(file_name,' ',''))+'*',240)")
                //     :CreateIndexes()
                // endwith
                // select ListOfFiles
                // scan all
                //     ?"Tag1 Index",">"+padr(trans(ListOfFiles->key)+'*'+upper(alltrim(ListOfFiles->file_name)),240)+"<"
                // endscan
                // ExportTableToHtmlFile("ListOfFiles",l_cOutputFolder+"Postgresql_ListOfFiles","From Postgresql",,,.t.)
                // ?"Seek test 001",vfp_seek(upper("LastExport.Zip"),"ListOfFiles","tag1"),ListOfFiles->key
                // ?"Seek test 002 - tag1",vfp_seek(upper("2*LastExp")       ,"ListOfFiles","tag1"),ListOfFiles->key
                // ?"Seek test 002 - tag2",vfp_seek(upper("2*LastExp")       ,"ListOfFiles","tag2"),ListOfFiles->key
                // ?"Seek test 003",vfp_seek(upper("build")         ,"ListOfFiles","tag1"),ListOfFiles->key







                :Table("PostgreSQLAddAllTypes","alltypes")
                :Field("integer"            ,123)
                :Field("big_integer"        ,10**15)
                :Field("money"              ,123456.1245)
                :Field("char10"             ,"Hello World Hello World Hello World")
                :Field("varchar10"          ,"Hello World Hello World Hello World")
                :Field("binary10"           ,"01010")
                // :Field("varbinary10"        ,"0101010101010")
                :Field("memo"               ,"Test")
                :Field("raw"                ,"Test")
                :Field("logical"            ,.t.)
                :Field("date"               ,hb_ctod("02/24/2021"))
                :Field("time_with_zone"     ,"11:12:13")
                :Field("time_no_zone"       ,"11:12:13")

                // :Field("datetime_with_zone" ,hb_ctot("02/24/2021 11:12:13"))
                :FieldExpression("datetime_with_zone" ,"now()")

                :Field("datetime_no_zone"   ,hb_ctot("02/24/2021 11:12:13"))
                :Field("json1_without_null" ,'{"id": "123456"}::json')
                :Field("uuid1"              ,'11111111-2222-3333-4444-555555555555::uuid')


                :FieldArray("many_int",{1,2,3,4})
                :FieldArray("many_flags",{.f.,.f.,.t.})
                :FieldArray("many_uuid",{'46d8e196-1111-4404-b167-3756dfa32555','46d8e196-2222-4404-b167-3756dfa32555'})

                if :Add()
                //     l_nKey := :Key()
                //     :Table("PostgreSQLAddAllTypes","alltypes")
                //     :Field("json1"             ,'{"id": "123456789"}')
                //     :Update(l_nKey)
                endif

    ? "Will display :LastSQL()"
    ? :LastSQL()
    // l_cLastSQL := :LastSQL()
    // ? l_cLastSQL

                :Table( "fc20f0e9-fb3e-4094-9df3-591095385a1b","alltypes")
                :Column("alltypes.key"               ,"key")
                :Column("alltypes.money"             ,"money")
                :Column("alltypes.json1_without_null","json1_without_null")
                :Column("alltypes.uuid1"             ,"uuid1")
                :Column("alltypes.many_uuid"         ,"many_uuid")
                :Column("alltypes.many_int"          ,"many_int")
                :Column("alltypes.many_flags"        ,"many_flags")
                :OrderBy("key","desc")
                :Limit(11)
                :SQL("AllTypesRecords")
                if :Tally < 0
                    ?"SQL on AllTypesRecords : Last SQL Error = "+:ErrorMessage()
                    ?"SQL on AllTypesRecords : Last SQL Command = "+:LastSQL()
                endif

                ExportTableToHtmlFile("AllTypesRecords",l_cOutputFolder+"Postgresql_AllTypesRecords","From Postgresql",,,.t.)
                //html


                :Table("PostgreSQLAddAllTypes","alltypes")
                :Field("integer" ,124)
                if :Add()
                    l_nKey = :Key()
                    :Table("PostgreSQLAddAllTypes","alltypes")
                    :FieldArray("many_int",{5,1,0})
                    :FieldArray("many_flags",{.t.,.f.,.t.})
                    :FieldArray("many_uuid",{'46d8e196-3333-4404-b167-3756dfa32555','46d8e196-2222-4404-b167-3756dfa32555'})
                    :Update(l_nKey)
                endif



                :Table("PostgreSQLDecimalTest","table003")
                :Field("Decimal5_2","523.35")   //To trigger new SchemaAndDataErrorLog
                :Field("Decimal25_7","-1111567890123456.1234567")
                // :Field("DateTime",hb_ctot("02/25/2021 07:24:03:234 pm","mm/dd/yyyy", "hh:mm:ss:fff pp"))
                :Field("DateTime",hb_ctot("02/25/2021 07:24:04:1234","mm/dd/yyyy", "hh:mm:ss:ffff"))
                :Field("time","07:24:05.1234")
                // :Field("Boolean",.t.)
                :Add()


                :Table("PostgreSQLDecimalTest","table003")
                :Field("Decimal5_2","523.35")   //To trigger new SchemaAndDataErrorLog
                :Field("Decimal25_7","-1111567890123456.1234567")
                // :Field("DateTime",hb_ctot("02/25/2021 07:24:03:234 pm","mm/dd/yyyy", "hh:mm:ss:fff pp"))
                :Field("DateTime",hb_datetime())
                :Field("text",Replicate("0123456789",1000))   //Replicate(<cString>,<nCount>)
                :Field("time","07:24:05.1234")
                :Field("char50","élevé")   //UTF support

                // :Field("Boolean",.t.)
                :Add()


                :Table(8,"table003")
                :Column("table003.key"        ,"table003_key")
                :Column("table003.char50"     ,"table003_char50")
                :Column("table003.bigint"     ,"table003_Bigint")
                :Column("table003.Bit"        ,"table003_Bit")
                :Column("table003.Decimal5_2" ,"table003_Decimal5_2")
                :Column("table003.Varchar51"  ,"table003_Varchar51")
                :Column("table003.Text::varchar(1000)" ,"table003_Text")
                :Column("table003.BInary"     ,"table003_Binary")
                // :Column("table003.Varbinary55","table003_Varbinary55")
                :Column("table003.Date"       ,"table003_Date")
                :Column("table003.DateTime"   ,"table003_DateTime")
                :Column("table003.time"       ,"table003_Time")
                :Column("table003.Boolean"    ,"table003_Boolean")

                :Column("table003.TOZ"  ,"table003_TOZ")
                :Column("table003.TOZ4" ,"table003_TOZ4")
                :Column("table003.TO"   ,"table003_TO")
                :Column("table003.TO4"  ,"table003_TO4")
                :Column("table003.DTZ"  ,"table003_DTZ")
                :Column("table003.DTZ4" ,"table003_DTZ4")
                :Column("table003.DT"   ,"table003_DT")
                :Column("table003.DT4"  ,"table003_DT4")

                :OrderBy("table003_key","desc")
                //:Limit(10)
                :SQL("Table003Records")
                l_oCursorTable003Records := :p_oCursor  //Will Allow to keep a reference to the cursor and keep it open, even when l_oDB2:SQL() would be called

                // l_Tally        := :tally
                // l_cLastSQLError := :ErrorMessage()
    // l_cLastSQL      := :LastSQL()
    // altd()

    ?"valtype(Table003Records->table003_Time)     = ",valtype(Table003Records->table003_Time)    ,"  ",Table003Records->table003_Time
    ?"valtype(Table003Records->table003_DateTime) = ",valtype(Table003Records->table003_DateTime),"  ",Table003Records->table003_DateTime


    ?"1. >"+hb_TtoC(Table003Records->table003_Time)+"<"
    ?"1.5>"+hb_TtoC(hb_datetime())
    ?"1.6>",hb_CtoT("04/02/1969 11:05:123 pm", "mm/dd/yyyy", "hh:ss:fff pp")
    ?"1.7>",hb_CtoT("  /  /     11:06:123 pm", "mm/dd/yyyy", "hh:ss:fff pp")
    // ?"2. >"+hb_CtoT(hb_TtoC(hb_datetime()),"mm/dd/yy","hh:mm:ss.fff")+"<"
    // ?"3. >"+hb_CtoT(hb_TtoC(Table003Records->table003_Time),"mm/dd/yyyy","hh:mm:ss")+"<"


    l_cLastSQLError := :ErrorMessage()
    if !empty(l_cLastSQLError)
        ?"l_cLastSQLError = ",l_cLastSQLError
    endif

                ExportTableToHtmlFile("Table003Records",l_cOutputFolder+"PostgreSQL_Table003Records.html","From PostgreSQL",,25,.t.)

                :Table("Postgres 9","table001")
                :Field("age","a6")
                :Field("dob",date())
                :Field("dati",hb_datetime())
                :Field("fname","Michael"+' "excetera" 0123456789012345678901234567890123456789012345678901234567890123456789')
                :Field("lname","O'Hara 123")
                :Field("logical1",.t.)
                if :Add()
                    l_nKey := :Key()


                    :Table(10,"table001")
                    :Field("fname","Ingrid")
                    :Field("lname","1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890")
                    :Field("minitial","aBBA2")
                    :Update(l_nKey)
                
                endif

                ?"----------------------------------------------"
                :Table(13,"table001")
                :Column("table001.key"  ,"key")
                :Column("table001.fname","table001_fname")
                :Column("table001.lname","table001_lname")
                :Column("table002.children","table002_children")
                :Where("table001.key < 4")
                :Where("table001.fname = ^","Ingrid")
                // :Where("table002.children = ^","bbbb")
                :Where("table002.children = ^","127.0.0.1")
                :Join("inner","table002","","table002.p_table001 = table001.key")
                :SQL("AllRecords")

                ? :LastSQL()
                // l_cLastSQL := :LastSQL()
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
                :SQL()

                //Setup data in item_category, item and price_history tables
                :Table(14,"item_category")
                if :Count() == 0
                    :Table(15,"item_category")
                    :Field("item_category.name" , "Fruit")
                    :Add()
                    l_iCategoryFruit := :Key()

                    :Field("item_category.name" , "Vegetable")
                    :Add()
                    l_iCategoryVegetable := :Key()

                    :Field("item_category.name" , "Liquid")
                    :Add()
                    l_iCategoryLiquid := :Key()

                    :Table(16,"item")

                    :Field("item.fk_item_category" , l_iCategoryFruit)
                    :Field("item.name"             , "Apples")
                    :Add()
                    l_iFruitApples := :Key()

                    :Field("item.fk_item_category" , l_iCategoryFruit)
                    :Field("item.name"             , "Bananas")
                    :Add()
                    l_iFruitBananas := :Key()

                    :Field("item.fk_item_category" , l_iCategoryVegetable)
                    :Field("item.name"             , "Beans")
                    :Add()
                    l_iVegetableBeans := :Key()

                    :Field("item.fk_item_category" , l_iCategoryVegetable)
                    :Field("item.name"             , "Carrots")
                    :Add()
                    l_iVegetableCarrots := :Key()

                    :Field("item.fk_item_category" , l_iCategoryVegetable)
                    :Field("item.name"             , "Artichokes")
                    :Add()
                    l_iVegetableArtichokes := :Key()

                    :Field("item.fk_item_category" , l_iCategoryLiquid)
                    :Field("item.name"             , "Water")
                    :Add()
                    l_iLiquidWater := :Key()

                    :Field("item.fk_item_category" , l_iCategoryLiquid)
                    :Field("item.name"             , "Oil")
                    :Add()
                    l_iLiquidOil := :Key()

                    :Field("item.fk_item_category" , l_iCategoryLiquid)
                    :Field("item.name"             , "Milk")
                    :Add()
                    l_iLiquidMilk := :Key()

                    :Table(17,"price_history")
                    :Field("price_history.fk_item"        , l_iFruitApples)
                    :Field("price_history.effective_date" , {^ 2022-05-01})
                    :Field("price_history.price"          , 1.92)
                    :Add()

                    :Field("price_history.fk_item"        , l_iFruitApples)
                    :Field("price_history.effective_date" , {^ 2022-05-15})
                    :Field("price_history.price"          , 2.13)
                    :Add()

                    :Field("price_history.fk_item"        , l_iFruitApples)
                    :Field("price_history.effective_date" , {^ 2022-06-02})
                    :Field("price_history.price"          , 0.98)
                    :Add()

                    :Field("price_history.fk_item"        , l_iFruitBananas)
                    :Field("price_history.effective_date" , {^ 2022-04-01})
                    :Field("price_history.price"          , 1.13)
                    :Add()

                    :Field("price_history.fk_item"        , l_iFruitBananas)
                    :Field("price_history.effective_date" , {^ 2022-05-01})
                    :Field("price_history.price"          , 1.21)
                    :Add()


                    :Field("price_history.fk_item"        , l_iVegetableBeans)
                    :Field("price_history.effective_date" , {^ 2022-02-01})
                    :Field("price_history.price"          , 2.01)
                    :Add()

                    :Field("price_history.fk_item"        , l_iVegetableBeans)
                    :Field("price_history.effective_date" , {^ 2022-02-02})
                    :Field("price_history.price"          , 2.02)
                    :Add()

                    :Field("price_history.fk_item"        , l_iVegetableBeans)
                    :Field("price_history.effective_date" , {^ 2022-02-03})
                    :Field("price_history.price"          , 2.03)
                    :Add()

                    :Field("price_history.fk_item"        , l_iVegetableCarrots)
                    :Field("price_history.effective_date" , {^ 2021-12-03})
                    :Field("price_history.price"          , 13.96)
                    :Add()

                    // local l_iVegetableArtichokes

                    :Field("price_history.fk_item"        , l_iLiquidWater)
                    :Field("price_history.effective_date" , {^ 2021-12-31})
                    :Field("price_history.price"          , 31.01)
                    :Add()

                    :Field("price_history.fk_item"        , l_iLiquidWater)
                    :Field("price_history.effective_date" , {^ 2021-12-01})
                    :Field("price_history.price"          , 12.01)
                    :Add()

                    :Field("price_history.fk_item"        , l_iLiquidWater)
                    :Field("price_history.effective_date" , {^ 2021-11-01})
                    :Field("price_history.price"          , 11.01)
                    :Add()

                    :Field("price_history.fk_item"        , l_iLiquidOil)
                    :Field("price_history.effective_date" , {^ 2021-11-01})
                    :Field("price_history.price"          , 11.01)
                    :Add()

                    :Field("price_history.fk_item"        , l_iLiquidMilk)
                    :Field("price_history.effective_date" , {^ 2021-11-01})
                    :Field("price_history.price"          , 11.01)
                    :Add()

                endif

                :Table(18,"set001.item_category")
                :Column("item_category.name"           ,"item_category_name")
                :Column("item.name"                    ,"item_name")
                :Column("price_history.effective_date" ,"price_history_effective_date")
                :Column("price_history.price"          ,"price_history_price")

                :Column("item.sysm"                    ,"item_sysm")

                :Join("inner","set001.item"         ,"","item.fk_item_category = item_category.key")
                :Join("inner","set001.price_history","","price_history.fk_item = item.key")

                :DistinctOn("item_category_name")
                :DistinctOn("item_name")
                :OrderBy("price_history_effective_date","desc")

                :SQL("AllItems")

                ? :LastSQL()
                // l_cLastSQL := :LastSQL()
                // altd()

                ExportTableToHtmlFile("AllItems",l_cOutputFolder+"PostgreSQL_AllItems.html","From PostgreSQL",,25,.t.)


            end

        endif
    endif
endif


//-----------------------------------------------------------------------------------------------------------------------
if l_lTestSimpleQueries

    if l_lAccessMariaDB
        if l_oSQLConnection1:Connected
            l_oDB1 := hb_SQLData(l_oSQLConnection1)
            with object l_oDB1



                :Table("mysql 1","table003")
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

                :SQL("Table003Records")
                ? :LastSQL()

                if hb_orm_isnull("Table003Records","table003_Bigint")
                    ?"table003.bigint is null"
                else
                    ?"table003.bigint is not null"
                endif

                if hb_orm_isnull("Table003Records","table003_Decimal5_2")
                    ?"table003.Decimal5_2 is null"
                else
                    ?"table003.Decimal5_2 is not null"
                endif


                //Example of adding a record and adding a local index in activating it
                l_oCursor := l_oDB1:p_oCursor

                l_oCursor:AppendBlank() //Blank Record
                // l_oCursor:SetFieldValue("TABLE003_CHAR50","Bogus")

                l_oCursor:InsertRecord({"TABLE003_CHAR50" => "Fabulous",;
                                        "TABLE003_BIGINT" => 1234})

                l_oCursor:Index("tag1","TABLE003_CHAR50")
                l_oCursor:CreateIndexes()
                l_oCursor:SetOrder("tag1")
                
                ExportTableToHtmlFile("Table003Records",l_cOutputFolder+"MySQL_Table003Records","From MySQL",,,.t.)


                :Table(2,"table001")
                :Field("age","5")   //To trigger new SchemaAndDataErrorLog
                :Field("dob",date())
                :Field("dati",hb_datetime())
                :Field("fname","Michael"+' "excetera2" 0123456789012345678901234567890123456789012345678901234567890123456789')
                :Field("lname","O'Hara 123")
                // :Field("logical1",NIL)
                if :Add()
                    l_nKey := :Key()

                    :Table(3,"table001")
                    :Field("fname"   ,"Ingrid2")
                    :Field("lname","1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890")
                    :Field("minitial","aBBA2")
                    :Update(l_nKey)
                
                    // :Table(4,"table001")
                    // :Column("table001.fname","table001_fname")
                    // :Join("inner","table003","","table001.key = table003.key")
                    // l_oData := :Get(l_nKey) 

                    :Table(5,"table001")
                    :Column("table001.fname","table001_fname")
                    l_oData := :Get(l_nKey)

                    ?"Add record with key = "+Trans(l_nKey)+" First Name = "+l_oData:table001_fname

                endif

                :Table(6,"table001")
                // :Join("inner","table002","","table002.p_table001 = table001 and key = ^",5)
                l_xW1 := :Join("inner","table002","","table002.p_table001 = table001")
                :ReplaceJoin(l_xW1,"inner","table002","","table002.p_table001 = table001.key")

                l_xW1 := :Where("table001.fname = ^","Jodie")
                :Where("table001.lname = ^","Foster")
                :ReplaceWhere(l_xW1,"table001.fname = ^","Harrison")

                l_xW1 := :Having("table001.fname = ^","Jodie")
                :Having("table001.lname = ^","Foster")
                :ReplaceHaving(l_xW1,"table001.fname = ^","Harrison")

                //:KeywordCondition("Jodie","fname+lname","or",.t.)
                
                ?"----------------------------------------------"
                :Table(7,"table001")
                :Column("table001.key"  ,"key")
                :Column("table001.fname","table001_fname")
                :Column("table001.lname","table001_lname")
                :Column("table002.children","table002_children")
                :Where("table001.key < 4")
                :Join("inner","table002","","table002.p_table001 = table001.key")
                :SQL("AllRecords")
                
                ?"Will use scan/endscan"
                select AllRecords
                index on upper(field->table001_fname) tag ufname to AllRecords

                scan all
                    ?"MySQL "+trans(AllRecords->key)+" - "+allt(AllRecords->table001_fname)+" "+allt(AllRecords->table001_lname)+" "+allt(AllRecords->table002_children)
                endscan
                
                ExportTableToHtmlFile("AllRecords",l_cOutputFolder+"MySQL_Table001_Join_Table002","From MySQL",,,.t.)

                ?"----------------------------------------------"


                :SetExplainMode(2)
                :SQL()
                l_oCursor:Close()


            endwith
        endif
    endif

    if l_lAccessPostgresql
        if l_oSQLConnection2:Connected
            l_oDB2 := hb_SQLData()
            with object l_oDB2
                :UseConnection(l_oSQLConnection2)


                :Table( "fc20f0e9-fb3e-4094-9df3-591095385a1b","alltypes")
                :Column("alltypes.key"               ,"key")
                :Column("alltypes.money"             ,"money")
                :Column("alltypes.json1_without_null","json1_without_null")
                :Column("alltypes.uuid1"             ,"uuid1")
                :Column("alltypes.many_uuid"         ,"many_uuid")
                :Column("alltypes.many_int"          ,"many_int")
                :Column("alltypes.many_flags"        ,"many_flags")
                :OrderBy("key","desc")
                :Limit(11)
                :SQL("AllTypesRecords")
                if :Tally < 0
                    ?"SQL on AllTypesRecords : Last SQL Error = "+:ErrorMessage()
                    ?"SQL on AllTypesRecords : Last SQL Command = "+:LastSQL()
                endif

                ExportTableToHtmlFile("AllTypesRecords",l_cOutputFolder+"Postgresql_AllTypesRecords","From Postgresql",,,.t.)
                //html


                :Table(8,"table003")
                :Column("table003.key"        ,"table003_key")
                :Column("table003.char50"     ,"table003_char50")
                :Column("table003.bigint"     ,"table003_Bigint")
                :Column("table003.Bit"        ,"table003_Bit")
                :Column("table003.Decimal5_2" ,"table003_Decimal5_2")
                :Column("table003.Varchar51"  ,"table003_Varchar51")
                :Column("table003.Text::varchar(1000)" ,"table003_Text")
                :Column("table003.BInary"     ,"table003_Binary")
                // :Column("table003.Varbinary55","table003_Varbinary55")
                :Column("table003.Date"       ,"table003_Date")
                :Column("table003.DateTime"   ,"table003_DateTime")
                :Column("table003.time"       ,"table003_Time")
                :Column("table003.Boolean"    ,"table003_Boolean")

                :Column("table003.TOZ"  ,"table003_TOZ")
                :Column("table003.TOZ4" ,"table003_TOZ4")
                :Column("table003.TO"   ,"table003_TO")
                :Column("table003.TO4"  ,"table003_TO4")
                :Column("table003.DTZ"  ,"table003_DTZ")
                :Column("table003.DTZ4" ,"table003_DTZ4")
                :Column("table003.DT"   ,"table003_DT")
                :Column("table003.DT4"  ,"table003_DT4")

                :OrderBy("table003_key","desc")
                //:Limit(10)
                :SQL("Table003Records")
                l_oCursorTable003Records := :p_oCursor  //Will Allow to keep a reference to the cursor and keep it open, even when l_oDB2:SQL() would be called

                ?"Number of records in Table003Records "+alltrim(str(:Tally))

                ?"----------------------------------------------"
                :Table(13,"table001")
                :Column("table001.key"  ,"key")
                :Column("table001.fname","table001_fname")
                :Column("table001.lname","table001_lname")
                :Column("table002.children","table002_children")
                :Where("table001.key < 4")
                :Where("table001.fname = ^","Ingrid")
                // :Where("table002.children = ^","bbbb")
                :Where("table002.children = ^","127.0.0.1")
                :Join("inner","table002","","table002.p_table001 = table001.key")
                :SQL("AllRecords")

                ? :LastSQL()
                // l_cLastSQL := :LastSQL()
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
                :SQL()


                :Table(18,"set001.item_category")
                :Column("item_category.name"           ,"item_category_name")
                :Column("item.name"                    ,"item_name")
                :Column("price_history.effective_date" ,"price_history_effective_date")
                :Column("price_history.price"          ,"price_history_price")

                :Column("item.sysm"                    ,"item_sysm")

                :Join("inner","set001.item"         ,"","item.fk_item_category = item_category.key")
                :Join("inner","set001.price_history","","price_history.fk_item = item.key")

                :DistinctOn("item_category_name")
                :DistinctOn("item_name")
                :OrderBy("price_history_effective_date","desc")

                :SQL("AllItems")

                ? :LastSQL()
                // l_cLastSQL := :LastSQL()
                // altd()

                ExportTableToHtmlFile("AllItems",l_cOutputFolder+"PostgreSQL_AllItems.html","From PostgreSQL",,25,.t.)


            end

        endif
    endif

endif




//-----------------------------------------------------------------------------------------------------------------------
if l_lTestCombinedQueries

    if l_lAccessMariaDB
        if l_oSQLConnection1:Connected
            l_oDB1 := hb_SQLData(l_oSQLConnection1)
            with object l_oDB1

            endwith
        endif
    endif

    if l_lAccessPostgresql
        if l_oSQLConnection2:Connected
            l_oDB2 := hb_SQLData(l_oSQLConnection2)
            l_oDB3 := hb_SQLData(l_oSQLConnection2)
            l_oDB4 := hb_SQLData(l_oSQLConnection2)
            l_oDB5 := hb_SQLData(l_oSQLConnection2)
            l_oDB6 := hb_SQLData(l_oSQLConnection2)
            l_oDB7 := hb_SQLData(l_oSQLConnection2)
            l_oDB8 := hb_SQLData(l_oSQLConnection2)

            //----------------------------------
            with object l_oDB2

                :Table("f93a07dd-cd75-48f4-b0bc-5f3e5619e8ed","set001.item_category")
                :Column("item_category.name"           ,"item_category_name")
                :Column("item.name"                    ,"item_name")
                :Column("price_history.effective_date" ,"price_history_effective_date")
                :Column("price_history.price"          ,"price_history_price")

                :Column("item.sysm"                    ,"item_sysm")

                :Join("inner","set001.item"         ,"","item.fk_item_category = item_category.key")
                :Join("inner","set001.price_history","","price_history.fk_item = item.key")

                :DistinctOn("item_category_name")
                :DistinctOn("item_name")
                :OrderBy("price_history_effective_date","desc")

                :Where("item_category.name = ^","Fruit")

                :SQL("AllFruits")

                ?"------------------------------------"
                ?"Number of records in AllFruits "+alltrim(str(:Tally))
                // ? :LastSQL()
                select AllFruits
                scan all
                    ?AllFruits->item_category_name,;
                     AllFruits->item_name,;
                     AllFruits->price_history_effective_date,;
                     AllFruits->price_history_price
                endscan
                ?"------------------------------------"
            endwith
            //----------------------------------
            with object l_oDB3

                :Table("f93a07dd-cd75-48f4-b0bc-5f3e5619e8ef","set001.item_category")
                :Column("item_category.name"           ,"item_category_name")
                :Column("item.name"                    ,"item_name")
                :Column("price_history.effective_date" ,"price_history_effective_date")
                :Column("price_history.price"          ,"price_history_price")

                :Column("item.sysm"                    ,"item_sysm")

                :Join("inner","set001.item"         ,"","item.fk_item_category = item_category.key")
                :Join("inner","set001.price_history","","price_history.fk_item = item.key")

                :DistinctOn("item_category_name")
                :DistinctOn("item_name")
                :OrderBy("price_history_effective_date","desc")

                :Where("item_category.name = ^","Liquid")

                :SQL("AllLiquids")

                ?"------------------------------------"
                ?"Number of records in AllLiquids "+alltrim(str(:Tally))
                select AllLiquids
                scan all
                    ?AllLiquids->item_category_name,;
                     AllLiquids->item_name,;
                     AllLiquids->price_history_effective_date,;
                     AllLiquids->price_history_price
                endscan
                ?"------------------------------------"
            endwith
            //----------------------------------
            with object l_oDB4

                :Table("f93a07dd-cd75-48f4-b0bc-5f3e5619e8ea","set001.item_category")
                :Column("item_category.name"           ,"item_category_name")
                :Column("item.name"                    ,"item_name")
                :Column("price_history.effective_date" ,"price_history_effective_date")
                :Column("price_history.price"          ,"price_history_price")

                :Column("item.sysm"                    ,"item_sysm")

                :Join("inner","set001.item"         ,"","item.fk_item_category = item_category.key")
                :Join("inner","set001.price_history","","price_history.fk_item = item.key")

                :DistinctOn("item_category_name")
                :DistinctOn("item_name")
                :OrderBy("price_history_effective_date","desc")

                :Where("item.name = ^","Oil")

                :SQL("AllOils")

                ?"------------------------------------"
                ?"Number of records in AllOils "+alltrim(str(:Tally))
                select AllOils
                scan all
                    ?AllOils->item_category_name,;
                     AllOils->item_name,;
                     AllOils->price_history_effective_date,;
                     AllOils->price_history_price
                endscan
                ?"------------------------------------"
            endwith
            //----------------------------------

            //Test out an Union and except statement.
            l_oCompoundQuery1 := hb_SQLCompoundQuery(l_oSQLConnection2)
            with object l_oCompoundQuery1
                :AnchorAlias("56b5dea5-5efd-4323-842f-1a0963609eda","AllFruitsAndLiquids")

                //Following Makes no sense, only used to test generate of CTE
                // :AddSQLCTEQuery("Cursor1",l_oDB4)
                // :AddSQLCTEQuery("Cursor2",l_oDB3)

                :AddSQLDataQuery("AllFruits" ,l_oDB2)
                :AddSQLDataQuery("AllLiquids",l_oDB3)
                :AddSQLDataQuery("AllOils",l_oDB4)

                :CombineQueries(COMBINE_ACTION_UNION,"AllFruitsAndLiquids",.t.,"AllFruits","AllLiquids")
                :CombineQueries(COMBINE_ACTION_EXCEPT,"AllLiquids",.t.,"AllLiquids","AllOils")
                // :CombineQueries(COMBINE_ACTION_EXCEPT,"AllFruits",.t.,"AllFruits","AllOils")

                :SQL("ListOfFruitsAndLiquids")
                ? :LastSQL()
                ?"------------------------------------"
                ?"Number of records in ListOfFruitsAndLiquids "+alltrim(str(:Tally))
                select ListOfFruitsAndLiquids
                scan all
                    ?ListOfFruitsAndLiquids->item_category_name,;
                     ListOfFruitsAndLiquids->item_name,;
                     ListOfFruitsAndLiquids->price_history_effective_date,;
                     ListOfFruitsAndLiquids->price_history_price
                endscan
                ?"------------------------------------"

            endwith

            //Test out a CTE statement.
            //----------------------------------
            with object l_oDB5

                :Table("f93a07dd-cd75-48f4-b0bc-5f3e5619e8eb","set001.item_category")
                :Column("item_category.name"           ,"item_category_name")
                :Column("count(*)"                     ,"number_of_category_items")

                :Join("inner","set001.item"         ,"","item.fk_item_category = item_category.key")

                :GroupBy("item_category_name")
                :OrderBy("item_category_name","asc")

                :SQL("AllCategories")

                ?"------------------------------------"
                ?"Number of records in AllCategories "+alltrim(str(:Tally))
                select AllCategories
                scan all
                    ?AllCategories->item_category_name,;
                     AllCategories->number_of_category_items
                endscan
                ?"------------------------------------"
            endwith
            //----------------------------------

            with object l_oDB6

                :Table("f3da9a7e-0033-40af-8709-2077be896cf7","set001.item_category")
                :Column("item_category.name"           ,"item_category_name")
                :Column("item.name"                    ,"item_name")

                :Join("inner","set001.item"         ,"","item.fk_item_category = item_category.key")

                :OrderBy("item_category_name")
                :OrderBy("item_name")

                :SQL("AllItems")

                ?"------------------------------------"
                ?"Number of records in AllItems "+alltrim(str(:Tally))
                select AllItems
                scan all
                    ?AllItems->item_category_name,;
                     AllItems->item_name
                endscan
                ?"------------------------------------"
            endwith
            //----------------------------------

            with object l_oDB7

:AddNonTableAliases("AllCategories")
                :Table("f3da9a7e-0033-40af-8709-2077be896cf8","set001.item_category")

                :Column("item_category.name"                     ,"item_category_name")
                :Column("item.name"                              ,"item_name")
                :Column("AllCategories.number_of_category_items" ,"number_of_category_items")

                :Join("inner","set001.item"         ,"","item.fk_item_category = item_category.key")
                :Join("inner","AllCategories"       ,"","AllCategories.item_category_name = item_category.name")
//_M_ Will crash since the allcategories is not a real table. Have to allow reference to non tables. Add a method to allow "allcategories" alias

                :OrderBy("item_category_name")
                :OrderBy("item_name")

            endwith
            //----------------------------------
            l_oCompoundQuery2 := hb_SQLCompoundQuery(l_oSQLConnection2)
            with object l_oCompoundQuery2
                :AnchorAlias("56b5dea5-5efd-4323-842f-1a0963609edb","AllItemsWithTotals")

                :AddSQLCTEQuery("AllCategories",l_oDB5)

                :AddSQLDataQuery("AllItemsWithTotals" ,l_oDB7)


                :SQL("AllItemsWithTotals")
                ? :LastSQL()
                ?"------------------------------------"
                ?"Number of records in AllItemsWithTotals "+alltrim(str(:Tally))
                select AllItemsWithTotals
                scan all
                    ?AllItemsWithTotals->item_category_name+" - ",;
                     alltrim(AllItemsWithTotals->item_name)+" - ",;
                     alltrim(str(AllItemsWithTotals->number_of_category_items))
                endscan
                ?"------------------------------------"

            endwith


            //----------------------------------

            with object l_oDB8

:AddNonTableAliases("AllItemsWithTotals")
                :Table("f3da9a7e-0033-40af-8709-2077be896cf8","AllItemsWithTotals")
                :Distinct(.t.)
                :Column("AllItemsWithTotals.item_category_name"       ,"item_category_name")
                :Column("AllItemsWithTotals.number_of_category_items" ,"number_of_category_items")
                :OrderBy("number_of_category_items","desc")
                :OrderBy("item_category_name")

            endwith


            l_oCompoundQuery3 := hb_SQLCompoundQuery(l_oSQLConnection2)
            with object l_oCompoundQuery3
                :AnchorAlias("56b5dea5-5efd-4323-842f-1a0963609edc","AllCategoriesWithTotals")

                :AddSQLCTEQuery("AllCategories",l_oDB5)
                :AddSQLCTEQuery("AllItemsWithTotals",l_oDB7)

                :AddSQLDataQuery("AllCategoriesWithTotals" ,l_oDB8)


                :SQL("AllCategoriesWithTotals")
                ? :LastSQL()
                ?"------------------------------------"
                ?"Number of records in AllCategoriesWithTotals "+alltrim(str(:Tally))
                select AllCategoriesWithTotals
                scan all
                    ?AllCategoriesWithTotals->item_category_name+" - ",;
                     alltrim(str(AllCategoriesWithTotals->number_of_category_items))
                endscan
                ?"------------------------------------"

            endwith


        endif
    endif

endif
//-----------------------------------------------------------------------------------------------------------------------



if l_lAccessMariaDB
    l_oSQLConnection1:Disconnect()
    ?"MariaDB Get last Handle",l_oSQLConnection1:GetHandle()
endif

if l_lAccessPostgresql
    l_oSQLConnection2:Disconnect()
    ?"PostgreSQL Get last Handle",l_oSQLConnection2:GetHandle()
endif

?"Done"
return nil
//=================================================================================================================
//=================================================================================================================
