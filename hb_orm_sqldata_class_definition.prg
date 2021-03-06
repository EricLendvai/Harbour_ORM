#include "hbclass.ch"

#ifndef DEFINED_HB_ORM_CLASS
#define DEFINED_HB_ORM_CLASS

class hb_orm_SQLData
    hidden:
        data p_o_SQLConnection       init NIL
        data p_SQLEngineType         init 0
        data p_SQLConnection         init -1
        data p_ConnectionNumber      init 0
        data p_Database              init ""
        data p_SchemaName            init ""

        data p_PKFN                  init "key"        //Primary Key Field Name


        data p_TableName             init ""
        data p_TableAlias            init ""

        data p_Key                   init 0
        data p_ErrorMessage          init ""

        data p_FieldsAndValues       init {=>}   //p_FieldsAndValues[FieldName] := FieldValue

        data p_FieldToReturn          init {}
               // 1 - ""   VFP Expression
               // 2 - ""   Alias

        data p_Join                   init {}
               // 1 - 0    Type (1=inner,2=left outer join)
               // 2 - ""   Table
               // 3 - ""   Tables Alias
               // 4 - ""   VFP expression

        data p_Where                  init {}
               // 1 - ""   VFP Expression

        data p_GroupBy                init {}
               // 1 - ""   VFP Expression

        data p_Having          init {}
               // 1 - ""   VFP Expression

        data p_OrderBy init {}
               // 1 - ""    Column Name
               // 2 - .t.   .t. = Ascending  .f. = Descending

        data p_TableFullPath   init ""
        data p_CursorName      init ""
        data p_CursorUpdatable init .f.

        data p_ArrayHandle init 0

        data p_LastSQLCommand        init ""
        data p_LastRunTime           init 0

        data p_LastUpdateChangeddata         init .f.
        data p_LastDateTimeOfChangeFieldName init ""
        data p_AddLeadingBlankRecord         init .f.
        data p_AddLeadingRecordsCursorName   init ""

        data p_Distinct init .f.
        data p_Force    init .f.
        data p_NoTrack  init .f.
        data p_Limit    init 0

        data p_Mode init 0   // 0 = No MYSQL, 1 = Try to Use MySQL

        data p_NumberOfFetchedFields init 0          // Used on Select *
        data p_FetchedFieldsNames     init {}        // Used on Select *
               // 1 - ""   Used on Select *

        data p_MaxTimeForSlowWarning init 2.000  // number of seconds  _M_

        data p_ReferenceForSQLDataStrings init NIL
        data p_NumberOfSQLDataStrings init 0
        data p_SQLDataStrings init {}
               // 1 - ""

        data p_TableStructureNumberOfFields init 0
        data p_TableStructure init {}
               // 1 - ""    Field Name
               // 2 - ""    Field Type
               // 3 - 0     Field Length
               // 4 - 0     Field Dec

        data p_ExplainMode init 0     // 0 = Explain off, 1 = Explain with no run, 2 = Explain with run

        method IsConnected()                                                //Return .t. if has a connection
        method PrepExpression(par_Expression,...)                           //Used to "Freeze" parameters as values in "^" places
        method ExpressionToMYSQL(par_Expression)                            //_M_  to generalize UDF translation to backend
        method ExpressionToPostgreSQL(par_Expression)                       //_M_  to generalize UDF translation to backend
        method FixTableAndFieldNameCasingInExpression(par_Expression)       // to handle the casing of tables and fields, by using the connection's :p_schema
        method BuildSQL()                                                   // Used to build the SQL commands to send to server
        method GetFieldDefinition(par_Mode,par_FieldSQLName,par_FieldType,par_FieldLen,par_FieldDec,par_FieldSQLAlNull,par_FieldSQLautoinc)  // Build SQL Field Creation/Modification text
        method CaseTable(par_TableName)                                                                                                              // Format the tokens as handled by the SQL Server
        method CaseField(par_TableName,par_FieldName)                                                                                                              // Format the tokens as handled by the SQL Server
        method DelimitToken(par_Text)                                                                                                     // Format the tokens as handled by the SQL Server with delimiters
    exported:
        data Tally init 0 READONLY
        data p_oCursor                //In case :SQL("<CursorName>") was called, meaning a hb_orm_cursor was created


        method Init()          constructor  //Harbour does not call the constructor by default (BIG design mistake)
        method SetPrimaryKeyFieldName(par_name)
        method UseConnection(par_oSQLConnection)
        method Echo(par_Text)
        method Table(par_Name,par_Alias)
        method UsedInUnion(par_o_dl)
        method Distinct(par_Mode)
        method Limit(par_Limit)
        method Force(par_Mode)                                  //Used for VFP ORM, to disabled rishmore optimizer
        method NoTrack()
        method Key(par_Key)                                     //Set the key or retreive the last used key
        method Field(par_Name,par_Value)                        //To set a field (par_name) in the Table() to the value (par_value). If par_Value is not provided, will return the value from previous set field value
        method ErrorMessage()                                   //Retreive the error text of the last call to .SQL() or .Get() 
        // method GetFormattedErrorMessage()                       //Retreive the error text of the last call to .SQL() or .Get()  in an HTML formatted Fasion  (ELS)
        method Add(par_Key)                                     //Adds a record. par_Key is optional and can only be used with table with non auto-increment key field
        method Delete(par_1,par_2)                              //Delete record. Should be called as .Delete(Key) or .Delete(TableName,Key). The first form require a previous call to .Table(TableName)
        method Update(par_Key)                                  //Update a record in .Table(TableName)  where .Field(...) was called first
        
        method Column(par_Expression,par_Columns_Alias,...)     //Used with the .SQL() or .Get() to specify the fields/expressions to retreive

        method Join(par_Type,par_Table,par_Table_Alias,par_expression,...)                           // Join Tables
        method ReplaceJoin(par_JoinNumber,par_Type,par_Table,par_Table_Alias,par_expression,...)     // Replace a Join tables definition

        method Where(par_Expression,...)                                                             // Adds Where condition. Will return a handle that can be used later by ReplaceWhere()
        method ReplaceWhere(par_WhereNumber,par_Expression,...)                                      // Replace a Where definition

        method Having(par_Expression,...)                                                             // Adds Having condition. Will return a handle that can be used later by ReplaceHaving()
        method ReplaceHaving(par_WhereNumber,par_Expression,...)                                      // Replace a Having definition

        method KeywordCondition(par_Keywords,par_FieldToSearchFor,par_Operand,par_AsHaving)           // Creates Where or Having conditions as multi text search in fields.
        
        method GroupBy(par_Expression)                                                                // Add a Group By definition
        method OrderBy(par_Expression,par_Direction)                                                  // Add an Order By definition    par_Direction = "A"scending or "D"escending

        method ResetOrderBy()                                                                         // Delete all OrderBy definitions
        method ReadWrite(par_value)                                                                   // Was used in VFP ORM, not the Harbour version, since the result cursors are always ReadWriteable

        method AddLeadingBlankRecord()                                                                // If the result cursor should have a leading blank record, used mainly to create the concept of "not-selected" row
        method AddLeadingRecords(par_CursorName)                                                      // Specify to add records from par_CursorName as leading record to the future result cursor

        method SetExplainMode(par_mode)                                                               // Used to get explain information. 0 = Explain off, 1 = Explain with no run, 2 = Explain with run
        method SQL(par_1,par_2)                                                                       // Assemble and Run SQL command

        method LastSQL()       INLINE ::p_LastSQLCommand                                              // Get the last sent SQL command executed
        method LastRunTime()   INLINE ::p_LastRunTime                                                 // Get the last execution time in seconds

        method Get(par_1,par_2)                                                                       // Returns an Object with properties matching a record referred by primary key

        method UpdateTableStructure(par_TableName,par_Structure,par_AlsoRemoveFields)                 // Fix if needed a single file structure
    
        method FormatDateForSQLUpdate(par_Date)
        method FormatDateTimeForSQLUpdate(par_Dati)

    DESTRUCTOR destroy

endclass

#endif   /* DEFINED_HB_ORM_CLASS */
