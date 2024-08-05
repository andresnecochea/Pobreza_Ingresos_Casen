
# Paquetes ----------------------------------------------------------------

library(haven)
library(survey)
library(tidyverse)
library(magrittr, include.only = "%<>%")

# Leer Datos --------------------------------------------------------------

casen2022 <- read_spss("Bases de Datos/CASEN/2022/Base de datos Casen 2022 SPSS.sav")

# Procesamiento -----------------------------------------------------------

#   Filtro de la V región. Sólo para efectos de tener un subset para trabajar
# con menos. Comentar una vez que se haga el procesamiento definitivo.
# casen2022 %<>%
#   filter(region == 5)

# Variables utilizadas:
# expr: Factor de expansión regional
# estrato: Estrato (comuna-área-NSE)
# region: Región
# id_vivienda: Identificación vivienda
# hogar: Orden del hogar en la vivienda
# pco1_a: Jefatura de hogar
# sexo: Sexo
# edad: Edad
# pobreza: Categoría de pobreza
# tipohogar: Tipo de Hogar
# dau: Decil autónomo nacional
# ypc: Ingreso total per cápita del hogar corregido
# ytrabajocor: Ingreso del trabajo corregido
# ytrabajocorh: Ingreso del trabajo del hogar corregido
# ymonecor: Ingreso monetario Corregido
# ypchtrabcor: Ingreso del trabajo per cápita del hogar corregido
# ypchautcor: Ingreso autónomo per cápita del hogar corregido

casen2022 %<>%
  select(expr, estrato, region, id_vivienda, hogar, pco1_a, sexo, edad, pobreza,
         tipohogar, dau, ypc, ytrabajocor, ytrabajocorh, ymonecor, ypchtrabcor,
         ypchautcor)

# Crear las variables:
#  - sexo jefe de hogar
#  - Edad en tramos
casen2022 %<>%
  mutate(edad_tramos = cut(edad, c(0,18,64,max(edad)),
                           include.lowest = TRUE,
                           labels = c("0 - 18", "19 - 64", "65 o más"))) %>%
  group_by(id_vivienda, hogar) %>%
  mutate(sexo_jh = sexo[!is.na(pco1_a) & pco1_a == 1]) %>%
  ungroup()

# Se asigna etiquetas a las variables creadas.
attr(casen2022$edad_tramos, "label") <- "Edad en tramos"
attr(casen2022$sexo_jh, "label") <- "Sexo del jefe de hogar"

casen2022 %<>%
  as_factor() %>%
  zap_missing()

casen2022_svy <- svydesign(~1, weights = ~expr, strata = ~estrato, data=casen2022)

save(casen2022_svy, file="pobreza_ingresos_casen/casen2022.Rdata")
#load("pobreza_ingresos_casen/casen2022.Rdata")
