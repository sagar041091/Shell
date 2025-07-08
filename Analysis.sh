#!/bin/bash

# === Parameters ===
WORK_DATE="$1"  # Expected format: YYYYMMDD
ARCHIVE_DIR="./ARCHIVE"
WORKING_DIR="./ANALYSIS_WORKING"
OUTPUT_CSV="ANALYSIS_${WORK_DATE}.csv"
TEMP_DIR="${WORKING_DIR}/temp_${WORK_DATE}"

mkdir -p "$WORKING_DIR"
mkdir -p "$TEMP_DIR"

# === Step 1: Copy files for date to ANALYSIS_WORKING ===
echo "Copying files for $WORK_DATE..."
find "$ARCHIVE_DIR" -type f -name "*${WORK_DATE}*" -exec cp {} "$WORKING_DIR" \;

cd "$WORKING_DIR" || exit 1

# === Step 2: Unzip PQR_YYYYMMDD.zip ===
echo "Unzipping PQR_${WORK_DATE}.zip..."
unzip -q "PQR_${WORK_DATE}.zip" -d "$TEMP_DIR"

# Extract just the .csv file from PQR
PQR_CSV_FILE=$(find "$TEMP_DIR" -type f -name "*.csv")
PQR_BASENAME=$(basename "$PQR_CSV_FILE")

# === Step 3-5: Extract tar.gz files and prefix ===
function extract_and_prefix {
    TARFILE="$1"
    PREFIX="$2"

    mkdir -p "$TEMP_DIR/$PREFIX"
    tar -xzf "$TARFILE" -C "$TEMP_DIR/$PREFIX"

    for FILE in "$TEMP_DIR/$PREFIX"/*; do
        BASENAME=$(basename "$FILE")
        mv "$FILE" "$TEMP_DIR/${PREFIX}_${BASENAME}"
    done
    rm -r "$TEMP_DIR/$PREFIX"
}

echo "Unpacking and renaming contents..."
extract_and_prefix "${WORK_DATE}.ABCEU.tar.gz" "ABCEU"
extract_and_prefix "${WORK_DATE}.ABCUS.tar.gz" "ABCUS"
extract_and_prefix "${WORK_DATE}.ABCND.tar.gz" "ABCND"

# === Step 6: Create ANALYSIS_YYYYMMDD.csv with unique ORDERIDs ===
echo "Generating ANALYSIS CSV..."
ORDER_IDS=$(awk -F',' 'NR > 1 {print $1}' "$PQR_CSV_FILE" | sort | uniq)

{
  echo "ORDERID,COMMENTS"
  echo "$ORDER_IDS" | while read -r ORDER_ID; do
    echo "$ORDER_ID,"
  done
} > "$OUTPUT_CSV"

# === Step 7: Fill COMMENTS based on ORDERID match in column 18 of *_enter.csv files ===
echo "Filling COMMENTS in $OUTPUT_CSV..."

TMP_OUTPUT="${OUTPUT_CSV}.tmp"

tail -n +2 "$OUTPUT_CSV" | while IFS=',' read -r ORDER_ID COMMENT; do
    # Clean and trim ORDER_ID (remove \r and leading/trailing spaces)
    ORDER_ID_CLEAN=$(echo "$ORDER_ID" | tr -d '\r' | xargs)

    COMMENT_TEXT=""

    for file in "$TEMP_DIR"/*_enter.csv; do
        # Skip version line, check 18th column match
        if tail -n +2 "$file" | awk -F'|' -v oid="$ORDER_ID_CLEAN" '
            {
                gsub(/\r/, "", $18)
                if ($18 == oid) {exit 0}
            }
            END {exit 1}
        '; then
            FILENAME=$(basename "$file")
            COMMENT_TEXT="Found in $FILENAME"
            break
        fi
    done

    echo "${ORDER_ID},\"${COMMENT_TEXT}\"" >> "$TMP_OUTPUT"
done

# Rebuild CSV with header
echo "ORDERID,COMMENTS" > "$OUTPUT_CSV"
cat "$TMP_OUTPUT" >> "$OUTPUT_CSV"
rm "$TMP_OUTPUT"

echo "COMMENTS updated successfully."
