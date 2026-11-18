/* =====================================================================
   Proyecto Final de Base de Datos (1M3214) - UTP
   M1 - Unidad 7: Configuración del acceso seguro a los servicios de IA
   Base de datos: PFBD2026 (Azure SQL Database)

   Requisitos previos (PowerShell, código adicional):
     az provider register --namespace Microsoft.CognitiveServices
     az cognitiveservices account create -n aoai-pfbd-em-2026 -g rg-pfbd-2026 -l northcentralus `
       --kind OpenAI --sku S0 --custom-domain aoai-pfbd-em-2026 --yes -o none
     az cognitiveservices account deployment create -n aoai-pfbd-em-2026 -g rg-pfbd-2026 `
       --deployment-name text-embedding --model-name text-embedding-3-small --model-version 1 `
       --model-format OpenAI --sku-name GlobalStandard --sku-capacity 1 -o none
     (Identidad administrada del servidor activada desde el portal: Servidor SQL > Identidad)

   Código oficial de PowerShell (adaptado: nombres de recursos):
     Install-Module Az.Accounts, Az.Sql, Az.Resources -Scope CurrentUser
     Connect-AzAccount
     $sqlIdentity = (Get-AzSqlServer -ServerName sqlsrv-pfbd-em-2026 -ResourceGroupName rg-pfbd-2026).Identity.PrincipalId
     $subId = (Get-AzContext).Subscription.Id
     New-AzRoleAssignment -ObjectId $sqlIdentity `
       -RoleDefinitionName "Cognitive Services User" `
       -Scope "/subscriptions/$subId/resourceGroups/rg-pfbd-2026/providers/Microsoft.CognitiveServices/accounts/aoai-pfbd-em-2026"
   ===================================================================== */

-- Código oficial (adaptado: nombre del recurso). En Azure SQL Database:
--   sys.dm_external_provider_certificate_store no existe (error 208)
--   CREATE EXTERNAL DATA SOURCE ... TYPE = REST no se admite (error 102)
SELECT * FROM sys.dm_external_provider_certificate_store;
GO
CREATE DATABASE SCOPED CREDENTIAL AzureOpenAICredential
WITH IDENTITY = 'Managed Identity',
SECRET = '{"resourceId": "https://cognitiveservices.azure.com/"}';
GO
CREATE EXTERNAL DATA SOURCE AzureOpenAI
WITH (
TYPE = REST,
LOCATION = 'https://aoai-pfbd-em-2026.openai.azure.com',
CREDENTIAL = AzureOpenAICredential
);
GO
CREATE PROCEDURE dbo.GetEmbedding
@InputText nvarchar(max),
@Embedding nvarchar(max) OUTPUT
AS
BEGIN
DECLARE @payload nvarchar(max) = JSON_OBJECT('input': @InputText);
DECLARE @response nvarchar(max);
EXEC sp_invoke_external_rest_endpoint
@url = 'https://aoai-pfbd-em-2026.openai.azure.com/openai/deployments/text-embedding/embeddings?api-version=2024-02-01',
@method = 'POST',
@payload = @payload,
@credential = AzureOpenAICredential,
@response = @response OUTPUT;
SET @Embedding = JSON_VALUE(@response, '$.data[0].embedding');
END;
GO
CREATE ROLE AIFeatureUsers;
GRANT EXECUTE ON dbo.GetEmbedding TO AIFeatureUsers;
ALTER ROLE AIFeatureUsers ADD MEMBER [app-service-identity];
GO

-- La llamada con AzureOpenAICredential devuelve el error 31630.
-- Adaptación: credencial con la URL como nombre, JSON_QUERY y ruta $.result
CREATE DATABASE SCOPED CREDENTIAL [https://aoai-pfbd-em-2026.openai.azure.com]
WITH IDENTITY = 'Managed Identity',
SECRET = '{"resourceId": "https://cognitiveservices.azure.com/"}';
GO
ALTER PROCEDURE dbo.GetEmbedding
@InputText nvarchar(max),
@Embedding nvarchar(max) OUTPUT
AS
BEGIN
DECLARE @payload nvarchar(max) = JSON_OBJECT('input': @InputText);
DECLARE @response nvarchar(max);
EXEC sp_invoke_external_rest_endpoint
@url = 'https://aoai-pfbd-em-2026.openai.azure.com/openai/deployments/text-embedding/embeddings?api-version=2024-02-01',
@method = 'POST',
@payload = @payload,
@credential = [https://aoai-pfbd-em-2026.openai.azure.com],
@response = @response OUTPUT;
SET @Embedding = JSON_QUERY(@response, '$.result.data[0].embedding');
END;
GO

DECLARE @e nvarchar(max);
EXEC dbo.GetEmbedding @InputText = N'Seguridad de bases de datos', @Embedding = @e OUTPUT;
SELECT LEFT(@e, 200) AS Embedding;
GO

-- Origen: M1 > Unidad 7 > Implementación de la supervisión de puntos de conexión
CREATE TABLE dbo.AIEndpointLog (
LogID int IDENTITY PRIMARY KEY,
CallTimestamp datetime2 DEFAULT SYSUTCDATETIME(),
CallerPrincipal nvarchar(128) DEFAULT ORIGINAL_LOGIN(),
EndpointName nvarchar(256),
InputLength int,
ResponseStatus int,
DurationMs int
);
GO

-- Adaptado: @payload como variable (la unidad pasa JSON_OBJECT directamente en EXEC),
-- credencial con la URL como nombre, JSON_QUERY y ruta $.result
CREATE PROCEDURE dbo.GetEmbeddingWithLogging
@InputText nvarchar(max),
@Embedding nvarchar(max) OUTPUT
AS
BEGIN
DECLARE @StartTime datetime2 = SYSUTCDATETIME();
DECLARE @payload nvarchar(max) = JSON_OBJECT('input': @InputText);
DECLARE @response nvarchar(max);
DECLARE @status int;
EXEC sp_invoke_external_rest_endpoint
@url = 'https://aoai-pfbd-em-2026.openai.azure.com/openai/deployments/text-embedding/embeddings?api-version=2024-02-01',
@method = 'POST',
@payload = @payload,
@credential = [https://aoai-pfbd-em-2026.openai.azure.com],
@response = @response OUTPUT;
INSERT INTO dbo.AIEndpointLog (EndpointName, InputLength, ResponseStatus, DurationMs)
VALUES ('text-embedding', LEN(@InputText), 200, DATEDIFF(millisecond, @StartTime, SYSUTCDATETIME()));
SET @Embedding = JSON_QUERY(@response, '$.result.data[0].embedding');
END;
GO

-- Datos adicionales para demostración
DECLARE @e nvarchar(max);
EXEC dbo.GetEmbeddingWithLogging @InputText = N'Cifrado de datos', @Embedding = @e OUTPUT;
EXEC dbo.GetEmbeddingWithLogging @InputText = N'Seguridad a nivel de fila', @Embedding = @e OUTPUT;
EXEC dbo.GetEmbeddingWithLogging @InputText = N'Auditoría de bases de datos', @Embedding = @e OUTPUT;
SELECT * FROM dbo.AIEndpointLog;

-- Código oficial
SELECT CallerPrincipal, COUNT(*) AS CallCount, AVG(DurationMs) AS AvgDuration
FROM dbo.AIEndpointLog
WHERE CallTimestamp > DATEADD(hour, -1, SYSUTCDATETIME())
GROUP BY CallerPrincipal
HAVING COUNT(*) > 100
ORDER BY CallCount DESC;
GO
