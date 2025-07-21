#!/bin/bash

# === CONFIGURATION ===
DATE="$1"  # Pass date in YYYYMMDD format as argument
INBOUND_DIR="${DATE}_INBOUND"
OUTBOUND_DIR="${DATE}_OUTBOUND"
UBS_FILE="${INBOUND_DIR}/UBS_${DATE}.csv"
ENTER_FILE="${OUTBOUND_DIR}/enter.csv"
COMPARISON_FILE="Comparison.csv"

# === CHECK FILES EXIST ===
if [[ ! -f "$UBS_FILE" ]]; then
  echo "ERROR: UBS file not found: $UBS_FILE"
  exit 1
fi

if [[ ! -f "$ENTER_FILE" ]]; then
  echo "ERROR: enter.csv file not found: $ENTER_FILE"
  exit 1
fi

# === EXTRACT REQUIRED COLUMNS ===
# Extract header first, then rows
awk -F, 'NR==1 {
    for(i=1;i<=NF;i++) {
        if($i=="ORDERID_37") orderid_col=i;
        if($i=="CLORDID_11") clordid_col=i;
    }
    print "ORDERID_37,CLORDID_11,COMMENTS"
    next
}
{
    print $orderid_col "," $clordid_col
}' "$UBS_FILE" > "$COMPARISON_FILE"

# === CREATE A TEMP FILE WITH ORDER_IDs FROM ENTER FILE ===
ORDER_IDs=$(mktemp)
awk -F, 'NR>1 { print $1 }' "$ENTER_FILE" > "$ORDER_IDs"

# === ADD COMMENTS COLUMN BASED ON MATCH ===
awk -F, -v ids_file="$ORDER_IDs" -v date="$DATE" '
BEGIN {
    while ((getline line < ids_file) > 0) {
        orderids[line]=1;
    }
}
NR==1 {
    print $0; next;
}
{
    comment = ($1 in orderids) ? "Found in enter file of " date : "";
    print $1 "," $2 "," comment;
}' "$COMPARISON_FILE" > temp && mv temp "$COMPARISON_FILE"

# === CLEAN UP ===
rm "$ORDER_IDs"

echo "Comparison file created: $COMPARISON_FILE"
