/* =====================================================================
   Proyecto Final de Base de Datos (1M3214) - UTP
   M1 - Ejercicio: Implement security and compliance with SQL
   Fuente: Microsoft Learn Lab Exercises (Módulo 1, unidad 9)
   Base de datos: SecurityLabDB (Azure SQL Database, oferta gratuita)
   Servidor: sqlsrv-securitylab-pf (grupo de recursos rg-securitylab)
   ===================================================================== */

/* ---------------------------------------------------------------------
   1. Create sample tables (código oficial)
   --------------------------------------------------------------------- */
-- Create tables for the exercise
CREATE TABLE dbo.Employees (
EmployeeID int PRIMARY KEY IDENTITY(1,1),
FirstName nvarchar(50) NOT NULL,
LastName nvarchar(50) NOT NULL,
Email nvarchar(100) NOT NULL,
SSN char(11) NOT NULL,
Salary decimal(18,2) NOT NULL,
Department nvarchar(50) NOT NULL
);
CREATE TABLE dbo.Customers (
CustomerID int PRIMARY KEY IDENTITY(1,1),
CompanyName nvarchar(100) NOT NULL,
ContactName nvarchar(100) NOT NULL,
Phone nvarchar(20) NOT NULL,
CreditCardNumber nvarchar(19) NOT NULL,
SalesRegion nvarchar(20) NOT NULL
);
-- Insert sample data
INSERT INTO dbo.Employees (FirstName, LastName, Email, SSN, Salary, Department)
VALUES
('Sarah', 'Chen', 'sarah.chen@contoso.com', '123-45-6789', 95000.00, 'Engineering'),
('Marcus', 'Johnson', 'marcus.johnson@contoso.com', '234-56-7890', 75000.00, 'Engineering'),
('Emily', 'Williams', 'emily.williams@contoso.com', '345-67-8901', 82000.00, 'Sales'),
('David', 'Brown', 'david.brown@contoso.com', '456-78-9012', 68000.00, 'Sales'),
('Lisa', 'Garcia', 'lisa.garcia@contoso.com', '567-89-0123', 71000.00, 'HR');
INSERT INTO dbo.Customers (CompanyName, ContactName, Phone, CreditCardNumber, SalesRegion)
VALUES
('Northwind Traders', 'John Smith', '206-555-0100', '4111-1111-1111-1111', 'West'),
('Adventure Works', 'Jane Doe', '425-555-0150', '5500-0000-0000-0004', 'East'),
('Fabrikam Inc', 'Bob Wilson', '503-555-0175', '3400-0000-0000-009', 'West'),
('Contoso Ltd', 'Alice Brown', '360-555-0125', '6011-0000-0000-0004', 'East');

-- Verificación (código adicional)
SELECT * FROM dbo.Employees;
SELECT * FROM dbo.Customers;
GO

/* ---------------------------------------------------------------------
   2. Implement Dynamic Data Masking (código oficial)
   --------------------------------------------------------------------- */
-- Mask SSN to show only last 4 digits
ALTER TABLE dbo.Employees
ALTER COLUMN SSN ADD MASKED WITH (FUNCTION = 'partial(0, "XXX-XX-", 4)');
-- Mask Salary with a random value
ALTER TABLE dbo.Employees
ALTER COLUMN Salary ADD MASKED WITH (FUNCTION = 'random(50000, 150000)');
-- Mask Email to show first character and domain
ALTER TABLE dbo.Employees
ALTER COLUMN Email ADD MASKED WITH (FUNCTION = 'email()');
GO

-- Mask credit card to show only last 4 digits
ALTER TABLE dbo.Customers
ALTER COLUMN CreditCardNumber ADD MASKED WITH (FUNCTION = 'partial(0, "XXXX-XXXX-XXXX-", 4)');
-- Mask phone number to show only last 4 digits
ALTER TABLE dbo.Customers
ALTER COLUMN Phone ADD MASKED WITH (FUNCTION = 'partial(0, "XXX-XXX-", 4)');
GO

-- Create a user without UNMASK permission
CREATE USER MaskedViewer WITHOUT LOGIN;
GRANT SELECT ON dbo.Employees TO MaskedViewer;
GRANT SELECT ON dbo.Customers TO MaskedViewer;
-- Query as the masked user (data appears masked)
EXECUTE AS USER = 'MaskedViewer';
SELECT FirstName, LastName, Email, SSN, Salary FROM dbo.Employees;
SELECT CompanyName, ContactName, Phone, CreditCardNumber FROM dbo.Customers;
REVERT;
-- Query as admin (data appears unmasked)
SELECT FirstName, LastName, Email, SSN, Salary FROM dbo.Employees;
GO

/* ---------------------------------------------------------------------
   3. Implement Row-Level Security (código oficial)
   --------------------------------------------------------------------- */
-- Create users for different sales regions
CREATE USER WestSalesRep WITHOUT LOGIN;
CREATE USER EastSalesRep WITHOUT LOGIN;
-- Grant SELECT permission on Customers table
GRANT SELECT ON dbo.Customers TO WestSalesRep;
GRANT SELECT ON dbo.Customers TO EastSalesRep;
GO

-- Create a schema for security objects
CREATE SCHEMA Security;
GO
-- Create a function that determines which rows a user can see
CREATE FUNCTION Security.fn_RegionFilter(@SalesRegion nvarchar(20))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS AccessGranted
     WHERE @SalesRegion =
            CASE USER_NAME()
                   WHEN 'WestSalesRep' THEN 'West'
                   WHEN 'EastSalesRep' THEN 'East'
                   ELSE @SalesRegion -- Admins see all regions
            END
          OR IS_MEMBER('db_owner') = 1;
GO

-- Create security policy
CREATE SECURITY POLICY CustomerRegionPolicy
ADD FILTER PREDICATE Security.fn_RegionFilter(SalesRegion)
     ON dbo.Customers
WITH (STATE = ON);
GO

-- Test as WestSalesRep (should see only West region customers)
EXECUTE AS USER = 'WestSalesRep';
SELECT * FROM dbo.Customers;
REVERT;
-- Test as EastSalesRep (should see only East region customers)
EXECUTE AS USER = 'EastSalesRep';
SELECT * FROM dbo.Customers;
REVERT;
-- Test as admin (should see all customers)
SELECT * FROM dbo.Customers;
GO

/* ---------------------------------------------------------------------
   4. Cleanup (código oficial)
   Después se eliminó el grupo de recursos rg-securitylab desde Azure Portal.
   --------------------------------------------------------------------- */
-- Remove security policy and function
DROP SECURITY POLICY IF EXISTS CustomerRegionPolicy;
DROP FUNCTION IF EXISTS Security.fn_RegionFilter;
DROP SCHEMA IF EXISTS Security;
-- Remove test users
DROP USER IF EXISTS MaskedViewer;
DROP USER IF EXISTS WestSalesRep;
DROP USER IF EXISTS EastSalesRep;
-- Drop tables
DROP TABLE IF EXISTS dbo.Customers;
DROP TABLE IF EXISTS dbo.Employees;
GO
