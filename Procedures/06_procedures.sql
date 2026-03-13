-- Mueve los fondos sobrantes del ciclo anterior hacia una meta.
-- Si falla la operación, se revierte todo.
CREATE OR REPLACE PROCEDURE sp_transferencia_a_meta(
    p_userId TEXT,
    p_metaId TEXT,
    p_monto  DOUBLE PRECISION
)
LANGUAGE plpgsql AS $$
DECLARE
    v_sobrante DOUBLE PRECISION;
BEGIN
    -- Verificar que el usuario tenga fondos suficientes para realizar el movimiento. 
    SELECT "sobranteCicloAnterior" INTO v_sobrante
    FROM "user_configs" WHERE "userId" = p_userId;

    IF v_sobrante < p_monto THEN
        RAISE EXCEPTION
            'No se puede realizar el movimiento. Disponible: %, Solicitado: %',
            v_sobrante, p_monto;
    END IF;

    -- Revisamos que la meta exista y pertenezca al usuario
    IF NOT EXISTS (
        SELECT 1 FROM metas WHERE id = p_metaId AND "userId" = p_userId
    ) THEN
        RAISE EXCEPTION 'Meta no encontrada o no le pertenece al usuario';
    END IF;

    -- Descontar del sobrante
    UPDATE user_configs
    SET "sobranteCicloAnterior" = "sobranteCicloAnterior" - p_monto
    WHERE "userId" = p_userId;
    -- Sumamos el monto descontado a la meta especifica
    UPDATE metas SET acumulado = acumulado + p_monto WHERE id = p_metaId;

    COMMIT;

EXCEPTION WHEN OTHERS THEN
    ROLLBACK;
    RAISE EXCEPTION 'Error en la transferencia: %', SQLERRM;
END;
$$;


---------------------------------------------------------------------------
-- Finaliza el ciclo
-- Compara el saldo final y guarda un registro en el historial
CREATE OR REPLACE PROCEDURE sp_cerrar_ciclo(p_userId TEXT)
LANGUAGE plpgsql AS $$
DECLARE
    v_salario DOUBLE PRECISION;
    v_saldo_actual DOUBLE PRECISION;
    v_frecuencia TEXT;
    v_ahorro_base DOUBLE PRECISION;
    v_sobrante DOUBLE PRECISION;
    v_meta_23 DOUBLE PRECISION;
    v_cumplio BOOLEAN;
    v_fecha_inicio DATE;
    v_total_apartar DOUBLE PRECISION := 0;
    v_semanas_usuario INTEGER;
    v_semanas_gasto INTEGER;
    v_ingresos_extra DOUBLE PRECISION;
    v_gasto RECORD;
BEGIN
    
    -- Si se intenta ejecutar dos veces el mismo dia, la segunda no se ejecutara (idempotencia)
    IF EXISTS (
        SELECT 1 FROM historial_ciclos
        WHERE "userId" = p_userId AND "fechaFin" = CURRENT_DATE
    ) THEN
        RAISE NOTICE 'El ciclo ya fue cerrado hoy.';
        RETURN;
    END IF;

    -- Obtener datos del usuario y guardarlos en las respectivas variables
    SELECT salario, "saldoActual", frecuencia::TEXT, "ahorroBaseEsperado"
    INTO v_salario, v_saldo_actual, v_frecuencia, v_ahorro_base
    FROM user_configs WHERE "userId" = p_userId;

    IF v_saldo_actual > 0 THEN
        v_sobrante := v_saldo_actual; -- si hay saldo positivo, se guarda
    ELSE
        v_sobrante := 0; -- si hay saldo negativo, se guarda en 0 (para no manejar negativos)
    END IF;

    -- Calculamos la meta del 23% del ahorro base y verificamos si cumplio la meta
    v_meta_23 := COALESCE(v_ahorro_base, 0) * 1.23;
    v_cumplio  := v_sobrante >= v_meta_23;

    -- Obtenemos la fecha de inicio del ciclo haciendo un conteo en reversa
    -- e ingresamos los datos en nuestro historial
    v_fecha_inicio := CASE v_frecuencia
        WHEN 'Mensual' THEN CURRENT_DATE - INTERVAL '1 month'
        WHEN 'Quincenal' THEN CURRENT_DATE - INTERVAL '15 days'
        WHEN 'Semanal' THEN CURRENT_DATE - INTERVAL '7 days'
        ELSE CURRENT_DATE - INTERVAL '1 month'
    END;
    INSERT INTO historial_ciclos (
        "userId", "fechaInicio", "fechaFin", "frecuencia",
        "metaAhorroEsperada", "sobranteReal", "cumplioMeta"
    )
    VALUES (
        p_userId, v_fecha_inicio, CURRENT_DATE, v_frecuencia,
        v_meta_23, v_sobrante, v_cumplio
    );

    -- Sumamos el sobrante al ahorro historico y reiniciamos el saldo actual
    UPDATE user_configs
    SET "sobranteCicloAnterior" = "sobranteCicloAnterior" + v_sobrante,
        "saldoActual"           = 0
    WHERE "userId" = p_userId;

    -- Si el saldo al finalizar el ciclo es negativo, se le resta al sueldo base
    -- si el saldo es positivo (o 0) se suma al nuevo sueldo
    IF v_saldo_actual < 0 THEN
        v_saldo_actual := v_salario + v_saldo_actual;
    ELSE
        v_saldo_actual := v_salario;
    END IF;

    -- Buscamos y sumamos los ingresos extras reservados
    SELECT COALESCE(SUM(monto), 0) INTO v_ingresos_extra
    FROM ingresos_extra WHERE "userId" = p_userId AND reservado = TRUE;
    v_saldo_actual := v_saldo_actual + v_ingresos_extra;

    
    -- Borramos los ingresos extras ya sumados y los gastos cancelados para no contarlo doble 
    DELETE FROM ingresos_extra WHERE "userId" = p_userId AND reservado = TRUE;
    DELETE FROM gastos WHERE "userId" = p_userId AND "canceladoParaElFuturo" = TRUE;

    -- Convertimos la frecuencia del usuario a semanas
    v_semanas_usuario := CASE v_frecuencia
        WHEN 'Mensual'   THEN 4
        WHEN 'Quincenal' THEN 2
        WHEN 'Semanal'   THEN 1
        ELSE 4
    END;

    -- Recorremos todos los gastos del usuario que no esten cancelados para el futuro
    FOR v_gasto IN
        SELECT monto, frecuencia::TEXT AS frec, pagado, "ignorarEsteCiclo"
        FROM gastos
        WHERE "userId" = p_userId AND "canceladoParaElFuturo" = FALSE
    LOOP

    -- Si el gasto ya fue pagado o se ignora este ciclo, se salta
        IF v_gasto."ignorarEsteCiclo" OR v_gasto.pagado THEN
            CONTINUE;
        END IF;

        -- Convertimos la frecuencia del gasto a semanas
        v_semanas_gasto := CASE v_gasto.frec
            WHEN 'Mensual'   THEN 4
            WHEN 'Quincenal' THEN 2
            WHEN 'Semanal'   THEN 1
            ELSE 4
        END;

        -- Calculamos el total a apartar haciendo la misma operación 
        -- que en la función de calcular dinero para gastar
        v_total_apartar := v_total_apartar +
            (v_gasto.monto * v_semanas_usuario::FLOAT
             / NULLIF(v_semanas_gasto, 0));
    END LOOP;

    -- Actualizar el saldo actual restando lo que hay que apartar 
    UPDATE user_configs
    SET "saldoActual" = v_saldo_actual - v_total_apartar
    WHERE "userId" = p_userId;

    -- Regresamos los gastos recurrentes a no pagados al igual que los cancelados
    UPDATE gastos
    SET pagado = FALSE, "ignorarEsteCiclo" = FALSE
    WHERE "userId" = p_userId AND "canceladoParaElFuturo" = FALSE;

    COMMIT;
    RAISE NOTICE 'Cierre de ciclo completado con exito.';

EXCEPTION WHEN OTHERS THEN
    ROLLBACK;
    RAISE EXCEPTION 'Error al cerrar el ciclo: %', SQLERRM;
END;
$$;


--------------------------------------------------------------------------
