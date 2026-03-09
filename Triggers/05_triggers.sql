-- Actualiza el campo updatedAt antes de guardar cambios
CREATE TRIGGER actualizar_users_updatedAt
    BEFORE UPDATE ON "users" -- Antes de actualizar algo en la tabla users
    FOR EACH ROW EXECUTE FUNCTION actualizar_columna_updatedAt();

CREATE TRIGGER actualizar_user_configs_updatedAt
    BEFORE UPDATE ON "user_configs" -- Antes de actualizar algo en la tabla user_configs
    FOR EACH ROW EXECUTE FUNCTION actualizar_columna_updatedAt();

