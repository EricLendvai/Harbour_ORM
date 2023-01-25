# Harbour ORM - Change Log

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
