library(dplyr)
library(stringr)

# Function to parse the address
parse_address <- function(address) {
  pattern <- "^(?:(\\d+)/)?(\\d+)\\s+([A-Z\\s]+)\\s+([A-Z]+),\\s+([A-Z\\s]+)$"

  match <- str_match(address, pattern)

  # Extract the matched groups
  unit_number <- ifelse(is.na(match[, 2]), NA, match[, 2])
  street_number <- match[, 3]
  street_name <- str_trim(match[, 4])
  street_type <- match[, 5]
  suburb <- str_trim(match[, 6])

  data.frame(
    "unit_number" = unit_number,
    "street_number" = street_number,
    "street_name" = street_name,
    "street_type" = street_type,
    "suburb" = suburb,
    stringsAsFactors = FALSE
  )
}

parsed_addresses <- function(addresses) {
  out <- bind_rows(furrr::future_map(addresses, parse_address, .progress = T))
  out$street_name <- str_replace_all(out$street_name, "\\b[A-Z] ", "")
  out
}

parsed_addressesp <- function(addresses) {
  out <- bind_rows(purrr::map(addresses, parse_address, .progress = T))
  out$street_name <- str_replace_all(out$street_name, "\\b[A-Z] ", "")
  out
}

