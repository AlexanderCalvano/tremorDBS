#!/bin/bash

dat_dir="/home/armink/tremorDBS/imaging_tremorDBS"
output_file="all_network_metrics.csv"

# Write header to output file (only once)
echo "side,contact,amp,sub,thresh,node,deg,bc" > "$output_file"

# find all network_metrics.csv files and process them
find $dat_dir -type f -name "network_metrics.csv" -path "*+/*" ! -path "*++/*" | while read file; do
#find $dat_dir -type f -name "network_metrics.csv" | while read file; do
    # Extract folder name (parent directory)
    echo $file
    folder_name=$(basename "$(dirname "$file")")

    # Extract metadata from folder name
    side=$(echo "$folder_name" | cut -d'_' -f1)  # R or L
    contact=$(echo "$folder_name" | grep -oP 'contact-\d+' | cut -d'-' -f2) 
    amp=$(echo "$folder_name" | grep -oP 'amp-[0-9.]+mA' | cut -d'-' -f2 | sed 's/mA//') 

    # store all metrics for all ROIS (remove only header):
    #tail -n +2 "$file" | awk -v s="$side" -v c="$contact" -v a="$amp" -F',' 'BEGIN {OFS=","} {print s, c, a, $0}' >> "$output_file"

    # store only rows with ROI 83 (the VAT)
    tail -n +2 "$file" | awk -v s="$side" -v c="$contact" -v a="$amp" -F',' '$3 == 83 {OFS=","; print s, c, a, $0}' >> "$output_file"

done
