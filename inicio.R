
library(svDialogs)
library(ConfigParser)

# Variables globales ------------------------------------------------------

# Link por defecto a la encuesta CASEN
casen_url_default <- "https://observatorio.ministeriodesarrollosocial.gob.cl/storage/docs/casen/2022/Base%20de%20datos%20Casen%202022%20SPSS_18%20marzo%202024.sav.zip"
casen_file_default <- "Base de datos Casen 2022 SPSS.sav"


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

# Leer la configuración ---------------------------------------------------

config <- ConfigParser$new()
if(file.exists("config.ini")) {
  config$read("config.ini")
} else {
  config$set("main", dir_main, "dirs", FALSE)
}

# Configurar Directorios --------------------------------------------------

if(is.null(config$get("data", fallback = NULL, section="dirs"))) {
  dir_data <- file.path(dir_main, "Bases de Datos")
  config$set("data", dir_data, "dirs")
}

#   Se consulta al usuario si desea seleccionar un directorio diferente para las
# bases de datos.
select_dir_yn <- dlg_message("¿Desea ingresar un directorio diferente para descargar las bases de datos?",
            type="yesno")
if(select_dir_yn$res == "no") {
  # Si el directorio "Bases de datos" no existe, se crea.
  if(!dir.exists(config$data$dirs$data)) {
    dir.create(config$data$dirs$data)
  }
} else {
  #   Se pide al usuario que elija un directorio diferente para las bases de
  # datos.
  #   Si el directorio es diferente de "Bases de Datos" se crea un enlace
  # simbólico.
  dlg_dir_data <- dlg_dir(title="Seleccione un directorio para las bases de datos")
  dir_data <- dlg_dir_data$res
  config$data$dirs$data <- dir_data
}

# Descargar Casen ---------------------------------------------------------

# Se crea el directorio en el que se descargará la CASEN
# La estructura de directorio es:
## | Bases de datos/
## +- CASEN/
##  +- 2022/
##   |- Base Datos Casen 2022.sav

dir_data <- config$data$dirs$data
if(!dir.exists(file.path(dir_data, "CASEN", "2022"))) {
  dir.create(file.path(dir_data, "CASEN", "2022"), recursive = TRUE)
}

# Si no existe, se fija el nombre de archivo de la CASEN por defecto
if(is.null(config$get("casen_file", fallback = NULL, section="casen"))) {
  config$set("casen_file", casen_file_default, "casen", FALSE)
}
# Si no existe, se fija la url por defecto para descargar la CASEN
if(is.null(config$get("casen_url", fallback = NULL, section="casen"))) {
  config$set("casen_url", casen_url_default, "casen", FALSE)
}

# En las siguientes líneas se descargará la CASEN si es que no existe el archivo
# Si la descarga falla se deberá proveer un link de descarga correcto
if(!file.exists(file.path(dir_data, "CASEN", "2022", config$data$casen$casen_file))) {
  while(TRUE) {
    url_casen <- config$data$casen$casen_url
    destfile_casen <- file.path(dir_data, "CASEN", "2022", "Base Datos Casen 2022.zip")
    tryCatch(
      expr = {
        download.file(url_casen, destfile=destfile_casen, mode="wb")
        unzip(destfile_casen, exdir=file.path(dir_data, "CASEN", "2022"))
        file.remove(destfile_casen)
        casen_file <- list.files(file.path(dir_data, "CASEN", "2022"), pattern="*.sav")[1]
        config$data$casen$casen_file <- casen_file
      },
      error = function(e) {
        error_descarga <- dlg_message("Falló la descarga de la Encuesta CASEN. ¿desea ingresar la url correcta?",
                                      type="yesno")
        if(error_descarga$res == "yes") {
          casen_url_dlg <- dlg_input("Ingrese la url de la encuesta Casen")
          config$data$casen$casen_url <- casen_url_dlg$res
        } else {
          stop("Falló la descarga de la encuesta casen!")
        }
      }
    )
    if(file.exists(file.path(dir_data, "CASEN", "2022", config$data$casen$casen_file))) {
      break
    }
  }
}

# Instalar paquetes -------------------------------------------------------

#   Instalará los paquetes requeridos automáticamente si es que el usuario desea
# instalarlos
dlg_instalar_paquetes <- dlg_message("¿desea instalar los paquetes requeridos?",
                                     type="yesno")
if(dlg_instalar_paquetes$res == "yes") {
  paquetes_requeridos <- c("haven", "survey", "tidyverse", "magrittr", "scales",
                           "shiny")
  paquetes_instalados <- installed.packages() |> rownames()
  install.packages(paquetes_requeridos[!paquetes_requeridos %in% paquetes_instalados])
}

# Guardar configuración ---------------------------------------------------

config$write("config.ini")

# Ejecutar App ------------------------------------------------------------

# Consultar al usuario si desea procesar los datos nuevamente
if (file.exists("pobreza_ingresos_casen/casen2022.Rdata")) {
  dlg_procesar_datos <- dlg_message(message = "¿Desea Procesar los datos nuevamente?", type="yesno")
} else {
  dlg_procesar_datos <- list(res="yes")
}

# Procesar los datos
if(dlg_procesar_datos$res == "yes") {
  source("procesamiento.R")
}

shiny::runApp("pobreza_ingresos_casen/app.R")
