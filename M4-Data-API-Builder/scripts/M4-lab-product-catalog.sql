/* =====================================================================
   Proyecto Final de Base de Datos (1M3214) - UTP
   M4 - Ejercicio: Integrate SQL solutions with Azure services
   Fuente: Microsoft Learn Lab Exercises (Módulo 4)
   Servidor: sqlsrv-awlt-pf (Azure SQL Database)
   ===================================================================== */

-- Set up the sample database (código oficial) - ejecutar en master
CREATE DATABASE ProductCatalog;
GO

-- Abrir una nueva consulta sobre ProductCatalog (en Azure SQL no se usa USE)

-- Create Categories table
CREATE TABLE dbo.Categories (
CategoryID INT IDENTITY(1,1) PRIMARY KEY,
CategoryName NVARCHAR(50) NOT NULL,
Description NVARCHAR(200)
);

-- Create Products table
CREATE TABLE dbo.Products (
ProductID INT IDENTITY(1,1) PRIMARY KEY,
ProductName NVARCHAR(100) NOT NULL,
CategoryID INT NOT NULL,
UnitPrice DECIMAL(10,2) NOT NULL,
UnitsInStock INT NOT NULL DEFAULT 0,
Discontinued BIT NOT NULL DEFAULT 0,
CONSTRAINT FK_Products_Categories
FOREIGN KEY (CategoryID) REFERENCES dbo.Categories(CategoryID)
);
GO

-- Create a view combining product and category information
CREATE VIEW dbo.ProductCatalogView AS
SELECT
p.ProductID,
p.ProductName,
c.CategoryName,
p.UnitPrice,
p.UnitsInStock,
CASE
WHEN p.UnitsInStock = 0 THEN 'Out of Stock'
WHEN p.UnitsInStock < 10 THEN 'Low Stock'
ELSE 'Available'
END AS StockStatus
FROM dbo.Products p
INNER JOIN dbo.Categories c ON p.CategoryID = c.CategoryID
WHERE p.Discontinued = 0;
GO

-- Insert categories
INSERT INTO dbo.Categories (CategoryName, Description) VALUES
('Electronics', 'Electronic devices and accessories'),
('Clothing', 'Apparel and fashion items'),
('Home & Garden', 'Products for home improvement');

-- Insert products
INSERT INTO dbo.Products (ProductName, CategoryID, UnitPrice, UnitsInStock) VALUES
('Wireless Headphones', 1, 79.99, 50),
('USB-C Cable', 1, 12.99, 200),
('Laptop Stand', 1, 45.00, 5),
('Cotton T-Shirt', 2, 24.99, 100),
('Running Shoes', 2, 89.99, 0),
('Garden Hose', 3, 34.99, 25);
GO

-- Cleanup (código oficial)
USE master;
GO
DROP DATABASE IF EXISTS ProductCatalog;
GO
