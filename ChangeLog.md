# Harbour ORM - Change Log

## 06/22/2025 V 4.17
* Support for creating cursors with timestamp (datetime) field types: "@".
* Fix on Schema Migration script generation on namespace renames.
* Speed optimization for Schema Delta tool.
* Fix of devcontainer settings.

## 12/08/2024 V 4.16
* Support for transactions, including "commit","rollback" and isolation levels via the following connection methods (currently only available for Postgres. All methods return True on success, otherwise False. ):
  * :BeginTransactionReadCommitted()
  * :BeginTransactionRepeatableRead()
  * :BeginTransactionSerializable()
  * :EndTransactionCommit()
  * :EndTransactionRollback()
* Updated VSCode setting file to handle new includes.

## 10/23/2024 V 4.15
* Work around false positive error on bulk updated.

## 08/09/2024 V 4.14
* Added Postgresql code generation for Interval data types (with no precision for now.). No support in CRUD and query methods yet.

## 08/06/2024 V 4.13
* Added support to connect to Oracle SQL Server
* Added support to Float field types.

## 06/26/2024 V 4.12
* Added definition of HB_ORM_INVALUEWITCH to allow to mark any parts of expressions as values, disabling the automatic casing of columns.
* Added "SchemaAndDataErrorMessage" in ORM namespace, to reduce the size of repeating errors.

## 06/26/2024 V 4.11
* Fix on Missing creation of table WharfConfig in ORM Namespace.

## 06/23/2024 V 4.10
* Fixed Inserting/Updating Binary and Variable Binary in PostgreSQL.
* Added "fk_user" column to the ORM error logs.
* New connection methods SetCurrentUserPk(<UserPk>), GetCurrentUserPk() and ClearCurrentUserPk(). A UserPk can be a Big Integer and will be used when SchemaAndDataErrorLog or SchemaAutoTrimLog records are added.
* New connection methods SetApplicationVersion(<Text>),ClearApplicationVersion(),GetApplicationVersion(). Will be used when SchemaAndDataErrorLog or SchemaAutoTrimLog records are added.
* New connection methods SetApplicationBuildInfo(<Text>),ClearApplicationBuildInfo(),GetApplicationBuildInfo(). Will be used when SchemaAndDataErrorLog or SchemaAutoTrimLog records are added.
* New connection methods SetTimeZoneName(<TimeZoneName>),ClearTimeZoneName(),GetTimeZoneName(). By default the time zone is "UTC". Any query via SQLData class that includes columns on non transformed (or expression) of "Date Time with time zone" type columns will be displayed in the TimeZone set by previously called SetTimeZoneName(..).
*New connection method GetLastCheckConnectionUTCTime(), PostgreSQL only, which returns the last time the CheckIfStillConnected() method was called. The return value is a string formatted as 'YYYY-MM-DD HH24:MI:SS.USTZH', which is the format returned for Timestamps with Time Zone casted as 'Text'.
* New connection method GetCurrentTimeInTimeZoneAsText(<cTimeZone>), PostgreSQL only.
* New sqldata method GetArrayForFieldValueOfTimestampWithTimeZoneAsText(<cDateTimeUTC>,<cTimeZone>). Will return an array to be used by the Field() method to store Postgresql timestamp values with high precision. Parameters is a text formatted as 'YYYY-MM-DD HH24:MI:SS.USTZH'

## 05/30/2024 V 4.9
* Enhanced connection method GetColumnConfiguration to also include Column AKA.
* New connection method GetTableConfiguration(par_cNamespaceAndTableName).
* Fix Add method in PostgreSQL to allow to specify a primary key for its optional parameter.
* Fix Add() method in PostgreSQL when setting a blob field with a all blank character string.
* Fix on redundant schema structure loading.

## 05/03/2024 V 4.8
* Discontinued the use of the methods SetPrimaryKeyFieldName() and GetPrimaryKeyFieldName().   
  The are no longer needed since we are now using WharfConfig, which does specify the primary key for every tables.
* Please note Example/SQL_CRUD is not fully compatible with MySQL. 
* Removed Connection Methods SetPrimaryKeyFieldName and GetPrimaryKeyFieldName
* Removed parameter par_cPKFN from connection method SetAllSettings(). For code readability, it is encouraged to not used SetAllSettings() and instead use individual method to set each settings.
* Fix on Migration Script generation, failed to detect new Enumeration Value for Native PostgreSQL Enumerations.

## 04/04/2024 V 4.7
* Foreign Key Constraint Generation will handled manually altered changes.
* Indexes and Foreign Key Names that are beyond PostgreSQL length limit will be replace using StaticUIDs from DataWharf. Must use WharfConfig structures from DataWharf 4.6+.

## 03/25/2024 V 4.6
* Add support for extended Datetime field types in cursors.
* New WharfConfig table in the ORM namespace. This will ensure that latest ORM/schema change is applied.

## 03/06/2024 V 4.5  BREAKING CHANGES
* The connection methods MigrateSchema and GenerateMigrateSchemaScript now will take a single parameter, the WharfConfig Hash structure generated by DataWharf.
* The connection constructor function hb_SQLConnect() may not have parameters anymore. After the object is create and before the Connect() method is called, the following setting methods should be called. (listed in the order of past parameters):
  * :SetBackendType(...)
  * :SetDriver(...)
  * :SetServer(...)
  * :SetPort(...)
  * :SetUser(...)
  * :SetPassword(...)
  * :SetDatabase(...)
  * :SetCurrentNamespaceName(...)
* Before calling Connect() method from a connection object, You must call :LoadWharfConfiguration(...) and either pass a WharfConfig Hash structure created using DataWharf or no parameters. If no WharfConfig hash was passed, No SQLData object can be created, meaning none of the following methods could be used: Add, Update, Delete, SQL, Count, Get.  The connection methods like schema migrations will be allowed.
* Support to rename Namespaces, Tables, Columns, Enumerations and EnumValues in PostgreSQL only for now!
* Changed the input parameter of the following methods to simply use the WharfConfig hash structure:
  * GenerateMigrateSchemaScript
  * MigrateSchema
* Renamed property "p_WharfConfig" to "p_hWharfConfig"
* Renamed method "LoadSchema" to "LoadMetadata"
* Renamed property "p_TableSchema" to "p_hMetadataTable"
* New properties p_hMetadataNamespace, p_hMetadataEnumeration

## 02/19/2024 V 4.4
* Switch from using Harbour_VFP to Harbour_EL dependency.

## 02/18/2024 V 4.3
* Minor fix to support some special characters in column names.

## 01/28/2024 V 4.2
* Added support to UsedAs in p_WharfConfig Column configurations.

## 01/28/2024 V 4.1
* Foreign key constraint names are now always lower case. This will make it easier when columns casing are changed.
* Fixed SQL_CRUD example to handle following new requirements:
  * You must call at least once the method LoadWharfConfiguration(<WharfConfig>). The ORM now requires definitions created by DataWharf.
  * You probably want to call the method SetForeignKeyNullAndZeroParity(.t.). This will convert any 0 use in foreign keys to nulls.
* Allowed to SetHarbourORMNamespace("nohborm"), meaning with to not create a Harbour_ORM working Postgres schema (Namespace). This will disable to use of a Harbour ORM Namespace used for structure cache and logs. Should only be used if the purpose is to only update structure and not really have CRUD actions. Used by DataWharf's "Deployment Tools" feature.
* Renamed several method by adding prefix GMSS (Generate Migrate Schema Script).
* During the schema migrations, previously created hb_orm indexes (suffix "_idx") no longer defined will be deleted. The self cleaning of indexes does not impact actual data, and therefore is safe to happen. During schema migration, namespaces, tables and columns are never deleted, only added or altered.
* New method GenerateMigrateForeignKeyConstraintsScript().
* Renamed method AddUpdateWharfForeignKeyConstraints() to MigrateForeignKeyConstraints()
* Discontinued the method GenerateCurrentSchemaHarbourCode() since Harbour Code should always be generated from DataWharf, since it has more field properties that are lost in a deployment. It also was missing Postgresql Enumeration definitions.


## 01/05/2024 V 4.0   IMPORTANT COMPATIBILITY NOTE
* Stop assigning values to "PostgreSQLHBORMSchemaName" and instead call the following two new methods: SetHarbourORMNamespace(par_cName) and GetHarbourORMNamespace(). This will now also apply to MySQL/MariaDB.
* Support for JSONB PostgreSQL field types.
* New connection methods SetApplicationName and GetApplicationName, used to inform the SQL Backend the application connecting. Implemented in Postgres and can be tested using "select * from pg_stat_activity where state is not null" query.
* Renamed method GetCurrentSchemaName to GetCurrentNamespaceName.
* Renamed method SetCurrentSchemaName to SetCurrentNamespaceName.
* Renamed method UpdateSchemaName to UpdateNamespaceName.
* Code refactor, every where "Schema Name" or similar was used, we now use "Namespace Name". We avoid using "Schema" as the PostgreSQL definition, but instead it is a namespace. In Postgres, schemas also provide a mechanism to secure access right to elements in that schema.
* Major code refactoring to ensure proper support of Namespaces in MySQL Engine (meaning MariaDB as well).
* In MySQL engine, the "public" name space will be dropped in the name of tables.
* In MySQL indexes are names by simply using the Index Name, while in Postgres to ensure non conflict the index name is a concatenation of <tablename>_<indexnname>_idx.
* Support to have Combined SQL (unions ...) as CTE elements.
* Renamed property p_Schema to p_TableSchema (For the current loaded table definitions.)
* New Methods in SQLConnect:
  * DeleteAllOrphanRecords(par_hTableSchemaDefinition) - Destructive delete of any orphans in all the tables in par_hTableSchemaDefinition
  * RemoveWharfForeignKeyConstraints(par_hTableSchemaDefinition) - Remove any Foreign Key Constraint that and with "_fkc"
  * AddUpdateWharfForeignKeyConstraints(par_hTableSchemaDefinition) - Add/Update if missing any Foreign Key Constraint that and with "_fkc"
  * ForeignKeyConvertAllZeroToNull(par_hTableSchemaDefinition) - Find and replace any Zero in Integer type foreign key columns. Used to prepare data to handle foreign key constraints.

## 11/12/2023 V 3.14   IMPORTANT COMPATIBILITY NOTE
* The SQLExec method now requires the first parameter to be an EventId (Spring or Numeric). Highly recommend use uuid to generate a string!   
* The Delete method will not affect any previous call to Table method, meaning you can safely call :Delete(...) from within a scan/endscan without loosing cursor being traversed.   
    The following properties are still being affected: p_ErrorMessage,Tally.   
* New Function "hb_ORM_UsedWorkAreas()" to return a hash array listing all open work areas with the recno() and reccount().   
* Change is structure of p_TableSchema connection property. Each Table has now a hash array instead of a 2 dimension array. {HB_ORM_SCHEMA_FIELD=>  ,HB_ORM_SCHEMA_INDEX=>  }   
* Added support for PostgreSQL UNLOGGED table setting.   

## 11/05/2023 V 3.13
* In PostgreSQL, stopped adding the Namespace in index name. Since the restriction for index names is "Two indexes in the same schema cannot have the same name", across schema (Namespaces) they can be the same. This will make it easier to move table to other schemas, and help reduce the change of hitting the 63 character object name length.
* Fix minor bug on field definition compare on default values. Reduces the number of migration code being generated.

## 09/24/2023 V 3.12
* Update hb_orm to allow to search on "_" characters in method KeywordCondition(), instead of being a wildcard character.

## 09/09/2023 V 3.11
* Fix casing issue during linux build.

## 08/25/2023 V 3.10
* Fix issue when changing the case of NameSpaces (Postgres Schema), Tables and Columns names. This fix will make it easy to change the case of names, while still keeping the ORM to be case-insensitive. This will handle PostgreSQL on Windows and Linux, and MySQL/MariaDB on Linux (since always lower case on Windows).   
* On MySQL/MariaDB if the Namespace is "public", it will not be included in the file name. For example: "public.Clients" will be a "Clients" table in the "public" schema in PostgreSQL, while simply being "Clients" in MariaDB/MySQL (or "clients" if conversion to lower case occurs).   

## 08/20/2023 V 3.9
* Initial Support for CTE and Combined Selects via the use of a new class "hb_orm_SQLCompoundQuery" and hb_SQLCompoundQuery() constructor function. See SQL_CRUD.prg for sample use. 
Currently only 2 selects can be combined at one time and Count() method is not supported yet (Not the the SQL count(*) function.).   
* New methods AddNonTableAliases(par_aAliases) and ClearNonTableAliases() in hb_orm_SQLData class to register CTE aliases.   
* CTE Alias names are case sensitive.   
* For CTE explanations: https://www.postgresql.org/docs/current/queries-with.html   
* For Combined SQL unions: https://www.postgresql.org/docs/current/queries-union.html   

## 05/08/2023 v 3.8
* Fix connecting to Postgresql if password includes the "%" character.

## 04/08/2023 v 3.7
* Changed Dockerfiles of devcontainers to work around git install failure introduced around April 2023.

## 02/15/2023 v 3.7
* Simplified distribution of library by generating hb_orm.hbc file.

## 02/10/2023 v 3.6
* Fixed make files in examples, to handle updated Harbour_EL.

## 01/29/2023 v 3.5
* Additional parameter in function hb_orm_PostgresqlEncodeUTF8String, allowing to add extra ascii characters to be escaped.
* Support to OID (Object ID in PostgreSQL natively, in MySQL as a BIGINT). This was needed to provide support to Large Objects in PostgreSQL, allowing to store up to 4TB in a single column/record (Max 32TB total in a "database").
* New hb_orm_SQLData class methods: SaveFile, GetFile, DeleteFile. This enables storing of up to 4TB files inside PostgreSQL database.

## 01/24/2023 v 3.4
* New data type "IS" for Small Integer.

## 01/23/2023 v 3.3
* Beautify the output of LastSQL() when calling SQL() or Get() methods. Added CR+LF and blank spaces to align SQL() generated code.
* If a value is used with hb_orm_SendToDebugView function, any carriage return or line feed is converted to the text <br>.
* New GetLastEventId() method to return the ID used by the last Table() method. For example use hb_orm_SendToDebugView(:GetLastEventId(),:LastSQL()) to output to DebugView (Or Syslog on Linux) the SQL statement last created and used by the ORM. In Windows, we can use NotePad++ to convert "<br>" to actually line feed (\n).

## 01/08/2023 v 3.2
* Renamed function hb_orm_PostgresqlEncodeUTFString to hb_orm_PostgresqlEncodeUTF8String
* New Harbour function hb_UTF8FastPeek. Make Big-O performance of O(n) instead of O(n^2) made by hb_UTF8Peek. For example of how to use it, see function hb_orm_PostgresqlEncodeUTFString.

## 01/04/2023 v 3.1
* Modified examples for using a common BuildTools folder to compile applications

## 01/03/2023 v 3.1
* Code refactor on local variable names
* Simplified build of debug mode
* Multiple fixes in :SQL() method
* Support for UUID and JSON field types
* Multiple fixes in PostgreSQL structure caching and connection speed increase
* PostgreSQL native support for array column types
* Support to set default values
* Updated devcontainer to use ubuntu:22.04

## 07/17/2022 v 2.1
* Fix on Binary Fixed and Variable length in PostgreSQL. Using the comment field of columns.
* New p_hb_orm_version property of connection object

## 07/04/2022
* Enhancements for UTF8 support

## 06/13/2022
* Enhanced ExportTableToHtmlFile function to format dates in yyyy-mm-dd format

## 06/12/2022
* Fixed methods GetFieldValue,SetFieldValue and CreateIndexes to not rely on current area, but the one created by the orm. This also fixes the method InsertRecord.
* New method DistinctOn() for PostgreSQL support of "distinct on ()" SQL syntax.

## 06/07/2022
* Fix on orm schema in PostgreSQL is set not to be case sensitive.

## 03/22/2022
* Fixed issue for PostgreSQL loadschema to ignore non actual tables, meaning exclude views.

## 03/13/2022
* Schema Updates can switch an Integer/Big Integer/Numeric from accepting NULL to Not NULL with 0 default. All existing NULL values will be converted to 0.
