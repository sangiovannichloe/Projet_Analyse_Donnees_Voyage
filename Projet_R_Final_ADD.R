library(tidyverse)
library(jsonlite)

# Saisie contrôlée : forcer l’utilisateur à choisir parmi une liste
ask_choice <- function(prompt, choices) {
  repeat {
    cat(prompt, "\n")
    cat("Choix possibles :", paste(choices, collapse = " / "), "\n")
    ans <- readline("Votre choix : ")
    ans <- stringr::str_trim(ans)
    if (ans %in% choices) return(ans)
    cat("Entrée invalide. Recommence.\n\n")
  }
}

# Saisie contrôlée : demander un entier dans un intervalle (ex : 0 à 5)
ask_int_range <- function(prompt, min_val = 0, max_val = 5) {
  repeat {
    cat(prompt, "\n")
    cat("Réponse attendue :", min_val, "à", max_val, "\n")
    ans <- suppressWarnings(as.integer(readline("Votre réponse : ")))
    if (!is.na(ans) && ans >= min_val && ans <= max_val) return(ans)
    cat("Entrée invalide. Recommence.\n\n")
  }
}

# Saisie contrôlée : demander un nombre (budget, température, etc.)
ask_numeric <- function(prompt) {
  repeat {
    cat(prompt, "\n")
    ans <- suppressWarnings(as.numeric(readline("Votre réponse : ")))
    if (!is.na(ans)) return(ans)
    cat("Entrée invalide. Recommence.\n\n")
  }
}

# Saisie contrôlée : mois (1–12) ou 0 pour ignorer la météo
ask_optional_month <- function(prompt = "Mois souhaité (1-12) ou 0 pour ignorer") {
  repeat {
    cat(prompt, "\n")
    ans <- suppressWarnings(as.integer(readline("Votre réponse : ")))
    if (!is.na(ans) && ans >= 0 && ans <= 12) return(ans)
    cat("Entrée invalide. Recommence.\n\n")
  }
}

# Transformer les préférences en poids (somme = 1)
normalize_weights <- function(pref_named_vector) {
  if (sum(pref_named_vector) == 0) stop("Préférences invalides : tout est à 0.")
  pref_named_vector / sum(pref_named_vector)
}

# Convertir une catégorie de durée en nombre de jours
duration_to_days <- function(my_duration) {
  switch(
    my_duration,
    "Day trip"   = 1,
    "Weekend"    = 2,
    "Short trip" = 4,
    "One week"   = 7,
    "Long trip"  = 14,
    7
  )
}

# Estimer un coût journalier selon le niveau de budget (hypothèses simples)
estimate_daily_cost <- function(budget_level) {
  dplyr::case_when(
    budget_level == "Budget"    ~ 60,
    budget_level == "Mid-range" ~ 120,
    budget_level == "Luxury"    ~ 250,
    TRUE ~ 120
  )
}

# Calculer une distance entre deux points (lat/lon) en km (formule de Haversine)
haversine_km <- function(lat1, lon1, lat2, lon2) {
  to_rad <- function(x) x * pi / 180
  R <- 6371
  dlat <- to_rad(lat2 - lat1)
  dlon <- to_rad(lon2 - lon1)
  a <- sin(dlat/2)^2 + cos(to_rad(lat1)) * cos(to_rad(lat2)) * sin(dlon/2)^2
  2 * R * asin(pmin(1, sqrt(a)))
}

# Estimer un coût de transport en fonction de la distance et du mode
estimate_transport_cost <- function(distance_km, mode = "mixed") {
  rate <- switch(
    mode,
    "bus"   = 0.08,
    "train" = 0.15,
    "car"   = 0.20,
    "plane" = 0.25,
    "mixed" = 0.18,
    0.18
  )
  fixed <- switch(
    mode,
    "bus" = 10, "train" = 15, "car" = 0, "plane" = 30, "mixed" = 20, 20
  )
  fixed + rate * distance_km
}

# Calculer un coût total estimé : transport + (coût journalier × nb de jours)
estimate_total_trip_cost <- function(distance_km, budget_level, my_duration, mode = "mixed") {
  days <- duration_to_days(my_duration)
  daily <- estimate_daily_cost(budget_level)
  transport <- estimate_transport_cost(distance_km, mode = mode)
  transport + daily * days
}

# Extraire la température moyenne d’un mois depuis une chaîne JSON (avg_temp_monthly)
extract_month_avg_temp <- function(json_str, month) {
  x <- jsonlite::fromJSON(json_str)
  m <- as.character(month)
  if (!m %in% names(x)) return(NA_real_)
  as.numeric(x[[m]][["avg"]])
}

# Charger les données + convertir ideal_durations (JSON) en liste utilisable
load_cities_data <- function(path) {
  readr::read_csv(path, show_col_types = FALSE) %>%
    mutate(durations = purrr::map(ideal_durations, ~ jsonlite::fromJSON(.x)))
}

# Filtrer les villes selon le budget choisi et la durée souhaitée
filter_by_budget_duration <- function(Cities, my_budget, my_duration) {
  allowed_budgets <- switch(
    my_budget,
    "Budget"    = c("Budget"),
    "Mid-range" = c("Budget", "Mid-range"),
    "Luxury"    = c("Budget", "Mid-range", "Luxury"),
    c("Budget", "Mid-range", "Luxury")
  )
  
  Pool <- Cities %>%
    filter(budget_level %in% allowed_budgets) %>%
    filter(purrr::map_lgl(durations, ~ my_duration %in% .x))
  
  if (nrow(Pool) == 0) stop("Aucune ville ne correspond aux critères (budget + durée).")
  Pool
}

# Calculer le score_user : somme pondérée des critères selon les préférences
score_user_only <- function(Pool, pref) {
  w <- normalize_weights(pref)
  
  Pool %>%
    mutate(
      score_user =
        w["culture"]   * culture +
        w["adventure"] * adventure +
        w["nature"]    * nature +
        w["beaches"]   * beaches +
        w["nightlife"] * nightlife +
        w["cuisine"]   * cuisine +
        w["wellness"]  * wellness +
        w["urban"]     * urban +
        w["seclusion"] * seclusion
    ) %>%
    arrange(desc(score_user)) %>%
    distinct(city, country, .keep_all = TRUE)
}

# Donner une explication simple : critères dominants + points forts par ville
explain_top <- function(top_df, pref, k = 3) {
  top_prefs <- sort(pref, decreasing = TRUE)
  top_criteria <- names(top_prefs)[1:k]
  
  cat("\nCritères les plus importants :", paste(top_criteria, collapse = ", "), "\n")
  
  for (i in 1:nrow(top_df)) {
    v <- top_df[i, ]
    
    city_scores <- c(
      culture=v$culture, adventure=v$adventure, nature=v$nature, beaches=v$beaches,
      nightlife=v$nightlife, cuisine=v$cuisine, wellness=v$wellness, urban=v$urban, seclusion=v$seclusion
    )
    
    best2 <- names(sort(city_scores[top_criteria], decreasing = TRUE))[1:min(2, length(top_criteria))]
    
    cat("- ", v$city, " (", v$country, ") : points forts = ",
        paste(best2, collapse = " + "),
        " | score_user=", round(v$score_user, 2), "\n", sep = "")
  }
}

# Fonction principale : lance tout le pipeline en posant les questions et en affichant le TOP 5
run_travel_recommender <- function(data_path,
                                   top_pool_n = 30,
                                   top_final_n = 5,
                                   explain = TRUE) {
  
  cat("Étape 1 — Chargement de la base\n")
  Cities <- load_cities_data(data_path)
  
  cat("Étape 2 — Préférences (0 à 5)\n")
  pref <- c(
    culture   = ask_int_range("Culture (musées, histoire, monuments) ?"),
    adventure = ask_int_range("Aventure (activités, outdoor) ?"),
    nature    = ask_int_range("Nature (paysages, randos) ?"),
    beaches   = ask_int_range("Plage ?"),
    nightlife = ask_int_range("Vie nocturne ?"),
    cuisine   = ask_int_range("Cuisine / gastronomie ?"),
    wellness  = ask_int_range("Bien-être / détente ?"),
    urban     = ask_int_range("Ambiance urbaine / grandes villes ?"),
    seclusion = ask_int_range("Calme / isolement (loin de la foule) ?")
  )
  
  cat("Étape 3 — Contraintes (budget/durée)\n")
  my_budget <- ask_choice("Budget", c("Budget", "Mid-range", "Luxury"))
  my_duration <- ask_choice("Durée", c("Day trip", "Weekend", "Short trip", "One week", "Long trip"))
  
  cat("Étape 3bis — Contraintes transport + budget total\n")
  origin_city <- readline("Ville de départ (doit exister dans la base) : ")
  max_total_budget <- ask_numeric("Budget total maximum (€) ?")
  mode <- ask_choice("Mode transport", c("bus","train","car","plane","mixed"))
  
  cat("Étape 3ter — Contraintes météo (optionnel)\n")
  my_month <- ask_optional_month("Mois souhaité (1-12) ou 0 pour ignorer : ")
  tmin <- NA_real_
  tmax <- NA_real_
  if (my_month != 0) {
    tmin <- ask_numeric("Température minimale souhaitée (°C) ?")
    tmax <- ask_numeric("Température maximale souhaitée (°C) ?")
    if (tmin > tmax) stop("Température min > max (incohérent).")
  }
  
  cat("Étape 4 — Filtrage budget/durée\n")
  Pool <- filter_by_budget_duration(Cities, my_budget, my_duration)
  
  cat("Étape 4bis — Coût total estimé (distance + séjour) et filtre budget total\n")
  origin_row <- Cities %>%
    filter(str_to_lower(city) == str_to_lower(origin_city)) %>%
    slice(1)
  
  if (nrow(origin_row) == 0) stop("Ville de départ non trouvée dans la base (orthographe différente).")
  
  lat_col <- dplyr::case_when(
    "latitude" %in% names(Cities) ~ "latitude",
    "lat" %in% names(Cities)      ~ "lat",
    TRUE ~ NA_character_
  )
  
  lon_col <- dplyr::case_when(
    "longitude" %in% names(Cities) ~ "longitude",
    "lng" %in% names(Cities)       ~ "lng",
    "lon" %in% names(Cities)       ~ "lon",
    TRUE ~ NA_character_
  )
  
  if (is.na(lat_col) || is.na(lon_col)) {
    stop("Colonnes de coordonnées introuvables. Vérifie les noms (latitude/longitude ou lat/lon ou lat/lng).")
  }
  
  origin_lat <- origin_row[[lat_col]][1]
  origin_lon <- origin_row[[lon_col]][1]
  
  if (is.na(origin_lat) || is.na(origin_lon)) stop("Coordonnées manquantes pour la ville de départ.")
  
  Pool <- Pool %>%
    mutate(
      distance_km = haversine_km(origin_lat, origin_lon, .data[[lat_col]], .data[[lon_col]]),
      total_trip_cost = estimate_total_trip_cost(distance_km, budget_level, my_duration, mode = mode)
    ) %>%
    filter(total_trip_cost <= max_total_budget)
  
  if (nrow(Pool) == 0) stop("Aucune ville ne rentre dans le budget total (transport + séjour).")
  
  cat("Étape 4ter — Filtre météo (si activé)\n")
  if (my_month != 0) {
    Pool <- Pool %>%
      mutate(
        temp_avg = purrr::map_dbl(avg_temp_monthly, ~ extract_month_avg_temp(.x, my_month))
      ) %>%
      filter(!is.na(temp_avg)) %>%
      filter(temp_avg >= tmin, temp_avg <= tmax)
    
    if (nrow(Pool) == 0) stop("Aucune ville ne correspond aux critères météo.")
  } else {
    Pool <- Pool %>% mutate(temp_avg = NA_real_)
  }
  
  cat("Étape 5 — Scoring et classement\n")
  Pool_scored <- score_user_only(Pool, pref)
  
  Shortlist <- Pool_scored %>% slice(1:min(top_pool_n, n()))
  Top5 <- Shortlist %>% slice(1:min(top_final_n, n()))
  
  Top5_results <- Top5 %>%
    transmute(
      city, country, region, budget_level,
      duration = map_chr(durations, ~ paste(.x, collapse = ", ")),
      score_user = round(score_user, 2),
      distance_km = round(distance_km, 0),
      total_trip_cost = round(total_trip_cost, 0),
      temp_avg = ifelse(is.na(temp_avg), NA, round(temp_avg, 1))
    )
  
  print(Top5_results)
  
  if (explain) {
    cat("\nÉtape 6 — Explications\n")
    explain_top(Top5, pref, k = 3)
  }
  
  invisible(Top5_results)
}

run_travel_recommender(
  data_path = "/Users/leosangiovanni/Downloads/Analyse de données/Analyse de donnees/data/worldwide_travel_cities.csv"
)