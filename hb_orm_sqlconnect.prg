//Copyright (c) 2023 Eric Lendvai MIT License

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
method SQLExec(par_cCommand,par_cCursorName) class hb_orm_SQLConnect   //Returns .t. if succeeded
local l_cPreviousDefaultRDD := RDDSETDEFAULT("SQLMIX")
local l_lSQLExecResult := .f.
local l_oError
local l_nSelect := iif(used(),select(),0)
local cErrorInfo

// if "SchemaVersion" $ par_cCommand .and. "TABLE" $ par_cCommand
// altd()
// //     // par_cCommand := "CREATE TABLE `SchemaVersion` (`pk` INT NOT NULL AUTO_INCREMENT,`name` VARCHAR NOT NULL DEFAULT '',`version` INT NOT NULL DEFAULT 0,PRIMARY KEY (`pk`) USING BTREE) ENGINE=InnoDB COLLATE='utf8_general_ci';"
//     par_cCommand := strtran(par_cCommand,"CREATE TABLE","CREASDASDATE TABASDASDLE ")
// endif

if !::p_DoNotReportErrors
    ::p_SQLExecErrorMessage := ""
endif
if ::p_SQLConnection > 0
    try
        if pcount() == 2
            CloseAlias(par_cCursorName)
            select 0  //Ensure we don't overwrite any other work area
            l_lSQLExecResult := DBUseArea(.t.,"SQLMIX",par_cCommand,par_cCursorName,.t.,.t.,"UTF8EX",::p_SQLConnection)
            if l_lSQLExecResult
                //There is a bug with reccount() when using SQLMIX. So to force loading all the data, using goto bottom+goto top
                dbGoBottom()
                dbGoTop()
            endif
        else
            l_lSQLExecResult := hb_RDDInfo(RDDI_EXECUTE,par_cCommand,"SQLMIX",::p_SQLConnection)
        endif
// altd()
// cErrorInfo := hb_RDDInfo(RDDI_ERROR)

        if !::p_DoNotReportErrors
            if !l_lSQLExecResult
                ::p_SQLExecErrorMessage := "SQLExec Error Code: "+Trans(hb_RDDInfo(RDDI_ERRORNO))+" - Error description: "+alltrim(hb_RDDInfo(RDDI_ERROR))
            endif
        endif
    catch l_oError
        l_lSQLExecResult := .f.  //Just in case the catch occurs after DBUserArea / hb_RDDInfo
        if !::p_DoNotReportErrors
            ::p_SQLExecErrorMessage := "SQLExec Error Code: "+Trans(l_oError:oscode)+" - Error description: "+alltrim(l_oError:description)+" - Operation: "+l_oError:operation
        endif
        // Idea for later  ::SQLSendToLogFileAndMonitoringSystem(0,1,l_cSQLCommand+[ -> ]+::p_SQLExecErrorMessage)  _M_
    endtry


    if !::p_DoNotReportErrors
        if !empty(::p_SQLExecErrorMessage)
            cErrorInfo := hb_StrReplace(::p_SQLExecErrorMessage+" - Command: "+par_cCommand+iif(pcount() < 2,""," - Cursor Name: "+par_cCursorName),{chr(13)=>" ",chr(10)=>""})
            hb_orm_SendToDebugView(cErrorInfo)
            ::LogErrorEvent(,{{,,cErrorInfo,hb_orm_GetApplicationStack()}})   // par_cEventId,par_aErrors
        endif
    endif

endif

RDDSETDEFAULT(l_cPreviousDefaultRDD)
select (l_nSelect)
    
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
method SetPort(par_nNumber) class hb_orm_SQLConnect
::p_Port := par_nNumber
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetUser(par_cName) class hb_orm_SQLConnect
::p_User := par_cName
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetPassword(par_cPassword) class hb_orm_SQLConnect
::p_Password := par_cPassword
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
::p_PrimaryKeyFieldName := par_cName
return ::p_PrimaryKeyFieldName
//-----------------------------------------------------------------------------------------------------------------
method SetCreationTimeFieldName(par_cName) class hb_orm_SQLConnect
::p_CreationTimeFieldName := par_cName
return ::p_CreationTimeFieldName
//-----------------------------------------------------------------------------------------------------------------
method SetModificationTimeFieldName(par_cName) class hb_orm_SQLConnect
::p_ModificationTimeFieldName := par_cName
return ::p_ModificationTimeFieldName
//-----------------------------------------------------------------------------------------------------------------
method SetAllSettings(par_cBackendType,par_cDriver,par_Server,par_nPort,par_cUser,par_cPassword,par_cDatabase,par_cSchema,par_cPKFN) class hb_orm_SQLConnect
if !hb_IsNil(par_cBackendType)
    ::SetBackendType(par_cBackendType)
endif
if !hb_IsNil(par_cDriver)
    ::SetDriver(par_cDriver)
endif
if !hb_IsNil(par_Server)
    ::SetServer(par_Server)
endif
if !hb_IsNil(par_nPort)
    ::SetPort(par_nPort)
endif
if !hb_IsNil(par_cUser)
    ::SetUser(par_cUser)
endif
if !hb_IsNil(par_cPassword)
    ::SetPassword(par_cPassword)
endif
if !hb_IsNil(par_cDatabase)
    ::SetDatabase(par_cDatabase)
endif
if !hb_IsNil(par_cSchema)
    ::SetCurrentSchemaName(par_cSchema)
endif
if !hb_IsNil(par_cPKFN)
    ::SetPrimaryKeyFieldName(par_cPKFN)
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
        l_cConnectionString := "Server="+::p_Server+";Port="+AllTrim(str(::p_Port))+";Driver={"+::p_Driver+"};Uid="+::p_User+";Pwd="+::p_Password+";Database="+::p_Database+";BoolsAsChar=0;"
    otherwise
        ::p_ErrorMessage := "Invalid 'Backend Type'"
    endcase
    if !empty(l_cConnectionString)
        l_SQLHandle := hb_RDDInfo( RDDI_CONNECT, { "ODBC", l_cConnectionString })

        if l_SQLHandle == 0
            l_SQLHandle := -1
            ::p_ErrorMessage := "Unable connect to the server!"+Chr(13)+Chr(10)+Str(hb_RDDInfo( RDDI_ERRORNO ))+Chr(13)+Chr(10)+hb_RDDInfo( RDDI_ERROR )
            hb_orm_SendToDebugView("Unable connect to the server! "+::p_Server)
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
            if ::TableExists(::PostgreSQLHBORMSchemaName+".SchemaVersion")
                if ::GetSchemaDefinitionVersion("orm trigger version") != HB_ORM_TRIGGERVERSION
                ::EnableSchemaChangeTracking()
                ::SetSchemaDefinitionVersion("orm trigger version" ,HB_ORM_TRIGGERVERSION)
                endif
            endif
            ::UpdateSchemaCache()
        endif
    endif

    //Load the entire schema
    ::LoadSchema()

    //AutoFix ORM supporting tables
    if ::UpdateORMSupportSchema()
        ::LoadSchema()  // Only called again the the ORM schema changed
    endif

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
method Lock(par_cSchemaAndTableName,par_iKey) class hb_orm_SQLConnect

local l_nArrayRow
local l_cCursorTempName
local l_LockName
local l_lResult  := .f.
local l_nSelect
local l_cSQLCommand
local l_nPos,l_cSchemaName,l_cTableName
local l_iTableNumber

::p_ErrorMessage := ""

do case
case empty(par_cSchemaAndTableName)
    ::p_ErrorMessage := [Missing Table]
    
otherwise
    l_nSelect = iif(used(),select(),0)

    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_LockName  = "lock_"+lower(::p_Database)+"_"+lower(par_cSchemaAndTableName)+"_"+Trans(par_iKey)
        
        //Check if the lock is already created by the current connection
        l_nArrayRow = AScan( ::p_Locks, l_LockName )

        if !empty(l_nArrayRow)
            //Already Locked
            l_lResult = .t.
        else
            //No Locks entry to reuse

            //Do the actual locking
            l_cCursorTempName = "c_DB_Temp"
            l_cSQLCommand    = [SELECT GET_LOCK(']+l_LockName+[',]+Trans(::p_LockTimeout)+[) as result]
            if ::SQLExec(l_cSQLCommand,l_cCursorTempName)
                // if (l_cCursorTempName)->(FieldGet(1)) == 1  //Since there is one 1 field, retrieving its value.
                if c_DB_Temp->result == 1  //Since there is one 1 field, retrieving its value.
                    AAdd(::p_Locks,l_LockName)
                    l_lResult = .t.
                else
                    ::p_ErrorMessage := "Failed lock resource "+l_LockName
                    hb_orm_SendToDebugView(::p_ErrorMessage)
                endif
            else
                ::p_ErrorMessage := "Failed to Run SQL to lock() "+::p_SQLExecErrorMessage
                hb_orm_SendToDebugView(::p_ErrorMessage)
            endif
            CloseAlias(l_cCursorTempName)
            
        endif

    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        //There is a bug in PostgreSQL 12.3 with the 'SELECT * FROM pg_locks;' But the locks get release with pg_advisory_unlock()
        //No know timeout, unlike MySQL
        
        l_nPos := at(".",par_cSchemaAndTableName)
        if l_nPos == 0
            l_cSchemaName := ""
            l_cTableName  := par_cSchemaAndTableName
        else
            l_cSchemaName := left(par_cSchemaAndTableName,l_nPos-1)
            l_cTableName  := substr(par_cSchemaAndTableName,l_nPos+1)
        endif

        l_cSQLCommand := [SELECT pk]
        l_cSQLCommand += [ FROM  "]+::PostgreSQLHBORMSchemaName+["."SchemaTableNumber"]
        l_cSQLCommand += [ WHERE schemaname = ']+l_cSchemaName+[']
        l_cSQLCommand += [ AND   tablename = ']+l_cTableName+[']

        l_cCursorTempName = "c_DB_Temp"
        if ::SQLExec(l_cSQLCommand,l_cCursorTempName)
            // l_iTableNumber := (l_cCursorTempName)->(pk)
            l_iTableNumber := (l_cCursorTempName)->(FieldGet(FieldPos("pk")))
            CloseAlias(l_cCursorTempName)

            if l_iTableNumber > 0
                l_LockName := alltrim(str(par_iKey))+StrZero(l_iTableNumber,::MaxDigitsInTableNumber)

                //Check if the lock is already created by the current connection
                l_nArrayRow = AScan( ::p_Locks, l_LockName )

                if !empty(l_nArrayRow)
                    //Already Locked
                    l_lResult = .t.
                else
                    //No Locks entry to reuse

                    //Do the actual locking
                    l_cSQLCommand    = [SELECT pg_advisory_lock(']+l_LockName+[') as result]
                    if ::SQLExec(l_cSQLCommand,l_cCursorTempName)
                        //No know method to find out if lock failed.
                        // if (l_cCursorTempName)->(result) == 1
                            AAdd(::p_Locks,l_LockName)
                            l_lResult = .t.
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
        CloseAlias(l_cCursorTempName)

    endcase
    CloseAlias(l_cCursorTempName)
    select (l_nSelect)
    
endcase

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
method Unlock(par_cSchemaAndTableName,par_iKey) class hb_orm_SQLConnect

local l_nArrayRow
local l_cCursorTempName
local l_LockName
local l_lResult  := .f.
local l_nSelect
local l_cSQLCommand
local l_nPos,l_cSchemaName,l_cTableName
local l_iTableNumber

::p_ErrorMessage := ""
do case
case empty(par_cSchemaAndTableName)
    ::p_ErrorMessage := [Missing Table]
    
otherwise
    l_nSelect = iif(used(),select(),0)

    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_LockName  = "lock_"+lower(::p_Database)+"_"+lower(par_cSchemaAndTableName)+"_"+trans(par_iKey)
        
        //Check if the lock is already created by the current connection
        l_nArrayRow = AScan( ::p_Locks, l_LockName )

        if empty(l_nArrayRow)
            //Already Unlocked
            l_lResult = .t.
        else
            //No Locks entry to reuse

            //Do the actual locking
            l_cCursorTempName = "c_DB_Temp"
            l_cSQLCommand    = [SELECT RELEASE_LOCK(']+l_LockName+[') as result]
            if ::SQLExec(l_cSQLCommand,l_cCursorTempName)
                hb_ADel(::p_Locks,l_nArrayRow,.t.)
                l_lResult := .t.
            else
                ::p_ErrorMessage := "Failed to Run SQL to unlock() "+::p_SQLExecErrorMessage
                hb_orm_SendToDebugView(::p_ErrorMessage)
            endif
            CloseAlias(l_cCursorTempName)
            
        endif
            
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        //There is a bug in PostgreSQL 12.3 with the 'SELECT * FROM pg_locks;' But the locks get release with pg_advisory_unlock()

        l_nPos := at(".",par_cSchemaAndTableName)
        if l_nPos == 0
            l_cSchemaName := ""
            l_cTableName  := par_cSchemaAndTableName
        else
            l_cSchemaName := left(par_cSchemaAndTableName,l_nPos-1)
            l_cTableName  := substr(par_cSchemaAndTableName,l_nPos+1)
        endif

        l_cSQLCommand := [SELECT pk]
        l_cSQLCommand += [ FROM  "]+::PostgreSQLHBORMSchemaName+["."SchemaTableNumber"]
        l_cSQLCommand += [ WHERE schemaname = ']+l_cSchemaName+[']
        l_cSQLCommand += [ AND   tablename = ']+l_cTableName+[']

        l_cCursorTempName = "c_DB_Temp"
        if ::SQLExec(l_cSQLCommand,l_cCursorTempName)
            // l_iTableNumber := (l_cCursorTempName)->(pk)
            l_iTableNumber := (l_cCursorTempName)->(FieldGet(FieldPos("pk")))
            CloseAlias(l_cCursorTempName)

            if l_iTableNumber > 0
                l_LockName := alltrim(str(par_iKey))+StrZero(l_iTableNumber,::MaxDigitsInTableNumber)
                
                //Check if the lock is already created by the current connection
                l_nArrayRow = AScan( ::p_Locks, l_LockName )

                if empty(l_nArrayRow)
                    //Already Unlocked
                    l_lResult = .t.
                else
                    //No Locks entry to reuse

                    //Do the actual locking
                    l_cCursorTempName = "c_DB_Temp"
                    l_cSQLCommand    = [SELECT pg_advisory_unlock(']+l_LockName+[') as result]
                    if ::SQLExec(l_cSQLCommand,l_cCursorTempName)
                        hb_ADel(::p_Locks,l_nArrayRow,.t.)
                        l_lResult := .t.
                    else
                        ::p_ErrorMessage := "Failed to Run SQL to unlock() "+::p_SQLExecErrorMessage
                        hb_orm_SendToDebugView(::p_ErrorMessage)
                    endif
                    CloseAlias(l_cCursorTempName)
                    
                endif

            else
                ::p_ErrorMessage := [Failed to Run unlock(). Could not find table name "]+par_cSchemaAndTableName+[".]
                hb_orm_SendToDebugView(::p_ErrorMessage)
            endif
        else
            ::p_ErrorMessage := "Failed to Run Pre SQL to unlock() "+::p_SQLExecErrorMessage
            hb_orm_SendToDebugView(::p_ErrorMessage)
        endif
        CloseAlias(l_cCursorTempName)
            
    endcase
    
    select (l_nSelect)
    
endcase

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
method LogAutoTrimEvent(par_cEventId,par_cSchemaAndTableName,par_nKey,par_aAutoTrimmedFields) class hb_orm_SQLConnect
local l_cSQLCommand
local l_cLastErrorMessage
local l_iAutoTrimmedInfo
local l_cValue
local l_cFieldName,l_cFieldType,l_nFieldLen
local l_nPos,l_cSchemaName,l_cTableName

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cSQLCommand := [INSERT INTO ]+::FormatIdentifier("SchemaAutoTrimLog")+[ (]
    
    if !hb_IsNIL(par_cEventId)
        l_cSQLCommand += ::FormatIdentifier("eventid")+[,]
    endif
    l_cSQLCommand += ::FormatIdentifier("datetime")+[,]
    l_cSQLCommand += ::FormatIdentifier("ip")+[,]
    l_cSQLCommand += ::FormatIdentifier("tablename")+[,]
    l_cSQLCommand += ::FormatIdentifier("recordpk")+[,]
    l_cSQLCommand += ::FormatIdentifier("fieldname")+[,]
    l_cSQLCommand += ::FormatIdentifier("fieldtype")+[,]
    l_cSQLCommand += ::FormatIdentifier("fieldlen")+[,]
    l_cSQLCommand += ::FormatIdentifier("fieldvaluem")+[,]
    l_cSQLCommand += ::FormatIdentifier("fieldvaluer")

    l_cSQLCommand += [) VALUES ]

    for l_iAutoTrimmedInfo := 1 to len(par_aAutoTrimmedFields)
        l_cFieldName := par_aAutoTrimmedFields[l_iAutoTrimmedInfo][1]
        l_cValue     := par_aAutoTrimmedFields[l_iAutoTrimmedInfo][2]
        l_cFieldType := par_aAutoTrimmedFields[l_iAutoTrimmedInfo][3]
        l_nFieldLen  := par_aAutoTrimmedFields[l_iAutoTrimmedInfo][4]
        
        hb_orm_SendToDebugView("Auto Trim Event:"+;
                              iif(hb_IsNIL(par_cSchemaAndTableName) , "" , [  Table = "]+par_cSchemaAndTableName+["])+;
                              iif(hb_IsNIL(par_nKey)                , "" , [  Key = ]+trans(par_nKey))+;
                              iif(hb_IsNIL(l_cFieldName)             , "" , [  Field = "]+l_cFieldName+["]))
        
        if l_iAutoTrimmedInfo > 1
            l_cSQLCommand +=  [,]
        endif
        l_cSQLCommand +=  [(]

        if !hb_IsNIL(par_cEventId)
            l_cSQLCommand += [']+left(par_cEventId,HB_ORM_MAX_EVENTID_SIZE)+[',]
        endif
        l_cSQLCommand += [now(),]
        l_cSQLCommand += [SUBSTRING(USER(), LOCATE('@', USER())+1),]
        l_cSQLCommand += [']+par_cSchemaAndTableName+[',]
        l_cSQLCommand += trans(par_nKey)+[,]
        l_cSQLCommand += [']+l_cFieldName+[',]           // Field Name
        l_cSQLCommand += [']+allt(l_cFieldType)+[',]     // Field type
        l_cSQLCommand += trans(l_nFieldLen)+[,]
        
        if !empty(el_inlist(l_cFieldType,"B","BV","R"))
            //Binary
            l_cSQLCommand += [NULL,]
            l_cSQLCommand += [x']+hb_StrToHex(l_cValue)+[']
        else
            //Text
            l_cSQLCommand += [x']+hb_StrToHex(l_cValue)+[',]
            l_cSQLCommand += [NULL]
        endif

        l_cSQLCommand +=  [)]
    endfor

    l_cSQLCommand += [;]

    if !::SQLExec(l_cSQLCommand)
        l_cLastErrorMessage := ::GetSQLExecErrorMessage()
        hb_orm_SendToDebugView("Error on Auto Trim: "+l_cLastErrorMessage)
    endif

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_nPos := at(".",par_cSchemaAndTableName)
    if l_nPos == 0
        l_cSchemaName := ""
        l_cTableName  := par_cSchemaAndTableName
    else
        l_cSchemaName := left(par_cSchemaAndTableName,l_nPos-1)
        l_cTableName  := substr(par_cSchemaAndTableName,l_nPos+1)
    endif

    l_cSQLCommand := [INSERT INTO ]+::FormatIdentifier(::PostgreSQLHBORMSchemaName+".SchemaAutoTrimLog")+[ (]
    
    if !hb_IsNIL(par_cEventId)
        l_cSQLCommand += ::FormatIdentifier("eventid")+[,]
    endif
    l_cSQLCommand += ::FormatIdentifier("datetime")+[,]
    l_cSQLCommand += ::FormatIdentifier("ip")+[,]
    l_cSQLCommand += ::FormatIdentifier("schemaname")+[,]
    l_cSQLCommand += ::FormatIdentifier("tablename")+[,]
    l_cSQLCommand += ::FormatIdentifier("recordpk")+[,]
    l_cSQLCommand += ::FormatIdentifier("fieldname")+[,]
    l_cSQLCommand += ::FormatIdentifier("fieldtype")+[,]
    l_cSQLCommand += ::FormatIdentifier("fieldlen")+[,]
    l_cSQLCommand += ::FormatIdentifier("fieldvaluem")+[,]
    l_cSQLCommand += ::FormatIdentifier("fieldvaluer")

    l_cSQLCommand += [) VALUES ]

    for l_iAutoTrimmedInfo := 1 to len(par_aAutoTrimmedFields)
        l_cFieldName := par_aAutoTrimmedFields[l_iAutoTrimmedInfo][1]
        l_cValue     := par_aAutoTrimmedFields[l_iAutoTrimmedInfo][2]
        l_cFieldType := par_aAutoTrimmedFields[l_iAutoTrimmedInfo][3]
        l_nFieldLen  := par_aAutoTrimmedFields[l_iAutoTrimmedInfo][4]

        hb_orm_SendToDebugView("Auto Trim Event:"+;
                              iif(hb_IsNIL(par_cSchemaAndTableName) , "" , [  Table = "]+par_cSchemaAndTableName+["])+;
                              iif(hb_IsNIL(par_nKey)                , "" , [  Key = ]+trans(par_nKey))+;
                              iif(hb_IsNIL(l_cFieldName)             , "" , [  Field = "]+l_cFieldName+["]))
        
        if l_iAutoTrimmedInfo > 1
            l_cSQLCommand +=  [,]
        endif
        l_cSQLCommand +=  [(]

        if !hb_IsNIL(par_cEventId)
            l_cSQLCommand += [']+left(par_cEventId,HB_ORM_MAX_EVENTID_SIZE)+[',]
        endif
        l_cSQLCommand += [current_timestamp,]
        l_cSQLCommand += [inet_client_addr(),]
        l_cSQLCommand += [']+l_cSchemaName+[',]
        l_cSQLCommand += [']+l_cTableName+[',]
        l_cSQLCommand += trans(par_nKey)+[,]

        l_cSQLCommand += [']+l_cFieldName+[',]           // Field Name
        l_cSQLCommand += [']+allt(l_cFieldType)+[',]     // Field type
        l_cSQLCommand += trans(l_nFieldLen)+[,]

        if !empty(el_inlist(l_cFieldType,"B","BV","R"))
            //Binary
            l_cSQLCommand += [NULL,]
            // l_cSQLCommand += [E'\x]+hb_StrToHex(l_cValue,"\x")+[']
            l_cSQLCommand += hb_orm_PostgresqlEncodeBinary(l_cValue)
        else
            //Text UTF
            // l_cSQLCommand += [E'\x]+hb_StrToHex(l_cValue,"\x")+[',]
            l_cSQLCommand += hb_orm_PostgresqlEncodeUTFString(l_cValue)+[,]
            l_cSQLCommand += [NULL]
        endif

        l_cSQLCommand +=  [)]
    endfor

    l_cSQLCommand += [;]

    if !::SQLExec(l_cSQLCommand)
        l_cLastErrorMessage := ::GetSQLExecErrorMessage()
        hb_orm_SendToDebugView("Error on Auto Trim: "+l_cLastErrorMessage)
    endif

endcase
return NIL

//par_cTableName  par_cSchemaAndTableName

//-----------------------------------------------------------------------------------------------------------------
method LogErrorEvent(par_cEventId,par_aErrors) class hb_orm_SQLConnect
local l_cSQLCommand
local l_cLastErrorMessage
local l_iErrors
local l_cSchemaAndTableName,l_nKey,l_cErrorMessage
local l_lDoNotReportErrors := ::p_DoNotReportErrors
local l_nPos,l_cSchemaName,l_cTableName
local l_cAppStack

::p_DoNotReportErrors := .t.  // To avoid cycling reporting of errors

// altd()

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cSQLCommand := [INSERT INTO ]+::FormatIdentifier("SchemaAndDataErrorLog")+[ (]
    
    if !hb_IsNIL(par_cEventId)
        l_cSQLCommand += ::FormatIdentifier("eventid")+[,]
    endif

    l_cSQLCommand += ::FormatIdentifier("appstack")+[,]
    l_cSQLCommand += ::FormatIdentifier("datetime")+[,]
    l_cSQLCommand += ::FormatIdentifier("ip")+[,]
    l_cSQLCommand += ::FormatIdentifier("tablename")+[,]
    l_cSQLCommand += ::FormatIdentifier("recordpk")+[,]
    l_cSQLCommand += ::FormatIdentifier("errormessage")

    l_cSQLCommand += [) VALUES ]

    for l_iErrors := 1 to len(par_aErrors)
        l_cSchemaAndTableName := par_aErrors[l_iErrors][1]
        l_nKey                := par_aErrors[l_iErrors][2]
        l_cErrorMessage       := par_aErrors[l_iErrors][3]
        l_cAppStack           := par_aErrors[l_iErrors][4]

        hb_orm_SendToDebugView("Error Event:"+;
                              iif(hb_IsNIL(l_cSchemaAndTableName) , "" , [  Table = "]+l_cSchemaAndTableName+["])+;
                              iif(hb_IsNIL(l_nKey)                , "" , [  Key = ]+trans(l_nKey))+;
                              [  ]+l_cErrorMessage)

        if l_iErrors > 1
            l_cSQLCommand +=  [,]
        endif
        l_cSQLCommand +=  [(]

        if !hb_IsNIL(par_cEventId)
            l_cSQLCommand += [']+left(par_cEventId,HB_ORM_MAX_EVENTID_SIZE)+[',]
        endif
        if hb_IsNIL(l_cAppStack)
            l_cSQLCommand += [NULL,]
        else
            l_cSQLCommand += [x']+hb_StrToHex(l_cAppStack)+[',]
        endif
        l_cSQLCommand += [now(),]
        l_cSQLCommand += [SUBSTRING(USER(), LOCATE('@', USER())+1),]
        l_cSQLCommand += iif(hb_IsNIL(l_cTableName) , [NULL,] , [']+l_cTableName+[',])
        l_cSQLCommand += iif(hb_IsNIL(l_nKey)       , [NULL,] , trans(l_nKey)+[,])
        l_cSQLCommand += [x']+hb_StrToHex(l_cErrorMessage)+[']

        l_cSQLCommand +=  [)]
    endfor

    l_cSQLCommand += [;]

    if !::SQLExec(l_cSQLCommand)
        l_cLastErrorMessage := ::GetSQLExecErrorMessage()
        hb_orm_SendToDebugView("Error on Auto Trim: "+l_cLastErrorMessage)
    endif

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cSQLCommand := [INSERT INTO ]+::FormatIdentifier(::PostgreSQLHBORMSchemaName+".SchemaAndDataErrorLog")+[ (]
    
    if !hb_IsNIL(par_cEventId)
        l_cSQLCommand += ::FormatIdentifier("eventid")+[,]
    endif

    l_cSQLCommand += ::FormatIdentifier("appstack")+[,]
    l_cSQLCommand += ::FormatIdentifier("datetime")+[,]
    l_cSQLCommand += ::FormatIdentifier("ip")+[,]
    l_cSQLCommand += ::FormatIdentifier("schemaname")+[,]
    l_cSQLCommand += ::FormatIdentifier("tablename")+[,]
    l_cSQLCommand += ::FormatIdentifier("recordpk")+[,]
    l_cSQLCommand += ::FormatIdentifier("errormessage")

    l_cSQLCommand += [) VALUES ]

    for l_iErrors := 1 to len(par_aErrors)
        l_cSchemaAndTableName := par_aErrors[l_iErrors][1]
        l_nKey                := par_aErrors[l_iErrors][2]
        l_cErrorMessage       := par_aErrors[l_iErrors][3]
        l_cAppStack           := par_aErrors[l_iErrors][4]

        if hb_IsNIL(l_cSchemaAndTableName)
            l_cSchemaName := NIL
            l_cTableName  := NIL
        else
            l_nPos := at(".",l_cSchemaAndTableName)
            if l_nPos == 0
                l_cSchemaName := ""
                l_cTableName  := l_cSchemaAndTableName
            else
                l_cSchemaName := left(l_cSchemaAndTableName,l_nPos-1)
                l_cTableName  := substr(l_cSchemaAndTableName,l_nPos+1)
            endif
        endif


        hb_orm_SendToDebugView("Error Event:"+;
                              iif(hb_IsNIL(l_cSchemaAndTableName) , "" , [  Table = "]+l_cSchemaAndTableName+["])+;
                              iif(hb_IsNIL(l_nKey)                , "" , [  Key = ]+trans(l_nKey))+;
                              [  ]+l_cErrorMessage)

        if l_iErrors > 1
            l_cSQLCommand +=  [,]
        endif
        l_cSQLCommand +=  [(]

        if !hb_IsNIL(par_cEventId)
            l_cSQLCommand += [']+left(par_cEventId,HB_ORM_MAX_EVENTID_SIZE)+[',]
        endif
        if hb_IsNIL(l_cAppStack)
            l_cSQLCommand += [NULL,]
        else
            // l_cSQLCommand += [E'\x]+hb_StrToHex(l_cAppStack,"\x")+[',]
            l_cSQLCommand += hb_orm_PostgresqlEncodeUTFString(l_cAppStack)+[,]
        endif
        l_cSQLCommand += [current_timestamp,]
        l_cSQLCommand += [inet_client_addr(),]
        l_cSQLCommand += iif(hb_IsNIL(l_cSchemaName) , [NULL,] , [']+l_cSchemaName+[',])
        l_cSQLCommand += iif(hb_IsNIL(l_cTableName)  , [NULL,] , [']+l_cTableName+[',])
        l_cSQLCommand += iif(hb_IsNIL(l_nKey)        , [NULL,] , trans(l_nKey)+[,])
        // l_cSQLCommand += [E'\x]+hb_StrToHex(l_cErrorMessage,"\x")+[']
        l_cSQLCommand += hb_orm_PostgresqlEncodeUTFString(l_cErrorMessage)

        l_cSQLCommand +=  [)]
    endfor

    l_cSQLCommand += [;]

    if !::SQLExec(l_cSQLCommand)
        l_cLastErrorMessage := ::GetSQLExecErrorMessage()
        hb_orm_SendToDebugView("Error on Error Log: "+l_cLastErrorMessage)
    endif

endcase

::p_DoNotReportErrors := l_lDoNotReportErrors

return NIL

//-----------------------------------------------------------------------------------------------------------------
method CheckIfStillConnected() class hb_orm_SQLConnect // Returns .t. if connected. Will test if the connection is still present
local l_lResult := .f.  // By default assume not connected

if ::Connected
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        if ::SQLExec([select current_time;])
            l_lResult := .t.
        endif
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        if ::SQLExec([select current_time;])
            l_lResult := .t.
        endif
    endcase
    if l_lResult == .f.
        hb_orm_SendToDebugView("SQL Connection was lost")
        ::Disconnect()
    endif
endif

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method CheckIfSchemaCacheShouldBeUpdated() class hb_orm_SQLConnect // Return .t. if schema had changed since connected. Currently only PostgreSQL aware
local l_lResult := .f.
local l_cSQLCommand
local l_nSelect := iif(used(),select(),0)

if ::Connected
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        //_M_
        l_lResult := .t.
        if ::TableExists(::PostgreSQLHBORMSchemaName+".SchemaCacheLog")
            l_cSQLCommand := [SELECT pk,]
            l_cSQLCommand += [       cachedschema::integer]
            l_cSQLCommand += [ FROM  ]+::FormatIdentifier(::PostgreSQLHBORMSchemaName)+::FixCasingOfSchemaCacheTables([."SchemaCacheLog"])
            l_cSQLCommand += [ ORDER BY pk DESC]
            l_cSQLCommand += [ LIMIT 1]

            if ::SQLExec(l_cSQLCommand,"SchemaCacheLogLast")
                if SchemaCacheLogLast->(reccount()) == 1
                    if SchemaCacheLogLast->pk == ::p_SchemaCacheLogLastPk
                        l_lResult := .f.
                    endif
                endif
            endif

            CloseAlias("SchemaCacheLogLast")
            select (l_nSelect)
        endif

    endcase
    if l_lResult == .t.
        hb_orm_SendToDebugView("Schema Cache is out of date")
    endif
endif

return l_lResult
//-----------------------------------------------------------------------------------------------------------------
method GetUUIDString() class hb_orm_SQLConnect  //Will return a UUID string
local l_cUUID := []
local l_lResult := .f.

if ::Connected
    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        if ::SQLExec([select cast(UUID() AS char(36)) AS cuuid],"c_DB_Result_UUID")
            l_lResult := .t.
        endif
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        if ::SQLExec([select gen_random_uuid()::char(36) as cuuid],"c_DB_Result_UUID")
            l_lResult := .t.
        endif
    endcase
    if l_lResult == .t.
        if Valtype(c_DB_Result_UUID->cuuid) == "C"
            l_cUUID := trim(c_DB_Result_UUID->cuuid)
        endif
    endif
    CloseAlias("c_DB_Result_UUID")
endif
return l_cUUID
//-----------------------------------------------------------------------------------------------------------------
function hb_orm_GetApplicationStack()
local l_cInfo := ""
local l_nLevel := 1

do while !empty(ProcName(l_nLevel))
    if !empty(l_cInfo)
        l_cInfo += CRLF
    endif
    l_cInfo += trans(l_nLevel)+" "+ProcFile(l_nLevel)+"->"+ProcName(l_nLevel)+"("+trans(ProcLine(l_nLevel))+")"
    l_nLevel++
enddo

return l_cInfo
//-----------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------
#include "hb_orm_schema.prg"
//-----------------------------------------------------------------------------------------------------------------
