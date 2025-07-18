#!/bin/bash

# Base date prefix (modify if needed)
DATE_PREFIX="YYYYMMDD"

# Working directories
BASE_DIR=$(pwd)
TEMP_ROOT="temp_processing"
OUTBOUND_DIR="${DATE_PREFIX}_OUTBOUND"
mkdir -p "$TEMP_ROOT"
mkdir -p "$OUTBOUND_DIR"

# Process each .tar.gz file
for TAR_FILE in ${DATE_PREFIX}.*.tar.gz; do
    [[ -f "$TAR_FILE" ]] || continue

    EXCHANGE_NAME=$(basename "$TAR_FILE" .tar.gz | cut -d'.' -f2)
    WORKDIR="$TEMP_ROOT/$EXCHANGE_NAME"
    mkdir -p "$WORKDIR"

    # Extract contents
    tar -xzf "$TAR_FILE" -C "$WORKDIR"

    for FILE in "$WORKDIR"/*.csv; do
        BASENAME=$(basename "$FILE")
        TEMPFILE="$WORKDIR/tmp_$BASENAME"

        # Remove first line and add Exchange column
        awk -v exch="$EXCHANGE_NAME" '
        BEGIN { FS=OFS="|"; header=1 }
        {
            if (header) { header=0; next }
            print exch, $0
        }' "$FILE" > "$TEMPFILE"

        # Count columns
        NUM_COLS=$(head -n 1 "$TEMPFILE" | awk -F'|' '{print NF}')

        # Determine special header cases
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

            printf \\$(printf '%03o' $((96 + index)))
        }

        # Generate header
        HEADER="Exchange"
        for ((i=2; i<=NUM_COLS; i++)); do
            COL_NAME=$(get_custom_header_name "$BASENAME" "$i" "$NUM_COLS")
            HEADER="$HEADER|$COL_NAME"
        done

        # Overwrite original file
        echo "$HEADER" > "$FILE"
        cat "$TEMPFILE" >> "$FILE"
        rm "$TEMPFILE"
    done
done

# Merge same-named CSVs into YYYYMMDD_OUTBOUND/
ALL_NAMES=("amend.csv" "cantr.csv" "delet.csv" "enter.csv" "offtr.csv" "trade.csv")

for NAME in "${ALL_NAMES[@]}"; do
    OUTPUT_FILE="$OUTBOUND_DIR/$NAME"
    > "$OUTPUT_FILE"  # create empty file

    for EXDIR in "$TEMP_ROOT"/*; do
        [[ -f "$EXDIR/$NAME" ]] && tail -n +1 "$EXDIR/$NAME" >> "$OUTPUT_FILE"
    done
done

echo "✅ All files processed and combined into folder: $OUTBOUND_DIR"
