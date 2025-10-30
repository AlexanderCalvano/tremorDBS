#!/bin/bash

basedir="../../tremorDBS/imaging_tremorDBS"
outfile="../results/vat_connectivity_matrix.csv"

# Output header
echo "subject,side,contact,amp,$(seq -s, 1 83)" > $outfile

find "$basedir" -type f -name "fdt_network_matrix" -path "*+/*" ! -path "*++/*" | while read -r file; do
    folder=$(dirname "$file")
    foldername=$(basename "$folder")

    # Get subject folder (grandgrandparent of the "+" folder)
    subject=$(basename "$(dirname "$(dirname "$(dirname "$folder")")")")

    if [[ "$foldername" =~ ([LR])_contact-([0-9]+)_amp-([0-9.]+)mA\+ ]]; then
	side="${BASH_REMATCH[1]}"
	contact="${BASH_REMATCH[2]}"
	amp="${BASH_REMATCH[3]}"

	# Clean VAT line and remove trailing comma
	vat_line=$(tail -n 1 "$file" | tr -s '[:space:]' ',' | sed 's/,$//')

	echo "$subject,$side,$contact,$amp,$vat_line"
    fi
done >> $outfile
