#!/bin/bash

# ✅ Accept date as argument (format: YYYYMMDD)
if [ -z "$1" ]; then
    echo "Usage: $0 <DATE: YYYYMMDD>"
    exit 1
fi

RUN_DATE="$1"

# Input files
INBOUND_FILE="${RUN_DATE}_INBOUND/UBS_${RUN_DATE}.csv"
DELET_OB_FILE="${RUN_DATE}_OUTBOUND/delet.csv"

# Output temp files
INBOUND_TEMP="inbound_temp"
DELET_OB_TEMP="delet_temp"

# Step 1: Process INBOUND file (CSV) → group by CLORDID_11 & EXECTYPE_150
awk -F',' '
BEGIN { OFS="," }
NR==1 {
    for (i = 1; i <= NF; i++) {
        gsub(/"/, "", $i)
        header[$i] = i
    }
    next
}
{
    gsub(/"/, "", $0)
    clordid = $header["CLORDID_11"]
    exectype = $header["EXECTYPE_150"]
    key = clordid "|" exectype
    count[key]++
}
END {
    print "CLORDID_11,EXECTYPE_150,COUNT" > "'$INBOUND_TEMP'"
    for (k in count) {
        split(k, parts, "|")
        print parts[1], parts[2], count[k] >> "'$INBOUND_TEMP'"
    }
}
' "$INBOUND_FILE"

# Step 2: Process delet.csv (| delimited) → group by DATE, MESSAGE_TYPE & PARENT_ORDER_ID
awk -F'|' -v run_date="$RUN_DATE" '
BEGIN { OFS="," }
NR==1 {
    for (i = 1; i <= NF; i++) {
        gsub(/"/, "", $i)
        header[$i] = i
    }
    next
}
{
    gsub(/"/, "", $0)
    date = $header["DATE"]
    if (date != run_date) next
    msgtype = $header["MESSAGE_TYPE"]
    parentid = $header["PARENT_ORDER_ID"]
    key = date "|" msgtype "|" parentid
    count[key]++
}
END {
    print "DATE,MESSAGE_TYPE,PARENT_ORDER_ID,COUNT" > "'$DELET_OB_TEMP'"
    for (k in count) {
        split(k, parts, "|")
        print parts[1], parts[2], parts[3], count[k] >> "'$DELET_OB_TEMP'"
    }
}
' "$DELET_OB_FILE"

# Step 3: Extract CLORDID_11s with EXECTYPE_150 == 4 from INBOUND
awk -F',' 'NR > 1 && $2 == 4 { print $1 }' "$INBOUND_TEMP" | sort > clordid_exe4.txt

# Step 4: Extract PARENT_ORDER_IDs from DELET (column 3)
awk -F',' 'NR > 1 { print $3 }' "$DELET_OB_TEMP" | sort > parent_ids.txt

# Step 5: Compare counts and find missing IDs
clordid_count=$(wc -l < clordid_exe4.txt)
parentid_count=$(wc -l < parent_ids.txt)

echo "Date: $RUN_DATE"
echo "Count of CLORDID_11 with EXECTYPE_150 == 4: $clordid_count"
echo "Count of PARENT_ORDER_IDs: $parentid_count"

if [ "$clordid_count" -ne "$parentid_count" ]; then
    echo "❌ Count mismatch — finding missing CLORDID_11s..."
    comm -23 clordid_exe4.txt parent_ids.txt > missing_clordids.txt

    if [ -s missing_clordids.txt ]; then
        echo "Missing CLORDID_11s (present in inbound, not in outbound):"
        cat missing_clordids.txt
    else
        echo "All CLORDID_11s with EXECTYPE_150 = 4 are matched in outbound."
    fi
else
    echo "✅ Counts match — no missing CLORDID_11s."
fi
