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

