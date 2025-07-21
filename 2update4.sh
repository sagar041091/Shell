#!/bin/bash

# === STEP 0: Input Date Argument ===
DATE="$1"  # Example: 20250721
if [[ -z "$DATE" ]]; then
  echo "❌ ERROR: Please provide date in YYYYMMDD format as argument."
  echo "Usage: ./compare_ubs.sh 20250721"
  exit 1
fi

# === STEP 1: Define Paths ===
INBOUND_DIR="${DATE}_INBOUND"
OUTBOUND_DIR="${DATE}_OUTBOUND"
UBS_FILE="${INBOUND_DIR}/UBS_${DATE}.csv"
ENTER_FILE="${OUTBOUND_DIR}/enter.csv"
COMPARISON_FILE="Comparison.csv"

# === STEP 2: Validate Files Exist ===
if [[ ! -f "$UBS_FILE" ]]; then
  echo "❌ UBS file not found: $UBS_FILE"
  exit 1
fi

if [[ ! -f "$ENTER_FILE" ]]; then
  echo "❌ enter.csv file not found: $ENTER_FILE"
  exit 1
fi

# === STEP 3: Create Comparison.csv with 1st and 10th columns from UBS file ===
awk -F, 'NR==1 { print "ORDERID_37,CLORDID_11,COMMENTS"; next }
         { print $1 "," $10 ","
         }' "$UBS_FILE" > "$COMPARISON_FILE"

# === STEP 4: Create lookup set of 6th column (ORDER_ID) from enter.csv ===
ORDER_IDs=$(mktemp)
awk -F, 'NR>1 { print $6 }' "$ENTER_FILE" > "$ORDER_IDs"

# === STEP 5: Update Comparison.csv with COMMENTS if ORDERID_37 found in enter.csv ===
awk -F, -v ids_file="$ORDER_IDs" -v date="$DATE" '
BEGIN {
    while ((getline line < ids_file) > 0) {
        found[line] = 1;
    }
}
NR==1 {
    print $0;
    next;
}
{
    comment = ($1 in found) ? "Found in enter file of " date : "";
    print $1 "," $2 "," comment;
}' "$COMPARISON_FILE" > temp && mv temp "$COMPARISON_FILE"

# === STEP 6: Cleanup ===
rm "$ORDER_IDs"

echo "✅ Comparison file created: $COMPARISON_FILE"
