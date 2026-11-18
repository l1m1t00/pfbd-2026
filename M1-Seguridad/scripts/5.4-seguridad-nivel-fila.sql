/* =====================================================================
   Proyecto Final de Base de Datos (1M3214) - UTP
   M1 - Unidad 4: Implementar la seguridad a nivel de fila (RLS)
   Base de datos: PFBD2026 (Azure SQL Database)
   ===================================================================== */

-- Código adicional: tablas que la unidad usa pero no define
CREATE TABLE dbo.Orders (OrderID int PRIMARY KEY, TenantID int NOT NULL, OrderDate date, Total decimal(10,2));
CREATE TABLE dbo.OrderDetails (OrderDetailID int PRIMARY KEY, OrderID int, TenantID int NOT NULL, Product varchar(50), Quantity int);
CREATE TABLE dbo.Shipments (ShipmentID int PRIMARY KEY, TenantID int NOT NULL, ShipDate date);
CREATE TABLE dbo.CustomerAccounts (AccountID int PRIMARY KEY, CustomerName varchar(50), SalesRepID int NOT NULL);
GO

-- Datos adicionales para demostración: pedidos de dos inquilinos (42 y 7)
INSERT INTO dbo.Orders VALUES (1, 42, '2026-11-01', 150.00), (2, 42, '2026-11-03', 89.90), (3, 7, '2026-11-02', 230.00);
INSERT INTO dbo.OrderDetails VALUES (1, 1, 42, 'Teclado', 2), (2, 2, 42, 'Mouse', 1), (3, 3, 7, 'Monitor', 1);
SELECT * FROM dbo.Orders;
SELECT * FROM dbo.OrderDetails;
GO

-- Origen: M1 > Unidad 4 > Creación de predicados de filtro / directivas de seguridad (código oficial)
CREATE SCHEMA Security;
GO
CREATE FUNCTION Security.fn_TenantAccessPredicate(@TenantID int)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS fn_TenantAccessPredicate_Result
WHERE @TenantID = CAST(SESSION_CONTEXT(N'TenantID') AS int);
GO
CREATE SECURITY POLICY TenantSecurityPolicy
ADD FILTER PREDICATE Security.fn_TenantAccessPredicate(TenantID)
ON dbo.Orders,
ADD FILTER PREDICATE Security.fn_TenantAccessPredicate(TenantID)
ON dbo.OrderDetails
WITH (STATE = ON);
GO

-- Prueba
SELECT 'Sin contexto' AS Prueba, * FROM dbo.Orders;
EXEC sp_set_session_context @key = N'TenantID', @value = 42;   -- código oficial
SELECT 'TenantID = 42' AS Prueba, * FROM dbo.Orders;
SELECT 'TenantID = 42' AS Prueba, * FROM dbo.OrderDetails;
GO

-- Código adicional: usuarios, rol y permisos para probar el predicado por vendedor
CREATE USER SalesRep1 WITHOUT LOGIN;
CREATE USER SalesRep2 WITHOUT LOGIN;
CREATE USER SalesMgr1 WITHOUT LOGIN;
CREATE ROLE SalesManagers;
ALTER ROLE SalesManagers ADD MEMBER SalesMgr1;
GRANT SELECT, INSERT, UPDATE ON dbo.CustomerAccounts TO SalesRep1, SalesRep2, SalesMgr1;

-- Datos adicionales para demostración (antes de activar la directiva)
INSERT INTO dbo.CustomerAccounts VALUES
(1, 'Cliente A', USER_ID('SalesRep1')),
(2, 'Cliente B', USER_ID('SalesRep1')),
(3, 'Cliente C', USER_ID('SalesRep2'));
GO

-- Código oficial
CREATE FUNCTION Security.fn_SalesRepPredicate(@SalesRepID int)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS fn_SalesRepPredicate_Result
WHERE @SalesRepID = DATABASE_PRINCIPAL_ID()
OR IS_MEMBER('SalesManagers') = 1;
GO
CREATE SECURITY POLICY SalesSecurityPolicy
ADD FILTER PREDICATE Security.fn_SalesRepPredicate(SalesRepID)
ON dbo.CustomerAccounts,
ADD BLOCK PREDICATE Security.fn_SalesRepPredicate(SalesRepID)
ON dbo.CustomerAccounts AFTER INSERT,
ADD BLOCK PREDICATE Security.fn_SalesRepPredicate(SalesRepID)
ON dbo.CustomerAccounts AFTER UPDATE
WITH (STATE = ON);
GO

-- Demostración (código adicional)
EXECUTE AS USER = 'SalesRep1'; SELECT 'SalesRep1' AS Usuario, * FROM dbo.CustomerAccounts; REVERT;
EXECUTE AS USER = 'SalesMgr1'; SELECT 'SalesMgr1' AS Usuario, * FROM dbo.CustomerAccounts; REVERT;

EXECUTE AS USER = 'SalesRep1';
BEGIN TRY
    INSERT INTO dbo.CustomerAccounts VALUES (4, 'Cliente D', USER_ID('SalesRep2'));
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;
REVERT;
GO

-- Código adicional: columna requerida por el predicado jerárquico
ALTER TABLE dbo.Employees ADD ManagerID int NULL;
GO

-- Origen: M1 > Unidad 4 > Implementación de patrones de acceso jerárquicos (código oficial)
CREATE FUNCTION Security.fn_HierarchyPredicate(@OwnerID int)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
WITH EmployeeHierarchy AS (
SELECT EmployeeID, ManagerID
FROM dbo.Employees
WHERE EmployeeID = DATABASE_PRINCIPAL_ID()
UNION ALL
SELECT e.EmployeeID, e.ManagerID
FROM dbo.Employees e
INNER JOIN EmployeeHierarchy h ON e.ManagerID = h.EmployeeID
)
SELECT 1 AS fn_HierarchyPredicate_Result
WHERE @OwnerID IN (SELECT EmployeeID FROM EmployeeHierarchy);
GO

-- Verificación (código adicional)
SELECT SCHEMA_NAME(schema_id) AS Esquema, name AS Funcion, type_desc, create_date
FROM sys.objects WHERE SCHEMA_NAME(schema_id) = 'Security';
GO

-- Origen: M1 > Unidad 4 > Administración de directivas de seguridad (código oficial)
ALTER SECURITY POLICY TenantSecurityPolicy
WITH (STATE = OFF);

ALTER SECURITY POLICY TenantSecurityPolicy
ADD FILTER PREDICATE Security.fn_TenantAccessPredicate(TenantID)
ON dbo.Shipments;

ALTER SECURITY POLICY TenantSecurityPolicy
DROP FILTER PREDICATE ON dbo.Orders;

SELECT p.name AS PolicyName,
p.is_enabled,
o.name AS TableName,
pred.predicate_definition
FROM sys.security_policies p
INNER JOIN sys.security_predicates pred ON p.object_id = pred.object_id
INNER JOIN sys.objects o ON pred.target_object_id = o.object_id;
GO
