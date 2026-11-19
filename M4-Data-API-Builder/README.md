# M4 - Data API Builder

Laboratorio *Integrate SQL solutions with Azure services* (Microsoft Learn, módulo 4).

| Ruta | Contenido |
|---|---|
| `config/dab-config.json` | Configuración final de Data API Builder 1.7.90 (entidades `Category`, `Product` y `ProductCatalog`) |
| `scripts/M4-lab-product-catalog.sql` | Base `ProductCatalog`: tablas, vista, datos de ejemplo y limpieza |

## Ejecución local

```powershell
dotnet tool install --global Microsoft.DataApiBuilder --version 1.7.90
$env:DATABASE_CONNECTION_STRING="Server=<servidor>.database.windows.net;Database=ProductCatalog;User Id=<usuario>;Password=<TU_CONTRASEÑA>;TrustServerCertificate=true"
dab start
```

- REST: `http://localhost:5000/api/Product`
- GraphQL: `http://localhost:5000/graphql`

La cadena de conexión se lee de la variable de entorno (`@env('DATABASE_CONNECTION_STRING')`); el archivo de configuración no contiene credenciales.
