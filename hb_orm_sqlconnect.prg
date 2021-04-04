//Copyright (c) 2021 Eric Lendvai MIT License

//Will connect using the odbc driver, will not use any DNS configuration.

#include "hb_orm.ch"

#include "dbinfo.ch"

//See https://groups.google.com/forum/#!topic/harbour-users/hqDDiRyOcBA   for examples

request SQLMIX , SDDODBC

//=================================================================================================================

#include "hb_orm_sqlconnect_class_definition.prg"

//-----------------------------------------------------------------------------------------------------------------
method destroy() class hb_orm_SQLConnect
::Disconnect()
return .t.
//-----------------------------------------------------------------------------------------------------------------
method SQLExec(par_Command,par_cCursorName) class hb_orm_SQLConnect   //Returns .t. if succeeded
local l_cPreviousDefaultRDD := RDDSETDEFAULT("SQLMIX")
local l_lSQLExecResult := .f.
local l_oError
local l_select := iif(used(),select(),0)
local cErrorInfo

// if "SchemaVersion" $ par_Command .and. "TABLE" $ par_Command
// altd()
// //     // par_Command := "CREATE TABLE `SchemaVersion` (`pk` INT NOT NULL AUTO_INCREMENT,`name` VARCHAR NOT NULL DEFAULT '',`version` INT NOT NULL DEFAULT 0,PRIMARY KEY (`pk`) USING BTREE) ENGINE=InnoDB COLLATE='utf8_general_ci';"
//     par_Command := strtran(par_Command,"CREATE TABLE","CREASDASDATE TABASDASDLE ")
// endif

::p_SQLExecErrorMessage := ""
if ::p_SQLConnection > 0
    try
        if pcount() == 2
            CloseAlias(par_cCursorName)
            select 0  //Ensure we don't overwrite any other work area
            l_lSQLExecResult := DBUseArea(.t.,"SQLMIX",par_Command,par_cCursorName,.t.,.t.,"UTF8",::p_SQLConnection)
            if l_lSQLExecResult
                //There is a bug with reccount() when using SQLMIX. So to force loading all the data, using goto bottom+goto top
                dbGoBottom()
                dbGoTop()
            endif
        else
            l_lSQLExecResult := hb_RDDInfo(RDDI_EXECUTE,par_Command,"SQLMIX",::p_SQLConnection)
        endif
// altd()
// cErrorInfo := hb_RDDInfo(RDDI_ERROR)

        if !l_lSQLExecResult
            ::p_SQLExecErrorMessage := "SQLExec Error Code: "+Trans(hb_RDDInfo(RDDI_ERRORNO))+" - Error description: "+alltrim(hb_RDDInfo(RDDI_ERROR))
        endif
    catch l_oError
        l_lSQLExecResult := .f.  //Just in case the catch occurs after DBUserArea / hb_RDDInfo
        ::p_SQLExecErrorMessage := "SQLExec Error Code: "+Trans(l_oError:oscode)+" - Error description: "+alltrim(l_oError:description)+" - Operation: "+l_oError:operation
        // Idea for later  ::SQLSendToLogFileAndMonitoringSystem(0,1,l_SQLCommand+[ -> ]+::p_SQLExecErrorMessage)  _M_
    endtry

    if !empty(::p_SQLExecErrorMessage)
        cErrorInfo := hb_StrReplace(::p_SQLExecErrorMessage+" - Command: "+par_Command+iif(pcount() < 2,""," - Cursor Name: "+par_cCursorName),{chr(13)=>" ",chr(10)=>""})
        hb_orm_SendToDebugView(cErrorInfo)

        if !::p_DoNotReportErrors
            ::LogErrorEvent(,hb_orm_GetApplicationStack(),{{,,cErrorInfo}})   // par_cEventId,par_aErrors
        endif
    endif

endif

RDDSETDEFAULT(l_cPreviousDefaultRDD)
select (l_select)
    
return l_lSQLExecResult
//-----------------------------------------------------------------------------------------------------------------
method SetBackendType(par_cName) class hb_orm_SQLConnect
local l_lResult := .t.

switch upper(par_cName)
case "MARIADB"
    ::p_BackendType   := HB_ORM_BACKENDTYPE_MARIADB
    ::p_SQLEngineType := HB_ORM_ENGINETYPE_MYSQL
    ::p_Port          := 3306
    ::p_Driver        := "MySQL ODBC 8.0 Unicode Driver" //"MariaDB ODBC 3.1 Driver"
    exit
case "MYSQL"
    ::p_BackendType   := HB_ORM_BACKENDTYPE_MYSQL
    ::p_SQLEngineType := HB_ORM_ENGINETYPE_MYSQL
    ::p_Port          := 3306
    ::p_Driver        := "MySQL ODBC 8.0 Unicode Driver"
    exit
case "POSTGRESQL"
    ::p_BackendType   := HB_ORM_BACKENDTYPE_POSTGRESQL
    ::p_SQLEngineType := HB_ORM_ENGINETYPE_POSTGRESQL
    ::p_Port          := 5432
    ::p_Driver        := "PostgreSQL Unicode"
    exit
otherwise
    l_lResult = .f.
endswitch
    
return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method SetDriver(par_cName) class hb_orm_SQLConnect
::p_Driver := par_cName
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetServer(par_cName) class hb_orm_SQLConnect
::p_Server := par_cName
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetPort(par_number) class hb_orm_SQLConnect
::p_Port := par_number
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetUser(par_cName) class hb_orm_SQLConnect
::p_User := par_cName
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetPassword(par_password) class hb_orm_SQLConnect
::p_Password := par_password
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetDatabase(par_cName) class hb_orm_SQLConnect
::p_Database := par_cName
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetCurrentSchemaName(par_cName) class hb_orm_SQLConnect   //Return the name of the schema before being set
local l_cPreviousSchemaName := ::p_SchemaName
::p_SchemaName := iif(hb_IsNil(par_cName) .or. empty(par_cName),"public",par_cName)
return l_cPreviousSchemaName
//-----------------------------------------------------------------------------------------------------------------
method SetPrimaryKeyFieldName(par_cName) class hb_orm_SQLConnect
::p_PKFN := par_cName
return ::p_PKFN
//-----------------------------------------------------------------------------------------------------------------
method SetAllSettings(par_BackendType,par_Driver,par_Server,par_Port,par_User,par_Password,par_Database,par_Schema,par_PKFN) class hb_orm_SQLConnect
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
    ::SetCurrentSchemaName(par_Schema)
endif
if !hb_IsNil(par_PKFN)
    ::SetPrimaryKeyFieldName(par_PKFN)
endif
return Self
//-----------------------------------------------------------------------------------------------------------------
method Connect() class hb_orm_SQLConnect   // Return -1 on error, 0 if already connected, >0 if succeeded
local l_SQLHandle := -1
local l_cConnectionString := ""
local l_cPreviousDefaultRDD

::ConnectionCounter++
::p_ConnectionNumber := ::ConnectionCounter
hb_orm_SendToDebugView("hb_orm_sqlconnect Connection Number "+trans(::p_ConnectionNumber))

l_cPreviousDefaultRDD = RDDSETDEFAULT( "SQLMIX" )

do case
case ::p_SQLConnection > 0
    ::p_ErrorMessage := "Already connected, disconnect first"
    l_SQLHandle := 0
case ::p_BackendType == 0
    ::p_ErrorMessage := "Missing 'Backend Type'"
case empty(::p_Driver)
    ::p_ErrorMessage := "Missing 'Driver'"
case empty(::p_Server)
    ::p_ErrorMessage := "Missing 'Server'"
case empty(::p_Port)
    ::p_ErrorMessage := "Missing 'Port'"
case empty(::p_User)
    ::p_ErrorMessage := "Missing 'User'"
case empty(::p_Database)
    ::p_ErrorMessage := "Missing 'Database'"
otherwise
    do case
    case ::p_BackendType == HB_ORM_BACKENDTYPE_MARIADB .or. ::p_BackendType == HB_ORM_BACKENDTYPE_MYSQL   // MySQL or MariaDB
        // To enable multi statements to be executed, meaning multiple SQL commands separated by ";", had to use the OPTION= setting.
        // See: https://dev.mysql.com/doc/connector-odbc/en/connector-odbc-configuration-connection-parameters.html#codbc-dsn-option-flags
        l_cConnectionString := "SERVER="+::p_Server+";Driver={"+::p_Driver+"};USER="+::p_User+";PASSWORD="+::p_Password+";DATABASE="+::p_Database+";PORT="+AllTrim(str(::p_Port)+";OPTION=67108864;")
    case ::p_BackendType == HB_ORM_BACKENDTYPE_POSTGRESQL   // PostgreSQL
        l_cConnectionString := "Server="+::p_Server+";Port="+AllTrim(str(::p_Port))+";Driver={"+::p_Driver+"};Uid="+::p_User+";Pwd="+::p_Password+";Database="+::p_Database+";"
    otherwise
        ::p_ErrorMessage := "Invalid 'Backend Type'"
    endcase
    if !empty(l_cConnectionString)
        l_SQLHandle := hb_RDDInfo( RDDI_CONNECT, { "ODBC", l_cConnectionString })

        if l_SQLHandle == 0
            l_SQLHandle := -1
            ::p_ErrorMessage := "Unable connect to the server!"+Chr(13)+Chr(10)+Str(hb_RDDInfo( RDDI_ERRORNO ))+Chr(13)+Chr(10)+hb_RDDInfo( RDDI_ERROR )
        else
            ::p_SQLConnection    := l_SQLHandle
            ::p_ErrorMessage := ""
        endif
    endif
endcase

RDDSETDEFAULT(l_cPreviousDefaultRDD)
// ?hb_DateTime()
if l_SQLHandle > 0
    ::Connected := .t.

    if ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        if !::TableExists(::PostgreSQLHBORMSchemaName+".SchemaCacheLog")
            ::EnableSchemaChangeTracking()
            ::UpdateSchemaCache(.t.)
        else
            ::UpdateSchemaCache()
        endif
    endif

    //Load the entire schema
    ::LoadSchema()

    //AutoFix ORM supporting tables
    if ::UpdateORMSupportSchema()
        ::LoadSchema()
    endif

    // altd()
    // if hb_hPos(::p_Schema,"SchemaVersion")         <= 0 .or. ;
    //    hb_hPos(::p_Schema,"SchemaAutoTrimLog")     <= 0 .or. ;
    //    hb_hPos(::p_Schema,"SchemaAndDataErrorLog") <= 0
    // endif
else
    ::Connected := .f.
endif

// ?hb_DateTime()

return l_SQLHandle
//-----------------------------------------------------------------------------------------------------------------
method Disconnect() class hb_orm_SQLConnect
if ::p_ConnectionNumber > 0
    hb_orm_SendToDebugView("hb_orm_sqlconnect Disconnecting Connection Number "+trans(::p_ConnectionNumber))
    ::p_ConnectionNumber := 0
    CloseAlias("hb_orm_sql_schema"+trans(::p_ConnectionNumber))
endif

if ::p_SQLConnection > 0
    hb_RDDInfo(RDDI_DISCONNECT,,"SQLMIX",::p_SQLConnection)
    ::p_SQLConnection := 0
endif

::Connected := .f.

return NIL
//-----------------------------------------------------------------------------------------------------------------
method GetHandle() class hb_orm_SQLConnect
return ::p_SQLConnection  // Returns 0 if not connected
//-----------------------------------------------------------------------------------------------------------------
method GetErrorMessage() class hb_orm_SQLConnect
return ::p_ErrorMessage
//-----------------------------------------------------------------------------------------------------------------
method Lock(par_cSchemaAndTableName,par_Key) class hb_orm_SQLConnect

local l_ArrayRow
local l_CursorTempName
local l_LockName
local l_result  := .f.
local l_select
local l_SQLCommand
local l_iPos,l_cSchemaName,l_cTableName
local l_iTableNumber

::p_ErrorMessage := ""

do case
case empty(par_cSchemaAndTableName)
    ::p_ErrorMessage := [Missing Table]
    
otherwise
    l_select = iif(used(),select(),0)

    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_LockName  = "lock_"+lower(::p_Database)+"_"+lower(par_cSchemaAndTableName)+"_"+Trans(par_Key)
        
        //Check if the lock is already created by the current connection
        l_ArrayRow = AScan( ::p_Locks, l_LockName )

        if !empty(l_ArrayRow)
            //Already Locked
            l_result = .t.
        else
            //No Locks entry to reuse

            //Do the actual locking
            l_CursorTempName = "c_DB_Temp"
            l_SQLCommand    = [SELECT GET_LOCK(']+l_LockName+[',]+Trans(::p_LockTimeout)+[) as result]
            if ::SQLExec(l_SQLCommand,l_CursorTempName)
                // if (l_CursorTempName)->(FieldGet(1)) == 1  //Since there is one 1 field, retrieving its value.
                if c_DB_Temp->result == 1  //Since there is one 1 field, retrieving its value.
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
        //There is a bug in PostgreSQL 12.3 with the 'SELECT * FROM pg_locks;' But the locks get release with pg_advisory_unlock()
        //No know timeout, unlike MySQL
        
        l_iPos := at(".",par_cSchemaAndTableName)
        if l_iPos == 0
            l_cSchemaName := ""
            l_cTableName  := par_cSchemaAndTableName
        else
            l_cSchemaName := left(par_cSchemaAndTableName,l_iPos-1)
            l_cTableName  := substr(par_cSchemaAndTableName,l_iPos+1)
        endif

        l_SQLCommand := [SELECT pk]
        l_SQLCommand += [ FROM  "]+::PostgreSQLHBORMSchemaName+["."SchemaTableNumber"]
        l_SQLCommand += [ WHERE schemaname = ']+l_cSchemaName+[']
        l_SQLCommand += [ AND   tablename = ']+l_cTableName+[']

        l_CursorTempName = "c_DB_Temp"
        if ::SQLExec(l_SQLCommand,l_CursorTempName)
            // l_iTableNumber := (l_CursorTempName)->(pk)
            l_iTableNumber := (l_CursorTempName)->(FieldGet(FieldPos("pk")))
            CloseAlias(l_CursorTempName)

            if l_iTableNumber > 0
                l_LockName := alltrim(str(par_Key))+StrZero(l_iTableNumber,::MaxDigitsInTableNumber)

                //Check if the lock is already created by the current connection
                l_ArrayRow = AScan( ::p_Locks, l_LockName )

                if !empty(l_ArrayRow)
                    //Already Locked
                    l_result = .t.
                else
                    //No Locks entry to reuse

                    //Do the actual locking
                    l_SQLCommand    = [SELECT pg_advisory_lock(']+l_LockName+[') as result]
                    if ::SQLExec(l_SQLCommand,l_CursorTempName)
                        //No know method to find out if lock failed.
                        // if (l_CursorTempName)->(result) == 1
                            AAdd(::p_Locks,l_LockName)
                            l_result = .t.
                        // else
                        //     hb_orm_SendToDebugView("Failed lock resource "+l_LockName)
                        // endif
                    else
                        ::p_ErrorMessage := "Failed to Run SQL to lock() "+::p_SQLExecErrorMessage
                        hb_orm_SendToDebugView(::p_ErrorMessage)
                    endif
                    
                endif
            else
                ::p_ErrorMessage := [Failed to Run lock(). Could not find table name "]+par_cSchemaAndTableName+[".]
                hb_orm_SendToDebugView(::p_ErrorMessage)
            endif
        else
            ::p_ErrorMessage := "Failed to Run Pre SQL to lock() "+::p_SQLExecErrorMessage
            hb_orm_SendToDebugView(::p_ErrorMessage)
        endif
        CloseAlias(l_CursorTempName)

    endcase
    CloseAlias(l_CursorTempName)
    select (l_select)
    
endcase

return l_result
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
method Unlock(par_cSchemaAndTableName,par_Key) class hb_orm_SQLConnect

local l_ArrayRow
local l_CursorTempName
local l_LockName
local l_result  := .f.
local l_select
local l_SQLCommand
local l_iPos,l_cSchemaName,l_cTableName
local l_iTableNumber

::p_ErrorMessage := ""
do case
case empty(par_cSchemaAndTableName)
    ::p_ErrorMessage := [Missing Table]
    
otherwise
    l_select = iif(used(),select(),0)

    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_LockName  = "lock_"+lower(::p_Database)+"_"+lower(par_cSchemaAndTableName)+"_"+trans(par_Key)
        
        //Check if the lock is already created by the current connection
        l_ArrayRow = AScan( ::p_Locks, l_LockName )

        if empty(l_ArrayRow)
            //Already Unlocked
            l_result = .t.
        else
            //No Locks entry to reuse

            //Do the actual locking
            l_CursorTempName = "c_DB_Temp"
            l_SQLCommand    = [SELECT RELEASE_LOCK(']+l_LockName+[') as result]
            if ::SQLExec(l_SQLCommand,l_CursorTempName)
                hb_ADel(::p_Locks,l_ArrayRow,.t.)
                l_result := .t.
            else
                ::p_ErrorMessage := "Failed to Run SQL to unlock() "+::p_SQLExecErrorMessage
                hb_orm_SendToDebugView(::p_ErrorMessage)
            endif
            CloseAlias(l_CursorTempName)
            
        endif
            
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        //There is a bug in PostgreSQL 12.3 with the 'SELECT * FROM pg_locks;' But the locks get release with pg_advisory_unlock()

        l_iPos := at(".",par_cSchemaAndTableName)
        if l_iPos == 0
            l_cSchemaName := ""
            l_cTableName  := par_cSchemaAndTableName
        else
            l_cSchemaName := left(par_cSchemaAndTableName,l_iPos-1)
            l_cTableName  := substr(par_cSchemaAndTableName,l_iPos+1)
        endif

        l_SQLCommand := [SELECT pk]
        l_SQLCommand += [ FROM  "]+::PostgreSQLHBORMSchemaName+["."SchemaTableNumber"]
        l_SQLCommand += [ WHERE schemaname = ']+l_cSchemaName+[']
        l_SQLCommand += [ AND   tablename = ']+l_cTableName+[']

        l_CursorTempName = "c_DB_Temp"
        if ::SQLExec(l_SQLCommand,l_CursorTempName)
            // l_iTableNumber := (l_CursorTempName)->(pk)
            l_iTableNumber := (l_CursorTempName)->(FieldGet(FieldPos("pk")))
            CloseAlias(l_CursorTempName)

            if l_iTableNumber > 0
                l_LockName := alltrim(str(par_Key))+StrZero(l_iTableNumber,::MaxDigitsInTableNumber)
                
                //Check if the lock is already created by the current connection
                l_ArrayRow = AScan( ::p_Locks, l_LockName )

                if empty(l_ArrayRow)
                    //Already Unlocked
                    l_result = .t.
                else
                    //No Locks entry to reuse

                    //Do the actual locking
                    l_CursorTempName = "c_DB_Temp"
                    l_SQLCommand    = [SELECT pg_advisory_unlock(']+l_LockName+[') as result]
                    if ::SQLExec(l_SQLCommand,l_CursorTempName)
                        hb_ADel(::p_Locks,l_ArrayRow,.t.)
                        l_result := .t.
                    else
                        ::p_ErrorMessage := "Failed to Run SQL to unlock() "+::p_SQLExecErrorMessage
                        hb_orm_SendToDebugView(::p_ErrorMessage)
                    endif
                    CloseAlias(l_CursorTempName)
                    
                endif

            else
                ::p_ErrorMessage := [Failed to Run unlock(). Could not find table name "]+par_cSchemaAndTableName+[".]
                hb_orm_SendToDebugView(::p_ErrorMessage)
            endif
        else
            ::p_ErrorMessage := "Failed to Run Pre SQL to unlock() "+::p_SQLExecErrorMessage
            hb_orm_SendToDebugView(::p_ErrorMessage)
        endif
        CloseAlias(l_CursorTempName)
            
    endcase
    
    select (l_select)
    
endcase

return l_result
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
method LogAutoTrimEvent(par_cEventId,par_cSchemaAndTableName,par_nKey,par_aAutoTrimmedFields) class hb_orm_SQLConnect
local l_SQLCommand
local l_LastErrorMessage
local l_iAutoTrimmedInfo
local l_Value
local l_FieldName,l_FieldType,l_FieldLen
local l_iPos,l_cSchemaName,l_cTableName

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_SQLCommand := [INSERT INTO ]+::FormatIdentifier("SchemaAutoTrimLog")+[ (]
    
    if !hb_IsNIL(par_cEventId)
        l_SQLCommand += ::FormatIdentifier("eventid")+[,]
    endif
    l_SQLCommand += ::FormatIdentifier("datetime")+[,]
    l_SQLCommand += ::FormatIdentifier("ip")+[,]
    l_SQLCommand += ::FormatIdentifier("tablename")+[,]
    l_SQLCommand += ::FormatIdentifier("recordpk")+[,]
    l_SQLCommand += ::FormatIdentifier("fieldname")+[,]
    l_SQLCommand += ::FormatIdentifier("fieldtype")+[,]
    l_SQLCommand += ::FormatIdentifier("fieldlen")+[,]
    l_SQLCommand += ::FormatIdentifier("fieldvaluem")+[,]
    l_SQLCommand += ::FormatIdentifier("fieldvaluer")

    l_SQLCommand += [) VALUES ]

    for l_iAutoTrimmedInfo := 1 to len(par_aAutoTrimmedFields)
        l_FieldName := par_aAutoTrimmedFields[l_iAutoTrimmedInfo][1]
        l_Value     := par_aAutoTrimmedFields[l_iAutoTrimmedInfo][2]
        l_FieldType := par_aAutoTrimmedFields[l_iAutoTrimmedInfo][3]
        l_FieldLen  := par_aAutoTrimmedFields[l_iAutoTrimmedInfo][4]
        
        hb_orm_SendToDebugView("Auto Trim Event:"+;
                              iif(hb_IsNIL(par_cSchemaAndTableName) , "" , [  Table = "]+par_cSchemaAndTableName+["])+;
                              iif(hb_IsNIL(par_nKey)                , "" , [  Key = ]+trans(par_nKey))+;
                              iif(hb_IsNIL(l_FieldName)             , "" , [  Field = "]+l_FieldName+["]))
        
        if l_iAutoTrimmedInfo > 1
            l_SQLCommand +=  [,]
        endif
        l_SQLCommand +=  [(]

        if !hb_IsNIL(par_cEventId)
            l_SQLCommand += [']+left(par_cEventId,HB_ORM_MAX_EVENTID_SIZE)+[',]
        endif
        l_SQLCommand += [now(),]
        l_SQLCommand += [SUBSTRING(USER(), LOCATE('@', USER())+1),]
        l_SQLCommand += [']+par_cSchemaAndTableName+[',]
        l_SQLCommand += trans(par_nKey)+[,]
        l_SQLCommand += [']+l_FieldName+[',]           // Field Name
        l_SQLCommand += [']+allt(l_FieldType)+[',]     // Field type
        l_SQLCommand += trans(l_FieldLen)+[,]
        
        if !empty(el_inlist(l_FieldType,"B","BV","R"))
            //Binary
            l_SQLCommand += [NULL,]
            l_SQLCommand += [x']+hb_StrToHex(l_Value)+[']
        else
            //Text
            l_SQLCommand += [x']+hb_StrToHex(l_Value)+[',]
            l_SQLCommand += [NULL]
        endif

        l_SQLCommand +=  [)]
    endfor

    l_SQLCommand += [;]

    if !::SQLExec(l_SQLCommand)
        l_LastErrorMessage := ::GetSQLExecErrorMessage()
        hb_orm_SendToDebugView("Error on Auto Trim: "+l_LastErrorMessage)
    endif

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_iPos := at(".",par_cSchemaAndTableName)
    if l_iPos == 0
        l_cSchemaName := ""
        l_cTableName  := par_cSchemaAndTableName
    else
        l_cSchemaName := left(par_cSchemaAndTableName,l_iPos-1)
        l_cTableName  := substr(par_cSchemaAndTableName,l_iPos+1)
    endif

    l_SQLCommand := [INSERT INTO ]+::FormatIdentifier(::PostgreSQLHBORMSchemaName+".SchemaAutoTrimLog")+[ (]
    
    if !hb_IsNIL(par_cEventId)
        l_SQLCommand += ::FormatIdentifier("eventid")+[,]
    endif
    l_SQLCommand += ::FormatIdentifier("datetime")+[,]
    l_SQLCommand += ::FormatIdentifier("ip")+[,]
    l_SQLCommand += ::FormatIdentifier("schemaname")+[,]
    l_SQLCommand += ::FormatIdentifier("tablename")+[,]
    l_SQLCommand += ::FormatIdentifier("recordpk")+[,]
    l_SQLCommand += ::FormatIdentifier("fieldname")+[,]
    l_SQLCommand += ::FormatIdentifier("fieldtype")+[,]
    l_SQLCommand += ::FormatIdentifier("fieldlen")+[,]
    l_SQLCommand += ::FormatIdentifier("fieldvaluem")+[,]
    l_SQLCommand += ::FormatIdentifier("fieldvaluer")

    l_SQLCommand += [) VALUES ]

    for l_iAutoTrimmedInfo := 1 to len(par_aAutoTrimmedFields)
        l_FieldName := par_aAutoTrimmedFields[l_iAutoTrimmedInfo][1]
        l_Value     := par_aAutoTrimmedFields[l_iAutoTrimmedInfo][2]
        l_FieldType := par_aAutoTrimmedFields[l_iAutoTrimmedInfo][3]
        l_FieldLen  := par_aAutoTrimmedFields[l_iAutoTrimmedInfo][4]

        hb_orm_SendToDebugView("Auto Trim Event:"+;
                              iif(hb_IsNIL(par_cSchemaAndTableName) , "" , [  Table = "]+par_cSchemaAndTableName+["])+;
                              iif(hb_IsNIL(par_nKey)                , "" , [  Key = ]+trans(par_nKey))+;
                              iif(hb_IsNIL(l_FieldName)             , "" , [  Field = "]+l_FieldName+["]))
        
        if l_iAutoTrimmedInfo > 1
            l_SQLCommand +=  [,]
        endif
        l_SQLCommand +=  [(]

        if !hb_IsNIL(par_cEventId)
            l_SQLCommand += [']+left(par_cEventId,HB_ORM_MAX_EVENTID_SIZE)+[',]
        endif
        l_SQLCommand += [current_timestamp,]
        l_SQLCommand += [inet_client_addr(),]
        l_SQLCommand += [']+l_cSchemaName+[',]
        l_SQLCommand += [']+l_cTableName+[',]
        l_SQLCommand += trans(par_nKey)+[,]

        l_SQLCommand += [']+l_FieldName+[',]           // Field Name
        l_SQLCommand += [']+allt(l_FieldType)+[',]     // Field type
        l_SQLCommand += trans(l_FieldLen)+[,]

        if !empty(el_inlist(l_FieldType,"B","BV","R"))
            //Binary
            l_SQLCommand += [NULL,]
            l_SQLCommand += [E'\x]+hb_StrToHex(l_Value,"\x")+[']
        else
            //Text
            l_SQLCommand += [E'\x]+hb_StrToHex(l_Value,"\x")+[',]
            l_SQLCommand += [NULL]
        endif

        l_SQLCommand +=  [)]
    endfor

    l_SQLCommand += [;]

    if !::SQLExec(l_SQLCommand)
        l_LastErrorMessage := ::GetSQLExecErrorMessage()
        hb_orm_SendToDebugView("Error on Auto Trim: "+l_LastErrorMessage)
    endif

endcase
return NIL

//par_cTableName  par_cSchemaAndTableName

//-----------------------------------------------------------------------------------------------------------------
method LogErrorEvent(par_cEventId,par_cAppStack,par_aErrors) class hb_orm_SQLConnect
local l_SQLCommand
local l_LastErrorMessage
local l_iErrors
local l_cSchemaAndTableName,l_nKey,l_cErrorMessage
local l_lDoNotReportErrors := ::p_DoNotReportErrors
local l_iPos,l_cSchemaName,l_cTableName

::p_DoNotReportErrors := .t.  // To avoid cycling reporting of errors

// altd()

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_SQLCommand := [INSERT INTO ]+::FormatIdentifier("SchemaAndDataErrorLog")+[ (]
    
    if !hb_IsNIL(par_cEventId)
        l_SQLCommand += ::FormatIdentifier("eventid")+[,]
    endif
    if !hb_IsNIL(par_cAppStack)
        l_SQLCommand += ::FormatIdentifier("appstack")+[,]
    endif
    l_SQLCommand += ::FormatIdentifier("datetime")+[,]
    l_SQLCommand += ::FormatIdentifier("ip")+[,]
    l_SQLCommand += ::FormatIdentifier("tablename")+[,]
    l_SQLCommand += ::FormatIdentifier("recordpk")+[,]
    l_SQLCommand += ::FormatIdentifier("errormessage")

    l_SQLCommand += [) VALUES ]

    for l_iErrors := 1 to len(par_aErrors)
        l_cSchemaAndTableName := par_aErrors[l_iErrors][1]
        l_nKey                := par_aErrors[l_iErrors][2]
        l_cErrorMessage       := par_aErrors[l_iErrors][3]

        hb_orm_SendToDebugView("Error Event:"+;
                              iif(hb_IsNIL(l_cSchemaAndTableName) , "" , [  Table = "]+l_cSchemaAndTableName+["])+;
                              iif(hb_IsNIL(l_nKey)                , "" , [  Key = ]+trans(l_nKey))+;
                              [  ]+l_cErrorMessage)

        if l_iErrors > 1
            l_SQLCommand +=  [,]
        endif
        l_SQLCommand +=  [(]

        if !hb_IsNIL(par_cEventId)
            l_SQLCommand += [']+left(par_cEventId,HB_ORM_MAX_EVENTID_SIZE)+[',]
        endif
        if !hb_IsNIL(par_cAppStack)
            l_SQLCommand += [x']+hb_StrToHex(par_cAppStack)+[',]
        endif
        l_SQLCommand += [now(),]
        l_SQLCommand += [SUBSTRING(USER(), LOCATE('@', USER())+1),]
        l_SQLCommand += iif(hb_IsNIL(l_cTableName) , [NULL,] , [']+l_cTableName+[',])
        l_SQLCommand += iif(hb_IsNIL(l_nKey)       , [NULL,] , trans(l_nKey)+[,])
        l_SQLCommand += [x']+hb_StrToHex(l_cErrorMessage)+[']

        l_SQLCommand +=  [)]
    endfor

    l_SQLCommand += [;]

    if !::SQLExec(l_SQLCommand)
        l_LastErrorMessage := ::GetSQLExecErrorMessage()
        hb_orm_SendToDebugView("Error on Auto Trim: "+l_LastErrorMessage)
    endif

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_SQLCommand := [INSERT INTO ]+::FormatIdentifier(::PostgreSQLHBORMSchemaName+".SchemaAndDataErrorLog")+[ (]
    
    if !hb_IsNIL(par_cEventId)
        l_SQLCommand += ::FormatIdentifier("eventid")+[,]
    endif
    if !hb_IsNIL(par_cAppStack)
        l_SQLCommand += ::FormatIdentifier("appstack")+[,]
    endif
    l_SQLCommand += ::FormatIdentifier("datetime")+[,]
    l_SQLCommand += ::FormatIdentifier("ip")+[,]
    l_SQLCommand += ::FormatIdentifier("schemaname")+[,]
    l_SQLCommand += ::FormatIdentifier("tablename")+[,]
    l_SQLCommand += ::FormatIdentifier("recordpk")+[,]
    l_SQLCommand += ::FormatIdentifier("errormessage")

    l_SQLCommand += [) VALUES ]

    for l_iErrors := 1 to len(par_aErrors)
        l_cSchemaAndTableName := par_aErrors[l_iErrors][1]
        l_nKey                := par_aErrors[l_iErrors][2]
        l_cErrorMessage       := par_aErrors[l_iErrors][3]

        if hb_IsNIL(l_cSchemaAndTableName)
            l_cSchemaName := NIL
            l_cTableName  := NIL
        else
            l_iPos := at(".",l_cSchemaAndTableName)
            if l_iPos == 0
                l_cSchemaName := ""
                l_cTableName  := l_cSchemaAndTableName
            else
                l_cSchemaName := left(l_cSchemaAndTableName,l_iPos-1)
                l_cTableName  := substr(l_cSchemaAndTableName,l_iPos+1)
            endif
        endif


        hb_orm_SendToDebugView("Error Event:"+;
                              iif(hb_IsNIL(l_cSchemaAndTableName) , "" , [  Table = "]+l_cSchemaAndTableName+["])+;
                              iif(hb_IsNIL(l_nKey)                , "" , [  Key = ]+trans(l_nKey))+;
                              [  ]+l_cErrorMessage)

        if l_iErrors > 1
            l_SQLCommand +=  [,]
        endif
        l_SQLCommand +=  [(]

        if !hb_IsNIL(par_cEventId)
            l_SQLCommand += [']+left(par_cEventId,HB_ORM_MAX_EVENTID_SIZE)+[',]
        endif
        if !hb_IsNIL(par_cAppStack)
            l_SQLCommand += [E'\x]+hb_StrToHex(par_cAppStack,"\x")+[',]
        endif
        l_SQLCommand += [current_timestamp,]
        l_SQLCommand += [inet_client_addr(),]
        l_SQLCommand += iif(hb_IsNIL(l_cSchemaName) , [NULL,] , [']+l_cSchemaName+[',])
        l_SQLCommand += iif(hb_IsNIL(l_cTableName)  , [NULL,] , [']+l_cTableName+[',])
        l_SQLCommand += iif(hb_IsNIL(l_nKey)        , [NULL,] , trans(l_nKey)+[,])
        l_SQLCommand += [E'\x]+hb_StrToHex(l_cErrorMessage,"\x")+[']

        l_SQLCommand +=  [)]
    endfor

    l_SQLCommand += [;]

    if !::SQLExec(l_SQLCommand)
        l_LastErrorMessage := ::GetSQLExecErrorMessage()
        hb_orm_SendToDebugView("Error on Error Log: "+l_LastErrorMessage)
    endif

endcase

::p_DoNotReportErrors := l_lDoNotReportErrors

return NIL
//-----------------------------------------------------------------------------------------------------------------
function hb_orm_GetApplicationStack()
local l_cInfo := ""
local nLevel  := 1

do while !empty(ProcName(nLevel))
    if !empty(l_cInfo)
        l_cInfo += CRLF
    endif
    l_cInfo += trans(nLevel)+" "+ProcFile(nLevel)+"->"+ProcName(nLevel)+"("+trans(ProcLine(nLevel))+")"
    nLevel++
enddo

return l_cInfo
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
#include "hb_orm_schema.prg"
//-----------------------------------------------------------------------------------------------------------------
