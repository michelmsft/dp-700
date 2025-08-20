---CREATE SCHEMA etl;

-- ========================================
-- etl.usp_LoadDimCustomers_SCD2
-- ========================================
CREATE OR ALTER PROCEDURE etl.usp_LoadDimCustomers_SCD2
AS
BEGIN

    DECLARE @MaxCustomerSK BIGINT = ISNULL(
        (SELECT MAX(CustomerSK) FROM prod.DimCustomers),
        0
    );

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
END
GO

-- ========================================
-- etl.usp_LoadDimEmployees_SCD2
-- ========================================

CREATE OR ALTER PROCEDURE etl.usp_LoadDimEmployees_SCD2
AS
BEGIN
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
END
GO

-- ========================================
-- etl.usp_LoadFactOrders
-- ========================================
CREATE OR ALTER PROCEDURE etl.usp_LoadFactOrders
AS
BEGIN
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
END
