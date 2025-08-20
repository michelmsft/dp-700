SELECT  TOP  10 * FROM  lnd.customers

TRUNCATE TABLE lnd.customers

COPY INTO lnd.customers
FROM 'https://factoryadlsgen2.blob.core.windows.net/data/silver/customers.csv'
WITH (
    FILE_TYPE = 'CSV',
    CREDENTIAL = (
        IDENTITY = 'Shared Access Signature',
        SECRET = '<SAS-TOKEN-FROm-ADLS>'
    ),
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0A',
    FIRSTROW = 2
);



COPY INTO lnd.customers
FROM 'https://factoryadlsgen2.blob.core.windows.net/data/silver/customers.csv'
WITH (
    FILE_TYPE = 'CSV',
    CREDENTIAL=(IDENTITY= 'Managed Identity'),
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0A',
    FIRSTROW = 2
);
