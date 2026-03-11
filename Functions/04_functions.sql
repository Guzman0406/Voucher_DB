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

---------------------------------------------------------------

-- Calcula el saldo real menos gastos pendientes.
-- Calcula cuánto dinero puede gastar libremente sin comprometer sus gastos recurrentes pendientes. 
CREATE OR REPLACE FUNCTION fn_calcular_dinero_disponible_para_gastar(p_userId TEXT)
RETURNS DOUBLE PRECISION AS $$
DECLARE
    v_saldo_actual DOUBLE PRECISION; 
    v_frecuencia_usuario TEXT;
    v_semanas_ciclo_usuario INTEGER; 
    v_total_gastos_ponderados DOUBLE PRECISION := 0; -- Suma del total de gastos en el ciclo del usuario
    v_semanas_frecuencia_gasto INTEGER;
    v_gasto_actual RECORD;
BEGIN
    -- Obtiene datos clave como el dinero actual y cada cuánto le pagan
    SELECT "saldoActual", frecuencia::TEXT
    INTO v_saldo_actual, v_frecuencia_usuario
    FROM "user_configs"
    WHERE "userId" = p_userId;

    -- convertir el ciclo de pago del usuario a semanas
    v_semanas_ciclo_usuario := 
    CASE v_frecuencia_usuario
        WHEN 'Mensual' THEN 4
        WHEN 'Quincenal' THEN 2
        WHEN 'Semanal' THEN 1
        ELSE 4
    END;

    -- Recorre uno por uno todos los gastos del usuario que todavia no estan 
    -- pagados, no han sido cancelados y no estan por ignorarse.
    FOR v_gasto_actual IN 
        SELECT monto, frecuencia::TEXT AS frecuencia
        FROM "gastos"
        WHERE "userId" = p_userId
          AND pagado = FALSE
          AND "canceladoParaElFuturo" = FALSE
          AND "ignorarEsteCiclo" = FALSE
    LOOP

        -- Convierte la frecuencia del gasto a semanas
        v_semanas_frecuencia_gasto := 
        CASE v_gasto_actual.frecuencia
            WHEN 'Mensual' THEN 4
            WHEN 'Quincenal' THEN 2
            WHEN 'Semanal' THEN 1
            ELSE 4
        END;

        v_total_gastos_ponderados := v_total_gastos_ponderados + (v_gasto_actual.monto * v_semanas_ciclo_usuario::FLOAT / NULLIF(v_semanas_frecuencia_gasto, 0));
    END LOOP;

    -- Saldo real menos compromisos
    RETURN COALESCE(v_saldo_actual, 0) - v_total_gastos_ponderados;
END;
$$ LANGUAGE plpgsql;
--------------------------------------------------------------------------

-- Devuelve una lista de gastos con el porcentaje que representan de su salario.
CREATE OR REPLACE FUNCTION fn_resumen_gastos_usuario(p_userId TEXT)
RETURNS TABLE (
    nombre_gasto TEXT,
    monto_original DOUBLE PRECISION,
    monto_ponderado DOUBLE PRECISION,
    categoria TEXT,
    frecuencia_gasto TEXT,
    pagado BOOLEAN,
    porcentaje_del_salario DOUBLE PRECISION
) AS $$
DECLARE
    v_salario DOUBLE PRECISION;
    v_frecuencia_usuario TEXT;
    v_semana_usuario INTEGER;
BEGIN

    -- Recuperamos el salario y frecuencia de cobro. 
    SELECT uc.salario, uc.frecuencia::TEXT
    INTO v_salario, v_frecuencia_usuario
    FROM user_configs uc
    WHERE uc."userId" = p_userId;

    -- equivalente en semanas
    v_semana_usuario := CASE v_frecuencia_usuario
        WHEN 'Mensual' THEN 4
        WHEN 'Quincenal' THEN 2
        WHEN 'Semanal' THEN 1
        ELSE 4
    END;

    RETURN QUERY
    SELECT
        g.nombre,  -- g= gastos
        g.monto,
        -- calculamos el monto ponderado de cada gasto de acuerdo a la frecuencia de pago
        g.monto * v_semana_usuario::FLOAT / NULLIF(
            CASE g.frecuencia::TEXT
                WHEN 'Mensual' THEN 4
                WHEN 'Quincenal' THEN 2
                WHEN 'Semanal' THEN 1
                ELSE 4
            END, 0),
        g.categoria::TEXT,
        g.frecuencia::TEXT,
        g.pagado,
        -- 
        ROUND((g.monto / NULLIF(v_salario, 0) * 100)::NUMERIC, 2)::DOUBLE PRECISION
        
    FROM gastos g
    WHERE g."userId" = p_userId
      AND g."canceladoParaElFuturo" = FALSE
    ORDER BY g.monto DESC;
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