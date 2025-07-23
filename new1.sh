#!/bin/bash

FILE="UBS_20230116.csv"
TEMP_FILE="temp_exec_count.csv"

awk -F',' '
BEGIN {
    OFS=","
}
NR==1 {
    for (i = 1; i <= NF; i++) {
        gsub(/"/, "", $i)  # Remove quotes
        header[$i] = i
    }
    clordid_col = header["CLORDID_11"]
    exectype_col = header["EXECTYPE_150"]
    next
}
{
    gsub(/"/, "", $clordid_col)
    gsub(/"/, "", $exectype_col)
    key = $clordid_col "|" $exectype_col
    count[key]++
}
END {
    print "CLORDID_11,EXECTYPE_150,COUNT" > "'"$TEMP_FILE"'"
    for (k in count) {
        split(k, parts, "|")
        print parts[1], parts[2], count[k] >> "'"$TEMP_FILE"'"
    }
}
' "$FILE"

awk -F',' 'NR > 1 && $2 == 4 { total += $3 } END { print total }' temp_exec_count.csv
