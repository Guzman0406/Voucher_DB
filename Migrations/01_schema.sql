CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Creación de ENUMS
CREATE TYPE "Frecuencia" AS ENUM ('Semanal', 'Quincenal', 'Mensual');
CREATE TYPE "CategoriaGasto" AS ENUM ('Vital', 'Recurrente');

-- Tabla: users
CREATE TABLE "users" (
    "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
    "name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, -- (3) Precisión en milisegundos
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "users_email_key" ON "users"("email"); -- Aceleramos busquedas por email (login)

-- Tabla: user_configs 
CREATE TABLE "user_configs" (
    "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
    "salario" DOUBLE PRECISION NOT NULL,
    "frecuencia" "Frecuencia" NOT NULL,
    "diaInicio" INTEGER NOT NULL,
    "saldoActual" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "ahorroHistorico" DOUBLE PRECISION NOT NULL DEFAULT 0,  -- Linea de ahorro ANTES de usar la app (se usa para evaluar la hipotesis)
    "sobranteCicloAnterior" DOUBLE PRECISION NOT NULL DEFAULT 0, 
    "ahorroBaseEsperado" DOUBLE PRECISION NOT NULL DEFAULT 0,    -- Meta de ahorro calculado por el backend
    "pendingConfig" JSONB, -- Configuración pendiente de cambiar como salario etc.
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "userId" TEXT NOT NULL,
    CONSTRAINT "user_configs_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "user_configs_userId_key" ON "user_configs"("userId"); -- Permite que un usuario solo tenga una configuración

