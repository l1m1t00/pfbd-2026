/* =====================================================================
   Proyecto Final de Base de Datos (1M3214) - UTP
   M1 - Unidad 5: Administración de permisos y acceso seguro
   Base de datos: PFBD2026 (Azure SQL Database)
   ===================================================================== */

-- Código adicional: objetos que la unidad usa pero no crea
CREATE USER SalesAnalyst WITHOUT LOGIN;
CREATE USER JohnSmith WITHOUT LOGIN;
CREATE USER JaneDoc WITHOUT LOGIN;
CREATE ROLE ReportingUsers;
CREATE ROLE CustomerServiceRole;
CREATE ROLE OrderProcessingRole;
CREATE ROLE HRAssistants;
CREATE ROLE SalesTeam;
CREATE ROLE HRAdministrators;
GO
CREATE SCHEMA Reports;
GO
CREATE TABLE dbo.EmployeeSalaries (EmployeeID int PRIMARY KEY, Salary money);
CREATE TABLE Sales.Orders (OrderID int PRIMARY KEY, OrderDate date, Total decimal(10,2));
GO

-- Origen: M1 > Unidad 5 (código oficial)
GRANT SELECT ON SCHEMA::Sales TO SalesAnalyst;
GRANT EXECUTE ON SCHEMA::Reports TO ReportingUsers;

GRANT SELECT ON dbo.Customers TO CustomerServiceRole;
GRANT INSERT, UPDATE ON dbo.Orders TO OrderProcessingRole;
DENY SELECT ON dbo.EmployeeSalaries TO HRAssistants;
REVOKE INSERT ON dbo.Customers FROM CustomerServiceRole;

CREATE ROLE DataReaders;
CREATE ROLE DataWriters;
GRANT SELECT ON SCHEMA::dbo TO DataReaders;
GRANT INSERT, UPDATE, DELETE ON SCHEMA::dbo TO DataWriters;
ALTER ROLE DataReaders ADD MEMBER JohnSmith;
ALTER ROLE DataWriters ADD MEMBER JaneDoc;
GO

-- CREATE SCHEMA Sales AUTHORIZATION dbo;  -- omitido: el esquema Sales ya existe (sección 5.3)
CREATE SCHEMA HR AUTHORIZATION dbo;
GO
GRANT SELECT, INSERT, UPDATE ON SCHEMA::Sales TO SalesTeam;
GRANT CONTROL ON SCHEMA::HR TO HRAdministrators;
GO

-- Visualización de permisos (código oficial)
SELECT
prin.name AS PrincipalName,
perm.permission_name,
perm.state_desc AS PermissionState,
obj.name AS ObjectName
FROM sys.database_permissions perm
INNER JOIN sys.database_principals prin ON perm.grantee_principal_id = prin.principal_id
LEFT JOIN sys.objects obj ON perm.major_id = obj.object_id
WHERE prin.name = 'SalesAnalyst';

SELECT * FROM fn_my_permissions('Sales.Orders', 'OBJECT');
GO

-- Verificación general (código adicional)
SELECT pr.name AS Principal, pe.permission_name AS Permiso, pe.state_desc AS Estado, pe.class_desc AS Nivel,
       CASE pe.class WHEN 1 THEN OBJECT_NAME(pe.major_id) WHEN 3 THEN SCHEMA_NAME(pe.major_id) END AS Objeto
FROM sys.database_permissions pe
JOIN sys.database_principals pr ON pe.grantee_principal_id = pr.principal_id
WHERE pr.name IN ('SalesAnalyst','ReportingUsers','CustomerServiceRole','OrderProcessingRole','HRAssistants',
                  'DataReaders','DataWriters','SalesTeam','HRAdministrators')
ORDER BY pr.name;
GO

/* ---------------------------------------------------------------------
   Autenticación sin contraseña (Microsoft Entra ID e identidades administradas)
   Requisito previo (PowerShell, código adicional):
     az provider register --namespace Microsoft.ManagedIdentity
     az identity create -g rg-pfbd-2026 -n app-service-identity -l brazilsouth -o none
     az identity create -g rg-pfbd-2026 -n MyWebApp -l brazilsouth -o none
   Ejecutar conectado con autenticación Microsoft Entra MFA (administrador de Entra).
   Adaptación: se omiten [developer@contoso.com] y [DataAnalystsGroup], que no existen
   en el tenant de la universidad.
   --------------------------------------------------------------------- */
CREATE USER [app-service-identity] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datawriter ADD MEMBER [app-service-identity];

CREATE USER [MyWebApp] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [MyWebApp];
ALTER ROLE db_datawriter ADD MEMBER [MyWebApp];

-- Verificación (código adicional)
SELECT SUSER_SNAME() AS ConectadoComo;
SELECT p.name AS Usuario, p.type_desc AS Tipo, p.authentication_type_desc AS Autenticacion, r.name AS Rol
FROM sys.database_principals p
LEFT JOIN sys.database_role_members rm ON rm.member_principal_id = p.principal_id
LEFT JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
WHERE p.name IN ('app-service-identity','MyWebApp');
GO
