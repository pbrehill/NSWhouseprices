
library(tidyverse)
library(sf)
library(ggspatial)
library(RSQLite)


houses <- read_csv("nsw_property_data.csv")

catchments <- st_read("catchments/catchments_secondary.shp")

# writeLines(paste0(houses$address[1:10000],", NSW ", houses$post_code), "addresses.txt")

source("parse_address.R")
# time <- Sys.time()
# parsed_addresses(houses$address[1:100000])
# Sys.time() - time

time <- Sys.time()
parsed_ads <- parsed_addresses(houses$address)
Sys.time() - time

parsed_houses <- bind_cols(parsed_ads, houses)

# Rename table in line with the database and add
parsed_houses <- parsed_houses |>
  rename(
    NUMBER_FIRST = street_number,
    STREET_NAME = street_name,
    POSTCODE = post_code
  ) |>
  mutate(lot_id = row_number())

setwd("G-NAF")

# Connect to the SQLite database
sqlite <- dbDriver("SQLite")
my_conn <- dbConnect(sqlite, "gnaf.db")

# Write out the dataframe into the database
dbWriteTable(my_conn, "prices", parsed_houses, row.names = FALSE, overwrite = TRUE)

# Put address data into one table

dbExecute(my_conn, "DROP TABLE IF EXISTS ADDRESS_TABLE")

dbExecute(my_conn, "CREATE TABLE IF NOT EXISTS ADDRESS_TABLE AS
  SELECT POSTCODE, STREET_NAME, NUMBER_FIRST, STREET_TYPE_CODE, LATITUDE, LONGITUDE FROM ADDRESS_VIEW
  WHERE STATE_ABBREVIATION = 'NSW';")

# Create the index if it doesn't exist
dbExecute(my_conn, "CREATE INDEX IF NOT EXISTS idx_postcode_streetname ON prices (POSTCODE, STREET_NAME, NUMBER_FIRST);")

# Reindex the table
dbExecute(my_conn, "REINDEX idx_postcode_streetname;")

dbExecute(my_conn, "CREATE INDEX IF NOT EXISTS idx_adt_postcode_streetname ON ADDRESS_TABLE(POSTCODE, STREET_NAME, NUMBER_FIRST);")

# Reindex the table
dbExecute(my_conn, "REINDEX idx_adt_postcode_streetname;")

# Run the JOIN query and fetch the result
join_query <- "
-- Run the query and output to CSV

SELECT
    p.POSTCODE, p.STREET_NAME, p.NUMBER_FIRST, p.street_type, p.lot_id, p.area, p.purchase_price, p.settlement_date,
    av.*
FROM
    prices p
LEFT JOIN
    ADDRESS_TABLE av
ON
    p.POSTCODE = av.POSTCODE
    AND p.STREET_NAME = av.STREET_NAME
    AND p.NUMBER_FIRST = av.NUMBER_FIRST;
"

njoin <- "WITH ranked_addresses AS (
    SELECT av.*,
           ROW_NUMBER() OVER (PARTITION BY av.POSTCODE, av.STREET_NAME, av.NUMBER_FIRST, av.STREET_TYPE_CODE) AS rn
    FROM ADDRESS_TABLE av
)
SELECT
    p.POSTCODE,
    p.STREET_NAME,
    p.NUMBER_FIRST,
    p.street_type,
    p.lot_id,
    p.area,
    p.purchase_price,
    p.settlement_date,
    av.*
FROM
    prices p
LEFT JOIN
    (SELECT *
     FROM ranked_addresses
     WHERE rn = 1) av
ON
    p.POSTCODE = av.POSTCODE
    AND p.STREET_NAME = av.STREET_NAME
    AND p.NUMBER_FIRST = av.NUMBER_FIRST;
"

# TODO: Add in a way to link across street types

# Fetch the result
result <- dbGetQuery(my_conn, njoin)

# Write the result to a CSV file
write.csv(result, "linked_prices.csv", row.names = FALSE)

# Close the connection
dbDisconnect(my_conn)






