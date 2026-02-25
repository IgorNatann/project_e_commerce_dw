-- ========================================
-- SCRIPT: 01_create_database.sql
-- OBJETIVO: criar database OLTP da origem
-- ========================================

USE master;
GO

IF DB_ID('ECOMMERCE_OLTP') IS NULL
BEGIN
    CREATE DATABASE ECOMMERCE_OLTP;
    PRINT 'Database ECOMMERCE_OLTP criada.';
END
ELSE
BEGIN
    PRINT 'Database ECOMMERCE_OLTP ja existe.';
END;
GO
