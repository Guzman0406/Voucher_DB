                /* TODAS LAS FK´S USAN ON DELETE CASCADE. eliminar 
                un usuario elimina todos sus datos financieros automaticamente*/

ALTER TABLE "user_configs" ADD CONSTRAINT "user_configs_userId_fk"
FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE; 

-- diaInicio puede ser hasta el 99 usado para representar el ultimo dia del mes
ALTER TABLE "user_configs" ADD CONSTRAINT "check_dia_inicio"
    CHECK ("diaInicio" >= 1 AND "diaInicio" <=99);

ALTER TABLE "user_configs" ADD CONSTRAINT "check_salario_positivo" 
    CHECK ("salario" > 0);

