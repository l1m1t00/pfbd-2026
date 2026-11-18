/* =====================================================================
   Proyecto Final de Base de Datos (1M3214) - UTP
   M1 - Unidad 3: Configuración del enmascaramiento dinámico de datos
   Base de datos: PFBD2026 (Azure SQL Database)
   ===================================================================== */

-- Origen: M1 > Unidad 3 > Configura máscaras de columna (código oficial)
CREATE TABLE Customers (
CustomerID int PRIMARY KEY,
FirstName varchar(50),
LastName varchar(50),
Email varchar(100) MASKED WITH (FUNCTION = 'email()'),
Phone varchar(20) MASKED WITH (FUNCTION = 'partial(3, "-XXX-XX", 2)'),
CreditCardNumber varchar(19) MASKED WITH (FUNCTION = 'partial(0, "XXXX-XXXX-XXXX-", 4)'),
Income decimal(18,2) MASKED WITH (FUNCTION = 'random(10000, 100000)'),
SSN char(11) MASKED WITH (FUNCTION = 'default()')
);
GO

-- Verificación (código adicional)
SELECT name AS Columna, masking_function AS FuncionMascara
FROM sys.masked_columns
WHERE object_id = OBJECT_ID('dbo.Customers');
GO

-- Código adicional: la columna DateOfBirth no existe en la tabla de la unidad
ALTER TABLE Customers ADD DateOfBirth date;
GO

-- Código oficial: agregar y quitar máscara
ALTER TABLE Customers
ALTER COLUMN DateOfBirth ADD MASKED WITH (FUNCTION = 'default()');

SELECT name AS Columna, masking_function AS FuncionMascara
FROM sys.masked_columns WHERE object_id = OBJECT_ID('dbo.Customers');

ALTER TABLE Customers
ALTER COLUMN DateOfBirth DROP MASKED;

SELECT name AS Columna, masking_function AS FuncionMascara
FROM sys.masked_columns WHERE object_id = OBJECT_ID('dbo.Customers');
GO

-- Código adicional: usuarios y esquema que la unidad menciona pero no crea
CREATE USER DataAnalyst WITHOUT LOGIN;
CREATE USER SalesManager WITHOUT LOGIN;
CREATE USER CustomerService WITHOUT LOGIN;
CREATE USER TelemarketingTeam WITHOUT LOGIN;
CREATE USER SupportStaff WITHOUT LOGIN;
CREATE USER ComplianceOfficer WITHOUT LOGIN;
GO
CREATE SCHEMA Sales;
GO

-- Origen: M1 > Unidad 3 > Control de la visibilidad de la máscara con permisos (código oficial)
GRANT UNMASK TO DataAnalyst;
GRANT UNMASK ON SCHEMA::Sales TO SalesManager;
GRANT UNMASK ON Customers TO CustomerService;
GRANT UNMASK ON Customers(Phone) TO TelemarketingTeam;
GO

-- Verificación (código adicional)
SELECT pr.name AS Usuario, pe.permission_name AS Permiso, pe.class_desc AS Nivel,
       CASE pe.class WHEN 1 THEN OBJECT_NAME(pe.major_id)
                     WHEN 3 THEN SCHEMA_NAME(pe.major_id) END AS Objeto,
       COL_NAME(pe.major_id, pe.minor_id) AS Columna
FROM sys.database_permissions pe
JOIN sys.database_principals pr ON pe.grantee_principal_id = pr.principal_id
WHERE pe.permission_name = 'UNMASK';
GO

-- Origen: M1 > Unidad 3 > Implementación de estrategias de enmascaramiento (código oficial)
CREATE ROLE MaskedDataViewers;
GRANT SELECT ON Customers TO MaskedDataViewers;

CREATE ROLE UnmaskedDataViewers;
GRANT SELECT ON Customers TO UnmaskedDataViewers;
GRANT UNMASK ON Customers TO UnmaskedDataViewers;

ALTER ROLE MaskedDataViewers ADD MEMBER SupportStaff;
ALTER ROLE UnmaskedDataViewers ADD MEMBER ComplianceOfficer;
GO

-- Verificación (código adicional)
SELECT r.name AS Rol, m.name AS Miembro
FROM sys.database_role_members rm
JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id
WHERE r.name IN ('MaskedDataViewers','UnmaskedDataViewers');
GO

-- Datos adicionales para demostración
INSERT INTO Customers (CustomerID, FirstName, LastName, Email, Phone, CreditCardNumber, Income, SSN, DateOfBirth)
VALUES (1, 'Ana',  'Pérez', 'ana.perez@contoso.com',  '206-555-0147', '4111-1111-1111-1234', 45000.00, '123-45-6789', '1990-05-14'),
       (2, 'Luis', 'Gómez', 'luis.gomez@contoso.com', '507-555-0198', '5500-0000-0000-0004', 72000.00, '987-65-4321', '1985-11-02');

GRANT SELECT ON Customers TO TelemarketingTeam;   -- solo para la demostración

EXECUTE AS USER = 'SupportStaff';       SELECT 'SupportStaff' AS Usuario, * FROM Customers;      REVERT;
EXECUTE AS USER = 'TelemarketingTeam';  SELECT 'TelemarketingTeam' AS Usuario, * FROM Customers; REVERT;
EXECUTE AS USER = 'ComplianceOfficer';  SELECT 'ComplianceOfficer' AS Usuario, * FROM Customers; REVERT;
GO
