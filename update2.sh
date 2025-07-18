#!/bin/bash

# Set base date from any of the .tar.gz files (assuming consistent naming)
SAMPLE_TAR=$(ls *.tar.gz 2>/dev/null | head -n 1)
[[ -z "$SAMPLE_TAR" ]] && echo "❌ No .tar.gz files found" && exit 1
DATE_PREFIX=$(echo "$SAMPLE_TAR" | cut -d'.' -f1)

# Setup directories
TEMP_ROOT="temp_processing"
OUTBOUND_DIR="${DATE_PREFIX}_OUTBOUND"
mkdir -p "$TEMP_ROOT"
mkdir -p "$OUTBOUND_DIR"

echo "📦 Processing TAR.GZ files..."

# Loop through each .tar.gz
for TAR_FILE in ${DATE_PREFIX}.*.tar.gz; do
    [[ -f "$TAR_FILE" ]] || continue

    EXCHANGE_NAME=$(basename "$TAR_FILE" .tar.gz | cut -d'.' -f2)
    WORKDIR="$TEMP_ROOT/$EXCHANGE_NAME"
    mkdir -p "$WORKDIR"

    # Extract archive
    tar -xzf "$TAR_FILE" -C "$WORKDIR"

    for FILE in "$WORKDIR"/*.csv; do
        BASENAME=$(basename "$FILE")
        TEMPFILE="$WORKDIR/tmp_$BASENAME"

        # Clean first row and prepend Exchange column
        awk -v exch="$EXCHANGE_NAME" '
        BEGIN { FS=OFS="|"; header=1 }
        {
            if (header) { header=0; next }
            print exch, $0
        }' "$FILE" > "$TEMPFILE"

        NUM_COLS=$(head -n 1 "$TEMPFILE" | awk -F'|' '{print NF}')

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

# Combine all same-named files into OUTBOUND
ALL_NAMES=("amend.csv" "cantr.csv" "delet.csv" "enter.csv" "offtr.csv" "trade.csv")
echo "📂 Merging files into $OUTBOUND_DIR..."

for NAME in "${ALL_NAMES[@]}"; do
    OUTPUT_FILE="$OUTBOUND_DIR/$NAME"
    > "$OUTPUT_FILE"

    FIRST=1
    for EXDIR in "$TEMP_ROOT"/*; do
        FILE="$EXDIR/$NAME"
        [[ -f "$FILE" ]] || continue

        if [[ $FIRST -eq 1 ]]; then
            cat "$FILE" >> "$OUTPUT_FILE"  # include header
            FIRST=0
        else
            tail -n +2 "$FILE" >> "$OUTPUT_FILE"  # skip header
        fi
    done
done

# Check for UBS_YYYYMMDD.zip and extract it
ZIP_FILE="UBS_${DATE_PREFIX}.zip"
INBOUND_DIR="${DATE_PREFIX}_INBOUND"

if [[ -f "$ZIP_FILE" ]]; then
    echo "🗜️  Unzipping $ZIP_FILE into $INBOUND_DIR..."
    mkdir -p "$INBOUND_DIR"
    unzip -q "$ZIP_FILE" -d "$INBOUND_DIR"
    echo "✅ Unzip complete."
else
    echo "⚠️  No UBS ZIP file found: $ZIP_FILE"
fi

echo "✅ All processing done."
