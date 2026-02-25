-- ========================================
-- SCRIPT: 01_create_database.sql
-- PURPOSE: Create OLTP source database
-- ========================================

USE master;
GO

IF DB_ID(''ECOMMERCE_OLTP'') IS NULL
BEGIN
    CREATE DATABASE ECOMMERCE_OLTP;
END;
GO

PRINT ''ECOMMERCE_OLTP ready.'';
GO