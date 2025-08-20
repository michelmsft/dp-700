--CREATE SCHEMA prod;



-- ========================================
-- prod.DimCustomers (SCD Type 2)
-- ========================================
CREATE TABLE prod.DimCustomers (
    CustomerSK BIGINT NOT NULL,
    CustomerID VARCHAR(50) NOT NULL,
    CompanyName VARCHAR(200),
    Contact VARCHAR(200),
    Email VARCHAR(200),
    Phone BIGINT,
    Industry VARCHAR(100),
    AccountCreated DATE,
    IsActive INT,
    Source VARCHAR(100),
    ValidFrom DATE NOT NULL,
    ValidTo DATE NOT NULL,
    IsCurrent BIT NOT NULL
);

ALTER TABLE prod.DimCustomers
ADD CONSTRAINT PK_DimCustomers PRIMARY KEY NONCLUSTERED (CustomerSK) NOT ENFORCED;

ALTER TABLE prod.DimCustomers
ADD CONSTRAINT AK_DimCustomers UNIQUE NONCLUSTERED (CustomerID, ValidFrom) NOT ENFORCED;

-- ========================================
-- prod.DimEmployees (SCD Type 2)
-- ========================================
CREATE TABLE prod.DimEmployees (
    EmployeeSK BIGINT NOT NULL,
    EmployeeID VARCHAR(50) NOT NULL,
    FullName VARCHAR(200),
    Email VARCHAR(200),
    Phone BIGINT,
    Domain VARCHAR(100),
    Department VARCHAR(100),
    Title VARCHAR(100),
    HireDate DATE,
    EmploymentType VARCHAR(100),
    IsActive INT,
    Source VARCHAR(100),
    ValidFrom DATE NOT NULL,
    ValidTo DATE NOT NULL,
    IsCurrent BIT NOT NULL
);

ALTER TABLE prod.DimEmployees
ADD CONSTRAINT PK_DimEmployees PRIMARY KEY NONCLUSTERED (EmployeeSK) NOT ENFORCED;

ALTER TABLE prod.DimEmployees
ADD CONSTRAINT AK_DimEmployees UNIQUE NONCLUSTERED (EmployeeID, ValidFrom) NOT ENFORCED;

-- ========================================
-- prod.DimProducts (SCD Type 2)
-- ========================================
CREATE TABLE prod.DimProducts (
    ProductSK BIGINT NOT NULL,
    ProductID VARCHAR(50) NOT NULL,
    Brand VARCHAR(100),
    ProductName VARCHAR(200),
    BasisWeight INT,
    Brightness INT,
    Certification VARCHAR(100),
    PalletsToTon FLOAT,
    Source VARCHAR(100),
    ValidFrom DATE NOT NULL,
    ValidTo DATE NOT NULL,
    IsCurrent BIT NOT NULL
);

ALTER TABLE prod.DimProducts
ADD CONSTRAINT PK_DimProducts PRIMARY KEY NONCLUSTERED (ProductSK) NOT ENFORCED;

ALTER TABLE prod.DimProducts
ADD CONSTRAINT AK_DimProducts UNIQUE NONCLUSTERED (ProductID, ValidFrom) NOT ENFORCED;

-- ========================================
-- prod.DimMachines (SCD Type 2)
-- ========================================
CREATE TABLE prod.DimMachines (
    MachineSK BIGINT NOT NULL,
    MachineID VARCHAR(50) NOT NULL,
    MillID VARCHAR(50),
    Type VARCHAR(100),
    CommissionDate DATE,
    RatedKW INT,
    Source VARCHAR(100),
    ValidFrom DATE NOT NULL,
    ValidTo DATE NOT NULL,
    IsCurrent BIT NOT NULL
);

ALTER TABLE prod.DimMachines
ADD CONSTRAINT PK_DimMachines PRIMARY KEY NONCLUSTERED (MachineSK) NOT ENFORCED;

ALTER TABLE prod.DimMachines
ADD CONSTRAINT AK_DimMachines UNIQUE NONCLUSTERED (MachineID, ValidFrom) NOT ENFORCED;

-- ========================================
-- prod.DimWarehouses (SCD Type 2)
-- ========================================
CREATE TABLE prod.DimWarehouses (
    WarehouseSK BIGINT NOT NULL,
    WarehouseID VARCHAR(50) NOT NULL,
    WarehouseName VARCHAR(200),
    Region VARCHAR(100),
    Type VARCHAR(50),
    AssignedMillID VARCHAR(50),
    CapacityPallets INT,
    Source VARCHAR(100),
    ValidFrom DATE NOT NULL,
    ValidTo DATE NOT NULL,
    IsCurrent BIT NOT NULL
);

ALTER TABLE prod.DimWarehouses
ADD CONSTRAINT PK_DimWarehouses PRIMARY KEY NONCLUSTERED (WarehouseSK) NOT ENFORCED;

ALTER TABLE prod.DimWarehouses
ADD CONSTRAINT AK_DimWarehouses UNIQUE NONCLUSTERED (WarehouseID, ValidFrom) NOT ENFORCED;

-- ========================================
-- prod.DimMills (SCD Type 2)
-- ========================================
CREATE TABLE prod.DimMills (
    MillSK BIGINT NOT NULL,
    MillID VARCHAR(50) NOT NULL,
    Name VARCHAR(200),
    ProductionTonsCapacity INT,
    Source VARCHAR(100),
    ValidFrom DATE NOT NULL,
    ValidTo DATE NOT NULL,
    IsCurrent BIT NOT NULL
);

ALTER TABLE prod.DimMills
ADD CONSTRAINT PK_DimMills PRIMARY KEY NONCLUSTERED (MillSK) NOT ENFORCED;

ALTER TABLE prod.DimMills
ADD CONSTRAINT AK_DimMills UNIQUE NONCLUSTERED (MillID, ValidFrom) NOT ENFORCED;



-- ========================================
-- prod.DimDate (NON - SCD)
-- ========================================

CREATE TABLE prod.DimDate (
    DateSK INT NOT NULL,               -- Format: YYYYMMDD (e.g., 20250818)
    FullDate DATE NOT NULL,            -- ISO date
    DayOfMonth SMALLINT NOT NULL,       -- 1-31
    MonthName VARCHAR(20) NOT NULL,    -- January, February...
    MonthNumber SMALLINT NOT NULL,      -- 1-12
    Quarter SMALLINT NOT NULL,          -- 1-4
    Year SMALLINT NOT NULL,            -- e.g., 2025
    WeekOfYear SMALLINT NOT NULL,       -- 1-53
    DayOfWeek SMALLINT NOT NULL,        -- 1=Monday ... 7=Sunday
    DayName VARCHAR(20) NOT NULL,      -- Monday, Tuesday...
    IsWeekend BIT NOT NULL,            -- 1 if Sat/Sun
    IsHoliday BIT NOT NULL,            -- Optional: default 0
    FiscalMonth SMALLINT,               -- Optional: if fiscal calendar applies
    FiscalQuarter SMALLINT,
    FiscalYear SMALLINT,
    Source VARCHAR(100)                -- Optional: 'Generated'
);

ALTER TABLE prod.DimDate
ADD CONSTRAINT PK_DimDate PRIMARY KEY NONCLUSTERED (DateSK) NOT ENFORCED;


-- Step 1: Generate sequence of numbers using cross joins
WITH N1 AS (
    SELECT 0 AS n UNION ALL SELECT 1
),
N2 AS (
    SELECT a.n + b.n * 2 AS n
    FROM N1 a CROSS JOIN N1 b
),
N3 AS (
    SELECT a.n + b.n * 4 AS n
    FROM N2 a CROSS JOIN N2 b
),
N4 AS (
    SELECT a.n + b.n * 16 AS n
    FROM N3 a CROSS JOIN N3 b
),
N5 AS (
    SELECT a.n + b.n * 256 AS n
    FROM N4 a CROSS JOIN N4 b
),
Numbers AS (
    SELECT TOP (DATEDIFF(DAY, '2015-01-01', '2035-12-31') + 1)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
    FROM N5
),
DateSequence AS (
    SELECT DATEADD(DAY, n, CAST('2015-01-01' AS DATE)) AS FullDate
    FROM Numbers
)
INSERT INTO prod.DimDate (
    DateSK, FullDate, DayOfMonth, MonthName, MonthNumber,
    Quarter, Year, WeekOfYear, DayOfWeek, DayName,
    IsWeekend, IsHoliday, FiscalMonth, FiscalQuarter, FiscalYear, Source
)
SELECT
    CAST(FORMAT(FullDate, 'yyyyMMdd') AS INT) AS DateSK,
    FullDate,
    DATEPART(DAY, FullDate) AS DayOfMonth,
    DATENAME(MONTH, FullDate) AS MonthName,
    DATEPART(MONTH, FullDate) AS MonthNumber,
    DATEPART(QUARTER, FullDate) AS Quarter,
    DATEPART(YEAR, FullDate) AS Year,
    DATEPART(WEEK, FullDate) AS WeekOfYear,
    DATEPART(WEEKDAY, FullDate) AS DayOfWeek,
    DATENAME(WEEKDAY, FullDate) AS DayName,
    CASE WHEN DATENAME(WEEKDAY, FullDate) IN ('Saturday', 'Sunday') THEN 1 ELSE 0 END AS IsWeekend,
    0 AS IsHoliday,
    NULL AS FiscalMonth,
    NULL AS FiscalQuarter,
    NULL AS FiscalYear,
    'Generated' AS Source
FROM DateSequence;


DROP TABLE IF EXISTS prod.FactMachineSensors;
DROP TABLE IF EXISTS prod.FactMachineDowntime;
DROP TABLE IF EXISTS prod.FactStockMovements;
DROP TABLE IF EXISTS prod.FactPlannedProduction;
DROP TABLE IF EXISTS prod.FactShipments;
DROP TABLE IF EXISTS prod.FactOrders;
GO



-- ========================================
-- prod.FactOrder
-- ========================================

CREATE TABLE prod.FactOrders (
    OrderSK BIGINT NOT NULL,
    OrderID VARCHAR(50) NOT NULL,
    OrderDate DATE NOT NULL,
    DateSK INT NOT NULL,
    CustomerSK BIGINT NOT NULL,
    ProductSK BIGINT NOT NULL,
    QuantityPallets INT,
    Source VARCHAR(100)
);

ALTER TABLE prod.FactOrders
ADD CONSTRAINT PK_FactOrders PRIMARY KEY NONCLUSTERED (OrderSK) NOT ENFORCED;

ALTER TABLE prod.FactOrders
ADD CONSTRAINT AK_FactOrders UNIQUE NONCLUSTERED (OrderID) NOT ENFORCED;

ALTER TABLE prod.FactOrders
ADD CONSTRAINT FK_FactOrders_Date FOREIGN KEY (DateSK) REFERENCES prod.DimDate(DateSK) NOT ENFORCED;

ALTER TABLE prod.FactOrders
ADD CONSTRAINT FK_FactOrders_Customer FOREIGN KEY (CustomerSK) REFERENCES prod.DimCustomers(CustomerSK) NOT ENFORCED;

ALTER TABLE prod.FactOrders
ADD CONSTRAINT FK_FactOrders_Product FOREIGN KEY (ProductSK) REFERENCES prod.DimProducts(ProductSK) NOT ENFORCED;

-- ========================================
-- prod.FactShipments
-- ========================================

CREATE TABLE prod.FactShipments (
    ShipmentSK BIGINT NOT NULL,
    ShipmentID VARCHAR(50) NOT NULL,
    Date DATE NOT NULL,
    DateSK INT NOT NULL,
    WarehouseSK BIGINT NOT NULL,
    OrderSK BIGINT NOT NULL,
    ProductSK BIGINT NOT NULL,
    Pallets INT,
    Source VARCHAR(100)
);

ALTER TABLE prod.FactShipments
ADD CONSTRAINT PK_FactShipments PRIMARY KEY NONCLUSTERED (ShipmentSK) NOT ENFORCED;

ALTER TABLE prod.FactShipments
ADD CONSTRAINT AK_FactShipments UNIQUE NONCLUSTERED (ShipmentID) NOT ENFORCED;

ALTER TABLE prod.FactShipments
ADD CONSTRAINT FK_FactShipments_Date FOREIGN KEY (DateSK) REFERENCES prod.DimDate(DateSK) NOT ENFORCED;

ALTER TABLE prod.FactShipments
ADD CONSTRAINT FK_FactShipments_Warehouse FOREIGN KEY (WarehouseSK) REFERENCES prod.DimWarehouses(WarehouseSK) NOT ENFORCED;

ALTER TABLE prod.FactShipments
ADD CONSTRAINT FK_FactShipments_Product FOREIGN KEY (ProductSK) REFERENCES prod.DimProducts(ProductSK) NOT ENFORCED;


ALTER TABLE prod.FactShipments
ADD CONSTRAINT FK_FactShipments_Order FOREIGN KEY (OrderSK) REFERENCES prod.FactOrders(OrderSK) NOT ENFORCED;

-- ========================================
-- prod.FactPlannedProduction
-- ========================================


CREATE TABLE prod.FactPlannedProduction (
    ProductionSK BIGINT NOT NULL,
    PlanID VARCHAR(50) NOT NULL,
    ProdDate DATE NOT NULL,
    DateSK INT NOT NULL,
    MillSK BIGINT NOT NULL,
    ProductSK BIGINT NOT NULL,
    Pallets INT,
    Tons FLOAT,
    EnergyMWh FLOAT,
    WaterM3 FLOAT,
    EmissionsKgCO2e INT,
    Source VARCHAR(100)
);

ALTER TABLE prod.FactPlannedProduction
ADD CONSTRAINT PK_FactPlannedProduction PRIMARY KEY NONCLUSTERED (ProductionSK) NOT ENFORCED;

ALTER TABLE prod.FactPlannedProduction
ADD CONSTRAINT AK_FactPlannedProduction UNIQUE NONCLUSTERED (PlanID) NOT ENFORCED;

ALTER TABLE prod.FactPlannedProduction
ADD CONSTRAINT FK_FactProd_Date FOREIGN KEY (DateSK) REFERENCES prod.DimDate(DateSK) NOT ENFORCED;

ALTER TABLE prod.FactPlannedProduction
ADD CONSTRAINT FK_FactProd_Mill FOREIGN KEY (MillSK) REFERENCES prod.DimMills(MillSK) NOT ENFORCED;

ALTER TABLE prod.FactPlannedProduction
ADD CONSTRAINT FK_FactProd_Product FOREIGN KEY (ProductSK) REFERENCES prod.DimProducts(ProductSK) NOT ENFORCED;


-- ========================================
-- prod.FactStockMovements
-- ========================================

CREATE TABLE prod.FactStockMovements (
    MovementSK BIGINT NOT NULL,
    MovementID VARCHAR(50) NOT NULL,
    Date DATE NOT NULL,
    DateSK INT NOT NULL,
    FromType VARCHAR(50),
    FromID VARCHAR(50),
    FromSK BIGINT NOT NULL,
    ToType VARCHAR(50),
    ToID VARCHAR(50),
    ToSK BIGINT NOT NULL,
    ProductSK BIGINT NOT NULL,
    Pallets INT,
    Tons FLOAT,
    Source VARCHAR(100)
);

ALTER TABLE prod.FactStockMovements
ADD CONSTRAINT PK_FactStockMovements PRIMARY KEY NONCLUSTERED (MovementSK) NOT ENFORCED;

ALTER TABLE prod.FactStockMovements
ADD CONSTRAINT AK_FactStockMovements UNIQUE NONCLUSTERED (MovementID) NOT ENFORCED;

ALTER TABLE prod.FactStockMovements
ADD CONSTRAINT FK_FactStockMove_Date FOREIGN KEY (DateSK) REFERENCES prod.DimDate(DateSK) NOT ENFORCED;

ALTER TABLE prod.FactStockMovements
ADD CONSTRAINT FK_FactStockMove_Product FOREIGN KEY (ProductSK) REFERENCES prod.DimProducts(ProductSK) NOT ENFORCED;

ALTER TABLE prod.FactStockMovements
ADD CONSTRAINT FK_FactStockMove_Mills FOREIGN KEY (FromSK) REFERENCES prod.DimMills(MillSK) NOT ENFORCED;

ALTER TABLE prod.FactStockMovements
ADD CONSTRAINT FK_FactStockMove_Warehouse FOREIGN KEY (ToSK) REFERENCES prod.DimWarehouses(WarehouseSK) NOT ENFORCED;

-- ========================================
-- prod.FactMachineSensors
-- ========================================

CREATE TABLE prod.FactMachineSensors (
    SensorSK BIGINT NOT NULL,
    MachineSK BIGINT NOT NULL,
    DateSK INT NOT NULL,
    Timestamp DATETIME2(3) NOT NULL,
    TempC FLOAT,
    VibrationMMs FLOAT,
    PowerKW FLOAT,
    AnomalyScore FLOAT,
    IsAnomaly INT,
    Source VARCHAR(100)
);

ALTER TABLE prod.FactMachineSensors
ADD CONSTRAINT PK_FactMachineSensors PRIMARY KEY NONCLUSTERED (SensorSK) NOT ENFORCED;

ALTER TABLE prod.FactMachineSensors
ADD CONSTRAINT FK_FactMachineSensors_Machine FOREIGN KEY (MachineSK) REFERENCES prod.DimMachines(MachineSK) NOT ENFORCED;

ALTER TABLE prod.FactMachineSensors
ADD CONSTRAINT FK_FactMachineSensors_Date FOREIGN KEY (DateSK) REFERENCES prod.DimDate(DateSK) NOT ENFORCED;

-- ========================================
-- prod.FactMachineDowntime 
-- ========================================

CREATE TABLE prod.FactMachineDowntime (
    DowntimeSK BIGINT NOT NULL,
    DowntimeID VARCHAR(50) NOT NULL,
    MachineSK BIGINT NOT NULL,
    StartTime DATETIME2(3) NOT NULL,
    EndTime DATETIME2(3) NOT NULL,
    DurationMinutes BIGINT,
    Reason VARCHAR(200),
    DateSK INT NOT NULL,
    Source VARCHAR(100)
);

ALTER TABLE prod.FactMachineDowntime
ADD CONSTRAINT PK_FactMachineDowntime PRIMARY KEY NONCLUSTERED (DowntimeSK) NOT ENFORCED;

ALTER TABLE prod.FactMachineDowntime
ADD CONSTRAINT AK_FactMachineDowntime UNIQUE NONCLUSTERED (DowntimeID) NOT ENFORCED;

ALTER TABLE prod.FactMachineDowntime
ADD CONSTRAINT FK_FactMachineDowntime_Machine FOREIGN KEY (MachineSK) REFERENCES prod.DimMachines(MachineSK) NOT ENFORCED;

ALTER TABLE prod.FactMachineDowntime
ADD CONSTRAINT FK_FactMachineDowntime_Date FOREIGN KEY (DateSK) REFERENCES prod.DimDate(DateSK) NOT ENFORCED;

