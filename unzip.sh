#!/bin/bash

# Input tar.gz file
TAR_FILE="YYYYMMDD.ICEEULBK.tar.gz"

# Extract Exchange name from file name
EXCHANGE_NAME=$(basename "$TAR_FILE" .tar.gz | cut -d'.' -f2)

# Working directory
WORKDIR="iceeulbk_temp"
mkdir -p "$WORKDIR"

# Extract contents
tar -xzf "$TAR_FILE" -C "$WORKDIR"

# Loop over each .csv file
for FILE in "$WORKDIR"/*.csv; do
    BASENAME=$(basename "$FILE")
    TEMPFILE="$WORKDIR/tmp_$BASENAME"

    # Remove first line (header) and prepend Exchange column (pipe-separated)
    awk -v exch="$EXCHANGE_NAME" '
    BEGIN { FS=OFS="|"; header=1 }
    {
        if (header) { header=0; next }
        print exch, $0
    }' "$FILE" > "$TEMPFILE"

    # Count number of columns (after adding Exchange column)
    NUM_COLS=$(head -n 1 "$TEMPFILE" | awk -F'|' '{print NF}')

    # Function: assign special header name based on rules
    get_custom_header_name() {
        local base="$1"
        local index="$2"
        local total="$3"
        local from_end=$((total - index + 1))

        case "$base" in
            "trade.csv")
                [[ $from_end -eq 2 ]] && echo "Parent Order Id" && return
                ;;
            "delet.csv")
                [[ $from_end -eq 3 ]] && echo "Parent Order Id" && return
                ;;
            "offtr.csv")
                [[ $from_end -eq 2 ]] && echo "Parent Order Id" && return
                ;;
        esac

        # Default: alphabetic column names (a, b, c...)
        printf \\$(printf '%03o' $((96 + index)))
    }

    # Construct the header row
    HEADER="Exchange"
    for ((i=2; i<=NUM_COLS; i++)); do
        COL_NAME=$(get_custom_header_name "$BASENAME" "$i" "$NUM_COLS")
        HEADER="$HEADER|$COL_NAME"
    done

    # Overwrite original file with new header + data
    echo "$HEADER" > "$FILE"
    cat "$TEMPFILE" >> "$FILE"
    rm "$TEMPFILE"
done

echo "✅ Pipe-delimited CSVs processed with custom headers. Output in: $WORKDIR"
