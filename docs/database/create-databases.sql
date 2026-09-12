-- =============================================================================
-- Script de Criação do Banco de Dados — Plataforma de Processamento de Vídeos
-- =============================================================================
--
-- ⚠️ ARQUITETURA REAL: DATABASE-PER-SERVICE (1 banco de dados por microsserviço)
-- -----------------------------------------------------------------------------
-- Cada microsserviço abaixo possui seu PRÓPRIO banco de dados PostgreSQL,
-- isolado, com usuário/credenciais exclusivos, rodando em um StatefulSet
-- Kubernetes dedicado no cluster local (Docker Desktop) — ver ADR-004 em
-- "fiap-14soat-tc-fase5-iac-terraform/docs/ADR - Architecture Decision Records/".
--
-- NENHUM microsserviço acessa a tabela de outro diretamente. Toda a integração
-- entre eles ocorre exclusivamente via RabbitMQ (mensageria assíncrona) ou
-- chamadas REST — nunca via acesso direto a banco de dados de outro serviço.
--
-- POR QUE ESTE SCRIPT ÚNICO EXISTE, ENTÃO?
-- -----------------------------------------------------------------------------
-- O enunciado do Hackathon (docs/requirements/POSTECH - SOAT - Fase 5 - Hacka.txt)
-- exige, no item de Entregáveis:
--   "Script de criação do banco de dados ou de outros recursos utilizados."
--
-- Este arquivo é uma CONSOLIDAÇÃO, criada apenas para atender a esse entregável
-- de forma centralizada e facilitar a avaliação/apresentação do projeto.
-- A fonte da verdade de cada schema continua sendo as migrations FLYWAY
-- versionadas dentro de cada repositório de microsserviço:
--
--   fiap-14soat-tc-fase5-auth/infrastructure/src/main/resources/db/migration/V1__create_users_table.sql
--   fiap-14soat-tc-fase5-video-upload-service/infrastructure/src/main/resources/db/migration/V1__create_videos_table.sql
--   fiap-14soat-tc-fase5-video-status-service/infrastructure/src/main/resources/db/migration/V1__create_videos_table.sql
--
-- Este script NÃO deve ser executado como parte de nenhum pipeline de deploy.
-- Ele serve apenas como documentação/DDL de referência para o desafio.
--
-- ACHADO: o Terraform (infra/secrets.tf, infra/postgres.tf) também provisiona
-- um banco "video_processing_db" para o video-processing-service, mas nenhuma
-- migration/uso desse banco foi identificado no código atual do serviço.
-- Mantido como está (fora de escopo desta revisão) — ver ADR-004.
-- =============================================================================


-- =============================================================================
-- 1) Banco: auth_db  —  Microsserviço: fiap-14soat-tc-fase5-auth
-- =============================================================================
-- Execução real: CREATE DATABASE auth_db; (usuário/senha via Secret Kubernetes
-- "postgres-auth-secret", StatefulSet "postgres-auth")

-- \connect auth_db

CREATE TABLE IF NOT EXISTS users (
    id            BIGSERIAL PRIMARY KEY,
    username      VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role          VARCHAR(50)  NOT NULL DEFAULT 'USER',
    active        BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Usuários de exemplo — apenas para ambiente local/demonstração do desafio.
-- NÃO usar estas credenciais em um ambiente real.
INSERT INTO users (username, password_hash, role)
VALUES
    ('admin', '$2b$12$iLk5Y4NuCe95qn.veHzN5OUy9r.WWxewTIRITXqjIZA8g1q8DMci.', 'ADMIN'),
    ('user',  '$2b$12$psMRyaK9wKbBaYf8QYWVl.b6GrFYCb4aArhlLTqpgHBS.JndV4fge', 'USER')
ON CONFLICT (username) DO NOTHING;
-- Credenciais padrão (ambiente local): admin/admin123 · user/user123


-- =============================================================================
-- 2) Banco: video_upload_db  —  Microsserviço: fiap-14soat-tc-fase5-video-upload-service
-- =============================================================================
-- Execução real: CREATE DATABASE video_upload_db; (Secret "postgres-upload-secret",
-- StatefulSet "postgres-upload")

-- \connect video_upload_db

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS videos (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           VARCHAR(255) NOT NULL,
    original_filename VARCHAR(500) NOT NULL,
    file_size_bytes   BIGINT       NOT NULL,
    mime_type         VARCHAR(100) NOT NULL,
    status            VARCHAR(50)  NOT NULL DEFAULT 'PENDING',
    storage_key       TEXT,
    created_at        TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_videos_user_id ON videos(user_id);
CREATE INDEX IF NOT EXISTS idx_videos_status  ON videos(status);


-- =============================================================================
-- 3) Banco: video_status_db  —  Microsserviço: fiap-14soat-tc-fase5-video-status-service
-- =============================================================================
-- Execução real: CREATE DATABASE video_status_db; (Secret "postgres-status-secret",
-- StatefulSet "postgres-status")

-- \connect video_status_db

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS videos (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           VARCHAR(255) NOT NULL,
    original_filename VARCHAR(500) NOT NULL,
    file_size_bytes   BIGINT       NOT NULL,
    mime_type         VARCHAR(100) NOT NULL,
    status            VARCHAR(50)  NOT NULL DEFAULT 'PENDING',
    storage_key       TEXT,
    created_at        TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_videos_user_id ON videos(user_id);
CREATE INDEX IF NOT EXISTS idx_videos_status  ON videos(status);


-- =============================================================================
-- 4) Banco: video_processing_db  —  Provisionado, sem uso identificado
-- =============================================================================
-- Execução real: CREATE DATABASE video_processing_db; (Secret "postgres-processing-secret",
-- StatefulSet "postgres-processing")
--
-- Nenhuma migration Flyway ou configuração de datasource foi encontrada no
-- código atual do video-processing-service. Mantido apenas como registro do
-- recurso provisionado — sem alteração de escopo (ver ADR-004).
-- =============================================================================
