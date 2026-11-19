/* =====================================================================
   Proyecto Final de Base de Datos (1M3214) - UTP
   M2 - Ejercicio: Optimize query performance
   Fuente: Microsoft Learn Lab Exercises (Módulo 2)
   Base de datos: AdventureWorksLT (Azure SQL Database, oferta gratuita, datos de muestra)
   Servidor: sqlsrv-awlt-pf (grupo de recursos rg-adventureworks-lab)
   Nota: los valores 69 (query_id) y 95 (session_id) se obtuvieron durante la
   ejecución y reemplazan los marcadores <query_id> y <blocking_session_id>.
   ===================================================================== */

/* ---------------------------------------------------------------------
   0. Verificación de los datos de muestra (adicional)
   --------------------------------------------------------------------- */
SELECT COUNT(*) AS Clientes  FROM SalesLT.Customer;
SELECT COUNT(*) AS Productos FROM SalesLT.Product;
GO

/* ---------------------------------------------------------------------
   1. Create the test workload (código oficial)
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS dbo.OrderHistory;

CREATE TABLE dbo.OrderHistory (
OrderID INT IDENTITY(1,1) PRIMARY KEY,
CustomerID INT NOT NULL,
ProductID INT NOT NULL,
OrderDate DATETIME NOT NULL,
Quantity INT NOT NULL,
UnitPrice DECIMAL(10,2) NOT NULL,
TotalAmount AS (Quantity * UnitPrice) PERSISTED,
Status NVARCHAR(20) NOT NULL
);

-- Insert 80,000 rows referencing real AdventureWorksLT customers and products
INSERT INTO dbo.OrderHistory (CustomerID, ProductID, OrderDate, Quantity, UnitPrice, Status)
SELECT TOP 80000
c.CustomerID,
p.ProductID,
DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE()),
ABS(CHECKSUM(NEWID())) % 10 + 1,
p.ListPrice,
CASE ABS(CHECKSUM(NEWID())) % 4
WHEN 0 THEN N'Pending'
WHEN 1 THEN N'Processing'
WHEN 2 THEN N'Shipped'
ELSE N'Delivered'
END
FROM SalesLT.Customer AS c
CROSS JOIN SalesLT.Product AS p
ORDER BY NEWID();

SELECT COUNT(*) AS TotalOrders FROM dbo.OrderHistory;
GO

/* ---------------------------------------------------------------------
   2. Enable and configure Query Store (código oficial)
   --------------------------------------------------------------------- */
ALTER DATABASE CURRENT SET QUERY_STORE = ON (
OPERATION_MODE = READ_WRITE,
QUERY_CAPTURE_MODE = AUTO,
WAIT_STATS_CAPTURE_MODE = ON
);
GO

-- Clear any prior data so only this exercise's queries appear
ALTER DATABASE CURRENT SET QUERY_STORE CLEAR;
GO

SELECT actual_state_desc, desired_state_desc,
current_storage_size_mb, max_storage_size_mb
FROM sys.database_query_store_options;
GO

/* ---------------------------------------------------------------------
   3. Analyze execution plans and add a missing index (código oficial)
      Ejecutar con "Incluir plan de ejecución real" (Ctrl+M)
   --------------------------------------------------------------------- */
SET STATISTICS IO ON;

SELECT
oh.OrderID,
oh.OrderDate,
p.Name AS ProductName,
oh.Quantity,
oh.UnitPrice,
oh.TotalAmount,
oh.Status
FROM dbo.OrderHistory AS oh
INNER JOIN SalesLT.Product AS p
ON oh.ProductID = p.ProductID
WHERE oh.CustomerID = 29485
AND oh.OrderDate >= DATEADD(MONTH, -3, GETDATE())
ORDER BY oh.OrderDate DESC;

SET STATISTICS IO OFF;
GO

CREATE NONCLUSTERED INDEX IX_OrderHistory_CustomerDate
ON dbo.OrderHistory (CustomerID, OrderDate DESC)
INCLUDE (ProductID, Quantity, UnitPrice, Status);
GO

/* ---------------------------------------------------------------------
   4. Use DMVs to find the most expensive queries (código oficial)
   --------------------------------------------------------------------- */
SELECT TOP 5
qs.total_worker_time / qs.execution_count AS avg_cpu_time_us,
qs.execution_count,
qs.total_logical_reads / qs.execution_count AS avg_logical_reads,
SUBSTRING(st.text, (qs.statement_start_offset / 2) + 1,
((CASE qs.statement_end_offset
WHEN -1 THEN DATALENGTH(st.text)
ELSE qs.statement_end_offset
END - qs.statement_start_offset) / 2) + 1) AS query_text
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
ORDER BY avg_cpu_time_us DESC;
GO

SELECT
p.Name AS ProductName,
p.ProductNumber,
oh.OrderDate,
oh.Quantity,
oh.TotalAmount
FROM dbo.OrderHistory AS oh
INNER JOIN SalesLT.Product AS p
ON oh.ProductID = p.ProductID
WHERE oh.Status = N'Pending'
AND oh.OrderDate >= DATEADD(MONTH, -1, GETDATE())
ORDER BY oh.TotalAmount DESC;
GO 5

SELECT TOP 10
mid.statement AS table_name,
mid.equality_columns,
mid.inequality_columns,
mid.included_columns,
ROUND(migs.avg_total_user_cost * migs.avg_user_impact *
(migs.user_seeks + migs.user_scans), 2) AS improvement_measure
FROM sys.dm_db_missing_index_groups AS mig
INNER JOIN sys.dm_db_missing_index_group_stats AS migs
ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details AS mid
ON mig.index_handle = mid.index_handle
ORDER BY improvement_measure DESC;
GO

/* ---------------------------------------------------------------------
   5. Simulate and detect a plan regression with Query Store (código oficial)
   --------------------------------------------------------------------- */
ALTER DATABASE CURRENT SET QUERY_STORE CLEAR;
GO
ALTER DATABASE CURRENT SET QUERY_STORE (
QUERY_CAPTURE_MODE = ALL
);
GO

DROP INDEX IF EXISTS IX_OrderHistory_CustomerDate ON dbo.OrderHistory;

CREATE NONCLUSTERED INDEX IX_OrderHistory_CustomerDate
ON dbo.OrderHistory (CustomerID, OrderDate DESC);
GO

INSERT INTO dbo.OrderHistory (CustomerID, ProductID, OrderDate, Quantity, UnitPrice, Status)
SELECT TOP 50000
1,
p.ProductID,
DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE()),
ABS(CHECKSUM(NEWID())) % 10 + 1,
p.ListPrice,
N'Pending'
FROM SalesLT.Product AS p
CROSS JOIN SalesLT.Product AS p2
ORDER BY NEWID();
GO

UPDATE STATISTICS dbo.OrderHistory;
GO

CREATE OR ALTER PROCEDURE dbo.GetCustomerOrders
@CustomerID INT
AS
BEGIN
SELECT
oh.OrderID,
oh.OrderDate,
p.Name AS ProductName,
oh.Quantity,
oh.UnitPrice,
oh.TotalAmount,
oh.Status
FROM dbo.OrderHistory AS oh
INNER JOIN SalesLT.Product AS p
ON oh.ProductID = p.ProductID
WHERE oh.CustomerID = @CustomerID
ORDER BY oh.OrderDate DESC;
END;
GO

-- Cause the regression
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO
EXEC dbo.GetCustomerOrders @CustomerID = 29485;
GO 10

ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO
EXEC dbo.GetCustomerOrders @CustomerID = 1;
GO

EXEC dbo.GetCustomerOrders @CustomerID = 29485;
GO 10

EXEC sp_query_store_flush_db;
GO

-- (SSMS) Almacén de consultas > Consultas que más recursos consumen > Forzar plan

-- Verify plan forcing with T-SQL
SELECT
q.query_id,
p.plan_id,
p.is_forced_plan,
p.force_failure_count,
qt.query_sql_text
FROM sys.query_store_plan AS p
INNER JOIN sys.query_store_query AS q
ON p.query_id = q.query_id
INNER JOIN sys.query_store_query_text AS qt
ON q.query_text_id = qt.query_text_id
WHERE p.is_forced_plan = 1;
GO

EXEC dbo.GetCustomerOrders @CustomerID = 29485;
GO
EXEC dbo.GetCustomerOrders @CustomerID = 1;
GO

-- Restore the covering index and clean up the stored procedure
DROP PROCEDURE IF EXISTS dbo.GetCustomerOrders;
DROP INDEX IX_OrderHistory_CustomerDate ON dbo.OrderHistory;

CREATE NONCLUSTERED INDEX IX_OrderHistory_CustomerDate
ON dbo.OrderHistory (CustomerID, OrderDate DESC)
INCLUDE (ProductID, Quantity, UnitPrice, Status);
GO

/* ---------------------------------------------------------------------
   6. Apply a Query Store hint (código oficial)
   --------------------------------------------------------------------- */
SELECT
oh.CustomerID,
p.Name AS ProductName,
pc.Name AS CategoryName,
oh.Status,
COUNT(*) AS OrderCount,
SUM(oh.TotalAmount) AS TotalRevenue,
AVG(oh.TotalAmount) AS AvgOrderValue,
STDEV(oh.TotalAmount) AS StdDevOrderValue,
RANK() OVER (PARTITION BY oh.Status
ORDER BY SUM(oh.TotalAmount) DESC) AS StatusRevenueRank,
PERCENT_RANK() OVER (PARTITION BY pc.Name
ORDER BY AVG(oh.TotalAmount)) AS CategoryPctRank,
SUM(COUNT(*)) OVER (PARTITION BY oh.Status) AS StatusTotalOrders
FROM dbo.OrderHistory AS oh
INNER JOIN SalesLT.Product AS p
ON oh.ProductID = p.ProductID
INNER JOIN SalesLT.ProductCategory AS pc
ON p.ProductCategoryID = pc.ProductCategoryID
GROUP BY oh.CustomerID, p.Name, pc.Name, oh.Status
ORDER BY TotalRevenue DESC;
GO

SELECT q.query_id, qt.query_sql_text
FROM sys.query_store_query_text AS qt
INNER JOIN sys.query_store_query AS q
ON qt.query_text_id = q.query_text_id
WHERE qt.query_sql_text LIKE '%RevenueRank%PARTITION%'
AND qt.query_sql_text NOT LIKE '%query_store%';
GO

-- <query_id> reemplazado por 69 (valor obtenido en la consulta anterior)
EXEC sp_query_store_set_hints
@query_id = 69,
@query_hints = N'OPTION (MAXDOP 1)';
GO

-- (Volver a ejecutar la consulta de agregación y comparar el plan)

EXEC sp_query_store_clear_hints @query_id = 69;
GO

/* ---------------------------------------------------------------------
   7. Identify and resolve blocking (código oficial)
   --------------------------------------------------------------------- */
-- Ventana 1
BEGIN TRANSACTION;
UPDATE dbo.OrderHistory SET Status = N'Cancelled' WHERE OrderID = 1;
-- Simulating an application that stopped without committing

-- Ventana 2
UPDATE dbo.OrderHistory SET Status = N'Shipped' WHERE OrderID = 1;

-- Ventana 3: Find blocked sessions
SELECT
r.session_id AS blocked_session,
r.blocking_session_id AS head_blocker,
r.wait_type,
r.wait_time AS wait_time_ms,
r.wait_resource,
t.text AS blocked_query
FROM sys.dm_exec_requests AS r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.blocking_session_id <> 0;

-- Ventana 3: Investigate the head blocker
-- <blocking_session_id> reemplazado por 95 (valor de head_blocker)
SELECT
s.session_id,
s.status,
s.login_time,
s.program_name,
s.host_name,
t.text AS last_query,
c.connect_time,
s.last_request_start_time,
s.last_request_end_time
FROM sys.dm_exec_sessions AS s
LEFT JOIN sys.dm_exec_connections AS c
ON s.session_id = c.session_id
CROSS APPLY sys.dm_exec_sql_text(c.most_recent_sql_handle) AS t
WHERE s.session_id = 95;

-- Ventana 1
ROLLBACK TRANSACTION;

/* ---------------------------------------------------------------------
   8. Cleanup (código oficial)
   --------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS dbo.GetCustomerOrders;
DROP TABLE IF EXISTS dbo.OrderHistory;
GO

-- Unforce all plans
DECLARE @qid INT, @pid INT;
SELECT TOP 1 @qid = q.query_id, @pid = p.plan_id
FROM sys.query_store_plan AS p
INNER JOIN sys.query_store_query AS q ON p.query_id = q.query_id
WHERE p.is_forced_plan = 1;
WHILE @@ROWCOUNT > 0
BEGIN
EXEC sp_query_store_unforce_plan @query_id = @qid, @plan_id = @pid;
SELECT TOP 1 @qid = q.query_id, @pid = p.plan_id
FROM sys.query_store_plan AS p
INNER JOIN sys.query_store_query AS q ON p.query_id = q.query_id
WHERE p.is_forced_plan = 1;
END
GO
