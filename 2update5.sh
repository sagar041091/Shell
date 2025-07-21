#!/bin/bash

# === CONFIGURATION ===
DATE="$1"  # Pass date in YYYYMMDD format (e.g., 20250721)
OUTBOUND_DIR="${DATE}_OUTBOUND"
ENTER_FILE="${OUTBOUND_DIR}/enter.csv"
COMPARISON_FILE="Comparison.csv"
UPDATED_COMPARISON="Comparison_updated.csv"

# === CHECK FILES EXIST ===
if [[ ! -f "$COMPARISON_FILE" ]]; then
  echo "ERROR: Comparison file not found: $COMPARISON_FILE"
  exit 1
fi

if [[ ! -f "$ENTER_FILE" ]]; then
  echo "ERROR: enter.csv file not found: $ENTER_FILE"
  exit 1
fi

# === EXTRACT ORDER_IDs (6th column) into a lookup set ===
cut -d, -f6 "$ENTER_FILE" | tail -n +2 | sort | uniq > /tmp/enter_ids.txt

# === PROCESS Comparison.csv and update COMMENTS ===
{
  # Print header
  head -n 1 "$COMPARISON_FILE"

  # Process each row
  tail -n +2 "$COMPARISON_FILE" | while IFS=',' read -r orderid clordid comment; do
    if grep -qx "$orderid" /tmp/enter_ids.txt; then
      echo "$orderid,$clordid,FOUND"
    else
      echo "$orderid,$clordid,NOT FOUND"
    fi
  done
} > "$UPDATED_COMPARISON"

# Replace original file
mv "$UPDATED_COMPARISON" "$COMPARISON_FILE"

# Cleanup
rm -f /tmp/enter_ids.txt

echo "✅ Comparison.csv updated with FOUND/NOT FOUND status in COMMENTS column."
