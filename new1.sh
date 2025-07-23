#!/bin/bash

CSV_FILE="UBS_YYYYMMDD.csv"
OUTPUT_FILE="UBS_Pivot_Output.csv"

# Check file exists
if [[ ! -f "$CSV_FILE" ]]; then
  echo "❌ File '$CSV_FILE' not found!"
  exit 1
fi

# Detect delimiter (| or ,)
DELIM=$(head -1 "$CSV_FILE" | grep -o "|" | wc -l)
if [[ "$DELIM" -gt 1 ]]; then
  FS='|'
else
  FS=','
fi

# Run AWK with quote handling
awk -F"$FS" -v OFS=',' -v out="$OUTPUT_FILE" '
function strip_quotes(s) {
    gsub(/^"/, "", s);
    gsub(/"$/, "", s);
    return s;
}

NR==1 {
    for (i=1; i<=NF; i++) {
        colname = strip_quotes($i);
        header[colname] = i;
    }
    if (!("EXECTYPE_150" in header) || !("CLORDID_11" in header)) {
        print "❌ Missing required columns in header. Found:" > "/dev/stderr";
        for (h in header) print h > "/dev/stderr";
        exit 1;
    }
    exec_col = header["EXECTYPE_150"];
    clord_col = header["CLORDID_11"];
    next;
}
{
    key = strip_quotes($exec_col) "|" strip_quotes($clord_col);
    count[key]++;
}
END {
    print "EXECTYPE_150,CLORDID_11,COUNT" > out;
    for (k in count) {
        split(k, parts, "|");
        print parts[1], parts[2], count[k] >> out;
    }
}
' "$CSV_FILE"

echo "✅ Done. Output saved to $OUTPUT_FILE"
