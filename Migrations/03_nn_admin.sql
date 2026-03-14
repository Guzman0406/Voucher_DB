CREATE TABLE "etiquetas_admin" (
    id TEXT NOT NULL DEFAULT gen_random_uuid()::text,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    "creadorId" TEXT NOT NULL,
    "createdAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "etiquetas_admin_pkey" PRIMARY KEY (id)
);

CREATE TABLE "ciclos_etiquetas" (
    "cicloId" TEXT NOT NULL,
    "etiquetaId" TEXT NOT NULL,
    "asignadoEn" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ciclo_categorias_pkey" PRIMARY KEY ("cicloId", "etiquetaId")
);

CREATE TABLE IF NOT EXISTS reporte_ahorro_admin (
    id TEXT NOT NULL DEFAULT gen_random_uuid()::text,
    "userId" TEXT NOT NULL,
    nombre TEXT NOT NULL,
    frecuencia TEXT NOT NULL,
    "ahorroHistorico" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "promedioSobrante" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "tasaExitoPct" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "totalCiclos" INTEGER NOT NULL DEFAULT 0,
    "ciclosExitosos" INTEGER NOT NULL DEFAULT 0,
    estado TEXT NOT NULL,
    "generadoEn" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT reporte_ahorro_admin_pkey PRIMARY KEY (id)
);

