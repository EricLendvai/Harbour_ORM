#include "hbclass.ch"

#ifndef DEFINED_HB_ORM_SQLCONNECT_CLASS
#define DEFINED_HB_ORM_SQLCONNECT_CLASS

class hb_orm_SQLConnect
    hidden:
        classdata ConnectionCounter       init 0    // Across all instances of this class. Used to ensure all the ::p_ConnectionNumber are unique across all instances in current running program.
        data p_ConnectionNumber           init 0    // Unique number across all instances in current running program. Can be used to help generate some names.
        data p_SQLConnection              init 0    // ODBC layer connection number
        data p_BackendType                init 0
        data p_SQLEngineType              init 0
        data p_Driver                     init ""
        data p_Server                     init "localhost"
        data p_Port                       init 0
        data p_User                       init ""
        data p_Password                   init ""
        data p_Database                   init ""
        data p_SchemaName                 init "public"     // Refers to the current Schema Namespace  (In MSSQL this would be "dbo")
        data p_PKFN                       init "key"        // Primary Key Field Name
        data p_ErrorMessage               init ""
        data p_Locks                      init {}
        data p_LockTimeout                init 20   //In Seconds
        data p_SQLExecErrorMessage        init ""
        data p_DoNotReportErrors          init .f.
        
        classdata MaxDigitsInTableNumber  init  5  // Needed for the lock/unlock methods. With 5 digits we should have less than 99999 tables.
        classdata ReservedWordsMySQL      init {"ACCESSIBLE","ADD","ALL","ALTER","ANALYZE","AND","AS","ASC","ASENSITIVE","BEFORE","BETWEEN","BIGINT","BINARY","BLOB","BOTH","BY","CALL","CASCADE","CASE","CHANGE","CHAR","CHARACTER","CHECK","COLLATE","COLUMN","CONDITION","CONSTRAINT","CONTINUE","CONVERT","CREATE","CROSS","CUBE","CUME_DIST","CURRENT_DATE","CURRENT_TIME","CURRENT_TIMESTAMP","CURRENT_USER","CURSOR","DATABASE","DATABASES","DAY_HOUR","DAY_MICROSECOND","DAY_MINUTE","DAY_SECOND","DEC","DECIMAL","DECLARE","DEFAULT","DELAYED","DELETE","DENSE_RANK","DESC","DESCRIBE","DETERMINISTIC","DISTINCT","DISTINCTROW","DIV","DOUBLE","DROP","DUAL","EACH","ELSE","ELSEIF","EMPTY","ENCLOSED","ESCAPED","EXCEPT","EXISTS","EXIT","EXPLAIN","FALSE","FETCH","FIRST_VALUE","FLOAT","FLOAT4","FLOAT8","FOR","FORCE","FOREIGN","FROM","FULLTEXT","FUNCTION","GENERATED","GET","GRANT","GROUP","GROUPING","GROUPS","HAVING","HIGH_PRIORITY","HOUR_MICROSECOND","HOUR_MINUTE","HOUR_SECOND","IF","IGNORE","IN","INDEX","INFILE","INNER","INOUT","INSENSITIVE","INSERT","INT","INT1","INT2","INT3","INT4","INT8","INTEGER","INTERVAL","INTO","IO_AFTER_GTIDS","IO_BEFORE_GTIDS","IS","ITERATE","JOIN","JSON_TABLE","KEY","KEYS","KILL","LAG","LAST_VALUE","LATERAL","LEAD","LEADING","LEAVE","LEFT","LIKE","LIMIT","LINEAR","LINES","LOAD","LOCALTIME","LOCALTIMESTAMP","LOCK","LONG","LONGBLOB","LONGTEXT","LOOP","LOW_PRIORITY","MASTER_BIND","MASTER_SSL_VERIFY_SERVER_CERT","MATCH","MAXVALUE","MEDIUMBLOB","MEDIUMINT","MEDIUMTEXT","MIDDLEINT","MINUTE_MICROSECOND","MINUTE_SECOND","MOD","MODIFIES","NATURAL","NOT","NO_WRITE_TO_BINLOG","NTH_VALUE","NTILE","NULL","NUMERIC","OF","ON","OPTIMIZE","OPTIMIZER_COSTS","OPTION","OPTIONALLY","OR","ORDER","OUT","OUTER","OUTFILE","OVER","PARTITION","PERCENT_RANK","PRECISION","PRIMARY","PROCEDURE","PURGE","RANGE","RANK","READ","READS","READ_WRITE","REAL","RECURSIVE","REFERENCES","REGEXP","RELEASE","RENAME","REPEAT","REPLACE","REQUIRE","RESIGNAL","RESTRICT","RETURN","REVOKE","RIGHT","RLIKE","ROW","ROWS","ROW_NUMBER","SCHEMA","SCHEMAS","SECOND_MICROSECOND","SELECT","SENSITIVE","SEPARATOR","SET","SHOW","SIGNAL","SMALLINT","SPATIAL","SPECIFIC","SQL","SQLEXCEPTION","SQLSTATE","SQLWARNING","SQL_BIG_RESULT","SQL_CALC_FOUND_ROWS","SQL_SMALL_RESULT","SSL","STARTING","STORED","STRAIGHT_JOIN","SYSTEM","TABLE","TERMINATED","THEN","TINYBLOB","TINYINT","TINYTEXT","TO","TRAILING","TRIGGER","TRUE","UNDO","UNION","UNIQUE","UNLOCK","UNSIGNED","UPDATE","USAGE","USE","USING","UTC_DATE","UTC_TIME","UTC_TIMESTAMP","VALUES","VARBINARY","VARCHAR","VARCHARACTER","VARYING","VIRTUAL","WHEN","WHERE","WHILE","WINDOW","WITH","WRITE","XOR","YEAR_MONTH","ZEROFILL"}
        classdata ReservedWordsPostgreSQL init {"ALL","ANALYSE","ANALYZE","AND","ANY","ARRAY","AS","ASC","ASYMMETRIC","BINARY","BOTH","CASE","CAST","CHECK","COLLATE","COLLATION","COLUMN","CONCURRENTLY","CONSTRAINT","CREATE","CROSS","CURRENT_CATALOG","CURRENT_DATE","CURRENT_ROLE","CURRENT_SCHEMA","CURRENT_TIME","CURRENT_TIMESTAMP","CURRENT_USER","DEFAULT","DEFERRABLE","DESC","DISTINCT","DO","ELSE","END","EXCEPT","FALSE","FETCH","FOR","FOREIGN","FREEZE","FROM","FULL","GRANT","GROUP","HAVING","ILIKE","IN","INITIALLY","INNER","INTERSECT","INTO","IS","ISNULL","JOIN","LATERAL","LEADING","LEFT","LIKE","LIMIT","LOCALTIME","LOCALTIMESTAMP","NATURAL","NOT","NOTNULL","NULL","OFFSET","ON","ONLY","OR","ORDER","OUTER","OVERLAPS","PLACING","PRIMARY","REFERENCES","RETURNING","RIGHT","SELECT","SESSION_USER","SIMILAR","SOME","SYMMETRIC","TABLE","TABLESAMPLE","THEN","TO","TRAILING","TRUE","UNION","UNIQUE","USER","USING","VARIADIC","VERBOSE","WHEN","WHERE","WINDOW","WITH"}

        method AddTable(par_cSchemaName,par_cTableName,par_hStructure)
        method AddField(par_cSchemaName,par_cTableName,par_cFieldName,par_aFieldDefinition)
        method AddIndex(par_cSchemaName,par_cTableName,par_hFields,par_cIndexName,par_aIndexDefinition)
        method UpdateField(par_cSchemaName,par_cTableName,par_cFieldName,par_aFieldDefinition,par_aCurrentFieldDefinition)

    exported:
        data p_Schema  init {=>}                                         //List of Tables Names. Each element is a 2 cell array ["Hash of Field Definition","Hash of Index Definitions"]. Named it with a leading "p_" to be threaded as internal.
        data Connected init .f.                                          //true if connected to a server
        method SetBackendType(par_cName)                                 // For Example, "MariaDB","MySQL","PostgreSQL"
        method GetSQLEngineType()     inline ::p_SQLEngineType           // 1 for"MariaDB" and "MySQL", 2 for "PostgreSQL"
        method SetDriver(par_cName)
        method SetServer(par_cName)
        method SetPort(par_number)
        method SetUser(par_cName)
        method SetPassword(par_password)
        method SetDatabase(par_cName)
        method SetCurrentSchemaName(par_cName)             //only used for PostgreSQL     Return the name of the schema before being set
        method GetPrimaryKeyFieldName() inline ::p_PKFN
        method SetPrimaryKeyFieldName(par_cName)
        method SetAllSettings(par_BackendType,par_Driver,par_Server,par_Port,par_User,par_Password,par_Database,par_Schema,par_PKFN)
        method Connect()
        method Disconnect()
        method GetHandle()
        method GetErrorMessage()
        method Lock(par_cSchemaAndTableName,par_Key)
        method Unlock(par_cSchemaAndTableName,par_Key)
        
        method SQLExec(par_Command,par_cCursorName)   //Used by the Locking system
        method GetSQLExecErrorMessage() inline ::p_SQLExecErrorMessage
        method GetConnectionNumber()    inline ::p_ConnectionNumber
        method GetDatabase()            inline ::p_Database
        method GetCurrentSchemaName()   inline iif(::p_SQLEngineType == HB_ORM_ENGINETYPE_POSTGRESQL,::p_SchemaName,"")
        method LoadSchema()             //Called on successful Connect(). Should be called if the Schema changed since the last Connect()
                                        //Will load the definition of all tables in all schema namespaces (PostgreSQL)

        // The following are Schema Namespace Aware. If no SchemaName is defined for any tables, the current schema name will be used.
        method GenerateMigrateSchemaScript(par_hSchemaDefinition)  // Will never drop tables, field and indexes. Call DeleteTable() DeleteIndex() DeleteField() methods as needed.
        method MigrateSchema(par_hSchemaDefinition)                // Will Call GenerateMigrateSchemaScript() and UpdateSchemaCache() and UpdateORMSchemaTableNumber()
        method GenerateCurrentSchemaHarbourCode(par_cFileName)     // For All Schema Namespaces

        method EnableSchemaChangeTracking()   // Currently only PostgreSQL ready
        method DisableSchemaChangeTracking()  // Currently only PostgreSQL ready
        method RemoveSchemaChangeTracking()   // Currently only PostgreSQL ready

        method UpdateSchemaCache(par_Force) // To help with speed problems especially in PostgreSQL

        //Set any of the following properties BEFORE calling Connect() method
        data PostgreSQLIdentifierCasing                 init 1
                                                                        // HB_ORM_POSTGRESQL_CASE_INSENSITIVE = 0 = Case Insensitive (displayed as lower case) except reserved words always lower case, 
                                                                        // HB_ORM_POSTGRESQL_CASE_SENSITIVE   = 1 = Case Sensitive (always delimited)
                                                                        // HB_ORM_POSTGRESQL_CASE_ALL_LOWER   = 2 = Convert all to lower case
        data PostgreSQLHBORMSchemaName init "hborm"    // The name of the postgresql schema (in a database), that will hold the log, cache files and trigger to speed up schema structure queries, and other hb_orm managed tables
        data MySQLEngineConvertIdentifierToLowerCase    init .t.

        method IsReservedWord(par_cIdentifier)
        method FormatIdentifier(par_cName)

        method CaseTableName(par_cSchemaAndTableName)                                                                                                              // Format the tokens as handled by the SQL Server
        method CaseFieldName(par_cSchemaAndTableName,par_cFieldName)                                                                                               // Format the tokens as handled by the SQL Server
        
        method FixCasingInFieldExpression(par_hFields,par_expression)

        method DeleteTable(par_cSchemaAndTableName)
        method DeleteIndex(par_cSchemaAndTableName,par_cIndexName)          // will only delete indexes created / managed by the orm. Restricted by index on file naming convention.
        method DeleteField(par_cSchemaAndTableName,par_xFieldNames)         // par_xFieldNames can be an array of field names or a single field name

        method TableExists(par_cSchemaAndTableName)         // Tests if the table exists

        method UpdateORMSupportSchema()                            //Create / Update Tables used by the ORM
        method UpdateORMSchemaTableNumber()                        //Update ORM Table SchemaTableNumber by adding all tables names in the dictionary/catalog

        method GetSchemaDefinitionVersion(par_cSchemaDefinitionName)                         // Since calling ::MigrateSchema() is cumulative with different hSchemaDefinition, each can be named and have a different version.
        method SetSchemaDefinitionVersion(par_cSchemaDefinitionName,par_iVersion)                         // Since calling ::MigrateSchema() is cumulative with different hSchemaDefinition, each can be named and have a different version.

        method LogAutoTrimEvent(par_cEventId,par_cSchemaAndTableName,par_nKey,par_aAutoTrimmedFields)
        method LogErrorEvent(par_cEventId,par_cAppStack,par_aErrors)

    DESTRUCTOR destroy()
        
endclass


#endif   /* DEFINED_HB_ORM_SQLCONNECT_CLASS */
