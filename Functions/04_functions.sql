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

--------------------------------------------------------------------------------

-- Valida que el monto sea mayor a 0 y la existencia de configuraciones antes de insertar un gasto.
CREATE OR REPLACE FUNCTION fn_validar_monto_gasto()
RETURNS TRIGGER AS $$
BEGIN
    -- Validamos que el monto ingresado sea mayor a 0.
    IF NEW.monto <= 0 THEN
        RAISE EXCEPTION
            'El monto del gasto debe ser mayor a 0. Recibido: %', NEW.monto;
    END IF;

    -- Validamos que el usuario tenga una configuración financiera activa.
    -- Select 1 para nada más saber si existe un registro, no queremos traer todos los registros 
    IF NOT EXISTS ( 
        SELECT 1 FROM user_configs WHERE "userId" = NEW."userId"
    ) THEN
        RAISE EXCEPTION
            'El usuario no cuenta con una configuracion financiera activa.';
    END IF;

    RETURN NEW; -- Guardamos el registro si nada falla
END;
$$ LANGUAGE plpgsql;