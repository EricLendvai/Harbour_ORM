# Ideas and Todos for hb_orm_Cursor
- Check every areas marked with _M_
- UTF8 support already exists, what about Code Pages
- For Field assignments add auto conversion maybe?
- Check memory use, or memory use limitation.
- Method to push cursor to server?
- Option to dump to DBF?
- Fix SQLMix support to descending orders and use that support in Index() and CreateIndexes() methods


# Ideas and Todos for hb_orm_sqldata
- Implement SQL UNIONs
- Implement Cross SQL Backends global UDFs that includes most hb and vfp manipulation.
  like for example: left(),right(),strtran(),padr(),allt(),iif(),case(),between(),inlist(),nvl(),round(),dtot(),dow(),trans(),bitand(),space(),mline(),chr(),FormatAlphaNumericForIndexing(), ....
- Add optional Field Flags attribute to Field() method
- Initialize the related hb_orm_cursor object's p_AutoIncrementLastValue property so newly added records will also have their auto-increment field properly set
- Default setting of "Trimmed" field Flag attribute for related hb_orm_cursor object character fields


# Ideas and Todos for ExportTableToHtmlFile
- On hover or onclick of binary field display text value?
- Bug with VarBinary MySQL rendering. See field TABLE003_VARBINARY55 created in SQL_CRUD.prg


# Other Ideas and Todos
- Create an orm_isnull() function that is more like the hb_isnil()
- Add support to SQLite
- Use in-memory SQLite for post local SQL commands.


# Miscellaneous
    For cursors created with SQLMIX:
        DBFieldInfo( DBS_ISNULL, <FieldPosition> ) always returns NIL, meaning fails to work.
        Use hb_IsNIL(FieldGet(<FieldPosition>)) to test if the field is Null (NIL Value)
        Always can assign NIL to any fields, even if not marked to allow Null values.
        Can assign a value content that exceeds field size (at least for "C" type).
        If a field was defined to allow Null, after a dbAppend() empty values are used instead (all blanks, 0d00000000 ...)
        Auto-increment fields are not initialized after dbAppend()
        Max Field Name Length is ?

    For cursors created with mem:table   VFPCDX or DBFCDX:
        Field Name length is limited to 10 characters
        Field defined as Null, after dbAppend() will have their values set as NIL


# Coding Standards
- Every local variable names start with "l_". Most of the time will be followed Hungarian notation.
- Every parameter names in a method or function start with "par_"
- Most property names start with "p_"
- Global variable names start with "v_"
