#' Code to produce a map of Australia with bar charts of population for each 
#' State and Territory. This code forms a template for future products.
#' 
library(tidyverse)
#' We will source population data using `readabs::read_abs`
library(readabs)
#' We will use the `strayr::read_absmap` to obtain shapefiles
#' We will use `strayr::state_name_au` and `strayr::state_abb_au` as factor levels
#' We will colour our bar charts using the `strayr::palette_state_name_2016` palette
library(strayr)


# Get ABS population data
population.tbl =
  read_abs("3101.0") |>
  # Filter for Persons and June population data
  # Filter for 2018 to 2013, this template can't handle more
  # than about five x values
  filter(str_detect(series, "Persons"),
         month(date)==6,
         year(date) %in% 2018:2023) |>
  # Extract state names from series
  separate_series() |> 
  rename("state_name"=series_3) |>
  select(state_name, date, value) |> 
  # Create factorised name and abbreviation variables.
  mutate(state_name = 
           factor(
             state_name,
             levels=strayr::state_name_au
             ),
         state_abb = 
           factor(
             state_name,
             levels=strayr::state_name_au,
             labels=strayr::state_abb_au
           )
         ) |> 
  filter(!is.na(state_name))

# Gather data for map
map.data = strayr::read_absmap("state2021", remove_year_suffix = TRUE) 

# Create base map
map.plot =
  ggplot() +
  geom_sf(
    data = map.data,
    aes(geometry = geometry),
    fill="lightgrey",
    colour="white"
  ) +
  coord_sf(xlim=c(115,152), ylim=c(-11,-44))+
  ggthemes::theme_map()




# Build grobs, being a column chart for each state
# For easy adjustment of size define width
grob.width = 3.2

# Make grobs
map.grobs =
  # Fet lat and long data from map data
  map.data |> 
  # Convert to tibble to enable removal of geometry
  as_tibble() |>  
  # Adjust position of ACT and TAS for cleaner map
  mutate(
    cent_long = case_when(str_detect(state_name,"Capital") ~ cent_long+5, 
                          TRUE ~ cent_long),
    cent_lat = case_when(str_detect(state_name,"Capital") ~ cent_lat-3, 
                         str_detect(state_name,"Wales") ~ cent_lat+1, 
                         str_detect(state_name,"Tas") ~ cent_lat-1, 
                         TRUE ~ cent_lat)) |> 
  select(state_name, cent_lat, cent_long)  |>
  # Join with population data
  inner_join(population.tbl) |> 
  # Nest chart data
  nest(data = c(state_name, state_abb,date, value)) |> 
  # Working rowwise make subplots
  rowwise() |> 
  mutate(subplots = list(
    ggplot(data, aes(x=date, y=value/1e6, fill=state_name)) + 
      geom_col(
        colour = "transparent",
        alpha = 0.75
      ) +
      theme_classic() + guides(colour = F, fill = FALSE) +
      scale_fill_manual(values=strayr::palette_state_name_2016)+
      scale_y_continuous(name=NULL, expand = c(0,0),
                         label=scales::label_number(accuracy=1),
                         breaks = seq(0,9,by=3),limits =c(0,9))+
      scale_x_date(name=NULL, 
                   expand = c(0,0),
                   breaks=lubridate::ymd("2018-6-1","2023-6-1"),
                   date_labels = "%Y"
                   )+
      labs(title = str_glue("{data$state_abb}"))+
      theme(plot.background = element_blank(),
            plot.margin = margin(0,0,0,0),
            panel.background = element_blank(),
            title = element_text(size=rel(.5),margin = margin(0,0,0,0)))
    )
    ) |> 
  # Create subgrobs with lat long added to subplots
  mutate(subgrobs = 
           list(
             annotation_custom(
               ggplotGrob(subplots), 
               x = cent_long-grob.width, y = cent_lat-grob.width, 
               xmax = cent_long+grob.width, ymax = cent_lat+grob.width)
             )
         ) 

# Add grobs to map
map.with.grobs =
  map.plot + 
  map.grobs$subgrobs



