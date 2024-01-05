//https://www.postgresqltutorial.com/postgresql-tutorial/postgresql-union/

#include "hbclass.ch"

#ifndef DEFINED_HB_ORM_SQLCOMPOUNDQUERY_CLASS
#define DEFINED_HB_ORM_SQLCOMPOUNDQUERY_CLASS

class hb_orm_SQLCompoundQuery
    hidden:
        data p_oSQLConnection              init NIL
        data p_SQLEngineType               init 0
        data p_SQLConnection               init -1    // ODBC layer connection number
        data p_ConnectionNumber            init 0     // Unique number across all instances in current running program. Can be used to help generate some names.
        data p_Database                    init ""
        data p_NamespaceName               init ""

        data p_PrimaryKeyFieldName         init "key"        // Primary Key Field Name
        data p_CreationTimeFieldName       init "sysc"       // Creation Time Field Name
        data p_ModificationTimeFieldName   init "sysm"       // Modification Time Field Name

        data p_cEventId                    init ""

        data p_ErrorMessage                init ""

        data p_ColumnToReturn              init {}
               // 1 - ""   Expression
               // 2 - ""   Alias

        data p_TableFullPath               init ""
        data p_CursorName                  init ""
        data p_CursorUpdatable             init .f.

        data p_LastSQLCommand              init ""
        data p_LastRunTime                 init 0

        data p_AddLeadingBlankRecord       init .f.
        data p_AddLeadingRecordsCursorName init ""


        data p_MaxTimeForSlowWarning       init 2.000  // number of seconds  _M_

        data p_ExplainMode                 init 0     // 0 = Explain off, 1 = Explain with no run, 2 = Explain with run

        data p_cAnchorAlias                init ""    // The final alias of a combined statement. Can be the same of :SQL(<cAlias>) if an in-memory table is requested as output.
        data p_hSQLDataQueries             init {=>}  // hash list of SQLData objects used for Combined queries, "alias name" => SQLDataObject
        data p_hAliasWithoutOrderBy        init {=>}  // hash list aliases that will have a combined transformation. This is needed to find out if may or may not include the "order by" clauses.
        data p_aSQLCTQueries               init {}    // array list of SQLData objects used for CTEs, "alias name" => SQLDataObject
        data p_aCombineQuery               init {}    // 2 D array, list of Combined Queries {nCombineAction,cGeneratedAlias,lAll,cAlia1,cAlia2,...}

        method IsConnected()                                                    //Return .t. if has a connection
        method SetEventId(par_xId)                                              // Called by Table() and Delete(). Used to identify SQL(), Add(), Update(), Delete() query and updates in logs, including error logs. par_xId may be a number of string. Numbers will be converted to string. Id must be max HB_ORM_MAX_EVENTID_SIZE character long.
    
    exported:
        data Tally init 0 READONLY
        data p_oCursor                //In case :SQL("<CursorName>") was called, meaning a hb_orm_cursor was created. Named with leading "p_" since used internally.

        method Init() constructor     //Harbour does not call the constructor by default (BIG design mistake)
        method UseConnection(par_oSQLConnection)

        method ErrorMessage()                                             //Retrieve the error text of the last call to :SQL(), :Get(), :Count(), :Add(), :Update(), :Delete()

        method ReadWrite(par_lValue)                                                                   // Was used in VFP ORM, not the Harbour version, since the result cursors are always ReadWriteable

        method AddLeadingBlankRecord()                                                                 // If the result cursor should have a leading blank record, used mainly to create the concept of "not-selected" row
        method AddLeadingRecords(par_cCursorName)                                                      // Specify to add records from par_cCursorName as leading record to the future result cursor

        method SetExplainMode(par_nMode)                                                               // Used to get explain information. 0 = Explain off, 1 = Explain with no run, 2 = Explain with run

        method BuildSQL(par_cAction)                                                                   // par_cAction is not used but needed since SQLData:BuildSQL would not know it is calling a Compound Class
        method SQL(par_1)                                                                              // Assemble and Run SQL command
        // method Count()                                                                              // Similar to SQL() but will not get the list of Column() and return a numeric, the number or records found. Will return -1 in case of error. The par_SQLID is optional (used if reporting error info).

        method GetLastEventId() INLINE ::p_cEventId                                                     // Will return the Last :Table() EventID. Useful to report where a problem occurred. 
        method LastSQL()        INLINE ::p_LastSQLCommand                                               // Get the last sent SQL command executed
        method LastRunTime()    INLINE ::p_LastRunTime                                                  // Get the last execution time in seconds




//Under development ideas
        method AnchorAlias(par_xEventId,par_cAlias)                                                              // Required to start the Combined Statement
        method AddSQLDataQuery(par_cAlias,par_oSQLData)                                                          // Add a hb_orm_sqldata to the list of queries to combine
        method AddSQLCTEQuery(par_cAlias,par_oSQLData)                                                           // Add a hb_orm_sqldata To be used as a Common Table in CTEs
        method CombineQueries(par_nCombineAction,par_cGeneratedAlias,par_lAll,par_cAlias1,par_cAlias2,...)       // par_nCombineAction can be one of COMBINE_ACTION_*
//        method CombineQueriesAsCTE(par_nCombineAction,par_cGeneratedAlias,par_lAll,par_cAlias1,par_cAlias2,...)  // par_nCombineAction can be one of COMBINE_ACTION_*

    DESTRUCTOR destroy()

endclass

#endif   /* DEFINED_HB_ORM_SQLCOMPOUNDQUERY_CLASS */
