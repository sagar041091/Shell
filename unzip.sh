#!/bin/bash

# Input file
TAR_FILE="YYYYMMDD.ICEEULBK.tar.gz"

# Extract Exchange name (e.g. ICEEULBK)
EXCHANGE_NAME=$(basename "$TAR_FILE" .tar.gz | cut -d'.' -f2)

# Working directory
WORKDIR="iceeulbk_temp"
mkdir -p "$WORKDIR"

# Extract files
tar -xzf "$TAR_FILE" -C "$WORKDIR"

# Loop over each CSV
for FILE in "$WORKDIR"/*.csv; do
    BASENAME=$(basename "$FILE")
    TEMPFILE="$WORKDIR/tmp_$BASENAME"

    # Remove first row and prepend Exchange column
    awk -v exch="$EXCHANGE_NAME" '
    BEGIN { OFS = ","; header = 1 }
    {
        if (header) {
            header = 0;
            next;
        }
        print exch, $0;
    }' "$FILE" > "$TEMPFILE"

    # Count columns
    NUM_COLS=$(head -n 1 "$TEMPFILE" | awk -F',' '{print NF}')

    # Determine which column should be 'Parent Order Id'
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

        # Default: alphabet a, b, c, ...
        printf \\$(printf '%03o' $((96 + index)))
    }

    # Generate header
    HEADER="Exchange"
    for ((i=2; i<=NUM_COLS; i++)); do
        COL_NAME=$(get_custom_header_name "$BASENAME" "$i" "$NUM_COLS")
        HEADER="$HEADER,$COL_NAME"
    done

    # Finalize file
    echo "$HEADER" > "$FILE"
    cat "$TEMPFILE" >> "$FILE"
    rm "$TEMPFILE"
done

echo "✅ All CSVs processed with special header logic. Output in: $WORKDIR"
