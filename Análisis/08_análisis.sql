/* Por cada usuario con una linea de ahorro registrada, calcula que 
porcentaje de sus ciclos cerrrados supero el 23%*/
SELECT
    u.name AS usuario,
    uc.frecuencia::TEXT AS tipo_ingreso,
    uc."ahorroHistorico" AS ahorro_base,
    COUNT(hc.id) AS total_ciclos,
    SUM(CASE WHEN hc."cumplioMeta" THEN 1 ELSE 0 END) AS ciclos_exitosos,

    ROUND(
        100.0 * SUM(CASE WHEN hc."cumplioMeta" THEN 1 ELSE 0 END)
        / NULLIF(COUNT(hc.id), 0), 2
    ) AS tasa_exito_porcentaje,

    -- Si el usuario cumplio con la meta el 50% de las veces, 
    -- se considera que la hipotesis es valida para el usuario
    CASE
        WHEN COUNT(hc.id) = 0 THEN 'Sin ciclos'
        WHEN ROUND(100.0 * SUM(CASE WHEN hc."cumplioMeta" THEN 1 ELSE 0 END)
             / NULLIF(COUNT(hc.id), 0), 2) >= 50
             THEN 'HIPOTESIS VALIDADA'
        ELSE 'En progreso'
    END AS estado

-- Left Join para incluir usuarios sin ciclos, Where para filtrar 
-- usuarios que no tienen una linea de ahorro registrada
-- Null Last para mandar al final a los usuarios con ciclos nulos. 
FROM users u
JOIN user_configs uc ON uc."userId" = u.id
LEFT JOIN historial_ciclos hc ON hc."userId" = u.id
WHERE uc."ahorroHistorico" > 0
GROUP BY u.id, u.name, uc.frecuencia, uc."ahorroHistorico" 
ORDER BY tasa_exito_porcentaje DESC NULLS LAST;

/*
usuario  | tipo_ingreso | ahorro_base | total_ciclos | ciclos_exitosos | tasa_exito | estado
Ángel    | Quincenal    | $500        | 6            | 4               | 66.67%     | HIPOTESIS VALIDA
Luis A.  | Mensual      | $800        | 3            | 1               | 33.33%     | En progreso
Luis Ali | Semanal      | $300        | 0            | 0               | NULL       | Sin ciclos
*/

-- ------------------------------------------------------------------------------

/* Mide que tan disciplinado es un usuario para marcar sus gastos como 
pagados y los categoriza por "disciplinado", "en progreso" y "requiere atencion"*/
WITH metricas AS ( -- Tabla temporal que almacena los datos de los usuarios
    SELECT
        u.id,
        u.name,
        uc.salario,
        (SELECT COUNT(*) FROM gastos g
         WHERE g."userId" = u.id
           AND g.pagado = TRUE
           AND g."canceladoParaElFuturo" = FALSE) AS cumplidos,
        (SELECT COUNT(*) FROM gastos g
         WHERE g."userId" = u.id
           AND g."canceladoParaElFuturo" = FALSE) AS total
    FROM users u
    JOIN user_configs uc ON uc."userId" = u.id
)

-- De la tabla temporal, se calcula el porcentaje de cumplimiento y se categoriza al usuario
SELECT
    name,
    salario,
    ROUND((cumplidos::NUMERIC / NULLIF(total, 0) * 100), 1) AS tasa_cumplimiento,
    CASE
        WHEN total = 0 THEN 'Sin gastos'
        WHEN cumplidos::NUMERIC / NULLIF(total, 0) >= 0.9 THEN 'Disciplinado'
        WHEN cumplidos::NUMERIC / NULLIF(total, 0) >= 0.5 THEN 'En progreso'
        ELSE 'Requiere atencion'
    END AS segmento
FROM metricas
ORDER BY tasa_cumplimiento DESC NULLS LAST; -- Ordena de mayor a menor cumplimiento

/*
name       | salario | tasa_cumplimiento | segmento
Ángel      | $500    | 100.0               | Disciplinado
Luis A.    | $800    | 50.0                | En progreso
Luis Ali   | $300    | NULL                | Sin gastos
*/

-- ------------------------------------------------------------------------------
/* Agrupa los gastos por categoria (recurrente o vital) y por frecuencia, calcula
cuantos hay, cuanto suman, cuanto es el promedio, minimo, maximo y que porcentaje
se ha pagado*/
SELECT
    g.categoria::TEXT AS categoria, -- Text convierte el Enum a texto legible
    g.frecuencia::TEXT AS frecuencia,
    COUNT(g.id) AS num_gastos,
    SUM(g.monto) AS total_comprometido,
    ROUND(AVG(g.monto)::NUMERIC, 2) AS promedio, -- Promedia los gastos y redondea a dos decimales
    MIN(g.monto) AS minimo,
    MAX(g.monto) AS maximo,

    -- Suma los gastos pagados entre todos los gastos y lo convierte a porcentaje
    ROUND(
        SUM(CASE WHEN g.pagado THEN 1 ELSE 0 END)::NUMERIC
        / COUNT(g.id) * 100, 1
    ) AS porcentaje_pagados

-- Filtra los gastos que no estan cancelados para el futuro
FROM gastos g
WHERE g."canceladoParaElFuturo" = FALSE
GROUP BY g.categoria, g.frecuencia
HAVING COUNT(g.id) > 0
ORDER BY total_comprometido DESC;
----------------------------------------------------------------------------------------

/* Muestra ciclo por ciclo si cumplio la meta de ese ciclo y que porcentaje representa el 
sobrante del ciclo respecto a la base inicial del usuario*/
SELECT
    u.name AS usuario,
    uc.frecuencia::TEXT AS tipo_ingreso,
    uc."ahorroHistorico" AS base,
    hc."fechaFin" AS cierre_ciclo,
    hc."sobranteReal" AS sobrante_ese_ciclo,
    hc."metaAhorroEsperada" AS meta_con_23pct,
    hc."cumplioMeta" AS cumplio,

    -- Calcula el porcentaje del ahorro real comparado con el ahorro base
    -- (750 / 500) * 100 = 150% = el usuario ahorro el 50% más de lo que ahorraba antes
    ROUND(
        (hc."sobranteReal" / NULLIF(uc."ahorroHistorico", 0) * 100)::NUMERIC, 2
    ) AS pct_vs_base

FROM users u
JOIN user_configs uc ON uc."userId" = u.id
JOIN historial_ciclos hc ON hc."userId" = u.id
WHERE uc."ahorroHistorico" > 0 -- Ignorar quienes no tienen un ahorro base registrado
ORDER BY u.name, hc."fechaFin" ASC;

-- ------------------------------------------------------------------------------
/* Extrae los promedios generales de los usuarios contra la base inicial.
Mostrando asi si la hipotesis se cumple a niveles grupales*/
WITH por_usuario AS (
    SELECT
        u.id,
        uc."ahorroHistorico" AS base,
        COUNT(hc.id) AS total_ciclos,
        SUM(CASE WHEN hc."cumplioMeta" THEN 1 ELSE 0 END) AS exitosos,
        COALESCE(AVG(hc."sobranteReal"), 0) AS promedio_sobrante
    FROM users u
    JOIN user_configs uc ON uc."userId" = u.id
    LEFT JOIN historial_ciclos hc ON hc."userId" = u.id
    WHERE uc."ahorroHistorico" > 0
    GROUP BY u.id, uc."ahorroHistorico"
)
SELECT
    COUNT(*) AS total_usuarios,
    SUM(total_ciclos) AS total_ciclos_sistema,
    ROUND(AVG(base)::NUMERIC, 2) AS ahorro_promedio_antes,
    ROUND(AVG(promedio_sobrante)::NUMERIC, 2) AS sobrante_promedio_por_ciclo,
    COUNT(CASE
        WHEN total_ciclos > 0
         AND exitosos::FLOAT / total_ciclos >= 0.5 THEN 1
    END) AS usuarios_validaron,
    ROUND(
        COUNT(CASE
            WHEN total_ciclos > 0
             AND exitosos::FLOAT / total_ciclos >= 0.5 THEN 1
        END)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 1
    ) AS porcentaje_validacion,
    CASE
        WHEN COUNT(CASE
                 WHEN total_ciclos > 0
                  AND exitosos::FLOAT / total_ciclos >= 0.5 THEN 1
             END)::FLOAT / NULLIF(COUNT(*), 0) >= 0.5
             THEN 'HIPOTESIS VALIDADA A NIVEL GRUPAL'
        ELSE 'No validada aun'
    END AS hipotesis_final
FROM por_usuario;