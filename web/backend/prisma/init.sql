-- LiveLingo Database Initialization Script
-- This script runs automatically when PostgreSQL container starts

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE livelingo TO postgres;

-- Create schema if not exists
CREATE SCHEMA IF NOT EXISTS public;

-- Set default search path
SET search_path TO public;

-- Log initialization
DO $$
BEGIN
    RAISE NOTICE 'LiveLingo database initialized successfully!';
END $$;
