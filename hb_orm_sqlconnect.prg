//Copyright (c) 2024 Eric Lendvai MIT License

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
method SQLExec(par_xEventId,par_cCommand,par_cCursorName) class hb_orm_SQLConnect   //Returns .t. if succeeded
local l_cPreviousDefaultRDD := RDDSETDEFAULT("SQLMIX")
local l_lSQLExecResult := .f.
local l_oError
local l_nSelect := iif(used(),select(),0)
local l_cErrorInfo
local l_nErrorNumber := 0

if !::p_DoNotReportErrors
    ::p_SQLExecErrorMessage := ""
endif

if ::p_SQLConnection > 0
    try
        if pcount() == 3
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

        if !l_lSQLExecResult
            l_nErrorNumber := hb_RDDInfo(RDDI_ERRORNO)
            if (l_nErrorNumber == 9999) .and. ;
               ((upper(left(par_cCommand,len("DELETE FROM "))) == "DELETE FROM ") .or. (upper(left(par_cCommand,len("UPDATE "))) == "UPDATE ")) // .and. (" RETURNING " $ upper(par_cCommand))
                //Ignore the error, because most likely no records where deleted.
                l_lSQLExecResult := .t.
                // hb_orm_SendToDebugView("Ignored unknown Error on "+par_cCommand)

            endif
        endif

        if !::p_DoNotReportErrors
            if !l_lSQLExecResult
                ::p_SQLExecErrorMessage := "SQLExec Error Code: "+Trans(l_nErrorNumber)+" - Error description: "+alltrim(hb_RDDInfo(RDDI_ERROR))
            endif
        endif

    catch l_oError
        l_nErrorNumber := l_oError:oscode
        if (l_nErrorNumber == 9999) .and. ;
            ((upper(left(par_cCommand,len("DELETE FROM "))) == "DELETE FROM ") .or. (upper(left(par_cCommand,len("UPDATE "))) == "UPDATE ")) .and. ;
            (" RETURNING " $ upper(par_cCommand))
            
            //Ignore the error, because most likely no records where deleted.
            l_lSQLExecResult := .t.  //Just in case the catch occurs after DBUserArea / hb_RDDInfo
            // hb_orm_SendToDebugView("Ignored unknown Error on "+par_cCommand)

        else
            l_lSQLExecResult := .f.  //Just in case the catch occurs after DBUserArea / hb_RDDInfo
        endif

        if !l_lSQLExecResult
            if !::p_DoNotReportErrors
                ::p_SQLExecErrorMessage := "SQLExec Error Code: "+Trans(l_nErrorNumber)+" - Error description: "+alltrim(l_oError:description)+" - Operation: "+l_oError:operation
            endif
            // Idea for later  ::SQLSendToLogFileAndMonitoringSystem(0,1,l_cSQLCommand+[ -> ]+::p_SQLExecErrorMessage)  _M_
        endif
    endtry

    if !::p_DoNotReportErrors
        if !empty(::p_SQLExecErrorMessage)
            l_cErrorInfo := hb_StrReplace(::p_SQLExecErrorMessage+" - Command: "+par_cCommand+iif(pcount() < 3,""," - Cursor Name: "+par_cCursorName),{chr(13)=>" ",chr(10)=>""})
            hb_orm_SendToDebugView(l_cErrorInfo)
            ::LogErrorEvent(par_xEventId,{{,,l_cErrorInfo,hb_orm_GetApplicationStack()}})   // par_xEventId,par_aErrors
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
method SetCurrentNamespaceName(par_cName) class hb_orm_SQLConnect   //Return the name of the schema before being set
local l_cPreviousNamespaceName := ::p_NamespaceName
::p_NamespaceName := iif(hb_IsNil(par_cName) .or. empty(par_cName),"public",par_cName)
return l_cPreviousNamespaceName
//-----------------------------------------------------------------------------------------------------------------
method SetApplicationName(par_cName) class hb_orm_SQLConnect
::p_ApplicationName := par_cName
if ::Connected
    if !empty(::p_ApplicationName)
        ::SQLExec("cbcb115d-7bda-4118-aa61-9340faab98fb","set application_name = '"+strtran(::p_ApplicationName,['],[])+"';")
    endif
endif
return NIL
//-----------------------------------------------------------------------------------------------------------------
method SetCreationTimeFieldName(par_cName) class hb_orm_SQLConnect
::p_CreationTimeFieldName := par_cName
return ::p_CreationTimeFieldName
//-----------------------------------------------------------------------------------------------------------------
method SetModificationTimeFieldName(par_cName) class hb_orm_SQLConnect
::p_ModificationTimeFieldName := par_cName
return ::p_ModificationTimeFieldName
//-----------------------------------------------------------------------------------------------------------------
method SetAllSettings(par_cBackendType,par_cDriver,par_Server,par_nPort,par_cUser,par_cPassword,par_cDatabase,par_cSchema) class hb_orm_SQLConnect
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
    ::SetCurrentNamespaceName(par_cSchema)
endif
return Self
//-----------------------------------------------------------------------------------------------------------------
method Connect() class hb_orm_SQLConnect   // Return -1 on error, 0 if already connected, >0 if succeeded
local l_SQLHandle
local l_cConnectionString
local l_cPreviousDefaultRDD
local l_lNoCache := (::p_HBORMNamespace == "nohborm")

do case
case ::Connected
    ::p_ErrorMessage := "Already Connected"
    l_SQLHandle := ::p_SQLConnection

case !::p_LoadedWharfConfiguration
    ::p_ErrorMessage := "LoadWharfConfiguration method must be called first"
    l_SQLHandle := -1

case ::p_SQLConnection > 0
    ::p_ErrorMessage := "Already connected, disconnect first"
    l_SQLHandle := -1

case ::p_BackendType == 0
    ::p_ErrorMessage := "Missing 'Backend Type'"
    l_SQLHandle := -1

case empty(::p_Driver)
    ::p_ErrorMessage := "Missing 'Driver'"
    l_SQLHandle := -1

case empty(::p_Server)
    ::p_ErrorMessage := "Missing 'Server'"
    l_SQLHandle := -1

case empty(::p_Port)
    ::p_ErrorMessage := "Missing 'Port'"
    l_SQLHandle := -1

case empty(::p_User)
    ::p_ErrorMessage := "Missing 'User'"
    l_SQLHandle := -1

case empty(::p_Database)
    ::p_ErrorMessage := "Missing 'Database'"
    l_SQLHandle := -1

otherwise
    ::p_ErrorMessage := ""
    l_SQLHandle      := -1
    
    ::ConnectionCounter++
    ::p_ConnectionNumber := ::ConnectionCounter
    hb_orm_SendToDebugView("hb_orm_sqlconnect Connection Number "+trans(::p_ConnectionNumber))

    l_cPreviousDefaultRDD = RDDSETDEFAULT( "SQLMIX" )

    do case
    case ::p_BackendType == HB_ORM_BACKENDTYPE_MARIADB .or. ::p_BackendType == HB_ORM_BACKENDTYPE_MYSQL   // MySQL or MariaDB
        // To enable multi statements to be executed, meaning multiple SQL commands separated by ";", had to use the OPTION= setting.
        // See: https://dev.mysql.com/doc/connector-odbc/en/connector-odbc-configuration-connection-parameters.html#codbc-dsn-option-flags
        l_cConnectionString := "SERVER="+::p_Server+";Driver={"+::p_Driver+"};USER="+::p_User+";PASSWORD="+::p_Password+";DATABASE="+::p_Database+";PORT="+AllTrim(str(::p_Port)+";OPTION=67108864;")
    case ::p_BackendType == HB_ORM_BACKENDTYPE_POSTGRESQL   // PostgreSQL
        // Fix for password that include the "%" character:  https://community.powerbi.com/t5/Desktop/PostgreSQL-ODBC-auth-failed/td-p/1589649
        l_cConnectionString := "Server="+::p_Server
        l_cConnectionString += ";Port="+AllTrim(str(::p_Port))
        l_cConnectionString += ";Driver={"+::p_Driver+"}"
        l_cConnectionString += ";Uid="+::p_User
        l_cConnectionString += ";Pwd="+strtran(::p_Password,"%","%25")
        l_cConnectionString += ";Database="+::p_Database
        l_cConnectionString += ";BoolsAsChar=0;"
    otherwise
        l_cConnectionString := ""
        ::p_ErrorMessage := "Invalid 'Backend Type'"
    endcase

    if !empty(l_cConnectionString)
        //The following can take up to 10 seconds when accessing a VMWare Ubuntu machine to test out MySQL.
        l_SQLHandle := hb_RDDInfo( RDDI_CONNECT, { "ODBC", l_cConnectionString })

        if l_SQLHandle == 0
            l_SQLHandle := -1
            ::p_ErrorMessage := "Unable connect to the server!"+Chr(13)+Chr(10)+Str(hb_RDDInfo( RDDI_ERRORNO ))+Chr(13)+Chr(10)+hb_RDDInfo( RDDI_ERROR )
            hb_orm_SendToDebugView("Unable connect to the server! "+::p_Server)
        else
            ::p_SQLConnection := l_SQLHandle
        endif
    endif

    RDDSETDEFAULT(l_cPreviousDefaultRDD)

    if l_SQLHandle > 0
        ::Connected := .t.

        do case
        case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
            // l_cBackendType := "PostgreSQL"
            if !empty(::p_ApplicationName)
                ::SQLExec("cbcb115d-7bda-4118-aa61-9340faab98fa","set application_name = '"+strtran(::p_ApplicationName,['],[])+"';")
            endif
            if !l_lNoCache
                if !::TableExists(::p_HBORMNamespace+".SchemaCacheLog")
                    ::EnableSchemaChangeTracking()
                    ::UpdateSchemaCache(.t.)
                else
                    if ::TableExists(::p_HBORMNamespace+".SchemaVersion")
                        if ::GetSchemaDefinitionVersion("orm trigger version") != HB_ORM_TRIGGERVERSION
                        ::EnableSchemaChangeTracking()
                        ::SetSchemaDefinitionVersion("orm trigger version" ,HB_ORM_TRIGGERVERSION)
                        endif
                    endif
                    ::UpdateSchemaCache()
                endif
            endif

        endcase

        //Load the entire schema
        ::LoadMetadata("Connect")
        if !l_lNoCache
            //AutoFix ORM supporting tables
            if ::UpdateORMSupportSchema()  //l_cBackendType
                ::LoadMetadata("Connect, after UpdateORMSupportSchema")  // Only called again the the ORM schema changed
            endif
        endif

    else
        ::Connected := .f.
    endif

endcase

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
method Lock(par_cNamespaceAndTableName,par_iKey) class hb_orm_SQLConnect

local l_nArrayRow
local l_cCursorTempName
local l_LockName
local l_lResult  := .f.
local l_nSelect
local l_cSQLCommand
local l_cNamespaceAndTableName := ::NormalizeTableNameInternal(par_cNamespaceAndTableName)
local l_nPos,l_cNamespaceName,l_cTableName
local l_iTableNumber

::p_ErrorMessage := ""

do case
case empty(l_cNamespaceAndTableName)
    ::p_ErrorMessage := [Missing Table]
    
otherwise
    l_nSelect = iif(used(),select(),0)

    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_LockName  = "lock_"+lower(::p_Database)+"_"+lower(l_cNamespaceAndTableName)+"_"+Trans(par_iKey)
        
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
            if ::SQLExec("Lock",l_cSQLCommand,l_cCursorTempName)
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
        
        l_nPos           := at(".",l_cNamespaceAndTableName)
        l_cNamespaceName := left(l_cNamespaceAndTableName,l_nPos-1)
        l_cTableName     := substr(l_cNamespaceAndTableName,l_nPos+1)

        l_cSQLCommand := [SELECT pk]
        l_cSQLCommand += [ FROM  "]+::p_HBORMNamespace+["."NamespaceTableNumber"]
        l_cSQLCommand += [ WHERE namespacename = ']+l_cNamespaceName+[']
        l_cSQLCommand += [ AND   tablename = ']+l_cTableName+[']

        l_cCursorTempName = "c_DB_Temp"
        if ::SQLExec("Lock",l_cSQLCommand,l_cCursorTempName)
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
                    l_cSQLCommand := [SELECT pg_advisory_lock(']+l_LockName+[') as result]
                    if ::SQLExec("Lock",l_cSQLCommand,l_cCursorTempName)
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
                ::p_ErrorMessage := [Failed to Run lock(). Could not find table name "]+par_cNamespaceAndTableName+[".]
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
method Unlock(par_cNamespaceAndTableName,par_iKey) class hb_orm_SQLConnect

local l_nArrayRow
local l_cCursorTempName
local l_LockName
local l_lResult  := .f.
local l_nSelect
local l_cSQLCommand
local l_cNamespaceAndTableName := ::NormalizeTableNameInternal(par_cNamespaceAndTableName)
local l_nPos,l_cNamespaceName,l_cTableName
local l_iTableNumber

::p_ErrorMessage := ""
do case
case empty(l_cNamespaceAndTableName)
    ::p_ErrorMessage := [Missing Table]
    
otherwise
    l_nSelect = iif(used(),select(),0)

    do case
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
        l_LockName  = "lock_"+lower(::p_Database)+"_"+lower(l_cNamespaceAndTableName)+"_"+trans(par_iKey)
        
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
            if ::SQLExec("Unlock",l_cSQLCommand,l_cCursorTempName)
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

        l_nPos           := at(".",l_cNamespaceAndTableName)
        l_cNamespaceName := left(l_cNamespaceAndTableName,l_nPos-1)
        l_cTableName     := substr(l_cNamespaceAndTableName,l_nPos+1)

        l_cSQLCommand := [SELECT pk]
        l_cSQLCommand += [ FROM  "]+::p_HBORMNamespace+["."NamespaceTableNumber"]
        l_cSQLCommand += [ WHERE namespacename = ']+l_cNamespaceName+[']
        l_cSQLCommand += [ AND   tablename = ']+l_cTableName+[']

        l_cCursorTempName = "c_DB_Temp"
        if ::SQLExec("Unlock",l_cSQLCommand,l_cCursorTempName)
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
                    l_cCursorTempName := "c_DB_Temp"
                    l_cSQLCommand := [SELECT pg_advisory_unlock(']+l_LockName+[') as result]
                    if ::SQLExec("Unlock",l_cSQLCommand,l_cCursorTempName)
                        hb_ADel(::p_Locks,l_nArrayRow,.t.)
                        l_lResult := .t.
                    else
                        ::p_ErrorMessage := "Failed to Run SQL to unlock() "+::p_SQLExecErrorMessage
                        hb_orm_SendToDebugView(::p_ErrorMessage)
                    endif
                    CloseAlias(l_cCursorTempName)
                    
                endif

            else
                ::p_ErrorMessage := [Failed to Run unlock(). Could not find table name "]+par_cNamespaceAndTableName+[".]
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
method LogAutoTrimEvent(par_xEventId,par_cNamespaceAndTableName,par_nKey,par_aAutoTrimmedFields) class hb_orm_SQLConnect
local l_cSQLCommand
local l_cLastErrorMessage
local l_iAutoTrimmedInfo
local l_cValue
local l_cFieldName,l_cFieldType,l_nFieldLen
local l_nPos,l_cNamespaceName,l_cTableName

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cSQLCommand := [INSERT INTO ]+::FormatIdentifier(::p_HBORMNamespace+".SchemaAutoTrimLog")+[ (]
    
    if !hb_IsNIL(par_xEventId)
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
                              iif(hb_IsNIL(par_cNamespaceAndTableName) , "" , [  Table = "]+par_cNamespaceAndTableName+["])+;
                              iif(hb_IsNIL(par_nKey)                , "" , [  Key = ]+trans(par_nKey))+;
                              iif(hb_IsNIL(l_cFieldName)             , "" , [  Field = "]+l_cFieldName+["]))
        
        if l_iAutoTrimmedInfo > 1
            l_cSQLCommand +=  [,]
        endif
        l_cSQLCommand +=  [(]

        if !hb_IsNIL(par_xEventId)
            l_cSQLCommand += [']+iif(ValType(par_xEventId) == "N",trans(par_xEventId),left(AllTrim(par_xEventId),HB_ORM_MAX_EVENTID_SIZE))+[',]
        endif
        l_cSQLCommand += [now(),]
        l_cSQLCommand += [SUBSTRING(USER(), LOCATE('@', USER())+1),]
        l_cSQLCommand += [']+par_cNamespaceAndTableName+[',]
        l_cSQLCommand += trans(par_nKey)+[,]
        l_cSQLCommand += [']+l_cFieldName+[',]           // Field Name
        l_cSQLCommand += [']+allt(l_cFieldType)+[',]     // Field type
        l_cSQLCommand += trans(l_nFieldLen)+[,]
        
        if el_IsInlist(l_cFieldType,"B","BV","R")
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

    if !::SQLExec("LogAutoTrimEvent",l_cSQLCommand)
        l_cLastErrorMessage := ::GetSQLExecErrorMessage()
        hb_orm_SendToDebugView("Error on Auto Trim: "+l_cLastErrorMessage)
    endif

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_nPos := at(".",par_cNamespaceAndTableName)
    if l_nPos == 0
        l_cNamespaceName := ""
        l_cTableName  := par_cNamespaceAndTableName
    else
        l_cNamespaceName := left(par_cNamespaceAndTableName,l_nPos-1)
        l_cTableName  := substr(par_cNamespaceAndTableName,l_nPos+1)
    endif

    l_cSQLCommand := [INSERT INTO ]+::FormatIdentifier(::p_HBORMNamespace+".SchemaAutoTrimLog")+[ (]
    
    if !hb_IsNIL(par_xEventId)
        l_cSQLCommand += ::FormatIdentifier("eventid")+[,]
    endif
    l_cSQLCommand += ::FormatIdentifier("datetime")+[,]
    l_cSQLCommand += ::FormatIdentifier("ip")+[,]
    l_cSQLCommand += ::FormatIdentifier("namespacename")+[,]
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
                              iif(hb_IsNIL(par_cNamespaceAndTableName) , "" , [  Table = "]+par_cNamespaceAndTableName+["])+;
                              iif(hb_IsNIL(par_nKey)                   , "" , [  Key = ]+trans(par_nKey))+;
                              iif(hb_IsNIL(l_cFieldName)               , "" , [  Field = "]+l_cFieldName+["]))
        
        if l_iAutoTrimmedInfo > 1
            l_cSQLCommand +=  [,]
        endif
        l_cSQLCommand +=  [(]

        if !hb_IsNIL(par_xEventId)
            l_cSQLCommand += [']+iif(ValType(par_xEventId) == "N",trans(par_xEventId),left(AllTrim(par_xEventId),HB_ORM_MAX_EVENTID_SIZE))+[',]
        endif
        l_cSQLCommand += [current_timestamp,]
        l_cSQLCommand += [inet_client_addr(),]
        l_cSQLCommand += [']+l_cNamespaceName+[',]
        l_cSQLCommand += [']+l_cTableName+[',]
        l_cSQLCommand += trans(par_nKey)+[,]

        l_cSQLCommand += [']+l_cFieldName+[',]           // Field Name
        l_cSQLCommand += [']+allt(l_cFieldType)+[',]     // Field type
        l_cSQLCommand += trans(l_nFieldLen)+[,]

        if el_IsInlist(l_cFieldType,"B","BV","R")
            //Binary
            l_cSQLCommand += [NULL,]
            // l_cSQLCommand += [E'\x]+hb_StrToHex(l_cValue,"\x")+[']
            l_cSQLCommand += hb_orm_PostgresqlEncodeBinary(l_cValue)
        else
            //Text UTF
            // l_cSQLCommand += [E'\x]+hb_StrToHex(l_cValue,"\x")+[',]
            l_cSQLCommand += hb_orm_PostgresqlEncodeUTF8String(l_cValue)+[,]
            l_cSQLCommand += [NULL]
        endif

        l_cSQLCommand +=  [)]
    endfor

    l_cSQLCommand += [;]

    if !::SQLExec("LogAutoTrimEvent",l_cSQLCommand)
        l_cLastErrorMessage := ::GetSQLExecErrorMessage()
        hb_orm_SendToDebugView("Error on Auto Trim: "+l_cLastErrorMessage)
    endif

endcase
return NIL
//-----------------------------------------------------------------------------------------------------------------
method LogErrorEvent(par_xEventId,par_aErrors) class hb_orm_SQLConnect
local l_cSQLCommand
local l_cLastErrorMessage
local l_iErrors
local l_cNamespaceAndTableName,l_nKey,l_cErrorMessage
local l_lDoNotReportErrors := ::p_DoNotReportErrors
local l_nPos,l_cNamespaceName,l_cTableName
local l_cAppStack

::p_DoNotReportErrors := .t.  // To avoid cycling reporting of errors

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL
    l_cSQLCommand := [INSERT INTO ]+::FormatIdentifier("SchemaAndDataErrorLog")+[ (]
    
    if !hb_IsNIL(par_xEventId)
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
        l_cNamespaceAndTableName := par_aErrors[l_iErrors][1]
        l_nKey                := par_aErrors[l_iErrors][2]
        l_cErrorMessage       := par_aErrors[l_iErrors][3]
        l_cAppStack           := par_aErrors[l_iErrors][4]

        hb_orm_SendToDebugView("Error Event:"+;
                              iif(hb_IsNIL(l_cNamespaceAndTableName) , "" , [  Table = "]+l_cNamespaceAndTableName+["])+;
                              iif(hb_IsNIL(l_nKey)                , "" , [  Key = ]+trans(l_nKey))+;
                              [  ]+l_cErrorMessage)

        if l_iErrors > 1
            l_cSQLCommand +=  [,]
        endif
        l_cSQLCommand +=  [(]

        if !hb_IsNIL(par_xEventId)
            l_cSQLCommand += [']+iif(ValType(par_xEventId) == "N",trans(par_xEventId),left(AllTrim(par_xEventId),HB_ORM_MAX_EVENTID_SIZE))+[',]
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

    if !::SQLExec("LogErrorEvent",l_cSQLCommand)
        l_cLastErrorMessage := ::GetSQLExecErrorMessage()
        hb_orm_SendToDebugView("Error on Auto Trim: "+l_cLastErrorMessage)
    endif

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    l_cSQLCommand := [INSERT INTO ]+::FormatIdentifier(::p_HBORMNamespace+".SchemaAndDataErrorLog")+[ (]
    
    if !hb_IsNIL(par_xEventId)
        l_cSQLCommand += ::FormatIdentifier("eventid")+[,]
    endif

    l_cSQLCommand += ::FormatIdentifier("appstack")+[,]
    l_cSQLCommand += ::FormatIdentifier("datetime")+[,]
    l_cSQLCommand += ::FormatIdentifier("ip")+[,]
    l_cSQLCommand += ::FormatIdentifier("namespacename")+[,]
    l_cSQLCommand += ::FormatIdentifier("tablename")+[,]
    l_cSQLCommand += ::FormatIdentifier("recordpk")+[,]
    l_cSQLCommand += ::FormatIdentifier("errormessage")

    l_cSQLCommand += [) VALUES ]

    for l_iErrors := 1 to len(par_aErrors)
        l_cNamespaceAndTableName := par_aErrors[l_iErrors][1]
        l_nKey                := par_aErrors[l_iErrors][2]
        l_cErrorMessage       := par_aErrors[l_iErrors][3]
        l_cAppStack           := par_aErrors[l_iErrors][4]

        if hb_IsNIL(l_cNamespaceAndTableName)
            l_cNamespaceName := NIL
            l_cTableName  := NIL
        else
            l_nPos := at(".",l_cNamespaceAndTableName)
            if l_nPos == 0
                l_cNamespaceName := ""
                l_cTableName  := l_cNamespaceAndTableName
            else
                l_cNamespaceName := left(l_cNamespaceAndTableName,l_nPos-1)
                l_cTableName  := substr(l_cNamespaceAndTableName,l_nPos+1)
            endif
        endif


        hb_orm_SendToDebugView("Error Event:"+;
                              iif(hb_IsNIL(l_cNamespaceAndTableName) , "" , [  Table = "]+l_cNamespaceAndTableName+["])+;
                              iif(hb_IsNIL(l_nKey)                   , "" , [  Key = ]   +trans(l_nKey))+;
                              [  ]+l_cErrorMessage)

        if l_iErrors > 1
            l_cSQLCommand +=  [,]
        endif
        l_cSQLCommand +=  [(]

        if !hb_IsNIL(par_xEventId)
            l_cSQLCommand += [']+iif(ValType(par_xEventId) == "N",trans(par_xEventId),left(AllTrim(par_xEventId),HB_ORM_MAX_EVENTID_SIZE))+[',]
        endif
        if hb_IsNIL(l_cAppStack)
            l_cSQLCommand += [NULL,]
        else
            // l_cSQLCommand += [E'\x]+hb_StrToHex(l_cAppStack,"\x")+[',]
            l_cSQLCommand += hb_orm_PostgresqlEncodeUTF8String(l_cAppStack)+[,]
        endif
        l_cSQLCommand += [current_timestamp,]
        l_cSQLCommand += [inet_client_addr(),]
        l_cSQLCommand += iif(hb_IsNIL(l_cNamespaceName) , [NULL,] , [']+l_cNamespaceName+[',])
        l_cSQLCommand += iif(hb_IsNIL(l_cTableName)  , [NULL,] , [']+l_cTableName+[',])
        l_cSQLCommand += iif(hb_IsNIL(l_nKey)        , [NULL,] , trans(l_nKey)+[,])
        // l_cSQLCommand += [E'\x]+hb_StrToHex(l_cErrorMessage,"\x")+[']
        l_cSQLCommand += hb_orm_PostgresqlEncodeUTF8String(l_cErrorMessage)

        l_cSQLCommand +=  [)]
    endfor

    l_cSQLCommand += [;]

    if !::SQLExec("LogErrorEvent",l_cSQLCommand)
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
        if ::SQLExec("CheckIfStillConnected",[select current_time;])
            l_lResult := .t.
        endif
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        if ::SQLExec("CheckIfStillConnected",[select current_time;])
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
        l_lResult := .t.
        if ::TableExists(::p_HBORMNamespace+".SchemaCacheLog")
            l_cSQLCommand := [SELECT pk,]
            l_cSQLCommand += [       cachedschema::integer]
            l_cSQLCommand += [ FROM  ]+::FormatIdentifier(::p_HBORMNamespace)+::FixCasingOfSchemaCacheTables([."SchemaCacheLog"])
            l_cSQLCommand += [ ORDER BY pk DESC]
            l_cSQLCommand += [ LIMIT 1]

            if ::SQLExec("CheckIfSchemaCacheShouldBeUpdated",l_cSQLCommand,"SchemaCacheLogLast")
                if SchemaCacheLogLast->(reccount()) == 1
                    if SchemaCacheLogLast->pk == ::p_iMetadataTableCacheLogLastPk
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
        if ::SQLExec("GetUUIDString",[select cast(UUID() AS char(36)) AS cuuid],"c_DB_Result_UUID")
            l_lResult := .t.
        endif
    case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
        if ::SQLExec("GetUUIDString",[select gen_random_uuid()::char(36) as cuuid],"c_DB_Result_UUID")
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
method SetHarbourORMNamespace(par_cName) class hb_orm_SQLConnect
::p_HBORMNamespace := iif(empty(par_cName),"hborm",par_cName)
return NIL
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
method SetForeignKeyNullAndZeroParity(par_lMode) class hb_orm_SQLConnect
::p_ForeignKeyNullAndZeroParity := par_lMode
return nil
//-----------------------------------------------------------------------------------------------------------------
method LoadWharfConfiguration(par_hConfig) class hb_orm_SQLConnect
local l_hReferenceTables
local l_hReferenceFields
local l_cReferenceFieldUsedAs
local l_cReferenceFieldType
local l_hTable
local l_hField
local l_cNamespaceAndTableName
local l_cColumnName

if !hb_IsNil(par_hConfig) .and. !empty(par_hConfig)
    hb_HMerge(::p_hWharfConfig,par_hConfig)
endif
::p_LoadedWharfConfiguration := .t.

hb_HCaseMatch(::p_hTablePrimaryKeyInfo,.f.)

//Update the list of Table Primary Key field Names and Types
l_hReferenceTables = hb_HGetDef(::p_hWharfConfig,"Tables",NIL)    //Find the equivalent of the p_hMetadataTable definitions
if !hb_IsNil(l_hReferenceTables)
    for each l_hTable in l_hReferenceTables
        l_cNamespaceAndTableName = l_hTable:__enumKey
        l_hReferenceFields := hb_HGetDef(l_hTable,HB_ORM_SCHEMA_FIELD,NIL)
        if !hb_IsNil(l_hReferenceFields)
            for each l_hField in l_hReferenceFields
                l_cReferenceFieldUsedAs := hb_HGetDef(l_hField,HB_ORM_SCHEMA_FIELD_USEDAS,NIL)
                if !hb_IsNil(l_cReferenceFieldUsedAs) .and. l_cReferenceFieldUsedAs == "Primary"
                    l_cReferenceFieldType := hb_HGetDef(l_hField,HB_ORM_SCHEMA_FIELD_TYPE,"I")
                    l_cColumnName = l_hField:__enumKey
                    ::p_hTablePrimaryKeyInfo[l_cNamespaceAndTableName] := {l_cColumnName,l_cReferenceFieldType}
                    exit
                endif
            endfor
        endif
    endfor
endif

return nil
//-----------------------------------------------------------------------------------------------------------------
method GetTableConfiguration(par_cNamespaceAndTableName) class hb_orm_SQLConnect

static l_cLastDefinitionSignature := ""
static l_hDefinitionCache := {=>}
local l_cDefinitionSignature
local l_hDefinition
local l_hReference
local l_cAKA      := ""
local l_lUnlogged := .f.
local l_cHashKey := iif(::p_ForeignKeyNullAndZeroParity,"T","F")+par_cNamespaceAndTableName

l_cDefinitionSignature := hb_HGetDef(::p_hWharfConfig,"GenerationSignature","")
if empty(l_cDefinitionSignature)
    // No Loaded Wharf Configuration
    l_hDefinition := {=>}
else
    //Purge Cache if DefinitionSignature changed
    if !(l_cDefinitionSignature == l_cLastDefinitionSignature)
        l_hDefinitionCache := {=>}
        l_cLastDefinitionSignature := l_cDefinitionSignature
    endif

    //Try to load from Cache
    l_hDefinition := hb_HGetDef(l_hDefinitionCache,l_cHashKey,{=>})

    //No Cache Entry
    if empty(l_hDefinition)
        // Find out if we are getting or setting a Foreign Key at is Nullable and if 0 is equivalent to NULL
        l_hReference = hb_HGetDef(::p_hWharfConfig,"Tables",NIL)    //Find the equivalent of the p_hMetadataTable definitions
        if !hb_IsNil(l_hReference)
            l_hReference := hb_HGetDef(l_hReference,par_cNamespaceAndTableName,NIL)       //Find the Table definition
            if !hb_IsNil(l_hReference)
                l_cAKA      := hb_HGetDef(l_hReference,"AKA"                ,"")
                l_lUnlogged := hb_HGetDef(l_hReference,"Unlogged"             ,.f.)
            endif
        endif

        l_hDefinition := {"AKA"                =>l_cAKA      ,;
                          "Unlogged"           =>l_lUnlogged  ;
                          }

        //Add to cache
        l_hDefinitionCache[l_cHashKey] := hb_HClone(l_hDefinition)

    endif

endif

return l_hDefinition
//-----------------------------------------------------------------------------------------------------------------
method GetColumnConfiguration(par_cNamespaceAndTableName,par_cFieldName) class hb_orm_SQLConnect

static l_cLastDefinitionSignature := ""
static l_hDefinitionCache := {=>}
local l_cDefinitionSignature
local l_hDefinition
local l_hReference
local l_cAKA                := ""
local l_cType               := ""
local l_cUsedAs             := ""
local l_cParentTable        := ""
local l_cOnDelete           := ""
local l_lIsNullable         := .f.
local l_nLength             := 0
local l_nScale              := 0
local l_lForeignKeyOptional := .f.
local l_cHashKey := iif(::p_ForeignKeyNullAndZeroParity,"T","F")+par_cNamespaceAndTableName+"*"+par_cFieldName

// if lower(par_cFieldName) == lower("fk_Enumeration")
//     altd()
// endif

l_cDefinitionSignature := hb_HGetDef(::p_hWharfConfig,"GenerationSignature","")
if empty(l_cDefinitionSignature)
    // No Loaded Wharf Configuration
    l_hDefinition := {=>}
else
    //Purge Cache if DefinitionSignature changed
    if !(l_cDefinitionSignature == l_cLastDefinitionSignature)
        l_hDefinitionCache := {=>}
        l_cLastDefinitionSignature := l_cDefinitionSignature
    endif

    //Try to load from Cache
    l_hDefinition := hb_HGetDef(l_hDefinitionCache,l_cHashKey,{=>})

    //No Cache Entry
    if empty(l_hDefinition)
        // Find out if we are getting or setting a Foreign Key at is Nullable and if 0 is equivalent to NULL
        l_hReference = hb_HGetDef(::p_hWharfConfig,"Tables",NIL)    //Find the equivalent of the p_hMetadataTable definitions
        if !hb_IsNil(l_hReference)
            l_hReference := hb_HGetDef(l_hReference,par_cNamespaceAndTableName,NIL)       //Find the Table definition
            if !hb_IsNil(l_hReference)
                l_hReference := hb_HGetDef(l_hReference,HB_ORM_SCHEMA_FIELD,NIL)                    //Find "Fields" definition
                if !hb_IsNil(l_hReference)
                    l_hReference := hb_HGetDef(l_hReference,par_cFieldName,NIL)            //Find the column definition
                    if !hb_IsNil(l_hReference)
                        l_cAKA                := hb_HGetDef(l_hReference,"AKA"                ,"")
                        l_cType               := hb_HGetDef(l_hReference,"Type"               ,"?")
                        l_cUsedAs             := hb_HGetDef(l_hReference,"UsedAs"             ,"")
                        l_cParentTable        := hb_HGetDef(l_hReference,"ParentTable"        ,"")
                        l_cOnDelete           := hb_HGetDef(l_hReference,"OnDelete"           ,"")
                        l_lIsNullable         := hb_HGetDef(l_hReference,"Nullable"           ,.f.)
                        l_nLength             := hb_HGetDef(l_hReference,"Length"             ,0)
                        l_nScale              := hb_HGetDef(l_hReference,"Scale"              ,0)
                        l_lForeignKeyOptional := hb_HGetDef(l_hReference,"ForeignKeyOptional" ,.f.)
                    endif
                endif
            endif
        endif

        l_hDefinition := {"AKA"                =>l_cAKA                ,;
                          "Type"               =>l_cType               ,;
                          "UsedAs"             =>l_cUsedAs             ,;
                          "ParentTable"        =>l_cParentTable        ,;
                          "IsNullable"         =>l_lIsNullable         ,;
                          "OnDelete"           =>l_cOnDelete           ,;
                          "Length"             =>l_nLength             ,;
                          "Scale"              =>l_nScale              ,;
                          "ForeignKeyOptional" =>l_lForeignKeyOptional ,;
                          "NullZeroEquivalent"=>::p_ForeignKeyNullAndZeroParity .and. (l_cUsedAs == "Foreign") .and. l_lIsNullable;
                          }

        //Add to cache
        l_hDefinitionCache[l_cHashKey] := hb_HClone(l_hDefinition)

    endif

endif

return l_hDefinition
//-----------------------------------------------------------------------------------------------------------------
method GetColumnsConfiguration(par_cNamespaceAndTableName) class hb_orm_SQLConnect   //Returns an array of column names

static l_cLastDefinitionSignature := ""
static l_aColumnsCache := {=>}
local l_cDefinitionSignature
local l_aColumns
local l_hFieldDefinition
local l_hReference
local l_cHashKey := par_cNamespaceAndTableName

l_cDefinitionSignature := hb_HGetDef(::p_hWharfConfig,"GenerationSignature","")
if empty(l_cDefinitionSignature)
    // No Loaded Wharf Configuration
    l_aColumns := {=>}
else
    //Purge Cache if DefinitionSignature changed
    if !(l_cDefinitionSignature == l_cLastDefinitionSignature)
        l_aColumnsCache := {=>}
        l_cLastDefinitionSignature := l_cDefinitionSignature
    endif

    //Try to load from Cache
    l_aColumns := hb_HGetDef(l_aColumnsCache,l_cHashKey,{})

    //No Cache Entry
    if empty(l_aColumns)
        // Find out if we are getting or setting a Foreign Key at is Nullable and if 0 is equivalent to NULL
        l_hReference = hb_HGetDef(::p_hWharfConfig,"Tables",NIL)    //Find the equivalent of the p_hMetadataTable definitions
        if !hb_IsNil(l_hReference)
            l_hReference := hb_HGetDef(l_hReference,par_cNamespaceAndTableName,NIL)       //Find the Table definition
            if !hb_IsNil(l_hReference)
                l_hReference := hb_HGetDef(l_hReference,HB_ORM_SCHEMA_FIELD,NIL)                    //Find "Fields" definition
                if !hb_IsNil(l_hReference)

                    for each l_hFieldDefinition in l_hReference
                        AAdd(l_aColumns,l_hFieldDefinition:__enumKey())
                    endfor

                endif
            endif
        endif

        //Add to cache
        l_aColumnsCache[l_cHashKey] := AClone(l_aColumns)

    endif

endif

return l_aColumns
//-----------------------------------------------------------------------------------------------------------------
// Destructive delete of any orphans in all the tables in par_hTableSchemaDefinition. Currently for PostgreSQL only
method DeleteAllOrphanRecords(par_hTableSchemaDefinition) class hb_orm_SQLConnect

local l_hTableDefinition
local l_cNamespaceAndTableName
local l_nPos
local l_cNamespaceName
local l_cTableName
local l_hFields
local l_hField
// local l_hCurrentTableDefinition
local l_cFieldName
local l_hFieldDefinition
local l_cFieldUsedAs
local l_cParentNamespaceAndTable
local l_cParentNamespaceName
local l_cParentTableName
local l_cSQLCommand
local l_hPrimaryKeys
local l_cParentTablePrimaryKey
local l_cChildTablePrimaryKey
local l_lDeleteRecords
local l_nMaxLoopOfTables := 10  //To deal with cascading deletions
local l_lForeignKeyOptional

if ::UpdateSchemaCache()
    ::LoadMetadata("DeleteAllOrphanRecords")
endif

l_hPrimaryKeys := ::GetListOfPrimaryKeysForAllTables(par_hTableSchemaDefinition)

do case
case ::p_SQLEngineType == HB_ORM_ENGINETYPE_MYSQL

case ::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL
    do while l_nMaxLoopOfTables > 0
        hb_orm_SendToDebugView("DeleteAllOrphanRecords - In Loop")
        l_nMaxLoopOfTables--
        l_lDeleteRecords := .f.
        for each l_hTableDefinition in par_hTableSchemaDefinition
            l_cNamespaceAndTableName := l_hTableDefinition:__enumKey()

            l_nPos := at(".",l_cNamespaceAndTableName)
            if empty(l_nPos)
                l_cNamespaceName := "public"
                l_cTableName     := l_cNamespaceAndTableName
            else
                l_cNamespaceName := left(l_cNamespaceAndTableName,l_nPos-1)
                l_cTableName     := substr(l_cNamespaceAndTableName,l_nPos+1)
            endif
            if l_cNamespaceName == "hborm" .and. !(::p_HBORMNamespace == "hborm")
                l_cNamespaceName := ::p_HBORMNamespace
            endif

            l_hFields := l_hTableDefinition[HB_ORM_SCHEMA_FIELD]

            for each l_hField in l_hFields
                l_cFieldName       := l_hField:__enumKey()
                l_hFieldDefinition := l_hField:__enumValue()
                l_cFieldUsedAs     := hb_HGetDef(l_hFieldDefinition,"UsedAs","")
                if l_cFieldUsedAs == "Foreign"
                    l_cParentNamespaceAndTable := hb_HGetDef(l_hFieldDefinition,"ParentTable","")

                    if !empty(l_cParentNamespaceAndTable)

                        l_lForeignKeyOptional := hb_HGetDef(l_hFieldDefinition,"ForeignKeyOptional",.f.)

                        l_nPos := at(".",l_cParentNamespaceAndTable)
                        if empty(l_nPos)
                            l_cParentNamespaceName := "public"
                            l_cParentTableName     := l_cParentNamespaceAndTable
                        else
                            l_cParentNamespaceName := left(l_cParentNamespaceAndTable,l_nPos-1)
                            l_cParentTableName     := substr(l_cParentNamespaceAndTable,l_nPos+1)
                        endif
                        if l_cParentNamespaceName == "hborm" .and. !(::p_HBORMNamespace == "hborm")
                            l_cParentNamespaceName := ::p_HBORMNamespace
                        endif

                        l_cChildTablePrimaryKey := hb_HGetDef(l_hPrimaryKeys,l_cNamespaceName+"."+l_cTableName,"")
                        if empty(l_cChildTablePrimaryKey)
                            hb_orm_SendToDebugView("DeleteAllOrphanRecords - Failed to find Primary key of Child Table: "+l_cNamespaceName+"."+l_cTableName)
                            loop
                        endif

                        l_cParentTablePrimaryKey := hb_HGetDef(l_hPrimaryKeys,l_cParentNamespaceName+"."+l_cParentTableName,"")
                        if empty(l_cChildTablePrimaryKey)
                            hb_orm_SendToDebugView("DeleteAllOrphanRecords - Failed to find Primary key of Parent Table: "+l_cNamespaceName+"."+l_cTableName)
                            loop
                        endif

                        if l_lForeignKeyOptional
                            l_cSQLCommand := [update "]+l_cNamespaceName+["."]+l_cTableName+[" set "]+l_cFieldName+[" = NULL WHERE "]+l_cChildTablePrimaryKey+[" in (]
                            l_cSQLCommand += [select "ChildTable"."]+l_cChildTablePrimaryKey+["]
                            l_cSQLCommand += [ from "]+l_cNamespaceName+["."]+l_cTableName+[" AS "ChildTable"]
                            l_cSQLCommand += [ left join "]+l_cParentNamespaceName+["."]+l_cParentTableName+[" AS "ParentTable" ON "ChildTable"."]+l_cFieldName+[" = "ParentTable"."]+l_cParentTablePrimaryKey+["]
                            l_cSQLCommand += [ where "ChildTable"."]+l_cFieldName+[" is not null]
                            l_cSQLCommand += [ and "ParentTable"."]+l_cParentTablePrimaryKey+[" is null]
                            l_cSQLCommand += [) RETURNING "]+l_cChildTablePrimaryKey+["]

                            if ::SQLExec("7f7557d0-08bd-4066-8669-7ef204a852b6",l_cSQLCommand,"hb_orm_ListOfUpdatedRecords")
                                if used("hb_orm_ListOfUpdatedRecords") .and. ("hb_orm_ListOfUpdatedRecords")->(reccount()) > 0
                                    l_lDeleteRecords := .t.
                                    hb_orm_SendToDebugView("DeleteAllOrphanRecords - Break Link - Table: "+l_cTableName+" Number Of Records: "+trans(("hb_orm_ListOfUpdatedRecords")->(reccount())))
                                endif
                            endif

                        else
                            l_cSQLCommand := [delete from "]+l_cNamespaceName+["."]+l_cTableName+[" WHERE "]+l_cChildTablePrimaryKey+[" in (]
                            l_cSQLCommand += [select "ChildTable"."]+l_cChildTablePrimaryKey+["]
                            l_cSQLCommand += [ from "]+l_cNamespaceName+["."]+l_cTableName+[" AS "ChildTable"]
                            l_cSQLCommand += [ left join "]+l_cParentNamespaceName+["."]+l_cParentTableName+[" AS "ParentTable" ON "ChildTable"."]+l_cFieldName+[" = "ParentTable"."]+l_cParentTablePrimaryKey+["]
                            l_cSQLCommand += [ where "ChildTable"."]+l_cFieldName+[" is not null]
                            l_cSQLCommand += [ and "ParentTable"."]+l_cParentTablePrimaryKey+[" is null]
                            l_cSQLCommand += [) RETURNING "]+l_cChildTablePrimaryKey+["]

                            if ::SQLExec("7f7557d0-08bd-4066-8669-7ef204a852b6",l_cSQLCommand,"hb_orm_ListOfDeletedRecords")
                                if used("hb_orm_ListOfDeletedRecords") .and. ("hb_orm_ListOfDeletedRecords")->(reccount()) > 0
                                    l_lDeleteRecords := .t.
                                    hb_orm_SendToDebugView("DeleteAllOrphanRecords - Delete Record - Table: "+l_cTableName+" Number Of Records: "+trans(("hb_orm_ListOfDeletedRecords")->(reccount())))
                                endif
                            endif

                        endif

                        CloseAlias("hb_orm_ListOfDeletedRecords")

                    endif

                endif

            endfor

        endfor
        if !l_lDeleteRecords  //Nothing left to delete.
            l_nMaxLoopOfTables := 0
        endif
    enddo
    
endcase

return nil
//-----------------------------------------------------------------------------------------------------------------
// Find and replace any Zero in Integer type foreign key columns. Used to prepare data to handle foreign key constraints.
method ForeignKeyConvertAllZeroToNull(par_hTableSchemaDefinition) class hb_orm_SQLConnect

local l_hTableDefinition
local l_cNamespaceAndTableName
local l_nPos
local l_cNamespaceName
local l_cTableName
local l_hFields
local l_hField
local l_cFieldName
local l_hFieldDefinition
local l_cFieldUsedAs
local l_cSQLCommand
local l_cFieldType

if ::UpdateSchemaCache()
    ::LoadMetadata("ForeignKeyConvertAllZeroToNull")
endif

for each l_hTableDefinition in par_hTableSchemaDefinition
    l_cNamespaceAndTableName := l_hTableDefinition:__enumKey()

    l_nPos := at(".",l_cNamespaceAndTableName)
    if empty(l_nPos)
        l_cNamespaceName := "public"
        l_cTableName     := l_cNamespaceAndTableName
    else
        l_cNamespaceName := left(l_cNamespaceAndTableName,l_nPos-1)
        l_cTableName     := substr(l_cNamespaceAndTableName,l_nPos+1)
    endif
    if l_cNamespaceName == "hborm" .and. !(::p_HBORMNamespace == "hborm")
        l_cNamespaceName := ::p_HBORMNamespace
    endif
    l_cNamespaceAndTableName := l_cNamespaceName+"."+l_cTableName

    l_hFields := l_hTableDefinition[HB_ORM_SCHEMA_FIELD]

    for each l_hField in l_hFields
        l_cFieldName       := l_hField:__enumKey()
        l_hFieldDefinition := l_hField:__enumValue()
        l_cFieldUsedAs     := hb_HGetDef(l_hFieldDefinition,"UsedAs","")
        l_cFieldType       := hb_HGetDef(l_hFieldDefinition,"Type","")
        if l_cFieldUsedAs == "Foreign" .and. el_IsInlist(l_cFieldType,"I","IB")
            l_cSQLCommand := [UPDATE ]+::FormatIdentifier(::NormalizeTableNamePhysical(l_cNamespaceAndTableName))+[ SET ]+::FormatIdentifier(l_cFieldName)+[ = NULL WHERE ]+::FormatIdentifier(l_cFieldName)+[ = 0]
            if !::SQLExec("0ffbf06e-4e79-4b23-9a89-073a56cfed08",l_cSQLCommand)
                //_M_ report error
            endif
        endif
    endfor
endfor

return nil
//-----------------------------------------------------------------------------------------------------------------
method GetListOfPrimaryKeysForAllTables(par_hTableSchemaDefinition)
local l_hPrimaryKeys := {=>}
local l_hTableDefinition
local l_cNamespaceAndTableName
local l_cNamespaceName
local l_cTableName
local l_nPos
local l_hFields
local l_hField
local l_cFieldName
local l_hFieldDefinition
local l_cFieldUsedAs

hb_HCaseMatch(l_hPrimaryKeys,.f.)

//Get the list of Primary Key in each tables in l_hPrimaryKeys
for each l_hTableDefinition in par_hTableSchemaDefinition
    l_cNamespaceAndTableName := l_hTableDefinition:__enumKey()

    l_nPos := at(".",l_cNamespaceAndTableName)
    if empty(l_nPos)
        l_cNamespaceName := "public"
        l_cTableName     := l_cNamespaceAndTableName
    else
        l_cNamespaceName := left(l_cNamespaceAndTableName,l_nPos-1)
        l_cTableName     := substr(l_cNamespaceAndTableName,l_nPos+1)
    endif
    if l_cNamespaceName == "hborm" .and. !(::p_HBORMNamespace == "hborm")
        l_cNamespaceName := ::p_HBORMNamespace
    endif
    l_cNamespaceAndTableName := l_cNamespaceName+"."+l_cTableName

    l_hFields := l_hTableDefinition[HB_ORM_SCHEMA_FIELD]
    for each l_hField in l_hFields
        l_cFieldName       := l_hField:__enumKey()
        l_hFieldDefinition := l_hField:__enumValue()
        l_cFieldUsedAs     := hb_HGetDef(l_hFieldDefinition,"UsedAs","")
        if l_cFieldUsedAs == "Primary"
            l_hPrimaryKeys[l_cNamespaceAndTableName] := l_cFieldName
            exit
        endif
    endfor
endfor

return l_hPrimaryKeys
//-----------------------------------------------------------------------------------------------------------------
#include "hb_orm_schema.prg"
//-----------------------------------------------------------------------------------------------------------------
