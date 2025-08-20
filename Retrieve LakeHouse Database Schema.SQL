SELECT 
    TABLE_SCHEMA AS schema_name,
    TABLE_NAME AS view_name,
    COLUMN_NAME,
    ORDINAL_POSITION,
    DATA_TYPE
FROM 
    INFORMATION_SCHEMA.COLUMNS
WHERE 
    TABLE_NAME IN (
        SELECT name FROM sys.tables
    ) and TABLE_SCHEMA='prod'
ORDER BY 
    schema_name, view_name, ORDINAL_POSITION;
