/* 

Step 1 — (One-time) create a staging schema + views over the Shortcuts
These views let you normalize types/column names once, then reuse everywhere.

*/

-- One-time setup
IF SCHEMA_ID('stg') IS NULL EXEC('CREATE SCHEMA stg;');

-- Each view wraps a Warehouse Shortcut (zero-copy link to Lakehouse_SV)
CREATE OR ALTER VIEW stg.Products           AS SELECT * FROM Lakehouse_Sv.dbo.products;
GO
CREATE OR ALTER VIEW stg.Warehouses         AS SELECT * FROM Lakehouse_Sv.dbo.warehouses;
GO
CREATE OR ALTER VIEW stg.Customers          AS SELECT * FROM Lakehouse_Sv.dbo.customers;
GO
CREATE OR ALTER VIEW stg.Mills              AS SELECT * FROM Lakehouse_Sv.dbo.mills;
GO
CREATE OR ALTER VIEW stg.Machines           AS SELECT * FROM Lakehouse_Sv.dbo.machines;
GO
CREATE OR ALTER VIEW stg.Employees          AS SELECT * FROM Lakehouse_Sv.dbo.employees;
GO
CREATE OR ALTER VIEW stg.Orders             AS SELECT * FROM Lakehouse_Sv.dbo.orders;
GO
CREATE OR ALTER VIEW stg.Shipments          AS SELECT * FROM Lakehouse_Sv.dbo.shipments;
GO
CREATE OR ALTER VIEW stg.StockMovements     AS SELECT * FROM Lakehouse_Sv.dbo.stockmovements;
GO
CREATE OR ALTER VIEW stg.PlannedProductions AS SELECT * FROM Lakehouse_Sv.dbo.plannedproductions;
GO
CREATE OR ALTER VIEW stg.MachineDowntime    AS SELECT * FROM Lakehouse_Sv.dbo.machinedowntime;
GO
CREATE OR ALTER VIEW stg.MachineSensors     AS SELECT * FROM Lakehouse_Sv.dbo.machinesensors;
GO

/*
Step 2 — DDL for Gold (same as before, small/pretty IDENTITY SKs)
(If you already ran this once, you can skip.)
*/

/* ============================
   DDL in Fabric style (no IDENTITY, no PK/FK, all NULLable)
   ============================ */

/* ============================
   DDL: Gold tables (VARCHAR only)
   ============================ */

-- Dimensions
IF OBJECT_ID('dbo.DimProduct','U') IS NULL
CREATE TABLE dbo.DimProduct (
  SurrogateKey   BIGINT          NULL,
  ProductID      VARCHAR(100)    NULL,
  Source         VARCHAR(100)    NULL,
  Brand          VARCHAR(200)    NULL,
  ProductName    VARCHAR(200)    NULL,
  BasisWeight    FLOAT           NULL,
  Brightness     FLOAT           NULL,
  Certification  VARCHAR(100)    NULL,
  PalletsToTon   FLOAT           NULL
);

IF OBJECT_ID('dbo.DimWarehouse','U') IS NULL
CREATE TABLE dbo.DimWarehouse (
  SurrogateKey     BIGINT         NULL,
  WarehouseID      VARCHAR(100)   NULL,
  Source           VARCHAR(100)   NULL,
  WarehouseName    VARCHAR(200)   NULL,
  Region           VARCHAR(100)   NULL,
  Type             VARCHAR(100)   NULL,
  AssignedMillID   VARCHAR(100)   NULL,
  CapacityPallets  FLOAT          NULL
);

IF OBJECT_ID('dbo.DimCustomer','U') IS NULL
CREATE TABLE dbo.DimCustomer (
  SurrogateKey   BIGINT          NULL,
  CustomerID     VARCHAR(100)    NULL,
  Source         VARCHAR(100)    NULL,
  CompanyName    VARCHAR(200)    NULL,
  Email          VARCHAR(200)    NULL,
  Industry       VARCHAR(100)    NULL,
  IsActive       BIT             NULL
);

IF OBJECT_ID('dbo.DimMill','U') IS NULL
CREATE TABLE dbo.DimMill (
  SurrogateKey            BIGINT         NULL,
  MillID                  VARCHAR(100)   NULL,
  Source                  VARCHAR(100)   NULL,
  Name                    VARCHAR(200)   NULL,
  ProductionTonsCapacity  FLOAT          NULL
);

IF OBJECT_ID('dbo.DimMachine','U') IS NULL
CREATE TABLE dbo.DimMachine (
  SurrogateKey    BIGINT          NULL,
  MachineID       VARCHAR(100)    NULL,
  Source          VARCHAR(100)    NULL,
  MillID          VARCHAR(100)    NULL,
  Type            VARCHAR(100)    NULL,
  CommissionDate  DATE            NULL,
  RatedKW         FLOAT           NULL
);

IF OBJECT_ID('dbo.DimEmployee','U') IS NULL
CREATE TABLE dbo.DimEmployee (
  SurrogateKey  BIGINT          NULL,
  EmployeeID    VARCHAR(100)    NULL,
  Source        VARCHAR(100)    NULL,
  FullName      VARCHAR(200)    NULL,
  Email         VARCHAR(200)    NULL,
  Department    VARCHAR(100)    NULL,
  HireDate      DATE            NULL
);

-- DimDate (replace TINYINT with INT)
IF OBJECT_ID('dbo.DimDate','U') IS NULL
CREATE TABLE dbo.DimDate (
  DateSK    INT    NULL,
  [Date]    DATE   NULL,
  [Year]    INT    NULL,
  [Month]   INT    NULL,
  [Day]     INT    NULL,
  [Quarter] INT    NULL  -- was TINYINT
);

-- Facts
IF OBJECT_ID('dbo.FactOrders','U') IS NULL
CREATE TABLE dbo.FactOrders (
  SurrogateKey    BIGINT         NULL,
  NaturalKey      CHAR(64)       NULL,   -- SHA-256 hex
  DateSK          INT            NULL,
  ProductSK       BIGINT         NULL,
  CustomerSK      BIGINT         NULL,
  Source          VARCHAR(100)   NULL,
  OrderedPallets  FLOAT          NULL,
  OrderedTons     FLOAT          NULL
);

IF OBJECT_ID('dbo.FactShipments','U') IS NULL
CREATE TABLE dbo.FactShipments (
  SurrogateKey     BIGINT         NULL,
  NaturalKey       CHAR(64)       NULL,
  DateSK           INT            NULL,
  ProductSK        BIGINT         NULL,
  WarehouseSK      BIGINT         NULL,
  Source           VARCHAR(100)   NULL,
  ShippedPallets   FLOAT          NULL,
  ShippedTons      FLOAT          NULL
);

IF OBJECT_ID('dbo.FactDailyFillRate','U') IS NULL
CREATE TABLE dbo.FactDailyFillRate (
  SurrogateKey  BIGINT   NULL,
  NaturalKey    CHAR(64) NULL,
  DateSK        INT      NULL,
  OrderedTons   FLOAT    NULL,
  ShippedTons   FLOAT    NULL,
  FillRate      FLOAT    NULL
);

IF OBJECT_ID('dbo.FactWarehouseDailyUtilization','U') IS NULL
CREATE TABLE dbo.FactWarehouseDailyUtilization (
  SurrogateKey     BIGINT         NULL,
  NaturalKey       CHAR(64)       NULL,
  DateSK           INT            NULL,
  WarehouseSK      INT         NULL,
  Source           VARCHAR(100)   NULL,
  PalletsOccupied  FLOAT          NULL,
  CapacityPallets  FLOAT          NULL,
  Utilization      FLOAT          NULL
);


/*
Step 3 — MERGE loads using three-part names (no OPENROWSET)
*/

-- UPDATE (CTE #1)
;WITH S AS (
  SELECT DISTINCT
    (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256',
       CONCAT(CAST(ProductID AS VARCHAR(100)),'|',CAST(Source AS VARCHAR(100)))
    ))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
    CAST(ProductID AS VARCHAR(100))  AS ProductID,
    CAST(Source    AS VARCHAR(100))  AS Source,
    CAST(Brand     AS VARCHAR(200))  AS Brand,
    CAST(ProductName AS VARCHAR(200)) AS ProductName,
    TRY_CAST(BasisWeight AS FLOAT)   AS BasisWeight,
    TRY_CAST(Brightness  AS FLOAT)   AS Brightness,
    CAST(Certification   AS VARCHAR(100)) AS Certification,
    COALESCE(TRY_CAST(PalletsToTon AS FLOAT), 1.0) AS PalletsToTon
  FROM stg.Products
)
UPDATE T
   SET T.SurrogateKey = S.SurrogateKey,
       T.Brand        = S.Brand,
       T.ProductName  = S.ProductName,
       T.BasisWeight  = S.BasisWeight,
       T.Brightness   = S.Brightness,
       T.Certification= S.Certification,
       T.PalletsToTon = S.PalletsToTon
FROM dbo.DimProduct AS T
JOIN S ON T.ProductID = S.ProductID AND T.Source = S.Source;

-- INSERT (CTE #2)
;WITH S AS (
  SELECT DISTINCT
    (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256',
       CONCAT(CAST(ProductID AS VARCHAR(100)),'|',CAST(Source AS VARCHAR(100)))
    ))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
    CAST(ProductID AS VARCHAR(100))  AS ProductID,
    CAST(Source    AS VARCHAR(100))  AS Source,
    CAST(Brand     AS VARCHAR(200))  AS Brand,
    CAST(ProductName AS VARCHAR(200)) AS ProductName,
    TRY_CAST(BasisWeight AS FLOAT)   AS BasisWeight,
    TRY_CAST(Brightness  AS FLOAT)   AS Brightness,
    CAST(Certification   AS VARCHAR(100)) AS Certification,
    COALESCE(TRY_CAST(PalletsToTon AS FLOAT), 1.0) AS PalletsToTon
  FROM stg.Products
)
INSERT INTO dbo.DimProduct
  (SurrogateKey, ProductID, Source, Brand, ProductName, BasisWeight, Brightness, Certification, PalletsToTon)
SELECT S.SurrogateKey, S.ProductID, S.Source, S.Brand, S.ProductName, S.BasisWeight, S.Brightness, S.Certification, S.PalletsToTon
FROM S
LEFT JOIN dbo.DimProduct AS T
  ON T.ProductID = S.ProductID AND T.Source = S.Source
WHERE T.ProductID IS NULL;

-- DimWarehouse

-- UPDATE
;WITH S AS (
  SELECT DISTINCT
    (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256',
      CONCAT(CAST(WarehouseID AS VARCHAR(100)),'|',CAST(Source AS VARCHAR(100)))
    ))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
    CAST(WarehouseID AS VARCHAR(100)) AS WarehouseID,
    CAST(Source      AS VARCHAR(100)) AS Source,
    CAST(WarehouseName AS VARCHAR(200)) AS WarehouseName,
    CAST(Region        AS VARCHAR(100)) AS Region,
    CAST(Type          AS VARCHAR(100)) AS Type,
    CAST(AssignedMillID AS VARCHAR(100)) AS AssignedMillID,
    TRY_CAST(CapacityPallets AS FLOAT) AS CapacityPallets
  FROM stg.Warehouses
)
UPDATE T SET
  T.SurrogateKey=S.SurrogateKey,
  T.WarehouseName=S.WarehouseName,
  T.Region=S.Region,
  T.Type=S.Type,
  T.AssignedMillID=S.AssignedMillID,
  T.CapacityPallets=S.CapacityPallets
FROM dbo.DimWarehouse AS T
JOIN S ON T.WarehouseID=S.WarehouseID AND T.Source=S.Source;

-- DimCustomer
-- INSERT
;WITH S AS (
  SELECT DISTINCT
    (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256',
      CONCAT(CAST(WarehouseID AS VARCHAR(100)),'|',CAST(Source AS VARCHAR(100)))
    ))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
    CAST(WarehouseID AS VARCHAR(100)) AS WarehouseID,
    CAST(Source      AS VARCHAR(100)) AS Source,
    CAST(WarehouseName AS VARCHAR(200)) AS WarehouseName,
    CAST(Region        AS VARCHAR(100)) AS Region,
    CAST(Type          AS VARCHAR(100)) AS Type,
    CAST(AssignedMillID AS VARCHAR(100)) AS AssignedMillID,
    TRY_CAST(CapacityPallets AS FLOAT) AS CapacityPallets
  FROM stg.Warehouses
)
INSERT INTO dbo.DimWarehouse
 (SurrogateKey, WarehouseID, Source, WarehouseName, Region, Type, AssignedMillID, CapacityPallets)
SELECT S.SurrogateKey, S.WarehouseID, S.Source, S.WarehouseName, S.Region, S.Type, S.AssignedMillID, S.CapacityPallets
FROM S
LEFT JOIN dbo.DimWarehouse T ON T.WarehouseID=S.WarehouseID AND T.Source=S.Source
WHERE T.WarehouseID IS NULL;

-- DimCustomer
IF OBJECT_ID('stg.Customers','V') IS NOT NULL
BEGIN
  -- UPDATE
  ;WITH S AS (
    SELECT DISTINCT
      (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256',
        CONCAT(CAST(CustomerID AS VARCHAR(100)),'|',CAST(Source AS VARCHAR(100)))
      ))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
      CAST(CustomerID AS VARCHAR(100)) AS CustomerID,
      CAST(Source     AS VARCHAR(100)) AS Source,
      CAST(CompanyName AS VARCHAR(200)) AS CompanyName,
      LOWER(NULLIF(LTRIM(RTRIM(CAST(email AS VARCHAR(200)))), '')) AS Email,
      CAST(Industry AS VARCHAR(100)) AS Industry,
      TRY_CAST(IsActive AS BIT) AS IsActive
    FROM stg.Customers
  )
  UPDATE T SET
    T.SurrogateKey=S.SurrogateKey,
    T.CompanyName=S.CompanyName,
    T.Email=S.Email,
    T.Industry=S.Industry,
    T.IsActive=S.IsActive
  FROM dbo.DimCustomer AS T
  JOIN S ON T.CustomerID=S.CustomerID AND T.Source=S.Source;

  -- INSERT
  ;WITH S AS (
    SELECT DISTINCT
      (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256',
        CONCAT(CAST(CustomerID AS VARCHAR(100)),'|',CAST(Source AS VARCHAR(100)))
      ))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
      CAST(CustomerID AS VARCHAR(100)) AS CustomerID,
      CAST(Source     AS VARCHAR(100)) AS Source,
      CAST(CompanyName AS VARCHAR(200)) AS CompanyName,
      LOWER(NULLIF(LTRIM(RTRIM(CAST(email AS VARCHAR(200)))), '')) AS Email,
      CAST(Industry AS VARCHAR(100)) AS Industry,
      TRY_CAST(IsActive AS BIT) AS IsActive
    FROM stg.Customers
  )
  INSERT INTO dbo.DimCustomer
   (SurrogateKey, CustomerID, Source, CompanyName, Email, Industry, IsActive)
  SELECT S.SurrogateKey, S.CustomerID, S.Source, S.CompanyName, S.Email, S.Industry, S.IsActive
  FROM S
  LEFT JOIN dbo.DimCustomer T ON T.CustomerID=S.CustomerID AND T.Source=S.Source
  WHERE T.CustomerID IS NULL;
END


-- DimMill

IF OBJECT_ID('stg.Mills','V') IS NOT NULL
BEGIN
  -- UPDATE
  ;WITH S AS (
    SELECT DISTINCT
      (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256',
        CONCAT(CAST(MillID AS VARCHAR(100)),'|',CAST(Source AS VARCHAR(100)))
      ))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
      CAST(MillID AS VARCHAR(100)) AS MillID,
      CAST(Source AS VARCHAR(100)) AS Source,
      CAST(Name   AS VARCHAR(200)) AS Name,
      TRY_CAST(ProductionTonsCapacity AS FLOAT) AS ProductionTonsCapacity
    FROM stg.Mills
  )
  UPDATE T SET
    T.SurrogateKey=S.SurrogateKey,
    T.Name=S.Name,
    T.ProductionTonsCapacity=S.ProductionTonsCapacity
  FROM dbo.DimMill AS T
  JOIN S ON T.MillID=S.MillID AND T.Source=S.Source;

  -- INSERT
  ;WITH S AS (
    SELECT DISTINCT
      (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256',
        CONCAT(CAST(MillID AS VARCHAR(100)),'|',CAST(Source AS VARCHAR(100)))
      ))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
      CAST(MillID AS VARCHAR(100)) AS MillID,
      CAST(Source AS VARCHAR(100)) AS Source,
      CAST(Name   AS VARCHAR(200)) AS Name,
      TRY_CAST(ProductionTonsCapacity AS FLOAT) AS ProductionTonsCapacity
    FROM stg.Mills
  )
  INSERT INTO dbo.DimMill (SurrogateKey, MillID, Source, Name, ProductionTonsCapacity)
  SELECT S.SurrogateKey, S.MillID, S.Source, S.Name, S.ProductionTonsCapacity
  FROM S
  LEFT JOIN dbo.DimMill T ON T.MillID=S.MillID AND T.Source=S.Source
  WHERE T.MillID IS NULL;
END




IF OBJECT_ID('stg.Machines','V') IS NOT NULL
BEGIN
  -- UPDATE
  ;WITH S AS (
    SELECT DISTINCT
      (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256',
        CONCAT(CAST(MachineID AS VARCHAR(100)),'|',CAST(Source AS VARCHAR(100)))
      ))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
      CAST(MachineID AS VARCHAR(100)) AS MachineID,
      CAST(Source    AS VARCHAR(100)) AS Source,
      CAST(MillID    AS VARCHAR(100)) AS MillID,
      CAST(Type      AS VARCHAR(100)) AS Type,
      TRY_CONVERT(DATE, CommissionDate) AS CommissionDate,
      TRY_CAST(RatedKW AS FLOAT) AS RatedKW
    FROM stg.Machines
  )
  UPDATE T SET
    T.SurrogateKey=S.SurrogateKey,
    T.MillID=S.MillID,
    T.Type=S.Type,
    T.CommissionDate=S.CommissionDate,
    T.RatedKW=S.RatedKW
  FROM dbo.DimMachine AS T
  JOIN S ON T.MachineID=S.MachineID AND T.Source=S.Source;

  -- INSERT
  ;WITH S AS (
    SELECT DISTINCT
      (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256',
        CONCAT(CAST(MachineID AS VARCHAR(100)),'|',CAST(Source AS VARCHAR(100)))
      ))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
      CAST(MachineID AS VARCHAR(100)) AS MachineID,
      CAST(Source    AS VARCHAR(100)) AS Source,
      CAST(MillID    AS VARCHAR(100)) AS MillID,
      CAST(Type      AS VARCHAR(100)) AS Type,
      TRY_CONVERT(DATE, CommissionDate) AS CommissionDate,
      TRY_CAST(RatedKW AS FLOAT) AS RatedKW
    FROM stg.Machines
  )
  INSERT INTO dbo.DimMachine (SurrogateKey, MachineID, Source, MillID, Type, CommissionDate, RatedKW)
  SELECT S.SurrogateKey, S.MachineID, S.Source, S.MillID, S.Type, S.CommissionDate, S.RatedKW
  FROM S
  LEFT JOIN dbo.DimMachine T ON T.MachineID=S.MachineID AND T.Source=S.Source
  WHERE T.MachineID IS NULL;
END


IF OBJECT_ID('stg.Employees','V') IS NOT NULL
BEGIN
  -- UPDATE
  ;WITH S AS (
    SELECT DISTINCT
      (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256',
        CONCAT(CAST(EmployeeID AS VARCHAR(100)),'|',CAST(Source AS VARCHAR(100)))
      ))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
      CAST(EmployeeID AS VARCHAR(100)) AS EmployeeID,
      CAST(Source     AS VARCHAR(100)) AS Source,
      CAST(FullName   AS VARCHAR(200)) AS FullName,
      CAST(email      AS VARCHAR(200)) AS Email,
      CAST(Department AS VARCHAR(100)) AS Department,
      TRY_CONVERT(DATE, HireDate) AS HireDate
    FROM stg.Employees
  )
  UPDATE T SET
    T.SurrogateKey=S.SurrogateKey,
    T.FullName=S.FullName,
    T.Email=S.Email,
    T.Department=S.Department,
    T.HireDate=S.HireDate
  FROM dbo.DimEmployee AS T
  JOIN S ON T.EmployeeID=S.EmployeeID AND T.Source=S.Source;

  -- INSERT
  ;WITH S AS (
    SELECT DISTINCT
      (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256',
        CONCAT(CAST(EmployeeID AS VARCHAR(100)),'|',CAST(Source AS VARCHAR(100)))
      ))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
      CAST(EmployeeID AS VARCHAR(100)) AS EmployeeID,
      CAST(Source     AS VARCHAR(100)) AS Source,
      CAST(FullName   AS VARCHAR(200)) AS FullName,
      CAST(email      AS VARCHAR(200)) AS Email,
      CAST(Department AS VARCHAR(100)) AS Department,
      TRY_CONVERT(DATE, HireDate) AS HireDate
    FROM stg.Employees
  )
  INSERT INTO dbo.DimEmployee (SurrogateKey, EmployeeID, Source, FullName, Email, Department, HireDate)
  SELECT S.SurrogateKey, S.EmployeeID, S.Source, S.FullName, S.Email, S.Department, S.HireDate
  FROM S
  LEFT JOIN dbo.DimEmployee T ON T.EmployeeID=S.EmployeeID AND T.Source=S.Source
  WHERE T.EmployeeID IS NULL;
END


-- UPDATE
;WITH D AS (
  SELECT CAST(OrderDate AS DATE) AS [date] FROM stg.Orders        WHERE OrderDate IS NOT NULL
  UNION SELECT CAST([Date] AS DATE) FROM stg.Shipments            WHERE [Date] IS NOT NULL
  UNION SELECT CAST([Date] AS DATE) FROM stg.StockMovements       WHERE [Date] IS NOT NULL
  -- UNION SELECT CAST(ProdDate AS DATE) FROM stg.PlannedProductions WHERE ProdDate IS NOT NULL
),
S AS (
  SELECT DISTINCT
    CONVERT(INT, FORMAT([date],'yyyyMMdd')) AS DateSK,
    [date] AS [Date],
    DATEPART(YEAR,[date])    AS [Year],
    DATEPART(MONTH,[date])   AS [Month],
    DATEPART(DAY,[date])     AS [Day],
    DATEPART(QUARTER,[date]) AS [Quarter]
  FROM D
)
UPDATE T SET
  T.DateSK=S.DateSK, T.[Year]=S.[Year], T.[Month]=S.[Month], T.[Day]=S.[Day], T.[Quarter]=S.[Quarter]
FROM dbo.DimDate AS T
JOIN S ON T.[Date]=S.[Date];

-- INSERT
;WITH D AS (
  SELECT CAST(OrderDate AS DATE) AS [date] FROM stg.Orders        WHERE OrderDate IS NOT NULL
  UNION SELECT CAST([Date] AS DATE) FROM stg.Shipments            WHERE [Date] IS NOT NULL
  UNION SELECT CAST([Date] AS DATE) FROM stg.StockMovements       WHERE [Date] IS NOT NULL
),
S AS (
  SELECT DISTINCT
    CONVERT(INT, FORMAT([date],'yyyyMMdd')) AS DateSK,
    [date] AS [Date],
    DATEPART(YEAR,[date])    AS [Year],
    DATEPART(MONTH,[date])   AS [Month],
    DATEPART(DAY,[date])     AS [Day],
    DATEPART(QUARTER,[date]) AS [Quarter]
  FROM D
)
INSERT INTO dbo.DimDate (DateSK,[Date],[Year],[Month],[Day],[Quarter])
SELECT S.DateSK, S.[Date], S.[Year], S.[Month], S.[Day], S.[Quarter]
FROM S
LEFT JOIN dbo.DimDate T ON T.[Date]=S.[Date]
WHERE T.[Date] IS NULL;




--FACTS
--FactOrders

-- UPDATE
;WITH S0 AS (
  SELECT
    d.DateSK,
    p.SurrogateKey AS ProductSK,
    c.SurrogateKey AS CustomerSK,
    CAST(o.Source AS VARCHAR(100)) AS Source,
    CAST(o.QuantityPallets AS FLOAT) AS OrderedPallets,
    CAST(o.QuantityPallets AS FLOAT) /
      NULLIF(CASE WHEN p.PalletsToTon IS NULL OR p.PalletsToTon=0 THEN 1.0 ELSE p.PalletsToTon END, 0) AS OrderedTons,
    CONCAT(CAST(o.OrderID AS VARCHAR(100)),'|',CAST(o.ProductID AS VARCHAR(100)),'|',COALESCE(CAST(o.Source AS VARCHAR(100)),'')) AS NK_str
  FROM stg.Orders o
  JOIN dbo.DimProduct  p ON p.ProductID=o.ProductID AND p.Source=o.Source
  LEFT JOIN dbo.DimCustomer c ON c.CustomerID=o.CustomerID AND c.Source=o.Source
  JOIN dbo.DimDate d ON d.[Date]=CAST(o.OrderDate AS DATE)
),
S AS (
  SELECT
    CONVERT(CHAR(64), HASHBYTES('SHA2_256', NK_str), 2) AS NaturalKey,
    (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256', NK_str))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
    DateSK, ProductSK, CustomerSK, Source, OrderedPallets, OrderedTons
  FROM S0
)
UPDATE T SET
  T.DateSK=S.DateSK, T.ProductSK=S.ProductSK, T.CustomerSK=S.CustomerSK,
  T.Source=S.Source, T.OrderedPallets=S.OrderedPallets, T.OrderedTons=S.OrderedTons,
  T.SurrogateKey=S.SurrogateKey
FROM dbo.FactOrders AS T
JOIN S ON T.NaturalKey=S.NaturalKey;

-- INSERT
;WITH S0 AS (
  SELECT
    d.DateSK,
    p.SurrogateKey AS ProductSK,
    c.SurrogateKey AS CustomerSK,
    CAST(o.Source AS VARCHAR(100)) AS Source,
    CAST(o.QuantityPallets AS FLOAT) AS OrderedPallets,
    CAST(o.QuantityPallets AS FLOAT) /
      NULLIF(CASE WHEN p.PalletsToTon IS NULL OR p.PalletsToTon=0 THEN 1.0 ELSE p.PalletsToTon END, 0) AS OrderedTons,
    CONCAT(CAST(o.OrderID AS VARCHAR(100)),'|',CAST(o.ProductID AS VARCHAR(100)),'|',COALESCE(CAST(o.Source AS VARCHAR(100)),'')) AS NK_str
  FROM stg.Orders o
  JOIN dbo.DimProduct  p ON p.ProductID=o.ProductID AND p.Source=o.Source
  LEFT JOIN dbo.DimCustomer c ON c.CustomerID=o.CustomerID AND c.Source=o.Source
  JOIN dbo.DimDate d ON d.[Date]=CAST(o.OrderDate AS DATE)
),
S AS (
  SELECT
    CONVERT(CHAR(64), HASHBYTES('SHA2_256', NK_str), 2) AS NaturalKey,
    (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256', NK_str))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
    DateSK, ProductSK, CustomerSK, Source, OrderedPallets, OrderedTons
  FROM S0
)
INSERT INTO dbo.FactOrders
 (SurrogateKey, NaturalKey, DateSK, ProductSK, CustomerSK, Source, OrderedPallets, OrderedTons)
SELECT S.SurrogateKey, S.NaturalKey, S.DateSK, S.ProductSK, S.CustomerSK, S.Source, S.OrderedPallets, S.OrderedTons
FROM S
LEFT JOIN dbo.FactOrders T ON T.NaturalKey=S.NaturalKey
WHERE T.NaturalKey IS NULL;

-- FactShipments
-- UPDATE
;WITH S0 AS (
  SELECT
    d.DateSK,
    p.SurrogateKey AS ProductSK,
    w.SurrogateKey AS WarehouseSK,
    CAST(s.Source AS VARCHAR(100)) AS Source,
    CAST(s.Pallets AS FLOAT) AS ShippedPallets,
    CAST(s.Pallets AS FLOAT) /
      NULLIF(CASE WHEN p.PalletsToTon IS NULL OR p.PalletsToTon=0 THEN 1.0 ELSE p.PalletsToTon END, 0) AS ShippedTons,
    CONCAT(CAST(s.ShipmentID AS VARCHAR(100)),'|',CAST(s.ProductID AS VARCHAR(100)),'|',
           CAST(s.WarehouseID AS VARCHAR(100)),'|',COALESCE(CAST(s.Source AS VARCHAR(100)),'')) AS NK_str
  FROM stg.Shipments s
  JOIN dbo.DimProduct   p ON p.ProductID=s.ProductID AND p.Source=s.Source
  JOIN dbo.DimWarehouse w ON w.WarehouseID=s.WarehouseID AND w.Source=s.Source
  JOIN dbo.DimDate      d ON d.[Date]=CAST(s.[Date] AS DATE)
),
S AS (
  SELECT
    CONVERT(CHAR(64), HASHBYTES('SHA2_256', NK_str), 2) AS NaturalKey,
    (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256', NK_str))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
    DateSK, ProductSK, WarehouseSK, Source, ShippedPallets, ShippedTons
  FROM S0
)
UPDATE T SET
  T.DateSK=S.DateSK, T.ProductSK=S.ProductSK, T.WarehouseSK=S.WarehouseSK,
  T.Source=S.Source, T.ShippedPallets=S.ShippedPallets, T.ShippedTons=S.ShippedTons,
  T.SurrogateKey=S.SurrogateKey
FROM dbo.FactShipments AS T
JOIN S ON T.NaturalKey=S.NaturalKey;

-- INSERT
;WITH S0 AS (
  SELECT
    d.DateSK,
    p.SurrogateKey AS ProductSK,
    w.SurrogateKey AS WarehouseSK,
    CAST(s.Source AS VARCHAR(100)) AS Source,
    CAST(s.Pallets AS FLOAT) AS ShippedPallets,
    CAST(s.Pallets AS FLOAT) /
      NULLIF(CASE WHEN p.PalletsToTon IS NULL OR p.PalletsToTon=0 THEN 1.0 ELSE p.PalletsToTon END, 0) AS ShippedTons,
    CONCAT(CAST(s.ShipmentID AS VARCHAR(100)),'|',CAST(s.ProductID AS VARCHAR(100)),'|',
           CAST(s.WarehouseID AS VARCHAR(100)),'|',COALESCE(CAST(s.Source AS VARCHAR(100)),'')) AS NK_str
  FROM stg.Shipments s
  JOIN dbo.DimProduct   p ON p.ProductID=s.ProductID AND p.Source=s.Source
  JOIN dbo.DimWarehouse w ON w.WarehouseID=s.WarehouseID AND w.Source=s.Source
  JOIN dbo.DimDate      d ON d.[Date]=CAST(s.[Date] AS DATE)
),
S AS (
  SELECT
    CONVERT(CHAR(64), HASHBYTES('SHA2_256', NK_str), 2) AS NaturalKey,
    (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256', NK_str))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
    DateSK, ProductSK, WarehouseSK, Source, ShippedPallets, ShippedTons
  FROM S0
)
INSERT INTO dbo.FactShipments
 (SurrogateKey, NaturalKey, DateSK, ProductSK, WarehouseSK, Source, ShippedPallets, ShippedTons)
SELECT S.SurrogateKey, S.NaturalKey, S.DateSK, S.ProductSK, S.WarehouseSK, S.Source, S.ShippedPallets, S.ShippedTons
FROM S
LEFT JOIN dbo.FactShipments T ON T.NaturalKey=S.NaturalKey
WHERE T.NaturalKey IS NULL;


-- FactDailyFillRate
-- UPDATE
;WITH o AS (
  SELECT CAST(o.OrderDate AS DATE) AS [date],
         SUM(CAST(o.QuantityPallets AS FLOAT) /
             NULLIF(CASE WHEN p.PalletsToTon IS NULL OR p.PalletsToTon=0 THEN 1.0 ELSE p.PalletsToTon END,0)) AS OrderedTons
  FROM stg.Orders o
  JOIN dbo.DimProduct p ON p.ProductID=o.ProductID AND p.Source=o.Source
  GROUP BY CAST(o.OrderDate AS DATE)
),
sh AS (
  SELECT CAST(s.[Date] AS DATE) AS [date],
         SUM(CAST(s.Pallets AS FLOAT) /
             NULLIF(CASE WHEN p.PalletsToTon IS NULL OR p.PalletsToTon=0 THEN 1.0 ELSE p.PalletsToTon END,0)) AS ShippedTons
  FROM stg.Shipments s
  JOIN dbo.DimProduct p ON p.ProductID=s.ProductID AND p.Source=s.Source
  GROUP BY CAST(s.[Date] AS DATE)
),
fr AS (
  SELECT COALESCE(o.[date], sh.[date]) AS [date],
         COALESCE(o.OrderedTons,0.0) AS OrderedTons,
         COALESCE(sh.ShippedTons,0.0) AS ShippedTons
  FROM o FULL JOIN sh ON o.[date]=sh.[date]
),
S0 AS (
  SELECT d.DateSK,
         f.OrderedTons, f.ShippedTons,
         CASE WHEN f.OrderedTons>0 THEN f.ShippedTons/f.OrderedTons ELSE 0 END AS FillRate,
         CONVERT(VARCHAR(30), d.[Date], 23) AS NK_str
  FROM fr f
  JOIN dbo.DimDate d ON d.[Date]=f.[date]
),
S AS (
  SELECT
    CONVERT(CHAR(64), HASHBYTES('SHA2_256', NK_str), 2) AS NaturalKey,
    (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256', NK_str))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
    DateSK, OrderedTons, ShippedTons,
    CASE WHEN OrderedTons>0 THEN ShippedTons/OrderedTons ELSE 0 END AS FillRate
  FROM S0
)
UPDATE T SET
  T.DateSK=S.DateSK, T.OrderedTons=S.OrderedTons, T.ShippedTons=S.ShippedTons, T.FillRate=S.FillRate,
  T.SurrogateKey=S.SurrogateKey
FROM dbo.FactDailyFillRate AS T
JOIN S ON T.NaturalKey=S.NaturalKey;

-- INSERT
;WITH o AS (
  SELECT CAST(o.OrderDate AS DATE) AS [date],
         SUM(CAST(o.QuantityPallets AS FLOAT) /
             NULLIF(CASE WHEN p.PalletsToTon IS NULL OR p.PalletsToTon=0 THEN 1.0 ELSE p.PalletsToTon END,0)) AS OrderedTons
  FROM stg.Orders o
  JOIN dbo.DimProduct p ON p.ProductID=o.ProductID AND p.Source=o.Source
  GROUP BY CAST(o.OrderDate AS DATE)
),
sh AS (
  SELECT CAST(s.[Date] AS DATE) AS [date],
         SUM(CAST(s.Pallets AS FLOAT) /
             NULLIF(CASE WHEN p.PalletsToTon IS NULL OR p.PalletsToTon=0 THEN 1.0 ELSE p.PalletsToTon END,0)) AS ShippedTons
  FROM stg.Shipments s
  JOIN dbo.DimProduct p ON p.ProductID=s.ProductID AND p.Source=s.Source
  GROUP BY CAST(s.[Date] AS DATE)
),
fr AS (
  SELECT COALESCE(o.[date], sh.[date]) AS [date],
         COALESCE(o.OrderedTons,0.0) AS OrderedTons,
         COALESCE(sh.ShippedTons,0.0) AS ShippedTons
  FROM o FULL JOIN sh ON o.[date]=sh.[date]
),
S0 AS (
  SELECT d.DateSK,
         f.OrderedTons, f.ShippedTons,
         CASE WHEN f.OrderedTons>0 THEN f.ShippedTons/f.OrderedTons ELSE 0 END AS FillRate,
         CONVERT(VARCHAR(30), d.[Date], 23) AS NK_str
  FROM fr f
  JOIN dbo.DimDate d ON d.[Date]=f.[date]
),
S AS (
  SELECT
    CONVERT(CHAR(64), HASHBYTES('SHA2_256', NK_str), 2) AS NaturalKey,
    (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256', NK_str))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
    DateSK, OrderedTons, ShippedTons,
    CASE WHEN OrderedTons>0 THEN ShippedTons/OrderedTons ELSE 0 END AS FillRate
  FROM S0
)
INSERT INTO dbo.FactDailyFillRate
 (SurrogateKey, NaturalKey, DateSK, OrderedTons, ShippedTons, FillRate)
SELECT S.SurrogateKey, S.NaturalKey, S.DateSK, S.OrderedTons, S.ShippedTons, S.FillRate
FROM S
LEFT JOIN dbo.FactDailyFillRate T ON T.NaturalKey=S.NaturalKey
WHERE T.NaturalKey IS NULL;



--- FactWarehouseDailyUtilization

-- UPDATE
;WITH rec AS (
  SELECT CAST(m.[Date] AS DATE) AS [Date], CAST(m.ToID AS VARCHAR(100)) AS WarehouseID,
         CAST(m.Source AS VARCHAR(100)) AS Source,
         SUM(CAST(m.Pallets AS FLOAT)) AS receipts_pallets
  FROM stg.StockMovements m
  WHERE m.ToType='Warehouse'
  GROUP BY CAST(m.[Date] AS DATE), m.ToID, m.Source
),
shp AS (
  SELECT CAST(m.[Date] AS DATE) AS [Date], CAST(m.FromID AS VARCHAR(100)) AS WarehouseID,
         CAST(m.Source AS VARCHAR(100)) AS Source,
         SUM(CAST(m.Pallets AS FLOAT)) AS shipments_pallets
  FROM stg.StockMovements m
  WHERE m.FromType='Warehouse'
  GROUP BY CAST(m.[Date] AS DATE), m.FromID, m.Source
),
daily AS (
  SELECT COALESCE(r.[Date], s.[Date]) AS [Date],
         COALESCE(r.WarehouseID, s.WarehouseID) AS WarehouseID,
         COALESCE(r.Source, s.Source) AS Source,
         COALESCE(r.receipts_pallets,0.0)  AS receipts_pallets,
         COALESCE(s.shipments_pallets,0.0) AS shipments_pallets,
         COALESCE(r.receipts_pallets,0.0) - COALESCE(s.shipments_pallets,0.0) AS delta_pallets
  FROM rec r FULL JOIN shp s
    ON r.[Date]=s.[Date] AND r.WarehouseID=s.WarehouseID AND r.Source=s.Source
),
eod AS (
  SELECT
    d.[Date], d.WarehouseID, d.Source,
    SUM(d.delta_pallets) OVER (PARTITION BY d.WarehouseID, d.Source ORDER BY d.[Date] ROWS UNBOUNDED PRECEDING) AS pallets_occupied
  FROM daily d
),
S0 AS (
  SELECT
    dt.DateSK,
    w.SurrogateKey AS WarehouseSK,
    e.Source,
    CAST(CASE WHEN e.pallets_occupied < 0 THEN 0 ELSE e.pallets_occupied END AS FLOAT) AS PalletsOccupied,
    CAST(COALESCE(w.CapacityPallets,0) AS FLOAT) AS CapacityPallets,
    CAST(CASE WHEN COALESCE(w.CapacityPallets,0)>0
              THEN (CASE WHEN e.pallets_occupied<0 THEN 0 ELSE e.pallets_occupied END)/w.CapacityPallets
              ELSE 0 END AS FLOAT) AS Utilization,
    CONCAT(CONVERT(VARCHAR(30), dt.[Date], 23),'|',CAST(w.WarehouseID AS VARCHAR(100)),'|',COALESCE(e.Source,'')) AS NK_str
  FROM eod e
  JOIN dbo.DimWarehouse w ON w.WarehouseID=e.WarehouseID AND w.Source=e.Source
  JOIN dbo.DimDate dt     ON dt.[Date]=e.[Date]
),
S AS (
  SELECT
    CONVERT(CHAR(64), HASHBYTES('SHA2_256', NK_str), 2) AS NaturalKey,
    (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256', NK_str))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
    DateSK, WarehouseSK, Source, PalletsOccupied, CapacityPallets, Utilization
  FROM S0
)
UPDATE T SET
  T.DateSK=S.DateSK, T.WarehouseSK=S.WarehouseSK, T.Source=S.Source,
  T.PalletsOccupied=S.PalletsOccupied, T.CapacityPallets=S.CapacityPallets, T.Utilization=S.Utilization,
  T.SurrogateKey=S.SurrogateKey
FROM dbo.FactWarehouseDailyUtilization AS T
JOIN S ON T.NaturalKey=S.NaturalKey;

-- INSERT
;WITH rec AS (
  SELECT CAST(m.[Date] AS DATE) AS [Date], CAST(m.ToID AS VARCHAR(100)) AS WarehouseID,
         CAST(m.Source AS VARCHAR(100)) AS Source,
         SUM(CAST(m.Pallets AS FLOAT)) AS receipts_pallets
  FROM stg.StockMovements m
  WHERE m.ToType='Warehouse'
  GROUP BY CAST(m.[Date] AS DATE), m.ToID, m.Source
),
shp AS (
  SELECT CAST(m.[Date] AS DATE) AS [Date], CAST(m.FromID AS VARCHAR(100)) AS WarehouseID,
         CAST(m.Source AS VARCHAR(100)) AS Source,
         SUM(CAST(m.Pallets AS FLOAT)) AS shipments_pallets
  FROM stg.StockMovements m
  WHERE m.FromType='Warehouse'
  GROUP BY CAST(m.[Date] AS DATE), m.FromID, m.Source
),
daily AS (
  SELECT COALESCE(r.[Date], s.[Date]) AS [Date],
         COALESCE(r.WarehouseID, s.WarehouseID) AS WarehouseID,
         COALESCE(r.Source, s.Source) AS Source,
         COALESCE(r.receipts_pallets,0.0)  AS receipts_pallets,
         COALESCE(s.shipments_pallets,0.0) AS shipments_pallets,
         COALESCE(r.receipts_pallets,0.0) - COALESCE(s.shipments_pallets,0.0) AS delta_pallets
  FROM rec r FULL JOIN shp s
    ON r.[Date]=s.[Date] AND r.WarehouseID=s.WarehouseID AND r.Source=s.Source
),
eod AS (
  SELECT
    d.[Date], d.WarehouseID, d.Source,
    SUM(d.delta_pallets) OVER (PARTITION BY d.WarehouseID, d.Source ORDER BY d.[Date] ROWS UNBOUNDED PRECEDING) AS pallets_occupied
  FROM daily d
),
S0 AS (
  SELECT
    dt.DateSK,
    w.SurrogateKey AS WarehouseSK,
    e.Source,
    CAST(CASE WHEN e.pallets_occupied < 0 THEN 0 ELSE e.pallets_occupied END AS FLOAT) AS PalletsOccupied,
    CAST(COALESCE(w.CapacityPallets,0) AS FLOAT) AS CapacityPallets,
    CAST(CASE WHEN COALESCE(w.CapacityPallets,0)>0
              THEN (CASE WHEN e.pallets_occupied<0 THEN 0 ELSE e.pallets_occupied END)/w.CapacityPallets
              ELSE 0 END AS FLOAT) AS Utilization,
    CONCAT(CONVERT(VARCHAR(30), dt.[Date], 23),'|',CAST(w.WarehouseID AS VARCHAR(100)),'|',COALESCE(e.Source,'')) AS NK_str
  FROM eod e
  JOIN dbo.DimWarehouse w ON w.WarehouseID=e.WarehouseID AND w.Source=e.Source
  JOIN dbo.DimDate dt     ON dt.[Date]=e.[Date]
),
S AS (
  SELECT
    CONVERT(CHAR(64), HASHBYTES('SHA2_256', NK_str), 2) AS NaturalKey,
    (CONVERT(BIGINT, CONVERT(VARBINARY(8), HASHBYTES('SHA2_256', NK_str))) & CAST(9223372036854775807 AS BIGINT)) AS SurrogateKey,
    DateSK, WarehouseSK, Source, PalletsOccupied, CapacityPallets, Utilization
  FROM S0
)
INSERT INTO dbo.FactWarehouseDailyUtilization
 (SurrogateKey, NaturalKey, DateSK, WarehouseSK, Source, PalletsOccupied, CapacityPallets, Utilization)
SELECT S.SurrogateKey, S.NaturalKey, S.DateSK, S.WarehouseSK, S.Source, S.PalletsOccupied, S.CapacityPallets, S.Utilization
FROM S
LEFT JOIN dbo.FactWarehouseDailyUtilization T ON T.NaturalKey=S.NaturalKey
WHERE T.NaturalKey IS NULL;

