# Harbour_ORM Documentation


The following is the list of the 4 classes / 3 constructors defined in this ORM.


|Class Name | Constructor Function | Use|
|:--- | :--- | :--- |
|hb_orm_SQLConnect | hb_SQLConnect | Objects are used to setup a connection to a backend server.<br>One object/connection can be used by multiple hb_orm_SQLData objects. |
|hb_orm_SQLData | hb_SQLData | Query backend and return either a hb_orm_Data or hb_orm_Cursor object.<br>Add, update or delete a record in backend server.|
|hb_orm_Cursor | hb_Cursor | Created when calling the SQL(\<CursorName>) method of an hb_orm_SQLData object.<br>Create a local in-memory table (Cursor)|
|hb_orm_Data |  | Created when calling the Get(...) method of a hb_orm_SQLData object.<br>Will have property names matching the requested field names.|

 
## Defining a Schema

For execution performance, not JSON but a Harbour Hash array

Hash of table names, the value is a 2 dimension array.
{Hash on field names,Hash on index names(*1)}

The Hash on field names is using the field name as the key and the value is an array as follow:
{
 BackendTypes,FieldType,FieldLength,FieldDecimals,AllowNulls,IsAutoIncrement
}

SQLEngines is a string. If blank or null, the field will exist in all backends.
If the string includes "P" it will be defined for PostgreSQL.
If the string includes "M" it will be defined for MySQL and MariaDB.
If the string includes "C" it will be defined for Microsoft SQL Server.  (Later)
If the string includes "L" it will be defined for SQL Lite.  (Later)

The Hash on index names is using the index name as the key and the value is an array as follow:
{
 BackendTypes,Expression,IsUnique,Algorithm (*2)
}

(*1), the name must be unique inside a table. To work around PostgreSQL index name conflict, and to help identify the hb_orm managed indexes, the indexes are actually name <TableName>_<IndexName>_idx, all lower case.
(*2), if blank BTREE will be used. The list of supported Algorithm depends on the BackendType

## Other
-VARCHAR with no max value will default to 255. This is due to a limitation of MySQL and the fact that it does not support VARCHAR(0) like in PostgreSQL