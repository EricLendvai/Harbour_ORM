# Harbour_ORM

## Definition
The ORM acronym stands for Object Relational Mapper.
ORMs are a method to access and manipulate data using objects, instead of direct access to SQL backends or other data stores.

## Warning
This project is still under development but already functions to provide query (SQL) and CRUD (Create, Read, Update and Delete) features.

Please review the file DevelopmentNotes.md for notes and roadmaps for this package.

Currently this repo is only tested/developed under Microsoft Windows.

Most API documentation is in the class definitions in the actual source code. 

Currently the SQL_CRUD example need some tables to be set on your MariaDB and PostgreSQL servers. An automated table creation will be added to this package. 

The examples source code still have a lot of under development test code, disregard. 

## Prerequisite
Set up your development environment, and use all the tools created in the article, [How to Install Harbour on Windows](https://harbour.wiki/index.asp?page=PublicArticles&mode=show&id=190401174818&sig=6893630672).

Basic knowledge of VSCODE (Microsoft Visual Studio Code) is recommended. See article [Developing and Debugging Harbour Programs with VSCODE](https://harbour.wiki/index.asp?page=PublicArticles&mode=show&id=190401174818&sig=6893630672).

This package uses the non-intrusive version of the package at https://github.com/EricLendvai/Harbour_VFP.

Latest MySQL and PostgreSQL MS Windows ODBC drivers (Unicode).

## This project
This project is not a standard ORM. Since Harbour is a xBase language, beside receiving objects as return values, in-memory tables (cursors) are created to hold the results of queries, which in turn will provide rich features to manipulating those cursors, like: local indexes, filtering, traversing the tables in any direction, in-place field replacements, exports and many more.

This ORM can currently access **MySQL**, **MariaDB** and **PostgreSQL** backends.

There are four classes and three constructors that work together to provide all the functionality for the ORM package.

A constructor is a function that will return an object based on one of the classes in this ORM.

Let's review how different languages create objects to better understand how Harbour and specifically this package is doing this.

- In **VFP** you would use the CreateObject() function.
For example: **oMyObject = CreateObject("MyClass",par1,par2)**
- In **Python** you would call the class name as a function.
For example: **oMyObject = MyClass(par1,par2)**
- In **JavaScript** object can exist without a class, or a constructor function can be used to build an object using the new operator. For example: **var myObject = new MyClass(par1,par2)**

Harbour can create an object by calling the class as a function, but no constructor method is automatically called to initialize properties. We can create a constructor method and call it in a chained fashion, as long as that method returns Self. For example: **My Object := MyClass():Init(par1,par2)** The easiest is to create constructor function that wraps around that logic. See for example the function **hb_SQLConnect(...)** that is a wrapper for the class hb_orm_SQLConnect() defined in hb_orm_core.prg.

```
function hb_SQLConnect(par_BackendType,par_...)  
return hb_orm_SQLConnect():SetAllSettings(par_BackendType,par_...)
```

The following is the list of the 4 classes / 3 constructors defined in this ORM.


|Class Name | Constructor Function | Use|
|:--- | :--- | :--- |
|hb_orm_SQLConnect | hb_SQLConnect | Objects are used to setup a connection to a backend server.<br>One object/connection can be used by multiple hb_orm_SQLData objects. |
|hb_orm_SQLData | hb_SQLData | Query backend and return either a hb_orm_Data or hb_orm_Cursor object.<br>Add, update or delete a record in backend server.|
|hb_orm_Cursor | hb_Cursor | Created when calling the SQL(\<CursorName>) method of an hb_orm_SQLData object.<br>Create a local in-memory table (Cursor)|
|hb_orm_Data |  | Created when calling the Get(...) method of a hb_orm_SQLData object.<br>Will have property names matching the requested field names.|

 
Please review the file .\Examples\SQL_CRUD\SQL_CRUD.prg file to see examples for accessing and update SQL backend data.

Please review the file .\Examples\Cursors\Cursors.prg file to see how to create an in-memory table from scratch.

They are 3 VSCode workspace files (.code-workspace) in this repo. One for the core source code, and one per example. Please update any references of "R:\Harbour_ORM\" in the .code-workspace, .vscode\launch.json and .vscode\tasks.json files to your local install of this repo.

## Use notes
- Do not created / specify indexes on primary keys. They are automatically added and managed by both engine types (PostgreSQL and MySQL).
- Do not have more than one field with same name using different casing. Casing should only be used for readability.
- All indexes managed by the orm are lower case and named as follows: "&lt;tablename&gt;&lowbar;&lt;indexname&gt;&lowbar;idx"   
You may create any other indexes that is not named with a leading "&lt;tablename&gt;_" and ending "_idx".
- Varchar types must have a max length. Zero is not allowed due to MySQL specification.

## MySQL Peculiarities
- No support for multiple PostgreSQL equivalent to "Schema Namespaces"
- Very fast at retrieving its schema column definition
- While retrieving schema information, buggy to list columns if also joining on table schema information. MySQL keeps version of schema definitions it seems.
- Case sensitivity See https://www.informit.com/articles/article.aspx?p=2036581&seqNum=3
  Column names, index names, stored functions and procedures name, ARE NOT case sensitive. Trigger names ARE case sensitive. Table names can be case sensitive on non-MS Windows, unless "lower_case_table_names" setting is set to 1, see https://dev.mysql.com/doc/refman/8.0/en/identifier-case-sensitivity.html
  To avoid any conflicts across platforms set the connection orm property "MySQLEngineConvertIdentifierToLowerCase" to true (default), before calling the Connect() method.
- Even though MySQL support specifying the column order, this orm will not change column orders. New columns are always added after all previous ones on file. Changing column order could wipe out column comments and other settings.
- To avoid performance issues when changing a table schema, avoiding table rewrites, see https://mysqlserverteam.com/mysql-8-0-innodb-now-supports-instant-add-column/ . To be compatible with the PostgreSQL engine, avoid using non null fields with non constant default values since this would require a default value.
- Varchar must have a max length. Unlike PostgreSQL, which treats 0 length as string with virtually no limits.
- TIME and DATETIME data types may have a precision of 0 to 6 digits, meaning a fraction of a second. For DATETIME, in Harbour it is limited to 3 digits (milliseconds). TIME data type can be entered as a string "hh:mm:ss.ffffff". The precision is limited by the field definition.
- Numeric (decimal types) Length includes the decimals but does not include the decimal point.
- Numeric (decimal types) Length is not affected by the sign.
- Numeric (decimal types) Length can be up to 65 digits. But in Harbour this is limited to 15 digits. To enter larger or higher precisions numerics, you may use the text expression of the number, for example: "123456789012345678.123456789" as a text will be sent "raw" to the server.


## PostgreSQL Peculiarities
- Has a table namespacing concept called "Schemas". This name makes it a little confusing since "Schema" mean the definition of entities (tables), not a namespace. To avoid confusion in the source code we are using SchemaName for referring the the Schema Namespace. The method LoadSchema() will "load in" the definition for all tables in all SchemaNames.
- Extremely slow when retrieving schema definition for database with several hundred tables. For this reason this orm create a "cache" of the schema definition, and maintains a log of schema changes.
- PostgreSQL does not allow you to specify the order of column. Any new column is always at the end of the current list of columns.
- PostgreSQL does not accept column alias names in HAVING clauses. You need to repeat the entire original column expression in HAVING clause.
- PostgreSQL treats identifiers case insensitively when not quoted. Reserved words must be quoted if used as identifiers. Non quoted identifiers are converted to lower case. To assist with identifier casing, set the connection orm property "PostgreSQLIdentifierCasing" to HB_ORM_POSTGRESQL_CASE_INSENSITIVE, HB_ORM_POSTGRESQL_CASE_SENSITIVE or HB_ORM_POSTGRESQL_CASE_ALL_LOWER, before the calling the Connect() method.
- PostgreSQL does not support changing column orders, neither does this orm.
- To avoid performance issues when changing a table schema, avoiding table rewrite, see https://www.postgresql.org/docs/11/ddl-alter.html . Use PostgreSQL version 11 or above to ensure that adding fields with default constant values can be done virtually instantly.
- Primary keys have indexes but they are not visible in the PgAdmin tool
- TIME and TIMESTAMP data types may have a precision of 0 to 6 digits, meaning a fraction of a second. For TIMESTAMP (Datetime), in Harbour it is limited to 3 digits (milliseconds). TIME data type can be entered as a string "hh:mm:ss.ffffff". The precision is limited by the field definition.
- Numeric (decimal types) Length includes the decimals but does not include the decimal point.
- Numeric (decimal types) Length is not affected by the sign.
- Numeric (decimal types) Length can be over 130000 digits. But in Harbour this is limited to 15 digits. To enter larger or higher precisions numerics, you may use the text expression of the number, for example: "123456789012345678.123456789" as a text will be sent "raw" to the server.


## For VFP Developers
This package can be used to query SQL backends and create the equivalent of readwrite VFP cursors, with long field names, Null and auto-increment support. Updates to tables (on remove server) must be done by using specify object methods.

## Roadmap
- Backup / Restore across backends. This would allow you to backup a MySQL and restore into PostgreSQL for example.
- Add support to CTE  Common Table Expression
- Add support to MSSQL
- Add support to SQLite
- PostgreSQL server side support for native Harbour language.
- Stored functions/procedure management
- Trigger based replication / cross backend aware.

## Documentation
- View Documentation.md file for user oriented documentation
- Vew DevelopmentNotes.md file if you are interested in the internal of this orm our would like to contribute.