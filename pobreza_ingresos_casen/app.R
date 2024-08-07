###                               ###
#   Shiny App sobre Encusta CASEN   #
###                               ###

library(shiny)

library(haven)
library(tidyverse)
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
           plotOutput("distPlot")
        )
    )
)

# Define server logic required to draw a histogram
server <- function(input, output) {
  observeEvent(input$generar_grafico,{
    grafico_deciles <- reactive({
      # La variable que se emplea en el eje Y es el valor solicitado o el n
      casen2022_svy_subset <- casen2022_svy
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
      
      datos <- svyby(as.formula(paste("~", input$variable_y)),
            as.formula(formula_grupos), casen2022_svy_subset, svymean, na.rm=TRUE) %>%
        left_join(
          subset(casen2022_svy_subset, !is.na(eval(parse(text=input$variable_y)))) |>
            svytable(as.formula(formula_grupos), design=_) |>
            array2DF()
        ) %>%
        rename(n=Value) %>%
        mutate(dau = factor(dau, levels=levels(casen2022_svy$variables$dau)))
      datos[[input$agrupar_col]] <- factor(datos[[input$agrupar_col]],
                                           levels = levels(casen2022_svy$variables[[input$agrupar_col]]))
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
                      Fuente: Elaboración propia en base a datos de CASEN(2022)")
    })
    output$distPlot <- renderPlot({
      isolate(grafico_deciles())
    })
  })
}

# Run the application 
shinyApp(ui = ui, server = server)
