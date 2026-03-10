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

-- Tabla: gastos 
CREATE TABLE "gastos" (
    "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
    "nombre" TEXT NOT NULL,
    "monto" DOUBLE PRECISION NOT NULL,
    "categoria" "CategoriaGasto" NOT NULL,
    "frecuencia" "Frecuencia" NOT NULL,
    "pagado" BOOLEAN NOT NULL DEFAULT false, -- Indica si el gasto ya fue pagado en el ciclo actual
    "canceladoParaElFuturo" BOOLEAN NOT NULL DEFAULT false, -- El gasto ya no aparece para futuro pero se guarda en el historial
    "ignorarEsteCiclo" BOOLEAN NOT NULL DEFAULT false, -- El gasto no se toma en cuenta para el cálculo del ciclo actual
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "userId" TEXT NOT NULL,
    CONSTRAINT "gastos_pkey" PRIMARY KEY ("id")
);

-- Tabla: transacciones
-- Se usa para registrar movimientos que no tienen frecuencia ni categoria (gastos hormiga)
CREATE TABLE "transacciones" ( 
    "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
    "nombre" TEXT NOT NULL,
    "monto" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "userId" TEXT NOT NULL,
    CONSTRAINT "transacciones_pkey" PRIMARY KEY ("id")
);

-- Tabla: ingresos_extra
CREATE TABLE "ingresos_extra" (
    "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
    "monto" DOUBLE PRECISION NOT NULL,
    "origen" TEXT,
    "reservado" BOOLEAN NOT NULL DEFAULT false, -- Indica si el ingreso extra ya fue reservado para una meta o siguiente ciclo
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "userId" TEXT NOT NULL,
    CONSTRAINT "ingresos_extra_pkey" PRIMARY KEY ("id")
);

