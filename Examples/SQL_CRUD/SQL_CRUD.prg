//Copyright (c) 2024 Eric Lendvai MIT License

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

local l_lTestUpdates         := .t.
local l_lTestSimpleQueries   := .t.
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

local l_hTableSchemaDefinitionA
local l_hTableSchemaDefinitionB

local l_cUpdateScript
local l_nMigrateSchemaResult := 0
local l_cLastError
local l_cLastSQLError
local l_cLastSQL

local l_nVersion

local l_cPreviousNamespaceName

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

local l_cRuntimePrefixStamp := GetZuluTimeStampForFileNameSuffix()+"_"

// local l_iPID := el_GetProcessId()

// altd()
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
        :SetHarbourORMNamespace("Harbour_ORM")

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
        // l_oSQLConnection2 := hb_SQLConnect("PostgreSQL","PostgreSQL ODBC Driver(UNICODE)","localhost",5432,"postgres","rndrnd","test001","set001")
        l_oSQLConnection2 := hb_SQLConnect("PostgreSQL","PostgreSQL Unicode(x64)","localhost",5432,"postgres","rndrnd","test001","set001")
    endif

    with object l_oSQLConnection2
        ?"PostgreSQL - ORM version - "+:p_hb_orm_version
        :PostgreSQLIdentifierCasing := HB_ORM_POSTGRESQL_CASE_SENSITIVE
        :SetHarbourORMNamespace("Harbour_ORM")
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
        l_cFullFileName := l_cOutputFolder+l_cRuntimePrefixStamp+"BeforeUpdatesSchema_MariaDB_"+l_oSQLConnection1:GetDatabase()+".txt"
        hb_orm_SendToDebugView("MariaDB - Will Generate file: "+l_cFullFileName)
        l_oSQLConnection1:GenerateCurrentSchemaHarbourCode(l_cFullFileName)
        hb_orm_SendToDebugView("MariaDB - Generated file: "+l_cFullFileName)

        //-------------------------------------------------------------------------------
        hb_orm_SendToDebugView("Will Initialize l_hTableSchemaDefinitionA")

        l_hTableSchemaDefinitionA := ;
            {"public.clients"=>{"Fields"=>;
                {"key" =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"name"=>{"Type"=>"CV","Length"=>100}};
                            };
            ,"set001.alltypes"=>{"Fields"=>;
                {"key"                =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"integer"            =>{"Type"=>"I","Nullable"=>.t.};
                ,"uuid1"              =>{"Type"=>"UUI"};
                ,"uuid2"              =>{"Type"=>"UUI","Default"=>"Wharf-uuid()","Nullable"=>.t.};
                ,"json1_without_null" =>{"Type"=>"JS"};
                ,"json2_with_null"    =>{"Type"=>"JS","Nullable"=>.t.};
                ,"jsonb1_without_null"=>{"Type"=>"JSB"};
                ,"jsonb2_with_null"   =>{"Type"=>"JSB","Nullable"=>.t.};
                ,"big_integer"        =>{"Type"=>"IB","Nullable"=>.t.};
                ,"small_integer"      =>{"Type"=>"IS","Nullable"=>.t.};
                ,"money"              =>{"Type"=>"Y"};
                ,"char10"             =>{"Type"=>"C","Length"=>10,"Nullable"=>.t.};
                ,"varchar10"          =>{"Type"=>"CV","Length"=>10,"Nullable"=>.t.};
                ,"binary10"           =>{"Type"=>"R","Nullable"=>.t.};
                ,"varbinary11"        =>{"Type"=>"R","Nullable"=>.t.};
                ,"memo"               =>{"Type"=>"M","Nullable"=>.t.};
                ,"raw"                =>{"Type"=>"R","Nullable"=>.t.};
                ,"logical"            =>{"Type"=>"L"};
                ,"date"               =>{"Type"=>"D","Nullable"=>.t.};
                ,"time_with_zone"     =>{"Type"=>"TOZ","Nullable"=>.t.};
                ,"time_no_zone"       =>{"Type"=>"TO","Nullable"=>.t.};
                ,"datetime_with_zone" =>{"Type"=>"DTZ","Nullable"=>.t.};
                ,"datetime_no_zone"   =>{"Type"=>"DT","Nullable"=>.t.}};
                                };
            ,"set001.dbf001"=>{"Fields"=>;
                {"key"          =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"customer_name"=>{"Type"=>"C","Length"=>50}};
                            };
            ,"set001.dbf002"=>{"Fields"=>;
                {"key"     =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"p_dbf001"=>{"Type"=>"I"}};
                            ,"Indexes"=>;
                {"p_dbf001"=>{"Expression"=>"p_dbf001"}}};
            ,"set001.item"=>{"Fields"=>;
                {"key"             =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"sysc"            =>{"Type"=>"DTZ"};
                ,"sysm"            =>{"Type"=>"DTZ"};
                ,"fk_item_category"=>{"Type"=>"I"};
                ,"name"            =>{"Type"=>"CV","Length"=>50};
                ,"note"            =>{"Type"=>"CV","Length"=>100}};
                            ,"Indexes"=>;
                {"fk_item_category"=>{"Expression"=>"fk_item_category"};
                ,"name"            =>{"Expression"=>"name"}}};
            ,"set001.item_category"=>{"Fields"=>;
                {"key" =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"sysc"=>{"Type"=>"DTZ"};
                ,"sysm"=>{"Type"=>"DTZ"};
                ,"name"=>{"Type"=>"CV","Length"=>50}};
                                    };
            ,"set001.noindextesttable"=>{"Fields"=>;
                {"KeY" =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"Code"=>{"Type"=>"C","Length"=>3,"Nullable"=>.t.}};
                                        };
            ,"set001.price_history"=>{"Fields"=>;
                {"key"           =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"sysc"          =>{"Type"=>"DTZ"};
                ,"sysm"          =>{"Type"=>"DTZ"};
                ,"fk_item"       =>{"Type"=>"I"};
                ,"effective_date"=>{"Type"=>"D"};
                ,"price"         =>{"Type"=>"N","Length"=>8,"Scale"=>2}};
                                    ,"Indexes"=>;
                {"effective_date"=>{"Expression"=>"effective_date"};
                ,"fk_item"       =>{"Expression"=>"fk_item"}}};
            ,"set001.table001"=>{"Fields"=>;
                {"key"     =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"sysc"    =>{"Type"=>"DTZ"};
                ,"sysm"    =>{"Type"=>"DTZ"};
                ,"LnAme"   =>{"Type"=>"C","Length"=>50};
                ,"fname"   =>{"Type"=>"C","Length"=>53};
                ,"minitial"=>{"Type"=>"C","Length"=>1};
                ,"age"     =>{"Type"=>"N","Length"=>3};
                ,"dob"     =>{"Type"=>"D"};
                ,"dati"    =>{"Type"=>"DTZ"};
                ,"logical1"=>{"Type"=>"L"};
                ,"numdec2" =>{"Type"=>"N","Length"=>6,"Scale"=>1};
                ,"varchar" =>{"Type"=>"CV","Length"=>203}};
                                ,"Indexes"=>;
                {"lname"=>{"Expression"=>"LnAme"}}};
            ,"set001.table002"=>{"Fields"=>;
                {"key"       =>{"Type"=>"I","Wharf-AutoIncrement"=>.t.};
                ,"p_table001"=>{"Type"=>"I","Nullable"=>.t.};
                ,"children"  =>{"Type"=>"CV","Length"=>200,"Nullable"=>.t.};
                ,"Cars"      =>{"Type"=>"CV","Length"=>300}};
                                ,"Indexes"=>;
                {"p_table001"=>{"Expression"=>"p_table001"}}};
            ,"set001.table003"=>{"Fields"=>;
                {"key"        =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"p_table001" =>{"Type"=>"I"};
                ,"p_table003" =>{"Type"=>"I"};
                ,"char50"     =>{"Type"=>"C","Length"=>50,"Default"=>"'val1A'","Nullable"=>.t.};
                ,"bigint"     =>{"Type"=>"IB","Nullable"=>.t.};
                ,"Bit"        =>{"Type"=>"R","Nullable"=>.t.};
                ,"Decimal5_2" =>{"Type"=>"N","Length"=>5,"Scale"=>2,"Nullable"=>.t.};
                ,"Decimal25_7"=>{"Type"=>"N","Length"=>25,"Scale"=>7,"Nullable"=>.t.};
                ,"VarChar51"  =>{"Type"=>"CV","Length"=>50,"Nullable"=>.t.};
                ,"VarChar52"  =>{"Type"=>"CV","Length"=>50,"Default"=>"'val1B'"};
                ,"Text"       =>{"Type"=>"M","Nullable"=>.t.};
                ,"Binary"     =>{"Type"=>"R","Nullable"=>.t.};
                ,"Date"       =>{"Type"=>"D","Nullable"=>.t.};
                ,"DateTime"   =>{"Type"=>"DT","Scale"=>4,"Default"=>"Wharf-Now()","Nullable"=>.t.};
                ,"TOZ"        =>{"Type"=>"TOZ","Nullable"=>.t.};
                ,"TOZ4"       =>{"Type"=>"TOZ","Scale"=>4,"Nullable"=>.t.};
                ,"TO"         =>{"Type"=>"TO","Nullable"=>.t.};
                ,"TO4"        =>{"Type"=>"TO","Scale"=>4,"Nullable"=>.t.};
                ,"DTZ"        =>{"Type"=>"DTZ","Nullable"=>.t.};
                ,"DTZ4"       =>{"Type"=>"DTZ","Scale"=>4,"Nullable"=>.t.};
                ,"DT"         =>{"Type"=>"DT","Nullable"=>.t.};
                ,"DT4"        =>{"Type"=>"DT","Scale"=>4,"Nullable"=>.t.};
                ,"time"       =>{"Type"=>"TO","Scale"=>4,"Nullable"=>.t.};
                ,"Boolean"    =>{"Type"=>"L","Nullable"=>.t.}};
                                ,"Indexes"=>;
                {"p_table001"=>{"Expression"=>"p_table001"};
                ,"p_table003"=>{"Expression"=>"p_table003"}}};
            ,"set001.table004"=>{"Fields"=>;
                {"id"    =>{"Type"=>"I"};
                ,"street"=>{"Type"=>"C","Length"=>50,"Nullable"=>.t.};
                ,"zip"   =>{"Type"=>"C","Length"=>5,"Nullable"=>.t.};
                ,"state" =>{"Type"=>"C","Length"=>2,"Nullable"=>.t.}};
                                ,"Indexes"=>;
                {"id"=>{"Expression"=>"id","Unique"=>.t.}}};
            ,"set001.zipcodes"=>{"Fields"=>;
                {"key"    =>{"Type"=>"IB","AutoIncrement"=>.t.};
                ,"zipcode"=>{"Type"=>"C","Length"=>5,"Nullable"=>.t.};
                ,"city"   =>{"Type"=>"C","Length"=>45,"Nullable"=>.t.}};
                                };
            }

        hb_orm_SendToDebugView("Initialized l_hTableSchemaDefinitionA")
        hb_orm_SendToDebugView("Will Initialize l_hTableSchemaDefinitionB")

        l_hTableSchemaDefinitionB := ;
            {"set003.cust001"=>{"Fields"=>;
                {"KeY" =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"Code"=>{"Type"=>"C","Length"=>3,"Nullable"=>.t.}};
                            };
            ,"set003.form001"=>{"Fields"=>;
                {"key"     =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"LnAme"   =>{"Type"=>"C","Length"=>50};
                ,"fname"   =>{"Type"=>"C","Length"=>53};
                ,"minitial"=>{"Type"=>"C","Length"=>1};
                ,"age"     =>{"Type"=>"N","Length"=>3};
                ,"dob"     =>{"Type"=>"D"};
                ,"dati"    =>{"Type"=>"DTZ"};
                ,"logical1"=>{"Type"=>"L"};
                ,"numdec2" =>{"Type"=>"N","Length"=>6,"Scale"=>1};
                ,"varchar" =>{"Type"=>"CV","Length"=>203}};
                            ,"Indexes"=>;
                {"lname"=>{"Expression"=>"LnAme"}}};
            ,"set003.form002"=>{"Fields"=>;
                {"key"       =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"p_table001"=>{"Type"=>"I","Nullable"=>.t.};
                ,"children"  =>{"Type"=>"CV","Length"=>200,"Nullable"=>.t.};
                ,"Cars"      =>{"Type"=>"CV","Length"=>300}};
                            };
            ,"set003.ListOfFiles"=>{"Fields"=>;
                {"key"                      =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"file_name"                =>{"Type"=>"C","Length"=>120,"Nullable"=>.t.};
                ,"reference_to_large_object"=>{"Type"=>"OID","Nullable"=>.t.}};
                                };
            }
        //-------------------------------------------------------------------------------

        ?"Table Exists clients: ",l_oSQLConnection1:TableExists("clients")
        l_oSQLConnection1:DeleteTable("clients")
        ?"Table Exists clients: ",l_oSQLConnection1:TableExists("clients")

        ?"Field Exists set001.table002.children: ",l_oSQLConnection1:FieldExists("set001.table002","children")
        l_oSQLConnection1:DeleteField("set001.table002","children")
        ?"Field Exists set001.table002.children: ",l_oSQLConnection1:FieldExists("set001.table002","children")

        l_oSQLConnection1:DeleteIndex("set001.table001","lname")


        // altd()
        l_cUpdateScript := l_cLastError := ""
        if el_AUnpack(l_oSQLConnection1:MigrateSchema(l_hTableSchemaDefinitionA),,@l_cUpdateScript,@l_cLastError) > 0
            hb_orm_SendToDebugView("MariaDB - Updated Schema with Definition A - No Errors")
        else
            if !empty(l_cLastError)
                l_cFullFileName := l_cOutputFolder+l_cRuntimePrefixStamp+"MigrationSqlScript_MariaDB_LastError_"+l_oSQLConnection1:GetDatabase()+"_A.txt"
                hb_MemoWrit(l_cFullFileName,l_cLastError)
                hb_orm_SendToDebugView("MariaDB - Generated file: "+l_cFullFileName)
            endif
        endif
        if !empty(l_cUpdateScript)
            l_cFullFileName := l_cOutputFolder+l_cRuntimePrefixStamp+"MigrationSqlScript_MariaDB_"+l_oSQLConnection1:GetDatabase()+"_A_"+".txt"
             hb_MemoWrit(l_cFullFileName,l_cUpdateScript)
            hb_orm_SendToDebugView("MariaDB - Generated file: "+l_cFullFileName)
        endif



        l_cUpdateScript := l_cLastError := ""
        if el_AUnpack(l_oSQLConnection1:MigrateSchema(l_hTableSchemaDefinitionB),,@l_cUpdateScript,@l_cLastError) > 0
            hb_orm_SendToDebugView("MariaDB - Updated Schema with Definition B - No Errors")
        else
            if !empty(l_cLastError)
                l_cFullFileName := l_cOutputFolder+l_cRuntimePrefixStamp+"MigrationSqlScript_MariaDB_LastError_"+l_oSQLConnection1:GetDatabase()+"_B.txt"
                hb_MemoWrit(l_cFullFileName,l_cLastError)
                hb_orm_SendToDebugView("MariaDB - Generated file: "+l_cFullFileName)
            endif
        endif
        if !empty(l_cUpdateScript)
            l_cFullFileName := l_cOutputFolder+l_cRuntimePrefixStamp+"MigrationSqlScript_MariaDB_"+l_oSQLConnection1:GetDatabase()+"_B_"+".txt"
             hb_MemoWrit(l_cFullFileName,l_cUpdateScript)
            hb_orm_SendToDebugView("MariaDB - Generated file: "+l_cFullFileName)
        endif


    endif
endif
//===========================================================================================================================
if l_lAccessPostgresql
    if l_oSQLConnection2:Connected

        l_oSQLConnection2:SetCurrentNamespaceName("set001")

// l_oDB2 := hb_SQLData(l_oSQLConnection2)
// altd()
// l_oDB2:Delete("SQLCRUD001","set001.dbf001",1)
// altd()
// l_oSQLConnection2:SQLExec("test1",[DELETE FROM "set001"."dbf001" WHERE 1=0 ])


        hb_orm_SendToDebugView("PostgreSQL - Will GenerateCurrentSchemaHarbourCode")
        l_oSQLConnection2:GenerateCurrentSchemaHarbourCode(l_cOutputFolder+l_cRuntimePrefixStamp+"CurrentSchema_PostgreSQL_"+l_oSQLConnection2:GetDatabase()+".txt")
        hb_orm_SendToDebugView("PostgreSQL - Done CurrentSchema_PostgreSQL_...text")

        //-------------------------------------------------------------------------------
        hb_orm_SendToDebugView("Will Initialize l_hTableSchemaDefinitionA")

        l_hTableSchemaDefinitionA := ;
            {"public.clients"=>{"Fields"=>;
                {"key" =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"name"=>{"Type"=>"CV","Length"=>100}};
                            };
            ,"set001.alltypes"=>{"Fields"=>;
                {"key"                =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"integer"            =>{"Type"=>"I","Nullable"=>.t.};
                ,"many_int"           =>{"Type"=>"I","Nullable"=>.t.,"Array"=>.t.};
                ,"many_flags"         =>{"Type"=>"L","Nullable"=>.t.,"Array"=>.t.};
                ,"uuid1"              =>{"Type"=>"UUI"};
                ,"uuid2"              =>{"Type"=>"UUI","Default"=>"Wharf-uuid()","Nullable"=>.t.};
                ,"many_uuid"          =>{"Type"=>"UUI","Nullable"=>.t.,"Array"=>.t.};
                ,"json1_without_null" =>{"Type"=>"JS"};
                ,"json2_with_null"    =>{"Type"=>"JS","Nullable"=>.t.};
                ,"jsonb1_without_null"=>{"Type"=>"JSB"};
                ,"jsonb2_with_null"   =>{"Type"=>"JSB","Nullable"=>.t.};
                ,"big_integer"        =>{"Type"=>"IB","Nullable"=>.t.};
                ,"small_integer"      =>{"Type"=>"IS","Nullable"=>.t.};
                ,"money"              =>{"Type"=>"Y"};
                ,"char10"             =>{"Type"=>"C","Length"=>10,"Nullable"=>.t.};
                ,"varchar10"          =>{"Type"=>"CV","Length"=>10,"Nullable"=>.t.};
                ,"binary10"           =>{"Type"=>"R","Nullable"=>.t.};
                ,"varbinary11"        =>{"Type"=>"R","Nullable"=>.t.};
                ,"memo"               =>{"Type"=>"M","Nullable"=>.t.};
                ,"raw"                =>{"Type"=>"R","Nullable"=>.t.};
                ,"logical"            =>{"Type"=>"L"};
                ,"date"               =>{"Type"=>"D","Nullable"=>.t.};
                ,"time_with_zone"     =>{"Type"=>"TOZ","Nullable"=>.t.};
                ,"time_no_zone"       =>{"Type"=>"TO","Nullable"=>.t.};
                ,"datetime_with_zone" =>{"Type"=>"DTZ","Nullable"=>.t.};
                ,"datetime_no_zone"   =>{"Type"=>"DT","Nullable"=>.t.}};
                                };
            ,"set001.dbf001"=>{"Fields"=>;
                {"key"          =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"customer_name"=>{"Type"=>"C","Length"=>50}};
                            };
            ,"set001.dbf002"=>{"Fields"=>;
                {"key"     =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"p_dbf001"=>{"Type"=>"I"}};
                            ,"Indexes"=>;
                {"p_dbf001"=>{"Expression"=>"p_dbf001"}}};
            ,"set001.item"=>{"Fields"=>;
                {"key"             =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"sysc"            =>{"Type"=>"DTZ"};
                ,"sysm"            =>{"Type"=>"DTZ"};
                ,"fk_item_category"=>{"Type"=>"I"};
                ,"name"            =>{"Type"=>"CV","Length"=>50};
                ,"note"            =>{"Type"=>"CV","Length"=>100}};
                            ,"Indexes"=>;
                {"fk_item_category"=>{"Expression"=>"fk_item_category"};
                ,"name"            =>{"Expression"=>"name"}}};
            ,"set001.item_category"=>{"Fields"=>;
                {"key" =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"sysc"=>{"Type"=>"DTZ"};
                ,"sysm"=>{"Type"=>"DTZ"};
                ,"name"=>{"Type"=>"CV","Length"=>50}};
                                    };
            ,"set001.noindextesttable"=>{"Fields"=>;
                {"KeY" =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"Code"=>{"Type"=>"C","Length"=>3,"Nullable"=>.t.}};
                                        };
            ,"set001.price_history"=>{"Fields"=>;
                {"key"           =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"sysc"          =>{"Type"=>"DTZ"};
                ,"sysm"          =>{"Type"=>"DTZ"};
                ,"fk_item"       =>{"Type"=>"I"};
                ,"effective_date"=>{"Type"=>"D"};
                ,"price"         =>{"Type"=>"N","Length"=>8,"Scale"=>2}};
                                    ,"Indexes"=>;
                {"effective_date"=>{"Expression"=>"effective_date"};
                ,"fk_item"       =>{"Expression"=>"fk_item"}}};
            ,"set001.table001"=>{"Fields"=>;
                {"key"     =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"sysc"    =>{"Type"=>"DTZ"};
                ,"sysm"    =>{"Type"=>"DTZ"};
                ,"LnAme"   =>{"Type"=>"C","Length"=>50};
                ,"fname"   =>{"Type"=>"C","Length"=>53};
                ,"minitial"=>{"Type"=>"C","Length"=>1};
                ,"age"     =>{"Type"=>"N","Length"=>3};
                ,"dob"     =>{"Type"=>"D"};
                ,"dati"    =>{"Type"=>"DTZ"};
                ,"logical1"=>{"Type"=>"L"};
                ,"numdec2" =>{"Type"=>"N","Length"=>6,"Scale"=>1};
                ,"varchar" =>{"Type"=>"CV","Length"=>203}};
                                ,"Indexes"=>;
                {"lname"=>{"Expression"=>"LnAme"};
                ,"tag1" =>{"Expression"=>"upper(LnAme)"}}};
            ,"set001.table002"=>{"Fields"=>;
                {"key"       =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"p_table001"=>{"Type"=>"I","Nullable"=>.t.};
                ,"children"  =>{"Type"=>"CV","Length"=>200,"Nullable"=>.t.};
                ,"Cars"      =>{"Type"=>"CV","Length"=>300}};
                                ,"Indexes"=>;
                {"p_table001"=>{"Expression"=>"p_table001"}}};
            ,"set001.table003"=>{"Fields"=>;
                {"key"        =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"p_table001" =>{"Type"=>"I"};
                ,"p_table003" =>{"Type"=>"I"};
                ,"char50"     =>{"Type"=>"C","Length"=>50,"Default"=>"'val1A'","Nullable"=>.t.};
                ,"bigint"     =>{"Type"=>"IB","Nullable"=>.t.};
                ,"Bit"        =>{"Type"=>"R","Nullable"=>.t.};
                ,"Decimal5_2" =>{"Type"=>"N","Length"=>5,"Scale"=>2,"Nullable"=>.t.};
                ,"Decimal25_7"=>{"Type"=>"N","Length"=>25,"Scale"=>7,"Nullable"=>.t.};
                ,"VarChar51"  =>{"Type"=>"CV","Length"=>50,"Nullable"=>.t.};
                ,"VarChar52"  =>{"Type"=>"CV","Length"=>50,"Default"=>"'val1B'"};
                ,"Text"       =>{"Type"=>"M","Nullable"=>.t.};
                ,"Binary"     =>{"Type"=>"R","Nullable"=>.t.};
                ,"Date"       =>{"Type"=>"D","Nullable"=>.t.};
                ,"DateTime"   =>{"Type"=>"DT","Scale"=>4,"Default"=>"Wharf-Now()","Nullable"=>.t.};
                ,"TOZ"        =>{"Type"=>"TOZ","Nullable"=>.t.};
                ,"TOZ4"       =>{"Type"=>"TOZ","Scale"=>4,"Nullable"=>.t.};
                ,"TO"         =>{"Type"=>"TO","Nullable"=>.t.};
                ,"TO4"        =>{"Type"=>"TO","Scale"=>4,"Nullable"=>.t.};
                ,"DTZ"        =>{"Type"=>"DTZ","Nullable"=>.t.};
                ,"DTZ4"       =>{"Type"=>"DTZ","Scale"=>4,"Nullable"=>.t.};
                ,"DT"         =>{"Type"=>"DT","Nullable"=>.t.};
                ,"DT4"        =>{"Type"=>"DT","Scale"=>4,"Nullable"=>.t.};
                ,"time"       =>{"Type"=>"TO","Scale"=>4,"Nullable"=>.t.};
                ,"Boolean"    =>{"Type"=>"L","Nullable"=>.t.}};
                                ,"Indexes"=>;
                {"p_table001"=>{"Expression"=>"p_table001"};
                ,"p_table003"=>{"Expression"=>"p_table003"}}};
            ,"set001.table004"=>{"Fields"=>;
                {"id"    =>{"Type"=>"I"};
                ,"street"=>{"Type"=>"C","Length"=>50,"Nullable"=>.t.};
                ,"zip"   =>{"Type"=>"C","Length"=>5,"Nullable"=>.t.};
                ,"state" =>{"Type"=>"C","Length"=>2,"Nullable"=>.t.}};
                                ,"Indexes"=>;
                {"id"=>{"Expression"=>"id","Unique"=>.t.}}};
            ,"set001.zipcodes"=>{"Fields"=>;
                {"key"    =>{"Type"=>"IB","AutoIncrement"=>.t.};
                ,"zipcode"=>{"Type"=>"C","Length"=>5,"Nullable"=>.t.};
                ,"city"   =>{"Type"=>"C","Length"=>45,"Nullable"=>.t.}};
                                };
            }

        hb_orm_SendToDebugView("Initialized l_hTableSchemaDefinitionA")
        hb_orm_SendToDebugView("Will Initialize l_hTableSchemaDefinitionB")

        l_hTableSchemaDefinitionB := ;
            {"set003.cust001"=>{"Fields"=>;
                {"KeY" =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"Code"=>{"Type"=>"C","Length"=>3,"Nullable"=>.t.}};
                            };
            ,"set003.form001"=>{"Fields"=>;
                {"key"     =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"LnAme"   =>{"Type"=>"C","Length"=>50};
                ,"fname"   =>{"Type"=>"C","Length"=>53};
                ,"minitial"=>{"Type"=>"C","Length"=>1};
                ,"age"     =>{"Type"=>"N","Length"=>3};
                ,"dob"     =>{"Type"=>"D"};
                ,"dati"    =>{"Type"=>"DTZ"};
                ,"logical1"=>{"Type"=>"L"};
                ,"numdec2" =>{"Type"=>"N","Length"=>6,"Scale"=>1};
                ,"varchar" =>{"Type"=>"CV","Length"=>203}};
                            ,"Indexes"=>;
                {"lname"=>{"Expression"=>"LnAme"};
                ,"tag1" =>{"Expression"=>"upper(LnAme)"}}};
            ,"set003.form002"=>{"Fields"=>;
                {"key"       =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"p_table001"=>{"Type"=>"I","Nullable"=>.t.};
                ,"children"  =>{"Type"=>"CV","Length"=>200,"Nullable"=>.t.};
                ,"Cars"      =>{"Type"=>"CV","Length"=>300}};
                            };
            ,"set003.ListOfFiles"=>{"Fields"=>;
                {"key"                      =>{"Type"=>"I","AutoIncrement"=>.t.};
                ,"file_name"                =>{"Type"=>"C","Length"=>120,"Nullable"=>.t.};
                ,"reference_to_large_object"=>{"Type"=>"OID","Nullable"=>.t.}};
                                };
            }
        //-------------------------------------------------------------------------------

        ?"Table Exists public.clients: ",l_oSQLConnection2:TableExists("public.clients")
        l_oSQLConnection2:DeleteTable("public.clients")
        ?"Table Exists public.clients: ",l_oSQLConnection2:TableExists("public.clients")

        ?"Field Exists set001.table002.children: ",l_oSQLConnection2:FieldExists("set001.table002","children")
        l_oSQLConnection2:DeleteField("set001.table002","children")
        ?"Field Exists set001.table002.children: ",l_oSQLConnection2:FieldExists("set001.table002","children")
        
        l_oSQLConnection2:DeleteIndex("set001.table001","lname")



        l_cUpdateScript := ""
        if el_AUnpack(l_oSQLConnection2:MigrateSchema(l_hTableSchemaDefinitionA),,@l_cUpdateScript,@l_cLastError) > 0
            hb_orm_SendToDebugView("PostgreSQL - Updated MigrationSqlScript_PostgreSQL_set001.txt")
        else
            if !empty(l_cLastError)
                hb_orm_SendToDebugView("PostgreSQL - Failed Migrate MigrationSqlScript_PostgreSQL_set001_....txt")
                hb_MemoWrit(l_cOutputFolder+l_cRuntimePrefixStamp+"MigrationSqlScript_PostgreSQL_set001_LastError_"+l_oSQLConnection2:GetDatabase()+".txt",l_cLastError)
            endif
        endif
        hb_MemoWrit(l_cOutputFolder+l_cRuntimePrefixStamp+"MigrationSqlScript_PostgreSQL_set001_"+l_oSQLConnection2:GetDatabase()+".txt",l_cUpdateScript)


        l_cPreviousNamespaceName := l_oSQLConnection2:SetCurrentNamespaceName("set002")

        l_cUpdateScript := ""
        if el_AUnpack(l_oSQLConnection2:MigrateSchema(l_hTableSchemaDefinitionB),,@l_cUpdateScript,@l_cLastError) > 0
            hb_orm_SendToDebugView("PostgreSQL - Updated MigrationSqlScript_PostgreSQL_set002....txt")
        else
            if !empty(l_cLastError)
                hb_orm_SendToDebugView("PostgreSQL - Failed Migrate MigrationSqlScript_PostgreSQL_set002_....txt")
                hb_MemoWrit(l_cOutputFolder+l_cRuntimePrefixStamp+"MigrationSqlScript_PostgreSQL_set002_LastError_"+l_oSQLConnection2:GetDatabase()+".txt",l_cLastError)
            endif
        endif
        hb_MemoWrit(l_cOutputFolder+l_cRuntimePrefixStamp+"MigrationSqlScript_PostgreSQL_set002_"+l_oSQLConnection2:GetDatabase()+".txt",l_cUpdateScript)








        l_oSQLConnection2:SetCurrentNamespaceName(l_cPreviousNamespaceName)
        

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
                :Table("MySQLAddAllTypes","set001.alltypes","alltypes")
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

                :Table("MySQLDecimalTest","set001.table003","table003")
                :Field("Decimal5_2","523.35")   //To trigger new SchemaAndDataErrorLog
                :Field("Decimal25_7","-1111567890123456.1234567")
                // :Field("DateTime",hb_ctot("02/25/2021 07:24:03:234 pm","mm/dd/yyyy", "hh:mm:ss:fff pp"))
                :Field("DateTime",hb_ctot("02/25/2021 07:24:04:1234","mm/dd/yyyy", "hh:mm:ss:ffff"))
                // :Field("char50","test1")
                :Add()

                // :UseConnection(l_oSQLConnection1)

                :Table("mysql 1","set001.table003","table003")
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
altd()
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
                // l_TestResult   := l_oSQLConnection1:p_TableSchema["table003"]["Fields"]

                ExportTableToHtmlFile("Table003Records",l_cOutputFolder+l_cRuntimePrefixStamp+"MySQL_Table003Records","From MySQL",,,.t.)


                :Table(2,"set001.table001","table001")
                :Field("age","5")   //To trigger new SchemaAndDataErrorLog
                :Field("dob",date())
                :Field("dati",hb_datetime())
                :Field("fname","Michael"+' "excetera2" 0123456789012345678901234567890123456789012345678901234567890123456789')
                :Field("lname","O'Hara 123")
                // :Field("logical1",NIL)
                if :Add()
                    l_nKey := :Key()

                    :Table(3,"set001.table001","table001")
                    :Field("fname"   ,"Ingrid2")
                    :Field("lname","1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890")
                    :Field("minitial","aBBA2")
                    :Update(l_nKey)
                
                    // :Table(4,"table001")
                    // :Column("table001.fname","table001_fname")
                    // :Join("inner","table003","","table001.key = table003.key")
                    // l_oData := :Get(l_nKey) 

                    :Table(5,"set001.table001","table001")
                    :Column("table001.fname","table001_fname")
                    l_oData := :Get(l_nKey)

                    ?"Add record with key = "+Trans(l_nKey)+" First Name = "+l_oData:table001_fname

                endif

                :Table(6,"set001.table001","table001")
                // :Join("inner","table002","","table002.p_table001 = table001 and key = ^",5)
                l_xW1 := :Join("inner","set001.table002","table002","table002.p_table001 = table001")
                :ReplaceJoin(l_xW1,"inner","set001.table002","table002","table002.p_table001 = table001.key")

                l_xW1 := :Where("table001.fname = ^","Jodie")
                :Where("table001.lname = ^","Foster")
                :ReplaceWhere(l_xW1,"table001.fname = ^","Harrison")

                l_xW1 := :Having("table001.fname = ^","Jodie")
                :Having("table001.lname = ^","Foster")
                :ReplaceHaving(l_xW1,"table001.fname = ^","Harrison")

                //:KeywordCondition("Jodie","fname+lname","or",.t.)
                
                ?"----------------------------------------------"
                :Table(7,"set001.table001","table001")
                :Column("table001.key"  ,"key")
                :Column("table001.fname","table001_fname")
                :Column("table001.lname","table001_lname")
                :Column("table002.children","table002_children")
                :Where("table001.key < 4")
                :Join("inner","set001.table002","","table002.p_table001 = table001.key")
                :SQL("AllRecords")
                
                ?"Will use scan/endscan"
                select AllRecords
                index on upper(field->table001_fname) tag ufname to AllRecords

                scan all
                    ?"MySQL "+trans(AllRecords->key)+" - "+allt(AllRecords->table001_fname)+" "+allt(AllRecords->table001_lname)+" "+allt(AllRecords->table002_children)
                endscan
                
                ExportTableToHtmlFile("AllRecords",l_cOutputFolder+l_cRuntimePrefixStamp+"MySQL_Table001_Join_Table002","From MySQL",,,.t.)

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
                // ExportTableToHtmlFile("ListOfFiles",l_cOutputFolder+l_cRuntimePrefixStamp+"Postgresql_ListOfFiles","From Postgresql",,,.t.)
                // ?"Seek test 001",vfp_seek(upper("LastExport.Zip"),"ListOfFiles","tag1"),ListOfFiles->key
                // ?"Seek test 002 - tag1",vfp_seek(upper("2*LastExp")       ,"ListOfFiles","tag1"),ListOfFiles->key
                // ?"Seek test 002 - tag2",vfp_seek(upper("2*LastExp")       ,"ListOfFiles","tag2"),ListOfFiles->key
                // ?"Seek test 003",vfp_seek(upper("build")         ,"ListOfFiles","tag1"),ListOfFiles->key







                :Table("PostgreSQLAddAllTypes","set001.alltypes","alltypes")
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

                :Table( "fc20f0e9-fb3e-4094-9df3-591095385a1b","set001.alltypes","alltypes")
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

                ExportTableToHtmlFile("AllTypesRecords",l_cOutputFolder+l_cRuntimePrefixStamp+"Postgresql_AllTypesRecords","From Postgresql",,,.t.)
                //html


                :Table("PostgreSQLAddAllTypes","set001.alltypes","alltypes")
                :Field("integer" ,124)
                if :Add()
                    l_nKey = :Key()
                    :Table("PostgreSQLAddAllTypes","set001.alltypes","alltypes")
                    :FieldArray("many_int",{5,1,0})
                    :FieldArray("many_flags",{.t.,.f.,.t.})
                    :FieldArray("many_uuid",{'46d8e196-3333-4404-b167-3756dfa32555','46d8e196-2222-4404-b167-3756dfa32555'})
                    :Update(l_nKey)
                endif



                :Table("PostgreSQLDecimalTest","set001.table003","table003")
                :Field("Decimal5_2","523.35")   //To trigger new SchemaAndDataErrorLog
                :Field("Decimal25_7","-1111567890123456.1234567")
                // :Field("DateTime",hb_ctot("02/25/2021 07:24:03:234 pm","mm/dd/yyyy", "hh:mm:ss:fff pp"))
                :Field("DateTime",hb_ctot("02/25/2021 07:24:04:1234","mm/dd/yyyy", "hh:mm:ss:ffff"))
                :Field("time","07:24:05.1234")
                // :Field("Boolean",.t.)
                :Add()


                :Table("PostgreSQLDecimalTest","set001.table003","table003")
                :Field("Decimal5_2","523.35")   //To trigger new SchemaAndDataErrorLog
                :Field("Decimal25_7","-1111567890123456.1234567")
                // :Field("DateTime",hb_ctot("02/25/2021 07:24:03:234 pm","mm/dd/yyyy", "hh:mm:ss:fff pp"))
                :Field("DateTime",hb_datetime())
                :Field("text",Replicate("0123456789",1000))   //Replicate(<cString>,<nCount>)
                :Field("time","07:24:05.1234")
                :Field("char50","élevé")   //UTF support

                // :Field("Boolean",.t.)
                :Add()


                :Table(8,"set001.table003","table003")
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

                ExportTableToHtmlFile("Table003Records",l_cOutputFolder+l_cRuntimePrefixStamp+"PostgreSQL_Table003Records.html","From PostgreSQL",,25,.t.)

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

                ExportTableToHtmlFile("AllItems",l_cOutputFolder+l_cRuntimePrefixStamp+"PostgreSQL_AllItems.html","From PostgreSQL",,25,.t.)


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



                :Table("mysql 1","set001.table003")
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
altd()
                l_oCursor:AppendBlank() //Blank Record
                // l_oCursor:SetFieldValue("TABLE003_CHAR50","Bogus")

                l_oCursor:InsertRecord({"TABLE003_CHAR50" => "Fabulous",;
                                        "TABLE003_BIGINT" => 1234})

                l_oCursor:Index("tag1","TABLE003_CHAR50")
                l_oCursor:CreateIndexes()
                l_oCursor:SetOrder("tag1")
                
                ExportTableToHtmlFile("Table003Records",l_cOutputFolder+l_cRuntimePrefixStamp+"MySQL_Table003Records","From MySQL",,,.t.)


                :Table(2,"set001.table001")
                :Field("age","5")   //To trigger new SchemaAndDataErrorLog
                :Field("dob",date())
                :Field("dati",hb_datetime())
                :Field("fname","Michael"+' "excetera2" 0123456789012345678901234567890123456789012345678901234567890123456789')
                :Field("lname","O'Hara 123")
                // :Field("logical1",NIL)
                if :Add()
                    l_nKey := :Key()

                    :Table(3,"set001.table001")
                    :Field("fname"   ,"Ingrid2")
                    :Field("lname","1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890")
                    :Field("minitial","aBBA2")
                    :Update(l_nKey)
                
                    // :Table(4,"table001")
                    // :Column("table001.fname","table001_fname")
                    // :Join("inner","table003","","table001.key = table003.key")
                    // l_oData := :Get(l_nKey) 

                    :Table(5,"set001.table001")
                    :Column("table001.fname","table001_fname")
                    l_oData := :Get(l_nKey)

                    ?"Add record with key = "+Trans(l_nKey)+" First Name = "+l_oData:table001_fname

                endif

                :Table(6,"set001.table001")
                // :Join("inner","table002","","table002.p_table001 = table001 and key = ^",5)
                l_xW1 := :Join("inner","set001.table002","","table002.p_table001 = table001")
                :ReplaceJoin(l_xW1,"inner","set001.table002","","table002.p_table001 = table001.key")

                l_xW1 := :Where("table001.fname = ^","Jodie")
                :Where("table001.lname = ^","Foster")
                :ReplaceWhere(l_xW1,"table001.fname = ^","Harrison")

                l_xW1 := :Having("table001.fname = ^","Jodie")
                :Having("table001.lname = ^","Foster")
                :ReplaceHaving(l_xW1,"table001.fname = ^","Harrison")

                //:KeywordCondition("Jodie","fname+lname","or",.t.)
                
                ?"----------------------------------------------"
                :Table(7,"set001.table001")
                :Column("table001.key"  ,"key")
                :Column("table001.fname","table001_fname")
                :Column("table001.lname","table001_lname")
                :Column("table002.children","table002_children")
                :Where("table001.key < 4")
                :Join("inner","set001.table002","","table002.p_table001 = table001.key")
                :SQL("AllRecords")
                
                ?"Will use scan/endscan"
                select AllRecords
                index on upper(field->table001_fname) tag ufname to AllRecords

                scan all
                    ?"MySQL "+trans(AllRecords->key)+" - "+allt(AllRecords->table001_fname)+" "+allt(AllRecords->table001_lname)+" "+allt(AllRecords->table002_children)
                endscan
                
                ExportTableToHtmlFile("AllRecords",l_cOutputFolder+l_cRuntimePrefixStamp+"MySQL_Table001_Join_Table002","From MySQL",,,.t.)

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

                ExportTableToHtmlFile("AllTypesRecords",l_cOutputFolder+l_cRuntimePrefixStamp+"Postgresql_AllTypesRecords","From Postgresql",,,.t.)
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

                ExportTableToHtmlFile("AllItems",l_cOutputFolder+l_cRuntimePrefixStamp+"PostgreSQL_AllItems.html","From PostgreSQL",,25,.t.)


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

                :AddSQLDataQuery("AllFruits" ,l_oDB2)
                :AddSQLDataQuery("AllLiquids",l_oDB3)
                :AddSQLDataQuery("AllOils",l_oDB4)

                :CombineQueries(COMBINE_ACTION_UNION,"AllFruitsAndLiquids",.t.,"AllFruits","AllLiquids")
                :CombineQueries(COMBINE_ACTION_EXCEPT,"AllLiquids",.t.,"AllLiquids","AllOils")

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
//=================================================================================================================
function GetZuluTimeStampForFileNameSuffix()
local l_cTimeStamp := hb_TSToStr(hb_TSToUTC(hb_DateTime()))
l_cTimeStamp := left(l_cTimeStamp,len(l_cTimeStamp)-4)
return hb_StrReplace( l_cTimeStamp , {" "=>"-",":"=>"-"})+"-Zulu"
//=================================================================================================================
