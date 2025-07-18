#!/bin/bash

# Input and output files
INPUT_FILE="input.csv"
OUTPUT_FILE="output.csv"

# Ensure output file is clean
echo -e "exec type\tPARENTID\tCOUNT" > "$OUTPUT_FILE"

# Skip header, sort and count by 'exec type' and 'PARENTID'
tail -n +2 "$INPUT_FILE" | awk -F',' '{print $1"\t"$2}' | sort | uniq -c | awk '{print $1"\t"$2"\t"$3}' | \
awk '
{
    if (prev_type != $2) {
        if (NR != 1) {
            print "" >> "'$OUTPUT_FILE'"
        }
        print $2 "\t" $3 "\t" $1 >> "'$OUTPUT_FILE'"
        prev_type = $2
    } else {
        print "\t" $3 "\t" $1 >> "'$OUTPUT_FILE'"
    }
}'
