#!/bin/bash

# --- 1. Input ---
if [ $# -lt 1 ]; then
    echo "❌ Usage: $0 <DATE_PREFIX>"
    echo "Example: $0 20250718"
    exit 1
fi

DATE_PREFIX="$1"
TEMP_ROOT="temp_processing"
OUTBOUND_DIR="${DATE_PREFIX}_OUTBOUND"
mkdir -p "$TEMP_ROOT"
mkdir -p "$OUTBOUND_DIR"

echo "📦 Processing files for date: $DATE_PREFIX"

# --- 2. Process each .tar.gz ---
for TAR_FILE in ${DATE_PREFIX}.*.tar.gz; do
    [[ -f "$TAR_FILE" ]] || continue

    EXCHANGE_NAME=$(basename "$TAR_FILE" .tar.gz | cut -d'.' -f2)
    WORKDIR="$TEMP_ROOT/$EXCHANGE_NAME"
    mkdir -p "$WORKDIR"

    echo "🔍 Extracting $TAR_FILE → $WORKDIR"
    tar -xzf "$TAR_FILE" -C "$WORKDIR"

    for FILE in "$WORKDIR"/*.csv; do
        BASENAME=$(basename "$FILE")
        TEMPFILE="$WORKDIR/tmp_$BASENAME"

        # Remove header and add Exchange column
        awk -v exch="$EXCHANGE_NAME" '
        BEGIN { FS=OFS="|"; header=1 }
        {
            if (header) { header=0; next }
            print exch, $0
        }' "$FILE" > "$TEMPFILE"

        # Skip if file is empty after header removal
        if [[ ! -s "$TEMPFILE" ]]; then
            echo "⚠️  Skipping empty file: $BASENAME (no data rows)"
            rm -f "$FILE" "$TEMPFILE"
            continue
        fi

        NUM_COLS=$(head -n 1 "$TEMPFILE" | awk -F'|' '{print NF}')

        # --- 3. Column Naming Function ---
        get_custom_header_name() {
            local base="$1"
            local index="$2"
            local total="$3"
            local from_end=$((total - index + 1))

            case "$base" in
                "trade.csv")
                    [[ $from_end -eq 2 ]] && echo "Parent Order Id" && return ;;
                "offtr.csv")
                    [[ $from_end -eq 2 ]] && echo "Parent Order Id" && return ;;
                "delet.csv")
                    [[ $from_end -eq 3 ]] && echo "Parent Order Id" && return ;;
                "enter.csv")
                    [[ $from_end -eq 5 ]] && echo "Parent Order Id" && return ;;
                "amend.csv")
                    [[ $from_end -eq 5 ]] && echo "Parent Order Id" && return ;;
            esac

            printf \\$(printf '%03o' $((96 + index)))
        }

        # --- 4. Build header line ---
        HEADER="Exchange"
        for ((i=2; i<=NUM_COLS; i++)); do
            COL_NAME=$(get_custom_header_name "$BASENAME" "$i" "$NUM_COLS")
            HEADER="$HEADER|$COL_NAME"
        done

        echo "$HEADER" > "$FILE"
        cat "$TEMPFILE" >> "$FILE"
        rm "$TEMPFILE"
    done
done

# --- 5. Merge CSVs ---
ALL_NAMES=("amend.csv" "cantr.csv" "delet.csv" "enter.csv" "offtr.csv" "trade.csv")
echo "📂 Merging files into: $OUTBOUND_DIR"

for NAME in "${ALL_NAMES[@]}"; do
    OUTPUT_FILE="$OUTBOUND_DIR/$NAME"
    > "$OUTPUT_FILE"
    FIRST=1

    for EXDIR in "$TEMP_ROOT"/*; do
        FILE="$EXDIR/$NAME"
        [[ -f "$FILE" ]] || continue

        if [[ $FIRST -eq 1 ]]; then
            cat "$FILE" >> "$OUTPUT_FILE"  # keep header
            FIRST=0
        else
            tail -n +2 "$FILE" >> "$OUTPUT_FILE"  # skip header
        fi
    done
done

# --- 6. Unzip UBS file ---
ZIP_FILE="UBS_${DATE_PREFIX}.zip"
INBOUND_DIR="${DATE_PREFIX}_INBOUND"

if [[ -f "$ZIP_FILE" ]]; then
    echo "🗜️  Unzipping $ZIP_FILE → $INBOUND_DIR"
    mkdir -p "$INBOUND_DIR"
    unzip -q "$ZIP_FILE" -d "$INBOUND_DIR"
    echo "✅ UBS zip extracted."
