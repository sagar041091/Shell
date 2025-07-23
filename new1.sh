#!/bin/bash

# Input files
INBOUND_FILE="20230116_INBOUND/UBS_20230116.csv"
DELET_OB_FILE="20230116_OUTBOUND/delet.csv"

# Output temp files
INBOUND_TEMP="inbound_temp"
DELET_OB_TEMP="delet_temp"

# Process UBS_20230116.csv → group by CLORDID_11 & EXECTYPE_150
awk -F',' '
BEGIN {
    OFS=","
}
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

# Process delet.csv → group by MESSAGE_TYPE & PARENT_ORDER_ID
awk -F',' '
BEGIN {
    OFS=","
}
NR==1 {
    for (i = 1; i <= NF; i++) {
        gsub(/"/, "", $i)
        header[$i] = i
    }
    next
}
{
    gsub(/"/, "", $0)
    msgtype = $header["MESSAGE_TYPE"]
    parentid = $header["PARENT_ORDER_ID"]
    key = msgtype "|" parentid
    count[key]++
}
END {
    print "MESSAGE_TYPE,PARENT_ORDER_ID,COUNT" > "'$DELET_OB_TEMP'"
    for (k in count) {
        split(k, parts, "|")
        print parts[1], parts[2], count[k] >> "'$DELET_OB_TEMP'"
    }
}
' "$DELET_OB_FILE"

# Step 1: Extract CLORDID_11s with EXECTYPE_150 == 4 from inbound_temp
awk -F',' 'NR > 1 && $2 == 4 { print $1 }' "$INBOUND_TEMP" | sort > clordid_exe4.txt

# Step 2: Extract PARENT_ORDER_IDs from delet_temp
awk -F',' 'NR > 1 { print $2 }' "$DELET_OB_TEMP" | sort > parent_ids.txt

# Step 3: Count the number of each
clordid_count=$(wc -l < clordid_exe4.txt)
parentid_count=$(wc -l < parent_ids.txt)

echo "Count of CLORDID_11 with EXECTYPE_150 == 4: $clordid_count"
echo "Count of PARENT_ORDER_IDs: $parentid_count"

# Step 4: Compare and find missing CLORDID_11s if counts don’t match
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
