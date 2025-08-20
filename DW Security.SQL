

CREATE TABLE sec.userAccess (
    Username VARCHAR(100) NOT NULL,
    Source VARCHAR(100) NOT NULL
);

ALTER TABLE sec.userAccess
ADD CONSTRAINT PK_userAccess PRIMARY KEY NONCLUSTERED (Username, Source) NOT ENFORCED;

INSERT INTO sec.userAccess (Username, Source)
VALUES 
    ('user1.sales@MngEnvMCAP164164.onmicrosoft.com', 'Sweden'),
    ('admin@MngEnvMCAP164164.onmicrosoft.com', 'All');

/* ==========================
-- Security settings
   ========================================== */

-- Create the database role
CREATE ROLE DbViewer;
GO

CREATE ROLE DbAdmin;
GO

-- Add the user to the role
ALTER ROLE DbViewer ADD MEMBER [user1.sales@MngEnvMCAP164164.onmicrosoft.com];
GO

ALTER ROLE DbAdmin ADD MEMBER [admin@MngEnvMCAP164164.onmicrosoft.com];
GO

DENY SELECT on prod.DimEmployees to [DbViewer]; 
CREATE OR ALTER VIEW prod.vw_DimEmployees_Viewer
AS
SELECT 
    EmployeeID,
    Source,
    FullName,
    Phone,
    Title
FROM prod.DimEmployees;

GRANT SELECT ON prod.vw_DimEmployees_Viewer TO [DbViewer];
GRANT SELECT ON prod.DimEmployees TO [DbAdmin];

DENY SELECT ON prod.DimCustomers (Email,Phone,Contact) TO [DbViewer];
-- REVOKE SELECT ON prod.DimCustomers (Email, Phone, Contact) TO [DbViewer];

Select * from prod.DimEmployees

---
-- DDM
----------------------

-- Mask Email column with email masking
ALTER TABLE prod.DimCustomers
ALTER COLUMN Email ADD MASKED WITH (FUNCTION = 'email()');

-- Mask Phone column to show only last 4 digits
ALTER TABLE prod.DimCustomers
ALTER COLUMN Phone ADD MASKED WITH (FUNCTION = 'default()');

-- Grant permission to view unmasked data
GRANT UNMASK TO [DbAdmin];

Select * from prod.DimCustomers


--------------------------
--- RLS
--------------------------

-- Create the Security Predicate Function
-- This function checks whether the current user has access to a specific Source:

CREATE OR ALTER FUNCTION sec.fn_FilterByUserSource(@Source VARCHAR(100))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS Allowed
    FROM sec.userAccess AS ua
    WHERE ua.Username = USER_NAME()
      AND (ua.Source = 'All' OR ua.Source = @Source);

-- Create RLS Security Policy
-- Apply this predicate to your target table, e.g., prod.DimCustomers
-- You can repeat the same logic on other tables like DimEmployees, FactShipments, etc., by changing the ON clause.

CREATE SECURITY POLICY sec.DimCustomers_RLS
ADD FILTER PREDICATE sec.fn_FilterByUserSource(Source)
ON prod.DimCustomers
WITH (STATE = ON);

Select * from prod.DimCustomers

--- To Disable or Drop RLS (Optional)

ALTER SECURITY POLICY sec.DimCustomers_RLS
WITH (STATE = OFF);

DROP SECURITY POLICY sec.DimCustomers_RLS;



