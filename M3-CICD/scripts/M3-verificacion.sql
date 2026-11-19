/* =====================================================================
   Proyecto Final de Base de Datos (1M3214) - UTP
   M3 - Ejercicio: Implement CI/CD with SQL Database Projects
   Consultas de verificación ejecutadas en SSMS después de cada despliegue
   Base de datos: AdventureWorksLT (servidor sqlsrv-awlt-pf)
   ===================================================================== */

-- Push and verify the first deployment (código oficial)
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME = 'InventoryLog';

SELECT ROUTINE_SCHEMA, ROUTINE_NAME
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_NAME = 'uspLogInventoryChange';

-- Push a schema change (código oficial)
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'InventoryLog'
ORDER BY ORDINAL_POSITION;
