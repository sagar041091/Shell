#!/bin/bash

# === CONFIGURATION ===
CSV_FILE="UBS_YYYYMMDD.csv"
OUTPUT_FILE="UBS_Pivot_Output.csv"

# === CHECK FILE EXISTS ===
if [[ ! -f "$CSV_FILE" ]]; then
  echo "Error: File '$CSV_FILE' not found!"
  exit 1
fi

# === Generate Pivot Table Using AWK ===
awk -F',' '
BEGIN {
    OFS = ",";
}
NR==1 {
    for (i=1; i<=NF; i++) {
        if ($i == "EXECTYPE_150") exec_col = i;
        if ($i == "CLORDID_11") clord_col = i;
    }
    if (!exec_col || !clord_col) {
        print "Required columns not found in header.";
        exit 1;
    }
    next;
}
{
    key = $exec_col "|" $clord_col;
    count[key]++;
}
END {
    print "EXECTYPE_150,CLORDID_11,COUNT" > "'"$OUTPUT_FILE"'";
    for (k in count) {
        split(k, parts, "|");
        print parts[1], parts[2], count[k] >> "'"$OUTPUT_FILE"'";
    }
}
' "$CSV_FILE"

echo "✅ Pivot file generated: $OUTPUT_FILE"
