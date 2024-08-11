
cat("########## Iniciando Procesamiento de Datos ##########")

# Paquetes ----------------------------------------------------------------

# Para leer el archivo de configuraciones
library(ConfigParser)

library(haven)
library(survey)
library(tidyverse)
library(magrittr, include.only = "%<>%")

# Directorio principal ----------------------------------------------------

#   Se establece como directorio la ubicación del script actual.
#   Estas líneas extraen el directorio en el que se ejecuta el script, debiese
# funcionar si se ejecuta desde la consola o desde Rstudio.
#
# Advertencia: No ha sido testeado en otras interfaces gráficas para R.
#
dir_main <- if(rstudioapi::isAvailable()) {
  dirname(rstudioapi::getSourceEditorContext()$path)
} else {
  dirname(getSrcDirectory(function(x) {x}))
}
if(dir_main=="") dir_main <- getwd()

#   Fijamos el directorio en el que se encuentra el script como directorio de
# trabajo.
setwd(dir_main)


# Leer configuración ------------------------------------------------------

config <- ConfigParser$new()
if(file.exists("config.ini")) {
  config$read("config.ini")
} else {
  config$set("data", "Bases de Datos", "dirs", FALSE)
  config$set("casen_file", "Base de datos Casen 2022 SPSS.sav", "casen", FALSE)
}

# Leer Datos --------------------------------------------------------------

casen2022 <- read_spss(file.path(config$data$dirs$data, "CASEN", "2022", config$data$casen$casen_file))

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
# ytotcor: Ingreso total corregido
# ypchtrabcor: Ingreso del trabajo per cápita del hogar corregido
# ypchautcor: Ingreso autónomo per cápita del hogar corregido

casen2022 %<>%
  select(expr, estrato, region, id_vivienda, hogar, pco1_a, sexo, edad, pobreza,
         tipohogar, dau, ypc, ytrabajocor, ytrabajocorh, ytotcor, ypchtrabcor,
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

cat("############ Datos generados correctamente ###########")
