###                               ###
#   Shiny App sobre Encusta CASEN   #
###                               ###

library(shiny)

library(haven)
library(tidyverse)
library(ggthemes)
library(paletteer)
library(scales)
library(survey)

# Se lee la base de datos con las ponderaciones ya aplicadas.
load("casen2022.Rdata")

yvars <- casen2022_svy$variables[,grep("^y", names(casen2022_svy$variables))] |>
  lapply(attr, "label")
variables_y <- names(yvars)
names(variables_y) <- unlist(yvars)
variables_y <- as.list(variables_y)

colorvars <- casen2022_svy$variables[,c("sexo", "edad_tramos", "sexo_jh", "tipohogar")] |>
  lapply(attr, "label")
variables_colores <- names(colorvars)
names(variables_colores) <- unlist(colorvars)
variables_colores <- as.list(variables_colores)

variables_grupos <- c("", variables_colores)

# Define UI for application that draws a histogram
ui <- fluidPage(

    # Application title
    titlePanel("Exploración de variables de Encuesta CASEN 2022"),

    # Sidebar with a slider input for number of bins 
    sidebarLayout(
        sidebarPanel(
            selectInput("variable_y", "Variable Eje Y",
                        choices = variables_y),
            radioButtons("var_grafico", "Variable para Graficar",
                         choices = c("Valor", "n"), inline = TRUE),
            selectInput("agrupar_col", "Variable Agrupación (colores)",
                        choices = variables_colores),
            selectInput("agrupar_facet", "Variable Agrupación (grupos)",
                        choices = variables_grupos),
            strong("Filtros:"), br(),
            tabsetPanel(
              tabPanel("Edad", 
                       selectInput("filtro_edad", "Edad",
                                   choices = c("", "<= 6", "<= 18", "> 18, < 65", ">= 65"))),
              tabPanel("Sexo", 
                       selectInput("filtro_sexo", "Sexo",
                                   choices = c("", levels(casen2022_svy$variables$sexo))))
            ),
            actionButton("generar_grafico", "Generar Gráfico")
        ),
        # Show a plot of the generated distribution
        mainPanel(
          tabsetPanel(
            tabPanel("Ingresos", plotOutput("grafico_deciles")),
            tabPanel("Pobreza",
                     fluidRow(
                       column(4, checkboxInput("excluir_no_pobres", "Excluir no pobres", value=TRUE)),
                       column(4, checkboxInput("porcentaje", "En porcentaje (%)", value=TRUE)),
                     ),
                     plotOutput("grafico_pobreza"))
          )
        )
    )
)

# Define server logic required to draw a histogram
server <- function(input, output) {
  observeEvent(input$generar_grafico,{
    
    casen_svy_subset <- reactive({
      casen2022_svy_subset <- casen2022_svy
      
      # Aplica el filtro de edad
      if(input$filtro_edad != "") {
        switch (input$filtro_edad,
                "<= 6" = {
                  casen2022_svy_subset <- subset(casen2022_svy_subset, edad <= 6)
                },
                "<= 18" = {
                  casen2022_svy_subset <- subset(casen2022_svy_subset, edad <= 18)
                },
                "> 18, < 65" = {
                  casen2022_svy_subset <- subset(casen2022_svy_subset, edad > 18 & edad < 65)
                },
                ">= 65" =  {
                  casen2022_svy_subset <- subset(casen2022_svy_subset, edad >= 65)
                }
        )
      }
      
      # Aplica el filtro de sexo
      if(input$filtro_sexo != "") {
        casen2022_svy_subset <- subset(casen2022_svy_subset, sexo == input$filtro_sexo)
      }
      casen2022_svy_subset
    })
    
    grafico_deciles <- reactive({
      # La variable que se emplea en el eje Y es el valor solicitado o el n
      if(input$var_grafico == "Valor") {
        variable_y <- input$variable_y
        label_y <- paste("Media de", attr(casen2022_svy$variables[[input$variable_y]], "label"),
                         "\n(En millones de pesos)")
      } else {
        variable_y <- "n"
        label_y <- paste("Cantidad de personas\n",
                         "(En miles de personas)")
      }

      # Construye la fórmula dependiendo si se ha especificado agrupación
      if(input$agrupar_facet == "") {
        formula_grupos <- paste("~dau +", input$agrupar_col)
      } else {
        formula_grupos <- paste("~dau +", input$agrupar_facet, "+", input$agrupar_col)
      }
      
      datos <- svyby(as.formula(paste("~", input$variable_y)),
            as.formula(formula_grupos), casen_svy_subset(), svymean, na.rm=TRUE) %>%
        left_join(
          subset(casen_svy_subset(), !is.na(eval(parse(text=input$variable_y)))) |>
            svytable(as.formula(formula_grupos), design=_) |>
            array2DF()
        ) %>%
        rename(n=Value)
      datos[,1:(length(datos)-3)] <- Map(
        \(x, nombre) factor(
          x,
          levels=levels(casen2022_svy$variables[[nombre]])
        ),
        x=datos[,1:(length(datos)-3)],
        nombre=names(datos[,1:(length(datos)-3)])
      )
      grafico <- datos %>%
        ggplot() +
        aes(x=dau, y=.data[[variable_y]], fill=.data[[input$agrupar_col]]) +
        geom_col(position = "dodge")
      
      if(input$agrupar_facet != "") {
        grafico <- grafico +
          facet_wrap(as.formula(paste("~", input$agrupar_facet)))
      }

      if(input$var_grafico == "Valor") {
        grafico <- grafico +
          scale_y_continuous(labels = label_number(scale=1e-6, prefix = "$ ", suffix = "M"))
      } else {
        grafico <- grafico +
          scale_y_continuous(labels = label_number(scale=1e-3, suffix = "m"))
      }

      subtitle <- paste("Según", attr(casen2022_svy$variables[[input$agrupar_col]], "label"))
      if(input$agrupar_facet != "") subtitle <- paste(subtitle, "y", attr(casen2022_svy$variables[[input$agrupar_facet]], "label"))
      grafico +
        labs(title="Media de ingreso por decil de ingreso autónomo",
             subtitle = subtitle,
             x=attr(casen2022_svy$variables$dau, "label"),
             y=label_y,
             fill=attr(casen2022_svy$variables[[input$agrupar_col]], "label"),
             caption="Autor: Andrés Necochea\n
                      Fuente: Elaboración propia en base a datos de CASEN(2022)") +
        scale_fill_paletteer_d("ggthemes_ptol::qualitative", 1, dynamic=TRUE) +
        theme_hc()
    })
    output$grafico_deciles <- renderPlot({
      isolate(grafico_deciles())
    })
    
    grafico_pobreza <- reactive({

      if(input$agrupar_facet == "") {
        formula_grupos <- paste("~pobreza +", input$agrupar_col)
      } else {
        formula_grupos <- paste("~pobreza +", input$agrupar_col, "+", input$agrupar_facet)
      }
      
      datos <- svytable(as.formula(formula_grupos), casen_svy_subset())

      #   Si está activo el checkbox de porcentajes se calcula porcentajes 
      # para los márgenes superiores a la variable pobreza.
      if(input$porcentaje) {
        datos <- proportions(datos, 2:length(dim(datos)))
      }
      
      datos <- array2DF(datos)
      datos[,-(length(datos))] <- Map(
        \(x, nombre) factor(
          x,
          levels=levels(casen2022_svy$variables[[nombre]])
        ),
        x=datos[,-(length(datos))],
        nombre=names(datos[,-(length(datos))])
      )

      if(input$excluir_no_pobres) {
        datos <- datos[datos$pobreza != "No pobreza",]
      }

      grafico_pobreza <- datos |>
        filter(Value != 0) |>
        ggplot() +
        aes(x=pobreza, y=Value, fill=.data[[input$agrupar_col]]) +
        geom_col(position = "dodge")
      
      if(input$porcentaje) {
        label_y <- "Porcentaje"
        grafico_pobreza <- grafico_pobreza +
          scale_y_continuous(label=label_percent())
      } else {
        label_y <- paste("Cantidad de personas\n",
                         "(En Millones de personas)")
        grafico_pobreza <- grafico_pobreza +
          scale_y_continuous(label=label_number(scale=1e-6, suffix = " M"))
      }
      
      if(input$agrupar_facet != "") {
        grafico_pobreza <- grafico_pobreza +
          facet_wrap(as.formula(paste("~", input$agrupar_facet)))
      }
      grafico_pobreza +
        labs(title = "Condición de pobreza",
             x = attr(casen2022_svy$variables$pobreza, "label"),
             y = label_y,
             fill=attr(casen2022_svy$variables[[input$agrupar_col]], "label"),
             caption="Autor: Andrés Necochea\n
                      Fuente: Elaboración propia en base a datos de CASEN(2022)") +
        scale_fill_paletteer_d("ggthemes_ptol::qualitative", 1, dynamic=TRUE) +
        theme_hc()
    })
    output$grafico_pobreza <- renderPlot({
      isolate(grafico_pobreza())
    })
  })
}

# Run the application 
shinyApp(ui = ui, server = server)
