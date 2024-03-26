#include "hbclass.ch"

#ifndef DEFINED_HB_ORM_SQLCONNECT_CLASS
#define DEFINED_HB_ORM_SQLCONNECT_CLASS

class hb_orm_SQLConnect
    hidden:
        classdata ConnectionCounter        init 0    // Across all instances of this class. Used to ensure all the ::p_ConnectionNumber are unique across all instances in current running program.
        data p_ConnectionNumber            init 0    // Unique number across all instances in current running program. Can be used to help generate some names.
        data p_SQLConnection               init 0    // ODBC layer connection number
        data p_BackendType                 init 0
        data p_SQLEngineType               init 0
        data p_Driver                      init ""
        data p_Server                      init "localhost"
        data p_Port                        init 0
        data p_User                        init ""
        data p_Password                    init ""
        data p_Database                    init ""
        data p_NamespaceName               init "public"     // Refers to the current Namespace  (In MSSQL this would be "dbo")
        data p_ApplicationName             init "Harbour_ORM"
        data p_PrimaryKeyFieldName         init "key"        // Primary Key Field Name
        data p_CreationTimeFieldName       init "sysc"       // Creation Time Field Name
        data p_ModificationTimeFieldName   init "sysm"       // Modification Time Field Name
        data p_ErrorMessage                init ""
        data p_Locks                       init {}
        data p_LockTimeout                 init 20   //In Seconds
        data p_SQLExecErrorMessage         init ""
        data p_DoNotReportErrors           init .f.
        data p_iMetadataTableCacheLogLastPk   init 0            // Used in case of schema caching
        data p_HBORMNamespace              init "hborm"      // The name of the postgresql schema (in a database), that will hold the log, cache files and trigger to speed up schema structure queries, and other hb_orm managed tables
        data p_ForeignKeyNullAndZeroParity init .f.                      //If 0 should be stored as NULL and NULL returned as 0 for Nullable Foreign keys. Makes it easier to query field ( "= 0" same as "IS NULL")
        data p_LoadedWharfConfiguration    init .f.
        
        classdata MaxDigitsInTableNumber  init  5  // Needed for the lock/unlock methods. With 5 digits we should have less than 99999 tables.
        classdata ReservedWordsMySQL      init {"ACCESSIBLE","ADD","ALL","ALTER","ANALYZE","AND","AS","ASC","ASENSITIVE","BEFORE","BETWEEN","BIGINT","BINARY","BLOB","BOTH","BY","CALL","CASCADE","CASE","CHANGE","CHAR","CHARACTER","CHECK","COLLATE","COLUMN","CONDITION","CONSTRAINT","CONTINUE","CONVERT","CREATE","CROSS","CUBE","CUME_DIST","CURRENT_DATE","CURRENT_TIME","CURRENT_TIMESTAMP","CURRENT_USER","CURSOR","DATABASE","DATABASES","DAY_HOUR","DAY_MICROSECOND","DAY_MINUTE","DAY_SECOND","DEC","DECIMAL","DECLARE","DEFAULT","DELAYED","DELETE","DENSE_RANK","DESC","DESCRIBE","DETERMINISTIC","DISTINCT","DISTINCTROW","DIV","DOUBLE","DROP","DUAL","EACH","ELSE","ELSEIF","EMPTY","ENCLOSED","ESCAPED","EXCEPT","EXISTS","EXIT","EXPLAIN","FALSE","FETCH","FIRST_VALUE","FLOAT","FLOAT4","FLOAT8","FOR","FORCE","FOREIGN","FROM","FULLTEXT","FUNCTION","GENERATED","GET","GRANT","GROUP","GROUPING","GROUPS","HAVING","HIGH_PRIORITY","HOUR_MICROSECOND","HOUR_MINUTE","HOUR_SECOND","IF","IGNORE","IN","INDEX","INFILE","INNER","INOUT","INSENSITIVE","INSERT","INT","INT1","INT2","INT3","INT4","INT8","INTEGER","INTERVAL","INTO","IO_AFTER_GTIDS","IO_BEFORE_GTIDS","IS","ITERATE","JOIN","JSON_TABLE","KEY","KEYS","KILL","LAG","LAST_VALUE","LATERAL","LEAD","LEADING","LEAVE","LEFT","LIKE","LIMIT","LINEAR","LINES","LOAD","LOCALTIME","LOCALTIMESTAMP","LOCK","LONG","LONGBLOB","LONGTEXT","LOOP","LOW_PRIORITY","MASTER_BIND","MASTER_SSL_VERIFY_SERVER_CERT","MATCH","MAXVALUE","MEDIUMBLOB","MEDIUMINT","MEDIUMTEXT","MIDDLEINT","MINUTE_MICROSECOND","MINUTE_SECOND","MOD","MODIFIES","NATURAL","NOT","NO_WRITE_TO_BINLOG","NTH_VALUE","NTILE","NULL","NUMERIC","OF","ON","OPTIMIZE","OPTIMIZER_COSTS","OPTION","OPTIONALLY","OR","ORDER","OUT","OUTER","OUTFILE","OVER","PARTITION","PERCENT_RANK","PRECISION","PRIMARY","PROCEDURE","PURGE","RANGE","RANK","READ","READS","READ_WRITE","REAL","RECURSIVE","REFERENCES","REGEXP","RELEASE","RENAME","REPEAT","REPLACE","REQUIRE","RESIGNAL","RESTRICT","RETURN","REVOKE","RIGHT","RLIKE","ROW","ROWS","ROW_NUMBER","SCHEMA","SCHEMAS","SECOND_MICROSECOND","SELECT","SENSITIVE","SEPARATOR","SET","SHOW","SIGNAL","SMALLINT","SPATIAL","SPECIFIC","SQL","SQLEXCEPTION","SQLSTATE","SQLWARNING","SQL_BIG_RESULT","SQL_CALC_FOUND_ROWS","SQL_SMALL_RESULT","SSL","STARTING","STORED","STRAIGHT_JOIN","SYSTEM","TABLE","TERMINATED","THEN","TINYBLOB","TINYINT","TINYTEXT","TO","TRAILING","TRIGGER","TRUE","UNDO","UNION","UNIQUE","UNLOCK","UNSIGNED","UPDATE","USAGE","USE","USING","UTC_DATE","UTC_TIME","UTC_TIMESTAMP","VALUES","VARBINARY","VARCHAR","VARCHARACTER","VARYING","VIRTUAL","WHEN","WHERE","WHILE","WINDOW","WITH","WRITE","XOR","YEAR_MONTH","ZEROFILL"}
        classdata ReservedWordsPostgreSQL init {"ALL","ANALYSE","ANALYZE","AND","ANY","ARRAY","AS","ASC","ASYMMETRIC","BINARY","BOTH","CASE","CAST","CHECK","COLLATE","COLLATION","COLUMN","CONCURRENTLY","CONSTRAINT","CREATE","CROSS","CURRENT_CATALOG","CURRENT_DATE","CURRENT_ROLE","CURRENT_SCHEMA","CURRENT_TIME","CURRENT_TIMESTAMP","CURRENT_USER","DEFAULT","DEFERRABLE","DESC","DISTINCT","DO","ELSE","END","EXCEPT","FALSE","FETCH","FOR","FOREIGN","FREEZE","FROM","FULL","GRANT","GROUP","HAVING","ILIKE","IN","INITIALLY","INNER","INTERSECT","INTO","IS","ISNULL","JOIN","LATERAL","LEADING","LEFT","LIKE","LIMIT","LOCALTIME","LOCALTIMESTAMP","NATURAL","NOT","NOTNULL","NULL","OFFSET","ON","ONLY","OR","ORDER","OUTER","OVERLAPS","PLACING","PRIMARY","REFERENCES","RETURNING","RIGHT","SELECT","SESSION_USER","SIMILAR","SOME","SYMMETRIC","TABLE","TABLESAMPLE","THEN","TO","TRAILING","TRUE","UNION","UNIQUE","USER","USING","VARIADIC","VERBOSE","WHEN","WHERE","WINDOW","WITH"}

        //Acronym: GMSS = Generate Migrate Schema Script
        method GMSSAddTable(par_cNamespaceName,par_cTableName,par_hStructure,par_lUnlogged)
        method GMSSAddField(par_cNamespaceName,par_cTableName,par_cFieldName,par_hFieldDefinition)
        method GMSSAddIndex(par_cNamespaceName,par_cTableName,par_hFields,par_cIndexName,par_hIndexDefinition)
        method GMSSDeleteIndex(par_cNamespaceName,par_cTableName,par_cIndexName)
        method GMSSUpdateNamespaceName(par_cNamespaceName,par_cCurrentNamespaceName)
        method GMSSUpdateTableName(par_cNamespaceName,par_cTableName,par_cCurrentNamespaceName,par_cCurrentTableName)
        method GMSSUpdateFieldName(par_cNamespaceName,par_cTableName,par_cFieldName,par_cCurrentFieldName)
        method GMSSUpdateField(par_cNamespaceName,par_cTableName,par_cFieldName,par_hFieldDefinition,par_hCurrentFieldDefinition)
        method FixCasingOfSchemaCacheTables(par_cTableName)
        method GetListOfPrimaryKeysForAllTables(par_hTableSchemaDefinition)             // Returns a Hash with the table name (with Namespace) as keys.
        method GetPostgresTableSchemaQuery()
        method GetPostgresIndexSchemaQuery()

    exported:
        data p_hMetadataTable       init {=>}          //List of Existing Tables Names. Each element is a hash with HB_ORM_SCHEMA_FIELD and HB_ORM_SCHEMA_INDEX array elements ["Hash of Field Definition","Hash of Index Definitions"]. Named it with a leading "p_" to be threaded as internal.
        data p_hMetadataNamespace   init {=>}
        data p_hMetadataEnumeration init {=>}

        data p_hWharfConfig init {=>}                                     //Application definition generated by DataWharf (WharfSystems in the future). This will be used to enforce OnDelete and Foreign key resolutions for example.
        data Connected init .f.                                          //true if connected to a server
        data p_hb_orm_version init HB_ORM_BUILDVERSION READONLY
        method SetBackendType(par_cName)                                 // For Example, "MariaDB","MySQL","PostgreSQL"
        method GetSQLEngineType() inline ::p_SQLEngineType               // HB_ORM_ENGINETYPE_MYSQL, HB_ORM_ENGINETYPE_POSTGRESQL, HB_ORM_ENGINETYPE_MSSQL
        method GetBackendType()   inline ::p_BackendType                 // HB_ORM_BACKENDTYPE_MARIADB, HB_ORM_BACKENDTYPE_MYSQL, HB_ORM_BACKENDTYPE_POSTGRESQL, HB_ORM_BACKENDTYPE_MSSQL
        method SetDriver(par_cName)
        method SetServer(par_cName)
        method GetServer() inline ::p_Server
        method SetPort(par_nNumber)
        method GetPort() inline ::p_Port
        method SetUser(par_cName)
        method GetUser() inline ::p_User
        method SetPassword(par_cPassword)
        method SetDatabase(par_cName)
        method GetDatabase() inline ::p_Database
        method SetCurrentNamespaceName(par_cName)             //only used for PostgreSQL     Return the name of the schema before being set
        method GetPrimaryKeyFieldName() inline ::p_PrimaryKeyFieldName
        method SetPrimaryKeyFieldName(par_cName)
        method SetApplicationName(par_cName)
        method GetApplicationName() inline ::p_ApplicationName
        method GetCreationTimeFieldName() inline ::p_CreationTimeFieldName
        method SetCreationTimeFieldName(par_cName)
        method GetModificationTimeFieldName() inline ::p_ModificationTimeFieldName
        method SetModificationTimeFieldName(par_cName)
        method SetAllSettings(par_cBackendType,par_cDriver,par_Server,par_nPort,par_cUser,par_cPassword,par_cDatabase,par_cSchema,par_cPKFN)
        method Connect()
        method Disconnect()
        method GetHandle()
        method GetErrorMessage()
        method Lock(par_cNamespaceAndTableName,par_iKey)
        method Unlock(par_cNamespaceAndTableName,par_iKey)
        
        method SQLExec(par_xEventId,par_cCommand,par_cCursorName)   //Used by the Locking system
        method GetSQLExecErrorMessage()  inline ::p_SQLExecErrorMessage
        method GetConnectionNumber()     inline ::p_ConnectionNumber
        method GetCurrentNamespaceName() inline ::p_NamespaceName
        method LoadMetadata(par_cSource)  //Called on successful Connect(). Should be called if the Schema changed since the last Connect()
                                        //Will load the definition of all tables in all namespaces (PostgreSQL)

        // The following are Namespace Aware. If no NamespaceName is defined for any tables, the current namespace will be used.
        method GenerateMigrateSchemaScript(par_hWharfConfig)  // Will never drop tables, field and indexes. Call DeleteTable() DeleteIndex() DeleteField() methods as needed.
        method MigrateSchema(par_hWharfConfig)                // Will Call GenerateMigrateSchemaScript() and UpdateSchemaCache() and UpdateORMNamespaceTableNumber()

        method EnableSchemaChangeTracking()   // Currently only PostgreSQL aware
        method DisableSchemaChangeTracking()  // Currently only PostgreSQL aware
        method RemoveSchemaChangeTracking()   // Currently only PostgreSQL aware

        method UpdateSchemaCache(par_lForce) // To help with speed problems especially in PostgreSQL

        method CheckIfStillConnected() // Returns .t. if connected. Will test if the connection is still present

        method CheckIfSchemaCacheShouldBeUpdated()   // Return .t. if schema had changed since connected. Currently only PostgreSQL aware

        //Set any of the following properties BEFORE calling Connect() method
        data PostgreSQLIdentifierCasing                 init 1
                                                                        // HB_ORM_POSTGRESQL_CASE_INSENSITIVE = 0 = Case Insensitive (displayed as lower case) except reserved words always lower case, 
                                                                        // HB_ORM_POSTGRESQL_CASE_SENSITIVE   = 1 = Case Sensitive (always delimited)
                                                                        // HB_ORM_POSTGRESQL_CASE_ALL_LOWER   = 2 = Convert all to lower case
        data MySQLEngineConvertIdentifierToLowerCase    init .t.

        method IsReservedWord(par_cIdentifier)
        method FormatIdentifier(par_cName)
        method FormatValue(par_cValue)

        method NormalizeTableNameInternal(par_cNamespaceAndTableName)                                      // Will clean up and adjust the table name based on Engine Type and to be used against ::p_hMetadataTable
        method NormalizeTableNamePhysical(par_cNamespaceAndTableName)                                      // Will clean up and adjust the table name based on Engine Type and to be used against Physical Backend
        method CaseTableName(par_cNamespaceAndTableName)                                                   // Gets the schema and table name properly cased or return empty if not found in dictionary
        method CaseFieldName(par_cNamespaceAndTableName,par_cFieldName)                                    // Get the field name properly cased or return empty if not found in dictionary
        method GetFieldInfo(par_cNamespaceAndTableName,par_cFieldName)                                     // Returns Hash Array
        
        method FixCasingInFieldExpression(par_hFields,par_cExpression)

        method DeleteTable(par_cNamespaceAndTableName)
        method DeleteIndex(par_cNamespaceAndTableName,par_cIndexName)                                      // will only delete indexes created / managed by the orm. Restricted by index on file naming convention.
        method DeleteField(par_cNamespaceAndTableName,par_xFieldNames)                                     // par_xFieldNames can be an array of field names or a single field name

        method TableExists(par_cNamespaceAndTableName)                                                     // Tests if the table exists
        method FieldExists(par_cNamespaceAndTableName,par_cFieldName)                                      // Tests if the table.field exists.

        method UpdateORMSupportSchema()                                                                    //Create / Update Tables used by the ORM
        method UpdateORMNamespaceTableNumber()                                                             //Update ORM Table NamespaceTableNumber by adding all tables names in the dictionary/catalog

        method GetSchemaDefinitionVersion(par_cSchemaDefinitionName)                                    // Since calling ::MigrateSchema() is cumulative with different hTableSchemaDefinition, each can be named and have a different version.
        method SetSchemaDefinitionVersion(par_cSchemaDefinitionName,par_iVersion)                       // Since calling ::MigrateSchema() is cumulative with different hTableSchemaDefinition, each can be named and have a different version.

        method RecordCurrentAppliedWharfConfig()              // Under Development.
        method GetWharfConfigAppliedStatus()                  // Will use the WharfConfig of the connection.
                //0  Current Database matches 
                //1  No information on File, meaning we should run the UpdateSchema and stamp it
                //2  Not up-to-date
                //3  Future Schema, meaning running an old app.

        method LogAutoTrimEvent(par_xEventId,par_cNamespaceAndTableName,par_nKey,par_aAutoTrimmedFields)
        method LogErrorEvent(par_xEventId,par_aErrors)                                                  // The par_aErrors is an array of arrays like {<cNamespaceAndTableName>,<nKey>,<cErrorMessage>,<cAppStack>}

        method NormalizeFieldDefaultForCurrentEngineType(par_cFieldDefault,par_cFieldType,par_nFieldDec)
        method SanitizeFieldDefaultFromDefaultBehavior(par_cSQLEngineType,par_cFieldType,par_lFieldNullable,par_cFieldDefault)
        
        method GetUUIDString()                                                                          //Will return a UUID string

        method SetHarbourORMNamespace(par_cName)
        method GetHarbourORMNamespace() inline ::p_HBORMNamespace

        method SetForeignKeyNullAndZeroParity(par_lMode)                                   // If should make Zero values stored as Null when used for Foreign Keys
        method GetForeignKeyNullAndZeroParity() inline ::p_ForeignKeyNullAndZeroParity
        method LoadWharfConfiguration(par_hConfig)                                         // Register a DataWharf Configuration
        method GetColumnConfiguration(par_cNamespaceAndTableName,par_cFieldName)           // Get Column Configuration
        method GetColumnsConfiguration(par_cNamespaceAndTableName)                         // Returns an array of column names

        method DeleteAllOrphanRecords(par_hTableSchemaDefinition)                          // Destructive delete of any orphans in all the tables in par_hTableSchemaDefinition
        method RemoveWharfForeignKeyConstraints(par_hTableSchemaDefinition)                // Remove any Foreign Key Constraint that and with "_fkc"
        method GenerateMigrateForeignKeyConstraintsScript(par_hTableSchemaDefinition)             // Generate the Script to Add/Update if missing any Foreign Key Constraint that and with "_fkc"
        method MigrateForeignKeyConstraints(par_hTableSchemaDefinition)                           // Add/Update if missing any Foreign Key Constraint that and with "_fkc"
        method ForeignKeyConvertAllZeroToNull(par_hTableSchemaDefinition)                  // Find and replace any Zero in Integer type foreign key columns. Used to prepare data to handle foreign key constraints.

    DESTRUCTOR destroy()
        
endclass


#endif   /* DEFINED_HB_ORM_SQLCONNECT_CLASS */
