-- Actualiza el campo updatedAt antes de guardar cambios
CREATE TRIGGER actualizar_users_updatedAt
    BEFORE UPDATE ON "users" -- Antes de actualizar algo en la tabla users
    FOR EACH ROW EXECUTE FUNCTION actualizar_columna_updatedAt();

CREATE TRIGGER actualizar_user_configs_updatedAt
    BEFORE UPDATE ON "user_configs" -- Antes de actualizar algo en la tabla user_configs
    FOR EACH ROW EXECUTE FUNCTION actualizar_columna_updatedAt();

CREATE TRIGGER actualizar_gastos_updatedAt
    BEFORE UPDATE ON "gastos" -- Antes de actualizar algo en la tabla gastos
    FOR EACH ROW EXECUTE FUNCTION actualizar_columna_updatedAt();

CREATE TRIGGER actualizar_metas_updatedAt
    BEFORE UPDATE ON "metas" -- Antes de actualizar algo en la tabla metas
    FOR EACH ROW EXECUTE FUNCTION actualizar_columna_updatedAt();

-- Impide que se registren gastos con un monto menor o igual a 0
CREATE TRIGGER tr_validar_monto_gasto
    BEFORE INSERT ON "gastos" -- Antes de insertar algo en la tabla gastos
    FOR EACH ROW EXECUTE FUNCTION fn_validar_monto_gasto();