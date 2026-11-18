/* =====================================================================
   Proyecto Final de Base de Datos (1M3214) - UTP
   M1 - Unidad 6: Implementación de la auditoría
   Parte 1: SQL Server Audit en la instancia local .\SQL2025
   Parte 2: Auditoría de Azure SQL Database (PFBD2026) con Log Analytics
   ===================================================================== */

/* ---------------------------------------------------------------------
   PARTE 1 - SQL Server (instancia local)
   Requisito previo (PowerShell como administrador, código adicional):
     icacls C:\AuditLogs /grant 'NT Service\MSSQL$SQL2025:(OI)(CI)M'
   --------------------------------------------------------------------- */
USE master;
GO

-- Origen: M1 > Unidad 6 > Configuración de la auditoría de SQL Server (código oficial)
CREATE SERVER AUDIT SecurityAudit
TO FILE (FILEPATH = 'C:\AuditLogs\', MAXSIZE = 100 MB, MAX_ROLLOVER_FILES = 10)
WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);

ALTER SERVER AUDIT SecurityAudit WITH (STATE = ON);

CREATE SERVER AUDIT SPECIFICATION ServerAuditSpec
FOR SERVER AUDIT SecurityAudit
ADD (FAILED_LOGIN_GROUP),
ADD (SUCCESSFUL_LOGIN_GROUP),
ADD (SERVER_PERMISSION_CHANGE_GROUP),
ADD (DATABASE_PERMISSION_CHANGE_GROUP)
WITH (STATE = ON);
GO

-- Verificación (código adicional)
SELECT name, status_desc, audit_file_path FROM sys.dm_server_audit_status;
SELECT audit_action_name FROM sys.server_audit_specification_details d
JOIN sys.server_audit_specifications s ON d.server_specification_id = s.server_specification_id
WHERE s.name = 'ServerAuditSpec';
GO

-- Código adicional: base de datos y tabla del ejemplo de la unidad
CREATE DATABASE MyDatabase;
GO
USE MyDatabase;
GO
CREATE TABLE dbo.SensitiveData (ID int PRIMARY KEY, Detalle varchar(100));
CREATE ROLE AuditTestRole;
CREATE USER AuditTestUser WITHOUT LOGIN;
GO

-- Código oficial
USE MyDatabase;
GO
CREATE DATABASE AUDIT SPECIFICATION DatabaseAuditSpec
FOR SERVER AUDIT SecurityAudit
ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.SensitiveData BY public),
ADD (EXECUTE ON SCHEMA::dbo BY public),
ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP)
WITH (STATE = ON);
GO

-- Verificación (código adicional)
SELECT audit_action_name, class_desc, OBJECT_NAME(major_id) AS Objeto
FROM sys.database_audit_specification_details;
GO

-- Datos adicionales para demostración: generar eventos
INSERT INTO dbo.SensitiveData VALUES (1, 'Dato confidencial de prueba');
SELECT * FROM dbo.SensitiveData;
UPDATE dbo.SensitiveData SET Detalle = 'Dato modificado' WHERE ID = 1;
ALTER ROLE AuditTestRole ADD MEMBER AuditTestUser;
GO
WAITFOR DELAY '00:00:02';

-- Origen: M1 > Unidad 6 > Consulta y análisis de registros de auditoría (código oficial)
SELECT
event_time,
action_id,
succeeded,
session_server_principal_name AS UserName,
database_name,
object_name,
statement
FROM fn_get_audit_file('C:\AuditLogs\*.sqlaudit', DEFAULT, DEFAULT)
WHERE event_time > DATEADD(day, -7, GETUTCDATE())
ORDER BY event_time DESC;
GO

/* ---------------------------------------------------------------------
   PARTE 2 - Azure SQL Database (PFBD2026)

   El T-SQL de la unidad no está admitido en Azure SQL Database
   (error 40510), por lo que la auditoría se configuró con Azure CLI:

   ALTER DATABASE AUDIT SPECIFICATION AzureAuditSpec
   ADD (SELECT, INSERT, UPDATE, DELETE ON DATABASE::PFBD2026 BY public)
   WITH (STATE = ON);

   PowerShell (configuración del JSON de la unidad aplicada con Azure CLI):
     az provider register --namespace Microsoft.OperationalInsights
     az provider register --namespace Microsoft.Insights
     az monitor log-analytics workspace create -g rg-pfbd-2026 -n law-pfbd-2026 -l brazilsouth -o none
     $lawId = az monitor log-analytics workspace show -g rg-pfbd-2026 -n law-pfbd-2026 --query id -o tsv
     az sql db audit-policy update -g rg-pfbd-2026 -s sqlsrv-pfbd-em-2026 -n PFBD2026 `
       --state Enabled `
       --actions SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP FAILED_DATABASE_AUTHENTICATION_GROUP BATCH_COMPLETED_GROUP `
       --log-analytics-target-state Enabled --log-analytics-workspace-resource-id $lawId -o none

   KQL (Log Analytics):

   -- Código oficial (devuelve 0 filas con BATCH_COMPLETED_GROUP)
   AzureDiagnostics
   | where Category == "SQLSecurityAuditEvents"
   | where TimeGenerated > ago(7d)
   | where action_name_s == "SELECT"
   | summarize count() by client_ip_s, server_principal_name_s
   | order by count_ desc

   -- Acciones registradas
   AzureDiagnostics
   | where Category == "SQLSecurityAuditEvents"
   | summarize count() by action_name_s

   -- Adaptado: filtro por BATCH COMPLETED
   AzureDiagnostics
   | where Category == "SQLSecurityAuditEvents"
   | where TimeGenerated > ago(7d)
   | where action_name_s == "BATCH COMPLETED" and statement_s contains "SELECT"
   | summarize count() by client_ip_s, server_principal_name_s
   | order by count_ desc
   --------------------------------------------------------------------- */
