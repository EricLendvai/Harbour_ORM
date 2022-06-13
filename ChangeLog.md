# Harbour ORM - Change Log

## 06/12/2022
* Fixed methods GetFieldValue,SetFieldValue and CreateIndexes to not rely on current area, but the one created by the orm. This also fixes the method InsertRecord.
* New method DistinctOn() for PostgreSQL support of "distinct on ()" SQL syntax.

## 06/07/2022
* Fix on orm schema in PostgreSQL is set not to be case sensitive.

## 03/22/2022
* Fixed issue for PostgreSQL loadschema to ignore non actual tables, meaning exclude views.

## 03/13/2022
* Schema Updates can switch an Integer/Big Integer/Numeric from accepting NULL to Not NULL with 0 default. All existing NULL values will be converted to 0.
