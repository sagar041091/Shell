#!/bin/bash

START_DATE_RAW="$1"
END_DATE_RAW="$2"

# Check if both parameters are provided
if [[ -z "$START_DATE_RAW" || -z "$END_DATE_RAW" ]]; then
    echo "Usage: $0 <START_DATE: YYYYMMDD> <END_DATE: YYYYMMDD>"
    exit 1
fi

# Convert to YYYY-MM-DD for `date` command
START_DATE=$(date -d "${START_DATE_RAW}" +"%Y-%m-%d") || { echo "Invalid start date"; exit 1; }
END_DATE=$(date -d "${END_DATE_RAW}" +"%Y-%m-%d") || { echo "Invalid end date"; exit 1; }

# Validate range
if [[ "$START_DATE" > "$END_DATE" ]]; then
    echo "Start date must not be after end date"
    exit 1
fi

# Loop through date range
CURRENT_DATE="$START_DATE"
while [[ "$CURRENT_DATE" < "$END_DATE" || "$CURRENT_DATE" == "$END_DATE" ]]; do
    FORMATTED_DATE=$(date -d "$CURRENT_DATE" +"%Y%m%d")
    echo "Running logic for $FORMATTED_DATE"

    # === YOUR LOGIC GOES HERE ===
    # Example: process_file_for_date "$FORMATTED_DATE"

    # Increment date
    CURRENT_DATE=$(date -I -d "$CURRENT_DATE + 1 day")
done
