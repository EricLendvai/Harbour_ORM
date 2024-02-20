#include "hbclass.ch"

#ifndef DEFINED_HB_ORM_SQLDATA_CLASS
#define DEFINED_HB_ORM_SQLDATA_CLASS

class hb_orm_SQLData
    hidden:
        data p_oSQLConnection                init NIL
        data p_BackendType                   init 0
        data p_SQLEngineType                 init 0
        data p_SQLConnection                 init -1    // ODBC layer connection number
        data p_ConnectionNumber              init 0     // Unique number across all instances in current running program. Can be used to help generate some names.
        data p_Database                      init ""
        data p_NamespaceName                 init ""
        data p_PrimaryKeyFieldName           init "key"        // Primary Key Field Name
        data p_CreationTimeFieldName         init "sysc"       // Creation Time Field Name
        data p_ModificationTimeFieldName     init "sysm"       // Modification Time Field Name

        data p_NamespaceAndTableName         init ""
        data p_cEventId                      init ""
        data p_TableAlias                    init ""

        data p_Key                           init 0
        data p_ErrorMessage                  init ""

        data p_AliasToNamespaceAndTableNames init {=>}  //Used by method FixAliasAndFieldNameCasingInExpression() to fix casing of field names

        data p_FieldsAndValues               init {=>}   // p_FieldsAndValues[FieldName] := {nType,xFieldValue}    where nType 1 = Regular Value, 2 = Server Side Expression, 3 = Array

        data p_ColumnToReturn                init {}
               // 1 - ""   Expression
               // 2 - ""   Alias

        data p_Join                          init {}
               // 1 - 0    Type (1=inner,2=left outer join)
               // 2 - ""   NamespaceAndTable Name
               // 3 - ""   Tables Alias
               // 4 - ""   Expression

        data p_Where                         init {}
               // 1 - ""   Expression

        data p_GroupBy                       init {}
               // 1 - ""   Expression

        data p_Having                        init {}
               // 1 - ""   Expression

        data p_OrderBy                       init {}
               // 1 - ""    Column Name
               // 2 - .t.   .t. = Ascending  .f. = Descending
               // 3 - .f.   Use for PostgreSQL "distinct on ()"

        data p_TableFullPath   init ""
        data p_CursorName      init ""
        data p_CursorUpdatable init .f.

        data p_LastSQLCommand        init ""
        data p_LastRunTime           init 0

        data p_LastUpdateChangeddata         init .f.
        data p_LastDateTimeOfChangeFieldName init ""
        data p_AddLeadingBlankRecord         init .f.
        data p_AddLeadingRecordsCursorName   init ""

        data p_DistinctMode init 0            // 0 = Distinct of, 1 = Distinct on (classic), 2 = DistinctOn (postgresql)
        data p_Limit        init 0

        // data p_Mode init 0   // 0 = No MYSQL, 1 = Try to Use MySQL

        data p_NumberOfFetchedFields  init 0          // Used on Select *
        data p_FetchedFieldsNames     init {}        // Used on Select *
               // 1 - ""   Used on Select *

        data p_MaxTimeForSlowWarning init 2.000  // number of seconds  _M_

        data p_ExplainMode init 0     // 0 = Explain off, 1 = Explain with no run, 2 = Explain with run

        data p_NonTableAliases init {=>}       //List of CTE and Temp Alias to exclude from table/column auto format and validate

        method IsConnected()                                                       //Return .t. if has a connection
        method PrepExpression(par_cExpression,...)                                 //Used to "Freeze" parameters as values in "^" places
        method ExpressionToMYSQL(par_cSource,par_cExpression)                      //_M_  to generalize UDF translation to backend
        method ExpressionToPostgreSQL(par_cSource,par_cExpression)                 //_M_  to generalize UDF translation to backend
        method FixAliasAndFieldNameCasingInExpression(par_cSourcepar_cExpression)  // to handle the casing of tables and fields, by using the connection's :p_TableSchema Since it is more of alias.field for now will assume alias same as table name and will use ::p_NamespaceName
        method PrepValueForMySQL(par_cAction,par_xValue,par_cTableName,par_nKey,par_cFieldName,par_hFieldInfo,l_aAutoTrimmedFields,l_aErrors)
        method PrepValueForPostgreSQL(par_cAction,par_xValue,par_cTableName,par_nKey,par_cFieldName,par_hFieldInfo,l_aAutoTrimmedFields,l_aErrors)
        method SetEventId(par_xId)                                              // Called by Table() and Delete(). Used to identify SQL(), Add(), Update(), Delete() query and updates in logs, including error logs. par_xId may be a number of string. Numbers will be converted to string. Id must be max HB_ORM_MAX_EVENTID_SIZE character long.
        method FieldSet(par_cName,par_nType,par_xValue)                         // Called by all other Field* methods. par_nType 1 = Regular Value, 2 = Server Side Expression, 3 = Array
        method GetPostgreSQLCastForFieldType(par_cFieldType,par_nFieldLen,par_nFieldDec)   // Used by :Add() and :Update()
    exported:
        data Tally init 0 READONLY
        data p_oCursor                //In case :SQL("<CursorName>") was called, meaning a hb_orm_cursor was created. Named with leading "p_" since used internally.

        method Init()          constructor  //Harbour does not call the constructor by default (BIG design mistake)
        method UseConnection(par_oSQLConnection)
        method Echo(par_cText)
        method Table(par_xEventId,par_cNamespaceAndTableName,par_cAlias)     // par_EventId can be a numeric or string. Will help in case of errors and should be unique across an application. par_cAlias is optional
        method Distinct(par_lMode)
        method Limit(par_Limit)
        method Key(par_iKey)                                              //Set the key or retrieve the last used key


        // For all the following Field* method the par_cName will be processed by ignoring any text before the rightmost ".". This allow to include a schema.table name that can assist when searching the source code.
        //Following should be deprecated and one of the other 3 method Field* should be used
        method Field(par_cName,par_xValue)                                //To set a field (par_cName) in the Table() to the value (par_xValue). If par_xValue is not provided, will return the value from previous set field value. If par_xValue is an array, the first element tell how to handle the following one. It {"S",<string>} will be handled 

        method FieldValue(par_cName,par_xValue)                           //To set a field (par_cName) in the Table() to the a value (non array). The value will be formatted for the engine type.
        method FieldExpression(par_cName,par_cValue)                      //To set a field (par_cName) in the Table() to an expression to be passed to the server. For example "now()"
        method FieldArray(par_cName,par_xValue)                           //Only for PostgreSQL. To set a field (par_cName) in the Table() to the an array of values


        method ErrorMessage()                                             //Retrieve the error text of the last call to :SQL(), :Get(), :Count(), :Add(), :Update(), :Delete()
        // method GetFormattedErrorMessage()                              //Retrieve the error text of the last call to :SQL(), :Get(), :Count(), :Add(), :Update(), :Delete() in an HTML formatted Fasion  (ELS)
        method Add(par_iKey)                                              //Adds a record. par_iKey is optional and can only be used with table with non auto-increment key field
        method Delete(par_xEventId,par_cNamespaceAndTableName,par_iKey)   //Delete record. Should be called as .Delete(uuid,TableName,Key).
        method Update(par_iKey)                                           //Update a record in .Table(TableName)  where .Field(...) was called first
        
        method Column(par_cExpression,par_cColumnsAlias,...)              //Used with the .SQL() or .Get() to specify the fields/expressions to retrieve

        method Join(par_cType,par_cNamespaceAndTableName,par_cAlias,par_cExpression,...)                         // Join Tables
        method ReplaceJoin(par_nJoinNumber,par_cType,par_cNamespaceAndTableName,par_cAlias,par_cExpression,...)  // Replace a Join tables definition

        method Where(par_cExpression,...)                                                              // Adds Where condition. Will return a handle that can be used later by ReplaceWhere()
        method ReplaceWhere(par_nWhereNumber,par_cExpression,...)                                      // Replace a Where definition

        method Having(par_cExpression,...)                                                             // Adds Having condition. Will return a handle that can be used later by ReplaceHaving()
        method ReplaceHaving(par_nHavingNumber,par_cExpression,...)                                    // Replace a Having definition

        method KeywordCondition(par_cKeywords,par_cFieldToSearchFor,par_cOperand,par_lAsHaving)        // Creates Where or Having conditions as multi text search in fields.
        
        method GroupBy(par_cExpression)                                                                // Add a Group By definition
        method OrderBy(par_cExpression,par_cDirection)                                                 // Add an Order By definition    par_cDirection = "A"scending or "D"escending
        method DistinctOn(par_cExpression,par_cDirection)                                              // PostgreSQL ONLY. Will use the "distinct on ()" feature and Add an Order By definition    par_cDirection = "A"scending or "D"escending

        method ResetOrderBy()                                                                          // Delete all OrderBy definitions
        method ReadWrite(par_lValue)                                                                   // Was used in VFP ORM, not the Harbour version, since the result cursors are always ReadWriteable

        method AddLeadingBlankRecord()                                                                 // If the result cursor should have a leading blank record, used mainly to create the concept of "not-selected" row
        method AddLeadingRecords(par_cCursorName)                                                      // Specify to add records from par_cCursorName as leading record to the future result cursor

        method SetExplainMode(par_nMode)                                                               // Used to get explain information. 0 = Explain off, 1 = Explain with no run, 2 = Explain with run
        method BuildSQL(par_cAction) //  par_cAction can be "Count" "Fetch"
        method SQL(par_1)                                                                              // Assemble and Run SQL command. par_1 can be a String (name of a in-memory table/cursor), reference to an array or reference to a hash array.
        method Count()                                                                                 // Similar to SQL() but will not get the list of Column() and return a numeric, the number or records found. Will return -1 in case of error.

        method GetLastEventId() INLINE ::p_cEventId                                                    // Will return the Last :Table() EventID. Useful to report where a problem occurred. 
        method LastSQL()        INLINE ::p_LastSQLCommand                                              // Get the last sent SQL command executed
        method LastRunTime()    INLINE ::p_LastRunTime                                                 // Get the last execution time in seconds

        method Get(par_iKey)                                                                           // Returns an Object with properties matching a record referred by primary key 
                                                                                                       // Either use (<par_cNamespaceAndTableName>,<par_iKey>)   or  (<par_iKey>))  as parameters

        method FormatDateForSQLUpdate(par_dDate)
        method FormatDateTimeForSQLUpdate(par_tDati,par_nPrecision)

        method SaveFile(par_xEventId,par_cNamespaceAndTableName,par_iKey,par_cOidFieldName,par_cFullPathFileName)   // Where par_cFieldName must be of type OID. Will store in PostgreSQL a file using Large Objects
                                                                                                                    // return true of false. If false call ::ErrorMessage() to get more information

        method GetFile(par_xEventId,par_cNamespaceAndTableName,par_iKey,par_cOidFieldName,par_cFullPathFileName)    // Will create a file at par_cFullPathFileName from the content previously saved
                                                                                                                    // return true of false. If false call ::ErrorMessage() to get more information

        method DeleteFile(par_xEventId,par_cNamespaceAndTableName,par_iKey,par_cOidFieldName)                       // To remove the file from the table and nullify par_cFieldName
                                                                                                                    // return true of false. If false call ::ErrorMessage() to get more information

        method AddNonTableAliases(par_aAliases)  // Used to add an alias to :p_NonTableAliases to prevent casing the aliases and columns.
        method ClearNonTableAliases()            // Used clear :p_NonTableAliases since calling :Table() will not do so, since its own source table might be a CTE alias.

    DESTRUCTOR destroy()

endclass

#endif   /* DEFINED_HB_ORM_SQLDATA_CLASS */
