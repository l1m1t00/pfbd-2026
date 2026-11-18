/* =====================================================================
   Proyecto Final de Base de Datos (1M3214) - UTP
   M1 - Unidad 2: Protección de datos con cifrado
   Base de datos: PFBD2026 (Azure SQL Database)
   ===================================================================== */

/* ---------------------------------------------------------------------
   1. TDE (código adicional: la unidad no incluye código de verificación)
   --------------------------------------------------------------------- */
SELECT DB_NAME(database_id) AS BaseDatos, encryption_state_desc, key_algorithm, key_length
FROM sys.dm_database_encryption_keys;
GO

/* ---------------------------------------------------------------------
   2. Always Encrypted
   Requisito previo (PowerShell, código adicional):
     az provider register --namespace Microsoft.KeyVault
     az keyvault create -n kv-pfbd-em-2026 -g rg-pfbd-2026 -l brazilsouth --enable-rbac-authorization true
     az role assignment create --assignee-object-id <OBJECT_ID> --assignee-principal-type User `
       --role "Key Vault Crypto Officer" --scope <KEYVAULT_ID>
     az keyvault key create --vault-name kv-pfbd-em-2026 -n MyCMK --kty RSA --size 2048
   --------------------------------------------------------------------- */

-- Origen: M1 > Unidad 2 > Configuración de Always Encrypted (adaptado: KEY_PATH)
CREATE COLUMN MASTER KEY MyCMK
WITH (
KEY_STORE_PROVIDER_NAME = 'AZURE_KEY_VAULT',
KEY_PATH = 'https://kv-pfbd-em-2026.vault.azure.net/keys/MyCMK/db3c15050a7a47859aa5085d448cf58a'
);
GO
SELECT name, key_store_provider_name, key_path FROM sys.column_master_keys;
GO

-- Origen: M1 > Unidad 2 > Configuración de Always Encrypted
-- La CEK MyCEK se creó desde SSMS (Seguridad > Claves de Always Encrypted >
-- Nueva clave de cifrado de columna), porque ENCRYPTED_VALUE se genera con la CMK
-- dentro de Key Vault y no puede escribirse a mano. Script generado por SSMS:
-- CREATE COLUMN ENCRYPTION KEY [MyCEK]
-- WITH VALUES (COLUMN_MASTER_KEY = [MyCMK], ALGORITHM = 'RSA_OAEP', ENCRYPTED_VALUE = 0x01A6...);

-- Origen: M1 > Unidad 2 > Configuración de Always Encrypted (código oficial)
CREATE TABLE Employees (
EmployeeID int PRIMARY KEY,
SSN char(11) COLLATE Latin1_General_BIN2
ENCRYPTED WITH (
ENCRYPTION_TYPE = DETERMINISTIC,
ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256',
COLUMN_ENCRYPTION_KEY = MyCEK
),
Salary money
ENCRYPTED WITH (
ENCRYPTION_TYPE = RANDOMIZED,
ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256',
COLUMN_ENCRYPTION_KEY = MyCEK
)
);
GO

-- Verificación (código adicional)
SELECT c.name AS Columna, c.encryption_type_desc AS TipoCifrado,
       c.encryption_algorithm_name AS Algoritmo, k.name AS CEK
FROM sys.columns c
LEFT JOIN sys.column_encryption_keys k ON c.column_encryption_key_id = k.column_encryption_key_id
WHERE c.object_id = OBJECT_ID('dbo.Employees');
GO

-- Datos adicionales para demostración.
-- Ejecutar en una conexión con "Habilitar Always Encrypted" y con la
-- parametrización de Always Encrypted activada en la ventana de consulta.
DECLARE @SSN1 char(11) = '123-45-6789';
DECLARE @Sal1 money = 52000;
DECLARE @SSN2 char(11) = '987-65-4321';
DECLARE @Sal2 money = 61500;

INSERT INTO Employees (EmployeeID, SSN, Salary) VALUES (1, @SSN1, @Sal1);
INSERT INTO Employees (EmployeeID, SSN, Salary) VALUES (2, @SSN2, @Sal2);

SELECT * FROM Employees;
SELECT * FROM Employees WHERE SSN = @SSN1;
GO

-- Desde una conexión SIN Always Encrypted, las columnas se ven cifradas:
-- SELECT * FROM Employees;

/* ---------------------------------------------------------------------
   3. Cifrado a nivel de columna
   Origen: M1 > Unidad 2 > Implementación del cifrado de nivel de columna
   (adaptado: contraseña propia, no incluida en el repositorio)
   --------------------------------------------------------------------- */
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '<TU_CONTRASEÑA>';
CREATE CERTIFICATE SensitiveDataCert
WITH SUBJECT = 'Certificate for sensitive data encryption';
CREATE SYMMETRIC KEY SensitiveDataKey
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE SensitiveDataCert;
GO
SELECT name, algorithm_desc, key_length FROM sys.symmetric_keys;
SELECT name, subject FROM sys.certificates WHERE name = 'SensitiveDataCert';
GO

-- Código adicional: tabla requerida por el ejemplo de la unidad
CREATE TABLE CustomerData (
CustomerID int PRIMARY KEY,
CreditCardNumber varbinary(256)
);
GO

-- Código oficial (ejecutar junto: la clave se abre y se cierra en la misma sesión)
OPEN SYMMETRIC KEY SensitiveDataKey
DECRYPTION BY CERTIFICATE SensitiveDataCert;
INSERT INTO CustomerData (CustomerID, CreditCardNumber)
VALUES (1, ENCRYPTBYKEY(KEY_GUID('SensitiveDataKey'), '4111-1111-1111-1111'));
CLOSE SYMMETRIC KEY SensitiveDataKey;

SELECT * FROM CustomerData;
GO

-- Código oficial (ejecutar junto)
OPEN SYMMETRIC KEY SensitiveDataKey
DECRYPTION BY CERTIFICATE SensitiveDataCert;
SELECT CustomerID,
CONVERT(varchar(20), DECRYPTBYKEY(CreditCardNumber)) AS CardNumber
FROM CustomerData;
CLOSE SYMMETRIC KEY SensitiveDataKey;
GO
