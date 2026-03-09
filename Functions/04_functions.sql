-- Actualiza automáticamente la columna updatedAt.
-- Necesario para saber en que momento se actulizo dicho registro
-- Se aplican a las tablas "users", "user_configs", "gastos" y "metas"
CREATE OR REPLACE FUNCTION actualizar_columna_updatedAt() -- Sin esta función el back tendría que realizarlo manualmente
RETURNS TRIGGER AS $$
BEGIN
    NEW."updatedAt" = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

