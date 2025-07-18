#!/bin/bash

# --- 1. Get DATE_PREFIX ---
if [ $# -lt 1 ]; then
    echo "❌ Usage: $0 <DATE_PREFIX>"
    echo "Example: $0 20250718"
    exit 1
fi

DATE_PREFIX="$1"

# --- 2. Setup folders ---
TEMP_ROOT="temp_processing"
OUTBOUND_DIR="${DATE_PREFIX}_OUTBOUND"
mkdir -p "$TEMP_ROOT"
mkdir -p "$OUTBOUND_DIR"

echo "📦 Processing TAR.GZ files for date: $DATE_PREFIX"

# --- 3. Loop through each TAR file ---
for TAR_FILE in ${DATE_PREFIX}.*.tar.gz; do
    [[ -f "$TAR_FILE" ]] || continue

    EXCHANGE_NAME=$(basename "$TAR_FILE" .tar.gz | cut -d'.' -f2)
    WORKDIR="$TEMP_ROOT/$EXCHANGE_NAME"
    mkdir -p "$WORKDIR"

    echo "🔍 Extracting: $TAR_FILE → $WORKDIR"
    tar -xzf "$TAR_FILE" -C "$WORKDIR"

    for FILE in "$WORKDIR"/*.csv; do
        BASENAME=$(basename "$FILE")
        TEMPFILE="$WORKDIR/tmp_$BASENAME"

        # Remove header, add Exchange column
        awk -v exch="$EXCHANGE_NAME" '
        BEGIN { FS=OFS="|"; header=1 }
        {
            if (header) { header=0; next }
            print exch, $0
        }' "$FILE" > "$TEMPFILE"

        # Count columns (after Exchange is added)
        NUM_COLS=$(head -n 1 "$TEMPFILE" | awk -F'|' '{print NF}')

        # --- Header logic ---
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
                "enter.csv")
                    [[ $from_end -eq 5 ]] && echo "Parent Order Id" && return
                    ;;
                "amend.csv")
                    [[ $from_end -eq 5 ]] && echo "Parent Order Id" && return
                    ;;
            esac

            printf \\$(printf '%03o' $((96 + index)))
        }

        # Generate header row
        HEADER="Exchange"
        for ((i=2; i<=NUM_COLS; i++)); do
            COL_NAME=$(get_custom_header_name "$BASENAME" "$i" "$NUM_COLS")
            HEADER="$HEADER|$COL_NAME"
        done

        # Save file with header
        echo "$HEADER" > "$FILE"
        cat "$TEMPFILE" >> "$FILE"
        rm "$TEMPFILE"
    done
done

# --- 4. Merge all same-named files into OUTBOUND ---
ALL_NAMES=("amend.csv" "cantr.csv" "delet.csv" "enter.csv" "offtr.csv" "trade.csv")
echo "📂 Merging into $OUTBOUND_DIR..."

for NAME in "${ALL_NAMES[@]}"; do
    OUTPUT_FILE="$OUTBOUND_DIR/$NAME"
    > "$OUTPUT_FILE"
    FIRST=1

    for EXDIR in "$TEMP_ROOT"/*; do
        FILE="$EXDIR/$NAME"
        [[ -f "$FILE" ]] || continue

        if [[ $FIRST -eq 1 ]]; then
            cat "$FILE" >> "$OUTPUT_FILE"
            FIRST=0
        else
            tail -n +2 "$FILE" >> "$OUTPUT_FILE"
        fi
    done
done

# --- 5. Unzip UBS zip file (if present) ---
ZIP_FILE="UBS_${DATE_PREFIX}.zip"
INBOUND_DIR="${DATE_PREFIX}_INBOUND"

if [[ -f "$ZIP_FILE" ]]; then
    echo "🗜️  Unzipping $ZIP_FILE → $INBOUND_DIR"
    mkdir -p "$INBOUND_DIR"
    unzip -q "$ZIP_FILE" -d "$INBOUND_DIR"
    echo "✅ UBS ZIP extracted"
else
    echo "⚠️  UBS ZIP not found: $ZIP_FILE"
fi

echo "✅ All tasks completed for: $DATE_PREFIX"
