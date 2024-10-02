# Credit for this to Peter Johnson - https://geocode.earth/blog/2021/exploring-gnaf-with-sqlite/
# cd G-NAF
#
# rm -f gnaf.db
#
# sqlite3 gnaf.db < Extras/GNAF_TableCreation_Scripts/create_tables_ansi.sql
# sqlite3 gnaf.db <<(sed 's/ OR REPLACE//g' Extras/GNAF_View_Scripts/address_view.sql)



# handle spaces in filenames
exec > gnaf-import.sql
OIFS="$IFS"
IFS=$'\n'

# csv mode (configured for .psv files)
echo '.mode csv'
echo '.separator "|"'

# fast import pragmas
echo 'PRAGMA synchronous=OFF;'
echo 'PRAGMA journal_mode=OFF;'
echo 'PRAGMA temp_store=MEMORY;'

# be verbose
echo '.echo on'

# import 'authority code'
for FILEPATH in `find "G-NAF AUGUST 2024/Authority Code" -type f -name "*.psv"`; do
  BASENAME=$(basename $FILEPATH)
  TABLE_NAME="${BASENAME/Authority_Code_/}"
  TABLE_NAME="${TABLE_NAME/_psv.psv/}"
  TABLE_NAME="${TABLE_NAME/.psv/}"
  echo ".import '${FILEPATH}' '${TABLE_NAME}'"
done

# import 'standard'
for FILEPATH in `find "G-NAF AUGUST 2024/Standard" -type f -name "*.psv"`; do
  BASENAME=$(basename $FILEPATH)
  TABLE_NAME="${BASENAME#*_}"
  TABLE_NAME="${TABLE_NAME/_psv.psv/}"
  TABLE_NAME="${TABLE_NAME/.psv/}"

  # only import to uppercase tables
  # this avoids files like 'nt_locality_pid_linkage.psv which dont exist in the schema
  if [[ $TABLE_NAME != $(echo $TABLE_NAME | tr '[:lower:]' '[:upper:']) ]]; then
    continue
  fi

  # skip the header row
  echo ".import '| tail -n +2 \"${FILEPATH}\"' '${TABLE_NAME}'"
done

IFS="$OIFS"
exec >/dev/tty


# Create database

sqlite3 gnaf.db < gnaf-import.sql


# Index database

sqlite3 gnaf.db <<SQL > gnaf-indices.sql

  SELECT printf(
    'CREATE INDEX IF NOT EXISTS %s ON %s (%s);',
    printf('%s_%s', LOWER(t.name), LOWER(c.name)),
    t.name, c.name
  )
  FROM sqlite_master t
  LEFT OUTER JOIN pragma_table_info(t.name) c
  WHERE t.type = 'table'
  AND (
    c.name LIKE '%\_pid' ESCAPE '\' OR
    c.name LIKE '%\_code' ESCAPE '\' OR
    c.name == 'code'
  );
SQL



# Overwrite original

sqlite3 gnaf.db < gnaf-indices.sql
