/*Por cada usuario nos muestra cuantas metas tiene, cuanto ha ahorrado, que porcentaje
de sus objetivos ha alcanzado y cuanto gasta en promedio.*/
CREATE OR REPLACE VIEW vista_rendimiento_metas AS
SELECT
    u.id AS usuario_id,
    u.name AS nombre_usuario,
    COUNT(m.id) AS metas, -- Cuenta el total de sus metas
    SUM(m.objetivo) AS suma_objetivos, -- Suma la cantidad de dinero entre todas sus metas
    SUM(m.acumulado) AS suma_acumulada, -- Cual es el dinero de sus metas hasta el momento
    ROUND((SUM(m.acumulado) / NULLIF(SUM(m.objetivo), 0) * 100)::NUMERIC, 2) AS porcentaje_cumplimiento,

-- Por cada usuario del SELECT principal se calcula su gasto promedio
-- considerando solo los gastos que no estan cancelados para el futuro
(SELECT COALESCE(AVG(g.monto), 0)
    FROM gastos g
    WHERE g."userId" = u.id
    AND g."canceladoParaElFuturo" = FALSE) 
AS gasto_promedio

FROM users u
JOIN metas m ON u.id = m."userId" -- Usuarios que tengan al menos una meta
GROUP BY u.id, u.name -- Agrupamo   s por usuario
HAVING SUM(m.acumulado) > 0 -- Filtramos solo los que tengan al menos un acumulado
ORDER BY suma_acumulada DESC; 

---------------------------------------------------------------------------------------------
/* Nos muestra por usuario, cuantos ciclos ha cerrado, cuantos fueron exitosos
cuanto ha ahorrado en toal y cuantos gastos activos tiene. 
En pocas palabras nos muestra si los usuarios estan cumpliendo con sus metas.*/
CREATE OR REPLACE VIEW vista_historial_admin AS
SELECT
    u.id AS usuario_id,
    u.name AS nombre_usuario,
    COUNT(hc.id) AS total_ciclos,-- Contamos el total de ciclos cerrados por cada usuario
    SUM(CASE WHEN hc."cumplioMeta" THEN 1 ELSE 0 END) AS ciclos_exitosos, -- Contamos los ciclos exitosos
    
    -- Calculamos los ciclos exitosos entre el total de ciclos y lo multiplicamos por 100
    -- para obtener el porcentaje de exito
    ROUND(
        100.0 * SUM(CASE WHEN hc."cumplioMeta" THEN 1 ELSE 0 END)
        / NULLIF(COUNT(hc.id), 0), 2
    ) AS tasa_exito_pct,

    --Sumamos el ahorro total de todos los ciclos del usuario
    SUM(hc."sobranteReal") AS ahorro_total_acumulado,

-- Contamos los gastos activos del usuario (Los que no tiene cancelados para el futuro)
(SELECT COUNT(*) FROM gastos g
    WHERE g."userId" = u.id
    AND g."canceladoParaElFuturo" = FALSE) 
AS gastos_activos

FROM users u
JOIN historial_ciclos hc ON u.id = hc."userId" -- Todos aquellos que tengan al menos un ciclo cerrado
GROUP BY u.id, u.name 
HAVING COUNT(hc.id) > 0 -- Filtramos solo los que tengan al menos un ciclo cerrado
ORDER BY tasa_exito_pct DESC;

-------------------------------------------------------------------------------------------
/*Por cada usuario compara su ahorro base declarado contra lo que realmente
ha sobrado en sus ciclos, calcula si supero los 23% y nos marca como hipotesis validada
o en revisión en caso de no. */
CREATE OR REPLACE VIEW vista_validacion_hipotesis AS
SELECT
    u.id AS usuario_id,
    u.name AS nombre,
    uc.frecuencia::TEXT AS tipo_ingreso,
    
    -- Mostramos el ahorro base del usuario y comparamos con el objetivo del 23%
    uc."ahorroHistorico" AS ahorro_base_declarado,
    ROUND(uc."ahorroHistorico" * 1.23, 2) AS objetivo_23_pct,

    -- Calcula el promedio de lo que ha sobrado por ciclo
    ROUND(COALESCE(AVG(hc."sobranteReal"), 0)::NUMERIC, 2) AS promedio_sobrante_por_ciclo,

    COUNT(hc.id) AS total_ciclos,

    SUM(CASE WHEN hc."cumplioMeta" THEN 1 ELSE 0 END) AS ciclos_con_meta_cumplida,

    -- Metas cumplidas / total de ciclos * 100 para el porcentaje de exito
    ROUND(
        100.0 * SUM(CASE WHEN hc."cumplioMeta" THEN 1 ELSE 0 END)
        / NULLIF(COUNT(hc.id), 0), 1
    ) AS tasa_exito_porcentaje,

    -- sobrante real - el ahorro base / ahorro base * 100 
    -- Nos muestra cuanto ahorro de más o de menos a comparación de antes de usar la app
    ROUND(
        (COALESCE(AVG(hc."sobranteReal"), 0) - uc."ahorroHistorico")
        / NULLIF(uc."ahorroHistorico", 0) * 100
    )::NUMERIC AS diferencia_pct_sobre_base,

    CASE
        WHEN COUNT(hc.id) = 0 THEN 'Sin ciclos registrados' -- Si no tiene ciclos, no se puede validar la hipotesis
        WHEN uc."ahorroHistorico" = 0 THEN 'Sin linea base' -- No podemos validar ya que no sabemos cuanto ahorraba antes
        WHEN 100.0 * SUM(CASE WHEN hc."cumplioMeta" THEN 1 ELSE 0 END)
             / NULLIF(COUNT(hc.id), 0) >= 50 THEN 'Hipotesis validada' -- Si cumple con el 50% o más de sus ciclos se valida la hipotesis
        ELSE 'En revision' -- Si no cumple con el 50% de sus ciclos, se deja en revision
    END AS estatus_hipotesis

FROM users u
JOIN user_configs uc ON uc."userId" = u.id -- Unimos con user_configs para obtener el ahorro base declarado
LEFT JOIN historial_ciclos hc ON hc."userId" = u.id -- Unimos con historial_ciclos para obtener los ciclos cerrados
WHERE uc."ahorroHistorico" > 0 -- Filtramos solo los que tengan al menos un ahorro base declarado
GROUP BY u.id, u.name, uc.frecuencia, uc."ahorroHistorico" -- Agrupamos por usuario 
ORDER BY tasa_exito_porcentaje DESC NULLS LAST; 