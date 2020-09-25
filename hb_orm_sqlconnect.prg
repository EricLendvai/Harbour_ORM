//Copyright (c) 2020 Eric Lendvai MIT License

//Will connect using the odbc driver, will not use any DNS configuration.

#include "hb_orm.ch"

#include "dbinfo.ch"

//See https://groups.google.com/forum/#!topic/harbour-users/hqDDiRyOcBA   for examples

request SQLMIX , SDDODBC

//=================================================================================================================
class hb_orm_SQLConnect
    hidden:
        classdata ConnectionCounter init 0    // Across all instances of this class. Used to ensure all the ::p_ConnectionNumber are unique accross instances.
        data p_ConnectionNumber     init 0
        data p_SQLConnection        init 0
        data p_BackendType          init 0
        data p_SQLEngineType        init 0
        data p_driver               init ""
        data p_server               init "localhost"
        data p_port                 init 0
        data p_user                 init ""
        data p_password             init ""
        data p_Database             init ""
        data p_SchemaName           init "public"
        data p_ErrorMessage         init ""
        data p_Locks                init {}
        data p_LockTimeout          init 20   //In Seconds
        data p_SQLExecErrorMessage  init ""

    exported:
        data p_Schema   init {=>}
        method SetBackendType(par_name)                                 // For Example, "MariaDB","MySQL","PostgreSQL"
        method GetSQLEngineType()     inline ::p_SQLEngineType          // 1 for"MariaDB" and "MySQL", 2 for "PostgreSQL"
        method SetDriver(par_name)
        method SetServer(par_name)
        method SetPort(par_number)
        method SetUser(par_name)
        method SetPassword(par_password)
        method SetDatabase(par_name)
        method SetSchema(par_name)             //only used for PostgreSQL
        method SetAllSettings(par_BackendType,par_Driver,par_Server,par_Port,par_User,par_Password,par_Database,par_Schema)
        method Connect()
        method Disconnect()
        method GetHandle()
        method GetErrorMessage()
        method Lock(par_Table,par_Key)
        method Unlock(par_Table,par_Key)
        
        method SQLExec(par_Command,par_CursorTempName)   //Used by the Locking system
        method GetSQLExecErrorMessage() inline ::p_SQLExecErrorMessage
        method GetConnectionNumber()    inline ::p_ConnectionNumber
        method GetDatabase()            inline ::p_Database
        method GetSchemaName()          inline ::p_SchemaName
        method LoadSchema()             //Called on successful Connect(). Should be called of the Schema changed since the last Connect()
    DESTRUCTOR destroy
endclass
//-----------------------------------------------------------------------------------------------------------------
method destroy() class hb_orm_SQLConnect
::Disconnect()
return .t.
//-----------------------------------------------------------------------------------------------------------------
method SQLExec(par_Command,par_CursorTempName) class hb_orm_SQLConnect   //Returns .t. if succeeded
local cPreviousDefaultRDD := RDDSETDEFAULT("SQLMIX")
local lSQLExecResult := .f.
local oError
local l_select := iif(used(),select(),0)

::p_SQLExecErrorMessage := ""
if ::p_SQLConnection > 0
    try
        if pcount() == 2
            CloseAlias(par_CursorTempName)
            select 0  //Ensure we don't overwrite any other work area
            lSQLExecResult := DBUseArea(.t.,"SQLMIX",par_Command,par_CursorTempName,.t.,.t.,"UTF8",::p_SQLConnection)
            if lSQLExecResult
                //There is a bug with reccount() when using SQLMIX. So to force loading all the data, using goto bottom+goto top
                dbGoBottom()
                dbGoTop()
            endif
        else
            lSQLExecResult := hb_RDDInfo(RDDI_EXECUTE,par_Command,"SQLMIX",::p_SQLConnection)
        endif
        if !lSQLExecResult
            ::p_SQLExecErrorMessage := "SQLExec Error Code: "+Trans(hb_RDDInfo(RDDI_ERRORNO))+" - Error description: "+hb_RDDInfo(RDDI_ERROR)
        endif
    catch oError
        // altd()
        lSQLExecResult := .f.  //Just in case the catch occurs after DBUserArea / hb_RDDInfo
        ::p_SQLExecErrorMessage := "SQLExec Error Code: "+Trans(oError:oscode)+" - Error description: "+oError:description+" - Operation: "+oError:operation
        // Idea for later  ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQL_Command+[ -> ]+::p_SQLExecErrorMessage)  _M_
    endtry
    if !empty(::p_SQLExecErrorMessage)
        hb_orm_SendToDebugView(::p_SQLExecErrorMessage)
    endif

endif

RDDSETDEFAULT(cPreviousDefaultRDD)
select (l_select)
    
return lSQLExecResult
//-----------------------------------------------------------------------------------------------------------------
method SetBackendType(par_name) class hb_orm_SQLConnect
local lResult := .t.

switch upper(par_name)
case "MARIADB"
    ::p_BackendType   := HB_ORM_BACKENDTYPE_MARIADB
    ::p_SQLEngineType := HB_ORM_ENGINETYPE_MYSQL
    ::p_port          := 3306
    ::p_driver        := "MySQL ODBC 8.0 Unicode Driver" //"MariaDB ODBC 3.1 Driver"
    exit
case "MYSQL"
    ::p_BackendType   := HB_ORM_BACKENDTYPE_MYSQL
    ::p_SQLEngineType := HB_ORM_ENGINETYPE_MYSQL
    ::p_port          := 3306
    ::p_driver        := "MySQL ODBC 8.0 Unicode Driver"
    exit
case "POSTGRESQL"
    ::p_BackendType   := HB_ORM_BACKENDTYPE_POSTGRESQL
    ::p_SQLEngineType := HB_ORM_ENGINETYPE_POSTGRESQL
    ::p_port          := 5432
    ::p_driver        := "PostgreSQL Unicode"
    exit
otherwise
    lResult = .f.
endswitch
    
return lResult
//-----------------------------------------------------------------------------------------------------------------
method SetDriver(par_name) class hb_orm_SQLConnect
::p_driver := par_name
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetServer(par_name) class hb_orm_SQLConnect
::p_server := par_name
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetPort(par_number) class hb_orm_SQLConnect
::p_port := par_number
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetUser(par_name) class hb_orm_SQLConnect
::p_user := par_name
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetPassword(par_password) class hb_orm_SQLConnect
::p_password := par_password
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetDatabase(par_name) class hb_orm_SQLConnect
::p_Database := par_name
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetSchema(par_name) class hb_orm_SQLConnect
::p_SchemaName := par_name
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetAllSettings(par_BackendType,par_Driver,par_Server,par_Port,par_User,par_Password,par_Database,par_Schema) class hb_orm_SQLConnect
if !hb_IsNil(par_BackendType)
    ::SetBackendType(par_BackendType)
endif
if !hb_IsNil(par_Driver)
    ::SetDriver(par_Driver)
endif
if !hb_IsNil(par_Server)
    ::SetServer(par_Server)
endif
if !hb_IsNil(par_Port)
    ::SetPort(par_Port)
endif
if !hb_IsNil(par_User)
    ::SetUser(par_User)
endif
if !hb_IsNil(par_Password)
    ::SetPassword(par_Password)
endif
if !hb_IsNil(par_Database)
    ::SetDatabase(par_Database)
endif
if !hb_IsNil(par_Schema)
    ::SetSchema(par_Schema)
endif
return Self
//-----------------------------------------------------------------------------------------------------------------
method Connect() class hb_orm_SQLConnect   // Return -1 on error, 0 if already connected, >0 if succeeded
local SQLHandle := -1
local cConnectionString := ""
local cPreviousDefaultRDD

::ConnectionCounter++
::p_ConnectionNumber := ::ConnectionCounter
hb_orm_SendToDebugView("hb_orm_sqlconnect Connecting Number="+trans(::p_ConnectionNumber))

cPreviousDefaultRDD = RDDSETDEFAULT( "SQLMIX" )

do case
case ::p_SQLConnection > 0
    ::p_ErrorMessage := "Already connected, disconnect first"
    SQLHandle := 0
case ::p_BackendType == 0
    ::p_ErrorMessage := "Missing 'Backend Type'"
case empty(::p_driver)
    ::p_ErrorMessage := "Missing 'Driver'"
case empty(::p_server)
    ::p_ErrorMessage := "Missing 'Server'"
case empty(::p_port)
    ::p_ErrorMessage := "Missing 'Port'"
case empty(::p_user)
    ::p_ErrorMessage := "Missing 'User'"
case empty(::p_Database)
    ::p_ErrorMessage := "Missing 'Database'"
otherwise
    do case
    case ::p_BackendType == HB_ORM_BACKENDTYPE_MARIADB .or. ::p_BackendType == HB_ORM_BACKENDTYPE_MYSQL   // MySQL or MariaDB
        cConnectionString := "SERVER="+::p_server+";Driver={"+::p_driver+"};USER="+::p_user+";PASSWORD="+::p_password+";DATABASE="+::p_Database+";PORT="+AllTrim(str(::p_port))
    case ::p_BackendType == HB_ORM_BACKENDTYPE_POSTGRESQL   // PostgreSQL
        cConnectionString := "Server="+::p_server+";Port="+AllTrim(str(::p_port))+";Driver={"+::p_driver+"};Uid="+::p_user+";Pwd="+::p_password+";Database="+::p_Database+";"
    otherwise
        ::p_ErrorMessage := "Invalid 'Backend Type'"
    endcase
    if !empty(cConnectionString)
        SQLHandle := hb_RDDInfo( RDDI_CONNECT, { "ODBC", cConnectionString })

        if SQLHandle == 0
            SQLHandle := -1
            ::p_ErrorMessage := "Unable connect to the server!"+Chr(13)+Chr(10)+Str(hb_RDDInfo( RDDI_ERRORNO ))+Chr(13)+Chr(10)+hb_RDDInfo( RDDI_ERROR )
        else
            ::p_SQLConnection    := SQLHandle
            ::p_ErrorMessage := ""
        endif
    endif
endcase

RDDSETDEFAULT(cPreviousDefaultRDD)

if SQLHandle > 0
    //Autoload the entire schema information in p_Schema
    ::LoadSchema()   
endif

return SQLHandle
//-----------------------------------------------------------------------------------------------------------------
method Disconnect() class hb_orm_SQLConnect
if ::p_ConnectionNumber > 0
    hb_orm_SendToDebugView("hb_orm_sqlconnect Disconnecting Number="+trans(::p_ConnectionNumber))
    ::p_ConnectionNumber := 0
    CloseAlias("hb_orm_sql_schema"+trans(::p_ConnectionNumber))
endif

if ::p_SQLConnection > 0
    hb_RDDInfo(RDDI_DISCONNECT, ::p_SQLConnection)
    ::p_SQLConnection := 0
endif
return NIL
//-----------------------------------------------------------------------------------------------------------------
method GetHandle() class hb_orm_SQLConnect
return ::p_SQLConnection  // Returns 0 if not connected
//-----------------------------------------------------------------------------------------------------------------
method GetErrorMessage() class hb_orm_SQLConnect
return ::p_ErrorMessage
//-----------------------------------------------------------------------------------------------------------------
method Lock(par_Table,par_Key) class hb_orm_SQLConnect

local l_ArrayRow
local l_CursorTempName
local l_LockName
local l_LockKey
local l_result  := .f.
local l_select
local l_SQL_Command

::p_ErrorMessage := ""

do case
case empty(par_Table)
    ::p_ErrorMessage := [Missing Table]
    
otherwise
    l_select = iif(used(),select(),0)

    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_LockName  = "lock_"+lower(::p_Database)+"_"+lower(par_Table)+"_"+Trans(par_Key)
        
        //Check if the lock is already created by the current connection
        l_ArrayRow = AScan( ::p_Locks, l_LockName )

        if !empty(l_ArrayRow)
            //Already Locked
            l_result = .t.
        else
            //No Locks entry to reuse

            //Do the actual locking
            l_CursorTempName = "c_DB_Temp"
            l_SQL_Command    = [SELECT GET_LOCK(']+l_LockName+[',]+Trans(::p_LockTimeout)+[) as result]
            if ::SQLExec(l_SQL_Command,l_CursorTempName)
                // if (l_CursorTempName)->(FieldGet(1)) == 1  //Since there is one 1 field, retreiving its value.
                if c_DB_Temp->result == 1  //Since there is one 1 field, retreiving its value.
                    AAdd(::p_Locks,l_LockName)
                    l_result = .t.
                else
                    ::p_ErrorMessage := "Failed lock resource "+l_LockName
                    hb_orm_SendToDebugView(::p_ErrorMessage)
                endif
            else
                ::p_ErrorMessage := "Failed to Run SQL to lock() "+::p_SQLExecErrorMessage
                hb_orm_SendToDebugView(::p_ErrorMessage)
            endif
            CloseAlias(l_CursorTempName)
            
        endif

    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        l_LockKey  := par_Key  //_M_ decide how to convert the par_Table+par_key to a single big int. 
        //There is a bug in PostgreSQL 12.3 with the 'SELECT * FROM pg_locks;' But the locks get release with pg_advisory_unlock()
        //No know timeout, unlike MySQL
        
        //Check if the lock is already created by the current connection
        l_ArrayRow = AScan( ::p_Locks, l_LockKey )

        if !empty(l_ArrayRow)
            //Already Locked
            l_result = .t.
        else
            //No Locks entry to reuse

            //Do the actual locking
            l_CursorTempName = "c_DB_Temp"
            l_SQL_Command    = [SELECT pg_advisory_lock(']+trans(l_LockKey)+[') as result]
            if ::SQLExec(l_SQL_Command,l_CursorTempName)
                //No know method to find out if lock failed.
                // if (l_CursorTempName)->(result) == 1
                    AAdd(::p_Locks,l_LockKey)
                    l_result = .t.
                // else
                //     hb_orm_SendToDebugView("Failed lock resource "+l_LockName)
                // endif
            else
                ::p_ErrorMessage := "Failed to Run SQL to lock() "+::p_SQLExecErrorMessage
                hb_orm_SendToDebugView(::p_ErrorMessage)
            endif
            CloseAlias(l_CursorTempName)
            
        endif

    endcase
    
    select (l_select)
    
endcase

return l_result
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
method Unlock(par_Table,par_Key) class hb_orm_SQLConnect

local l_ArrayRow
local l_CursorTempName
local l_LockName
local l_LockKey
local l_result  := .f.
local l_select
local l_SQL_Command

::p_ErrorMessage := ""
do case
case empty(par_Table)
    ::p_ErrorMessage := [Missing Table]
    
otherwise
    l_select = iif(used(),select(),0)

    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_LockName  = "lock_"+lower(::p_Database)+"_"+lower(par_Table)+"_"+trans(par_Key)
        
        //Check if the lock is already created by the current connection
        l_ArrayRow = AScan( ::p_Locks, l_LockName )

        if empty(l_ArrayRow)
            //Already Unocked
            l_result = .t.
        else
            //No Locks entry to reuse

            //Do the actual locking
            l_CursorTempName = "c_DB_Temp"
            l_SQL_Command    = [SELECT RELEASE_LOCK(']+l_LockName+[') as result]
            if ::SQLExec(l_SQL_Command,l_CursorTempName)
                hb_ADel(::p_Locks,l_ArrayRow,.t.)
                l_result := .t.
            else
                ::p_ErrorMessage := "Failed to Run SQL to unlock() "+::p_SQLExecErrorMessage
                hb_orm_SendToDebugView(::p_ErrorMessage)
            endif
            CloseAlias(l_CursorTempName)
            
        endif
            
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        l_LockKey  := par_Key  //_M_ decide how to convert the par_Table+par_key to a single big int. 
        //There is a bug in PostgreSQL 12.3 with the 'SELECT * FROM pg_locks;' But the locks get release with pg_advisory_unlock()
        
        //Check if the lock is already created by the current connection
        l_ArrayRow = AScan( ::p_Locks, l_LockKey )

        if empty(l_ArrayRow)
            //Already Unocked
            l_result = .t.
        else
            //No Locks entry to reuse

            //Do the actual locking
            l_CursorTempName = "c_DB_Temp"
            l_SQL_Command    = [SELECT pg_advisory_unlock(']+trans(l_LockKey)+[') as result]
            if ::SQLExec(l_SQL_Command,l_CursorTempName)
                hb_ADel(::p_Locks,l_ArrayRow,.t.)
                l_result := .t.
            else
                ::p_ErrorMessage := "Failed to Run SQL to unlock() "+::p_SQLExecErrorMessage
                hb_orm_SendToDebugView(::p_ErrorMessage)
            endif
            CloseAlias(l_CursorTempName)
            
        endif
            
    endcase
    
    select (l_select)
    
endcase

return l_result
//-----------------------------------------------------------------------------------------------------------------
method LoadSchema() class hb_orm_SQLConnect
local l_SQL_Command := ""
local l_FieldType,l_FieldLen,l_FieldDec,l_FieldAllowNull,l_FieldAutoIncrement
local l_TableName,l_TableNameLast
local l_TableSchema := {=>}

hb_hSetCaseMatch(l_TableSchema,.f.)
hb_HClear(::p_Schema)
hb_hSetCaseMatch(::p_Schema,.f.)

CloseAlias("hb_orm_sqlconnect_schema")

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL

    l_SQL_Command += [select tables.table_name                  as table_name,]
    l_SQL_Command += [       columns.ordinal_position           as field_position,]
    l_SQL_Command += [       columns.column_name                as field_name,]
    l_SQL_Command += [       columns.data_type                  as field_type,]
    l_SQL_Command += [       columns.character_maximum_length   as field_clength,]
    l_SQL_Command += [       columns.numeric_precision          as field_nlength,]
    l_SQL_Command += [       columns.numeric_scale              as field_decimals,]
    l_SQL_Command += [       (columns.is_nullable = 'YES')      as field_nullable,]
    l_SQL_Command += [       columns.column_default             as field_default,]
    l_SQL_Command += [       (columns.extra = 'auto_increment') as field_identity_is,]
    l_SQL_Command += [       upper(tables.table_name)           as tag1]
    l_SQL_Command += [ from information_schema.tables  as tables]
    l_SQL_Command += [ join information_schema.columns as columns on columns.TABLE_NAME = tables.TABLE_NAME]
    l_SQL_Command += [ where tables.table_schema    = ']+::p_Database+[']
    l_SQL_Command += [ and   tables.table_type      = 'BASE TABLE']
    l_SQL_Command += [ order by tag1,field_position]

    if !::SQLExec(l_SQL_Command,"hb_orm_sqlconnect_schema")
        ::p_ErrorMessage := [Failed SQL for hb_orm_sqlconnect_schema.]
        // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQL_Command+[ -> ]+::p_ErrorMessage)
    else
        if used("hb_orm_sqlconnect_schema")

            select hb_orm_sqlconnect_schema
// set filter to field->table_name = "table003"
// ExportTableToHtmlFile("hb_orm_sqlconnect_schema","MySQL_information_schema.html","MySQL Schema",,25)
// set filter to

            if Reccount() > 0
                l_TableNameLast := Trim(hb_orm_sqlconnect_schema->table_name)
                hb_HClear(l_TableSchema)

//altd()
                scan all
                    l_TableName := Trim(hb_orm_sqlconnect_schema->table_name)
                    if l_TableName != l_TableNameLast
                        ::p_Schema[l_TableNameLast] := hb_hClone(l_TableSchema)
                        hb_HClear(l_TableSchema)
                        l_TableNameLast := l_TableName
                    endif

                    switch trim(field->field_type)
                    case "int"
                        l_FieldType          := "I"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "bigint"
                        l_FieldType          := "IB"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "tinyint"
                        l_FieldType          := "L"   //_M_?
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "decimal"
                        l_FieldType          := "N"
                        l_FieldLen           := field->field_nlength
                        l_FieldDec           := field->field_decimals
                        exit
                    case "char"
                        l_FieldType          := "C"
                        l_FieldLen           := field->field_clength
                        l_FieldDec           := 0
                        exit
                    case "varchar"
                        l_FieldType          := "CV"
                        l_FieldLen           := field->field_clength
                        l_FieldDec           := 0
                        exit
                    case "text"
                        l_FieldType          := "M"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "date"
                        l_FieldType          := "D"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "binary"
                        l_FieldType          := "L"
                        l_FieldLen           := field->field_clength
                        l_FieldDec           := 0
                        exit
                    case "bit"
                        l_FieldType          := "BT"
                        l_FieldLen           := field->field_nlength
                        l_FieldDec           := 0
                        exit
                    case "time"  //_M_ ?
                        l_FieldType          := "T"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "datetime"
                        l_FieldType          := "TS"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    otherwise
                        l_FieldType          := "?"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                    endswitch

                    l_FieldAllowNull     := (field->field_nullable == 1)
                    l_FieldAutoIncrement := (field->field_identity_is == 1)
                    //{"I",,,,.t.}

                    l_TableSchema[trim(field->field_Name)] := {l_FieldType,;
                                                               l_FieldLen,;
                                                               l_FieldDec,;
                                                               l_FieldAllowNull,;
                                                               l_FieldAutoIncrement,;
                                                               field->field_type,;
                                                               field->field_clength,;
                                                               field->field_nlength,;
                                                               field->field_decimals,;
                                                               field->field_default}

                endscan

                ::p_Schema[l_TableNameLast] := hb_hClone(l_TableSchema)
                hb_HClear(l_TableSchema)

            endif

            // scan all for lower(trim(field->table_name)) == l_TableName_lower
            // HB_ORM_OUTPUTDEBUGSTRING("[Harbour] "+lower(trim(field->field_Name)) )
            // HB_ORM_OUTPUTDEBUGSTRING("[Harbour] "+lower(trim(field->field_type)) )

        endif

    endif


case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL

    l_SQL_Command += [select tables.table_name                as table_name,]
    l_SQL_Command += [       columns.ordinal_position         as field_position,]
    l_SQL_Command += [       columns.column_name              as field_name,]
    l_SQL_Command += [       columns.data_type                as field_type,]
    l_SQL_Command += [       columns.character_maximum_length as field_clength,]
    l_SQL_Command += [       columns.numeric_precision        as field_nlength,]
    l_SQL_Command += [       columns.numeric_scale            as field_decimals,]
    l_SQL_Command += [       (columns.is_nullable = 'YES')    as field_nullable,]
    l_SQL_Command += [       columns.column_default           as field_default,]
    l_SQL_Command += [       (columns.is_identity = 'YES')    as field_identity_is,]
    l_SQL_Command += [       upper(tables.table_name)         as tag1]
    // l_SQL_Command += [       (columns.identity_generation = 'ALWAYS')  as field_identity_always,]
    // l_SQL_Command += [       columns.identity_start                    as field_identity_start,]
    // l_SQL_Command += [       columns.identity_increment                as field_identity_increment]
    l_SQL_Command += [ from information_schema.tables  as tables]
    l_SQL_Command += [ join information_schema.columns as columns on columns.TABLE_NAME = tables.TABLE_NAME]
    l_SQL_Command += [ where tables.table_schema    = ']+::p_SchemaName+[']
    // l_SQL_Command += [ and   columns.table_schema   = ']+::p_SchemaName+[']
    l_SQL_Command += [ and   tables.table_type      = 'BASE TABLE']
    l_SQL_Command += [ order by tag1,field_position]




    if !::SQLExec(l_SQL_Command,"hb_orm_sqlconnect_schema")
        ::p_ErrorMessage := [Failed SQL for hb_orm_sqlconnect_schema.]
        // ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQL_Command+[ -> ]+::p_ErrorMessage)
    else
        if used("hb_orm_sqlconnect_schema")

            select hb_orm_sqlconnect_schema
// set filter to field->table_name = "table003"
// ExportTableToHtmlFile("hb_orm_sqlconnect_schema","PostgreSQL_information_schema.html","PostgreSQL Schema",,25)
// set filter to

            if Reccount() > 0
                l_TableNameLast := Trim(hb_orm_sqlconnect_schema->table_name)
                hb_HClear(l_TableSchema)

                scan all
                    l_TableName := Trim(hb_orm_sqlconnect_schema->table_name)
                    if l_TableName != l_TableNameLast
                        ::p_Schema[l_TableNameLast] := hb_hClone(l_TableSchema)
                        hb_HClear(l_TableSchema)
                        l_TableNameLast := l_TableName
                    endif
                    switch trim(field->field_type)
                    case "integer"
                        l_FieldType          := "I"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "bigint"
                        l_FieldType          := "IB"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "numeric"
                        l_FieldType          := "N"
                        l_FieldLen           := field->field_nlength
                        l_FieldDec           := field->field_decimals
                        exit
                    case "character"
                        l_FieldType          := "C"
                        l_FieldLen           := field->field_clength
                        l_FieldDec           := 0
                        exit
                    case "character varying"
                        l_FieldType          := "CV"
                        l_FieldLen           := field->field_clength
                        l_FieldDec           := 0
                        exit
                    case "text"
                        l_FieldType          := "M"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "date"
                        l_FieldType          := "D"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "boolean"
                        l_FieldType          := "L"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "time"
                        l_FieldType          := "T"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "timestamp"
                    case "timestamp without time zone"
                        l_FieldType          := "TS"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    case "money"
                        l_FieldType          := "Y"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                        exit
                    otherwise
                        l_FieldType          := "?"
                        l_FieldLen           := 0
                        l_FieldDec           := 0
                    endswitch

                    l_FieldAllowNull     := (field->field_nullable == "1")
                    l_FieldAutoIncrement := (field->field_identity_is == "1")                    //{"I",,,,.t.}

                    l_TableSchema[trim(field->field_Name)] := {l_FieldType,l_FieldLen,l_FieldDec,l_FieldAllowNull,l_FieldAutoIncrement}

                endscan

                ::p_Schema[l_TableNameLast] := hb_hClone(l_TableSchema)
                hb_HClear(l_TableSchema)

            endif

            // scan all for lower(trim(field->table_name)) == l_TableName_lower
            // HB_ORM_OUTPUTDEBUGSTRING("[Harbour] "+lower(trim(field->field_Name)) )
            // HB_ORM_OUTPUTDEBUGSTRING("[Harbour] "+lower(trim(field->field_type)) )

        endif

    endif

endcase

return NIL
//-----------------------------------------------------------------------------------------------------------------
