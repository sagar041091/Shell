#!/bin/bash

DATE_PREFIX="$1"

# Validate input
if [[ -z "$DATE_PREFIX" ]]; then
    echo "Usage: $0 <YYYY-MM-DD | YYYY-MM | YYYY-QX>"
    exit 1
fi

# Function to get dates from quarter
get_dates_from_quarter() {
    local quarter=$1
    local year=${quarter%-Q*}
    local q=${quarter#*Q}

    case $q in
        1) start="${year}-01-01"; end="${year}-03-31" ;;
        2) start="${year}-04-01"; end="${year}-06-30" ;;
        3) start="${year}-07-01"; end="${year}-09-30" ;;
        4) start="${year}-10-01"; end="${year}-12-31" ;;
        *) echo "Invalid quarter"; exit 1 ;;
    esac

    # Generate date range
    current="$start"
    while [[ "$current" < "$end" || "$current" == "$end" ]]; do
        echo "$current"
        current=$(date -I -d "$current + 1 day")
    done
}

# Identify format and generate dates
if [[ "$DATE_PREFIX" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    # Single date
    DATE_LIST=("$DATE_PREFIX")
elif [[ "$DATE_PREFIX" =~ ^[0-9]{4}-[0-9]{2}$ ]]; then
    # Full month
    year=${DATE_PREFIX%-*}
    month=${DATE_PREFIX#*-}
    days_in_month=$(cal $month $year | awk 'NF {DAYS = $NF}; END {print DAYS}')
    
    DATE_LIST=()
    for day in $(seq -w 1 $days_in_month); do
        DATE_LIST+=("${year}-${month}-${day}")
    done
elif [[ "$DATE_PREFIX" =~ ^[0-9]{4}-Q[1-4]$ ]]; then
    # Quarter
    DATE_LIST=($(get_dates_from_quarter "$DATE_PREFIX"))
else
    echo "Invalid format. Use YYYY-MM-DD, YYYY-MM, or YYYY-QX"
    exit 1
fi

# Iterate over the generated date list
for DATE in "${DATE_LIST[@]}"; do
    echo "Running logic for $DATE"
    # YOUR LOGIC HERE
done
