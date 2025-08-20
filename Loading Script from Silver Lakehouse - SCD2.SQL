-- ========================================
-- prod.DimCustomers
-- ========================================


-- Step 0: Get the current max surrogate key
DECLARE @MaxCustomerSK BIGINT = ISNULL(
    (SELECT MAX(CustomerSK) FROM prod.DimCustomers),
    0
);

-- Step 1: Identify changed records and expire existing rows
UPDATE tgt
SET IsCurrent = 0,
    ValidTo = CAST(GETDATE() AS DATE)
FROM prod.DimCustomers AS tgt
JOIN stg.Customers AS src 
  ON tgt.CustomerID = src.CustomerID AND tgt.Source = src.Source
WHERE tgt.IsCurrent = 1
  AND (
      tgt.CompanyName     <> src.CompanyName OR
      tgt.Contact         <> src.Contact OR
      tgt.Email           <> src.email OR
      tgt.Phone           <> src.Phone OR
      tgt.Industry        <> src.Industry OR
      tgt.AccountCreated  <> src.AccountCreated OR
      tgt.IsActive        <> src.IsActive
  );

-- Step 2: Insert new SCD2 version with incremental surrogate key
WITH ChangedRows AS (
    SELECT
        src.*,
        CAST(GETDATE() AS DATE) AS LoadDate
    FROM stg.Customers AS src
    LEFT JOIN prod.DimCustomers AS tgt
      ON tgt.CustomerID = src.CustomerID AND tgt.Source = src.Source AND tgt.IsCurrent = 1
    WHERE tgt.CustomerID IS NULL
       OR (
           tgt.CompanyName     <> src.CompanyName OR
           tgt.Contact         <> src.Contact OR
           tgt.Email           <> src.email OR
           tgt.Phone           <> src.Phone OR
           tgt.Industry        <> src.Industry OR
           tgt.AccountCreated  <> src.AccountCreated OR
           tgt.IsActive        <> src.IsActive
       )
),
Numbered AS (
    SELECT *,
           ROW_NUMBER() OVER (ORDER BY CustomerID, Source) + @MaxCustomerSK AS CustomerSK
    FROM ChangedRows
)
INSERT INTO prod.DimCustomers (
    CustomerSK, CustomerID, CompanyName, Contact, Email,
    Phone, Industry, AccountCreated, IsActive, Source,
    ValidFrom, ValidTo, IsCurrent
)
SELECT 
    CustomerSK, CustomerID, CompanyName, Contact, email,
    Phone, Industry, AccountCreated, IsActive, Source,
    LoadDate AS ValidFrom,
    '9999-12-31' AS ValidTo,
    1 AS IsCurrent
FROM Numbered;

-- ========================================
-- prod.DimEmployees
-- ========================================

DECLARE @MaxEmployeeSK BIGINT = ISNULL(
    (SELECT MAX(EmployeeSK) FROM prod.DimEmployees),
    0
);

UPDATE prod.DimEmployees
SET IsCurrent = 0,
    ValidTo = CAST(GETDATE() AS DATE)
FROM prod.DimEmployees AS tgt
JOIN stg.Employees AS src 
  ON tgt.EmployeeID = src.EmployeeID AND tgt.Source = src.Source
WHERE tgt.IsCurrent = 1
  AND (
      tgt.FullName       <> src.FullName OR
      tgt.Email          <> src.email OR
      tgt.Phone          <> src.Phone OR
      tgt.Domain         <> src.Domain OR
      tgt.Department     <> src.Department OR
      tgt.Title          <> src.Title OR
      tgt.HireDate       <> src.HireDate OR
      tgt.EmploymentType <> src.EmploymentType OR
      tgt.IsActive       <> src.IsActive
  );

WITH ChangedRows AS (
    SELECT src.*, CAST(GETDATE() AS DATE) AS LoadDate
    FROM stg.Employees src
    LEFT JOIN prod.DimEmployees tgt
      ON tgt.EmployeeID = src.EmployeeID AND tgt.Source = src.Source AND tgt.IsCurrent = 1
    WHERE tgt.EmployeeID IS NULL
       OR (
           tgt.FullName       <> src.FullName OR
           tgt.Email          <> src.email OR
           tgt.Phone          <> src.Phone OR
           tgt.Domain         <> src.Domain OR
           tgt.Department     <> src.Department OR
           tgt.Title          <> src.Title OR
           tgt.HireDate       <> src.HireDate OR
           tgt.EmploymentType <> src.EmploymentType OR
           tgt.IsActive       <> src.IsActive
       )
),
Numbered AS (
    SELECT *,
           ROW_NUMBER() OVER (ORDER BY EmployeeID, Source) + @MaxEmployeeSK AS EmployeeSK
    FROM ChangedRows
)
INSERT INTO prod.DimEmployees (
    EmployeeSK, EmployeeID, FullName, Email, Phone,
    Domain, Department, Title, HireDate, EmploymentType,
    IsActive, Source, ValidFrom, ValidTo, IsCurrent
)
SELECT 
    EmployeeSK, EmployeeID, FullName, email, Phone,
    Domain, Department, Title, HireDate, EmploymentType,
    IsActive, Source, LoadDate, '9999-12-31', 1
FROM Numbered;

-- ========================================
-- prod.DimProducts
-- ========================================

DECLARE @MaxProductSK BIGINT = ISNULL(
    (SELECT MAX(ProductSK) FROM prod.DimProducts),
    0
);

UPDATE prod.DimProducts
SET IsCurrent = 0,
    ValidTo = CAST(GETDATE() AS DATE)
FROM prod.DimProducts tgt
JOIN stg.Products src 
  ON tgt.ProductID = src.ProductID AND tgt.Source = src.Source
WHERE tgt.IsCurrent = 1
  AND (
      tgt.Brand         <> src.Brand OR
      tgt.ProductName   <> src.ProductName OR
      tgt.BasisWeight   <> src.BasisWeight OR
      tgt.Brightness    <> src.Brightness OR
      tgt.Certification <> src.Certification OR
      tgt.PalletsToTon  <> src.PalletsToTon
  );

WITH ChangedRows AS (
    SELECT src.*, CAST(GETDATE() AS DATE) AS LoadDate
    FROM stg.Products src
    LEFT JOIN prod.DimProducts tgt
      ON tgt.ProductID = src.ProductID AND tgt.Source = src.Source AND tgt.IsCurrent = 1
    WHERE tgt.ProductID IS NULL
       OR (
           tgt.Brand         <> src.Brand OR
           tgt.ProductName   <> src.ProductName OR
           tgt.BasisWeight   <> src.BasisWeight OR
           tgt.Brightness    <> src.Brightness OR
           tgt.Certification <> src.Certification OR
           tgt.PalletsToTon  <> src.PalletsToTon
       )
),
Numbered AS (
    SELECT *,
           ROW_NUMBER() OVER (ORDER BY ProductID, Source) + @MaxProductSK AS ProductSK
    FROM ChangedRows
)
INSERT INTO prod.DimProducts (
    ProductSK, ProductID, Brand, ProductName, BasisWeight,
    Brightness, Certification, PalletsToTon, Source,
    ValidFrom, ValidTo, IsCurrent
)
SELECT 
    ProductSK, ProductID, Brand, ProductName, BasisWeight,
    Brightness, Certification, PalletsToTon, Source,
    LoadDate, '9999-12-31', 1
FROM Numbered;

-- ========================================
-- prod.DimMachines
-- ========================================

DECLARE @MaxMachineSK BIGINT = ISNULL(
    (SELECT MAX(MachineSK) FROM prod.DimMachines),
    0
);

UPDATE prod.DimMachines
SET IsCurrent = 0,
    ValidTo = CAST(GETDATE() AS DATE)
FROM prod.DimMachines tgt
JOIN stg.Machines src 
  ON tgt.MachineID = src.MachineID AND tgt.Source = src.Source
WHERE tgt.IsCurrent = 1
  AND (
      tgt.MillID         <> src.MillID OR
      tgt.Type           <> src.Type OR
      tgt.CommissionDate <> src.CommissionDate OR
      tgt.RatedKW        <> src.RatedKW
  );

WITH ChangedRows AS (
    SELECT src.*, CAST(GETDATE() AS DATE) AS LoadDate
    FROM stg.Machines src
    LEFT JOIN prod.DimMachines tgt
      ON tgt.MachineID = src.MachineID AND tgt.Source = src.Source AND tgt.IsCurrent = 1
    WHERE tgt.MachineID IS NULL
       OR (
           tgt.MillID         <> src.MillID OR
           tgt.Type           <> src.Type OR
           tgt.CommissionDate <> src.CommissionDate OR
           tgt.RatedKW        <> src.RatedKW
       )
),
Numbered AS (
    SELECT *,
           ROW_NUMBER() OVER (ORDER BY MachineID, Source) + @MaxMachineSK AS MachineSK
    FROM ChangedRows
)
INSERT INTO prod.DimMachines (
    MachineSK, MachineID, MillID, Type, CommissionDate,
    RatedKW, Source, ValidFrom, ValidTo, IsCurrent
)
SELECT 
    MachineSK, MachineID, MillID, Type, CommissionDate,
    RatedKW, Source, LoadDate, '9999-12-31', 1
FROM Numbered;


-- ========================================
-- prod.DimWarehouses
-- ========================================

DECLARE @MaxWarehouseSK BIGINT = ISNULL(
    (SELECT MAX(WarehouseSK) FROM prod.DimWarehouses),
    0
);

UPDATE prod.DimWarehouses
SET IsCurrent = 0,
    ValidTo = CAST(GETDATE() AS DATE)
FROM prod.DimWarehouses tgt
JOIN stg.Warehouses src 
  ON tgt.WarehouseID = src.WarehouseID AND tgt.Source = src.Source
WHERE tgt.IsCurrent = 1
  AND (
      tgt.WarehouseName   <> src.WarehouseName OR
      tgt.Region          <> src.Region OR
      tgt.Type            <> src.Type OR
      tgt.AssignedMillID  <> src.AssignedMillID OR
      tgt.CapacityPallets <> src.CapacityPallets
  );

WITH ChangedRows AS (
    SELECT src.*, CAST(GETDATE() AS DATE) AS LoadDate
    FROM stg.Warehouses src
    LEFT JOIN prod.DimWarehouses tgt
      ON tgt.WarehouseID = src.WarehouseID AND tgt.Source = src.Source AND tgt.IsCurrent = 1
    WHERE tgt.WarehouseID IS NULL
       OR (
           tgt.WarehouseName   <> src.WarehouseName OR
           tgt.Region          <> src.Region OR
           tgt.Type            <> src.Type OR
           tgt.AssignedMillID  <> src.AssignedMillID OR
           tgt.CapacityPallets <> src.CapacityPallets
       )
),
Numbered AS (
    SELECT *,
           ROW_NUMBER() OVER (ORDER BY WarehouseID, Source) + @MaxWarehouseSK AS WarehouseSK
    FROM ChangedRows
)
INSERT INTO prod.DimWarehouses (
    WarehouseSK, WarehouseID, WarehouseName, Region, Type,
    AssignedMillID, CapacityPallets, Source, ValidFrom, ValidTo, IsCurrent
)
SELECT 
    WarehouseSK, WarehouseID, WarehouseName, Region, Type,
    AssignedMillID, CapacityPallets, Source, LoadDate, '9999-12-31', 1
FROM Numbered;

-- ========================================
-- prod.DimMills
-- ========================================

DECLARE @MaxMillSK BIGINT = ISNULL(
    (SELECT MAX(MillSK) FROM prod.DimMills),
    0
);

UPDATE prod.DimMills
SET IsCurrent = 0,
    ValidTo = CAST(GETDATE() AS DATE)
FROM prod.DimMills tgt
JOIN stg.Mills src 
  ON tgt.MillID = src.MillID AND tgt.Source = src.Source
WHERE tgt.IsCurrent = 1
  AND (
      tgt.Name                  <> src.Name OR
      tgt.ProductionTonsCapacity<> src.ProductionTonsCapacity
  );

WITH ChangedRows AS (
    SELECT src.*, CAST(GETDATE() AS DATE) AS LoadDate
    FROM stg.Mills src
    LEFT JOIN prod.DimMills tgt
      ON tgt.MillID = src.MillID AND tgt.Source = src.Source AND tgt.IsCurrent = 1
    WHERE tgt.MillID IS NULL
       OR (
           tgt.Name                  <> src.Name OR
           tgt.ProductionTonsCapacity<> src.ProductionTonsCapacity
       )
),
Numbered AS (
    SELECT *,
           ROW_NUMBER() OVER (ORDER BY MillID, Source) + @MaxMillSK AS MillSK
    FROM ChangedRows
)
INSERT INTO prod.DimMills (
    MillSK, MillID, Name, ProductionTonsCapacity, Source,
    ValidFrom, ValidTo, IsCurrent
)
SELECT 
    MillSK, MillID, Name, ProductionTonsCapacity, Source,
    LoadDate, '9999-12-31', 1
FROM Numbered;


-- ========================================
-- prod.FactOrders
-- ========================================
DECLARE @MaxOrderSK BIGINT = ISNULL((SELECT MAX(OrderSK) FROM prod.FactOrders), 0);

INSERT INTO prod.FactOrders (
    OrderSK, OrderID, OrderDate, DateSK, CustomerSK, ProductSK, QuantityPallets, Source
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY o.OrderID) + @MaxOrderSK AS OrderSK,
    o.OrderID,
    o.OrderDate,
    d.DateSK,
    c.CustomerSK,
    p.ProductSK,
    o.QuantityPallets,
    o.Source
FROM stg.Orders o
JOIN prod.DimDate d ON d.FullDate = o.OrderDate
JOIN prod.DimCustomers c ON c.CustomerID = o.CustomerID AND c.Source = o.Source AND c.IsCurrent = 1
JOIN prod.DimProducts p ON p.ProductID = o.ProductID AND p.Source = o.Source AND p.IsCurrent = 1;

-- ========================================
-- prod.FactShipments
-- ========================================
DECLARE @MaxShipmentSK BIGINT = ISNULL((SELECT MAX(ShipmentSK) FROM prod.FactShipments), 0);

    INSERT INTO prod.FactShipments (
        ShipmentSK, ShipmentID, Date, DateSK, WarehouseSK, OrderSK, ProductSK, Pallets, Source
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY s.ShipmentID) + @MaxShipmentSK,
        s.ShipmentID,
        s.Date,
        d.DateSK,
        w.WarehouseSK,
        o.OrderSK,
        p.ProductSK,
        s.Pallets,
        s.Source
    FROM stg.Shipments s
    JOIN prod.DimDate d 
        ON d.FullDate = s.Date
    JOIN prod.DimWarehouses w 
        ON w.WarehouseID = s.WarehouseID AND w.Source = s.Source AND w.IsCurrent = 1
    JOIN prod.DimProducts p 
        ON p.ProductID = s.ProductID AND p.Source = s.Source AND p.IsCurrent = 1
    JOIN prod.FactOrders o 
        ON o.OrderID = s.OrderID AND o.Source = s.Source;

-- ========================================
-- prod.FactPlannedProduction
-- ========================================
DECLARE @MaxProductionSK BIGINT = ISNULL((SELECT MAX(ProductionSK) FROM prod.FactPlannedProduction), 0);

INSERT INTO prod.FactPlannedProduction (
    ProductionSK, PlanID, ProdDate, DateSK, MillSK, ProductSK, Pallets, Tons, EnergyMWh, WaterM3, EmissionsKgCO2e, Source
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY p.PlanID) + @MaxProductionSK AS ProductionSK,
    p.PlanID,
    p.ProdDate,
    d.DateSK,
    m.MillSK,
    pr.ProductSK,
    p.Pallets,
    p.Tons,
    p.EnergyMWh,
    p.WaterM3,
    p.EmissionsKgCO2e,
    p.Source
FROM stg.PlannedProductions p
JOIN prod.DimDate d ON d.FullDate = p.ProdDate
JOIN prod.DimMills m ON m.MillID = p.MillID AND m.Source = p.Source AND m.IsCurrent = 1
JOIN prod.DimProducts pr ON pr.ProductID = p.ProductID AND pr.Source = p.Source AND pr.IsCurrent = 1;

-- ========================================
-- prod.FactStockMovements
-- ========================================
DECLARE @MaxMovementSK BIGINT = ISNULL((SELECT MAX(MovementSK) FROM prod.FactStockMovements), 0);

INSERT INTO prod.FactStockMovements (
    MovementSK, MovementID, Date, DateSK, FromType, FromID,FromSK, ToType, ToID,ToSK, ProductSK, Pallets, Tons, Source
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY m.MovementID) + @MaxMovementSK AS MovementSK,
    m.MovementID,
    m.Date,
    d.DateSK,
    m.FromType,
    m.FromID,
    ml.MillSK,
    m.ToType,
    m.ToID,
    w.WarehouseSK,
    p.ProductSK,
    m.Pallets,
    m.Tons,
    m.Source
FROM stg.StockMovements m
JOIN prod.DimDate d ON d.FullDate = m.Date
JOIN prod.DimProducts p ON p.ProductID = m.ProductID AND p.Source = m.Source AND p.IsCurrent = 1
JOIN prod.DimMills ml on ml.MillID = m.FromID AND ml.Source = m.Source
JOIN prod.DimWarehouses w on w.WarehouseID = m.ToID AND w.Source = m.Source;

-- ========================================
-- prod.FactMachineSensors
-- ========================================
DECLARE @MaxSensorSK BIGINT = ISNULL((SELECT MAX(SensorSK) FROM prod.FactMachineSensors), 0);

INSERT INTO prod.FactMachineSensors (
    SensorSK, MachineSK, DateSK, Timestamp, TempC, VibrationMMs, PowerKW, AnomalyScore, IsAnomaly, Source
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY s.Timestamp) + @MaxSensorSK AS SensorSK,
    m.MachineSK,
    d.DateSK,
    s.Timestamp,
    s.TempC,
    s.VibrationMMs,
    s.PowerKW,
    s.AnomalyScore,
    s.IsAnomaly,
    s.Source
FROM stg.MachineSensors s
JOIN prod.DimDate d ON d.FullDate = CAST(s.Timestamp AS DATE)
JOIN prod.DimMachines m ON m.MachineID = s.MachineID AND m.Source = s.Source AND m.IsCurrent = 1;

-- ========================================
-- prod.FactMachineDowntime
-- ========================================
DECLARE @MaxDowntimeSK BIGINT = ISNULL(
    (SELECT MAX(DowntimeSK) FROM prod.FactMachineDowntime),
    0
);

INSERT INTO prod.FactMachineDowntime (
    DowntimeSK, DowntimeID, MachineSK, StartTime, EndTime, DurationMinutes, Reason, DateSK, Source
)
SELECT
    ROW_NUMBER() OVER (ORDER BY d.MachineID, d.StartTime, d.EndTime, d.Source) + @MaxDowntimeSK AS DowntimeSK,
    CONCAT(d.MachineID, '-', FORMAT(d.StartTime, 'yyyyMMddHHmm'), '-', FORMAT(d.EndTime, 'yyyyMMddHHmm')) AS DowntimeID,
    m.MachineSK,
    d.StartTime,
    d.EndTime,
    DATEDIFF(MINUTE, d.StartTime, d.EndTime) AS DurationMinutes,
    d.Reason,
    dd.DateSK,
    d.Source
FROM stg.MachineDowntime d
JOIN prod.DimDate dd 
    ON dd.FullDate = CAST(d.StartTime AS DATE)
JOIN prod.DimMachines m 
    ON m.MachineID = d.MachineID AND m.Source = d.Source AND m.IsCurrent = 1;

