#!/bin/bash

# === CONFIGURATION ===
DATE="$1"  # Format: YYYYMMDD
INBOUND_DIR="${DATE}_INBOUND"
OUTBOUND_DIR="${DATE}_OUTBOUND"
UBS_FILE="${INBOUND_DIR}/UBS_${DATE}.csv"
ENTER_FILE="${OUTBOUND_DIR}/enter.csv"
COMPARISON_FILE="Comparison.csv"

# === CHECK FILES EXIST ===
if [[ ! -f "$UBS_FILE" ]]; then
  echo "❌ UBS file not found: $UBS_FILE"
  exit 1
fi

if [[ ! -f "$ENTER_FILE" ]]; then
  echo "❌ enter.csv file not found: $ENTER_FILE"
  exit 1
fi

# === STEP 1: Extract 1st and 10th columns into Comparison.csv ===
awk -F, 'NR==1 { print "ORDERID_37,CLORDID_11,COMMENTS"; next }
         { print $1 "," $10 }' "$UBS_FILE" > "$COMPARISON_FILE"

# === STEP 2: Extract 5th column (ORDER_ID) from enter.csv ===
ORDER_IDs=$(mktemp)
awk -F, 'NR > 1 { print $5 }' "$ENTER_FILE" > "$ORDER_IDs"

# === STEP 3: Compare ORDERID_37 with ORDER_ID (5th col from enter.csv) ===
awk -F, -v ids_file="$ORDER_IDs" -v date="$DATE" '
BEGIN {
    while ((getline line < ids_file) > 0) {
        order_ids[line] = 1;
    }
}
NR == 1 {
    print $0; next;
}
{
    comment = ($1 in order_ids) ? "Found in enter file of " date : "";
    print $1 "," $2 "," comment;
}' "$COMPARISON_FILE" > temp && mv temp "$COMPARISON_FILE"

# === CLEAN UP ===
rm "$ORDER_IDs"

echo "✅ Comparison file created: $COMPARISON_FILE"
