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

Latest MySQL and PostgreSQL MS Windows ODBC drivers (Unicode preferably).

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

They are 3 VSCode workspace files (.code-workspace) in this repo. One for the core source code, and one per example. Please update any references of "r:\Harbour_orm\" in the .code-workspace, .vscode\launch.json and .vscode\tasks.json files to your local install of this repo.

## For VFP Developers
This package can be used to query SQL backends and create the equivalent of readwrite VFP cursors, with long field names, Null and auto-increment support. Updates to tables (on remove server) must be done by using specify object methods.