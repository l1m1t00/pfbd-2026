# M3 - CI/CD con proyectos de SQL Database

Copia del laboratorio *Implement CI/CD with SQL Database Projects* (Microsoft Learn, módulo 3).
El pipeline se ejecutó en el repositorio privado `AdventureWorksDB`, que crea el laboratorio.

## Estructura

| Ruta | Contenido |
|---|---|
| `database-project/AdventureWorksDB/` | Proyecto SDK de SQL Database (destino Azure SQL Database, `SqlAzureV12`) |
| `pipelines/build-deploy.yml` | Flujo de GitHub Actions que compila el `.dacpac` y lo publica con `azure/sql-action` |
| `scripts/M3-verificacion.sql` | Consultas de verificación ejecutadas en SSMS |

## Funcionamiento

1. Cada push a `main` activa el flujo.
2. `dotnet build` compila el proyecto y genera `AdventureWorksDB.dacpac`.
3. `azure/sql-action` compara el `.dacpac` con la base de datos y aplica los `CREATE`/`ALTER` necesarios.

La cadena de conexión se guarda como el secreto `SQL_CONNECTION_STRING` del repositorio y nunca se escribe en el código.

> El flujo está fuera de `.github/workflows` a propósito, para que no se ejecute en este repositorio, que no tiene el secreto configurado.
