#!/bin/bash

# Calculate the PIV value from the leave-one-patient-out effectiveness maps
# each subject's PIV is extracted from the map that excluded them

cd "$(dirname "$0")"

data_dir="../data"
vta_root="${data_dir}/leaddbs"                
sweet_spot_dir="${data_dir}/sweet_spot_zscore"
tremor_left_stn="${data_dir}/tremor_leftSTN_final.csv"
tremor_right_stn="${data_dir}/tremor_rightSTN_final.csv"

tmp_dir="${data_dir}/tmp_miv_extraction"
mkdir -p "$tmp_dir"

output_left="${data_dir}/piv_leftSTN.csv"
output_right="${data_dir}/piv_rightSTN.csv"

echo "subnum,side,contact,amp,MIV_mean,MIV_peak" > "$output_left"
echo "subnum,side,contact,amp,MIV_mean,MIV_peak" > "$output_right"

# ----- quick helper to see the extracted peak value -------

extract_miv() {
    local sweet_spot=$1
    local vta=$2
    local tag=$3

    local masked="${tmp_dir}/masked_${tag}.nii.gz"

    local mean_val
    mean_val=$(fslstats "$sweet_spot" -k "$vta" -m)

    # mask the map with the VTA and take the 90th percentile. We use FSL for this and the -k on the masked
    # image
    fslmaths "$sweet_spot" -mas "$vta" "$masked"

    local peak_val
    peak_val=$(fslstats "$masked" -k "$vta" -P 90)

    rm -f "$masked"

    # Handle the empty values
    if [[ "$mean_val" == *"nan"* ]] || [[ -z "$mean_val" ]]; then
        mean_val="0"
    fi
    if [[ "$peak_val" == *"nan"* ]] || [[ -z "$peak_val" ]]; then
        peak_val="0"
    fi

    mean_val=$(echo "$mean_val" | xargs)
    peak_val=$(echo "$peak_val" | xargs)

    echo "$mean_val $peak_val"
}

# -------------- Process left STN -----------------
{
    read header
    while IFS=, read -r subnum side contact amp rms; do
        subnum=$(echo "$subnum" | tr -d '"')
        contact=$(echo "$contact" | tr -d '"')
        amp=$(echo "$amp" | tr -d '"')
        contact_formatted=$(printf "%02d" "$contact")

        loso_sweet_spot="${sweet_spot_dir}/LOSO_sub-subject${subnum}/sweet_spot_left.nii.gz"
        if [ ! -f "$loso_sweet_spot" ]; then
            echo "warning: loso map not found: $loso_sweet_spot" >&2
            continue
        fi

        vta_file="${vta_root}/sub-subject${subnum}/stimulations/MNI152NLin2009bAsym/L_contact-${contact_formatted}_amp-${amp}mA/sub-subject${subnum}_sim-binary_model-simbio_hemi-L_MNI_1mm.nii.gz"
        if [ ! -f "$vta_file" ]; then
            echo "warning: vta not found: $vta_file" >&2
            continue
        fi

        read miv_mean miv_peak < <(extract_miv "$loso_sweet_spot" "$vta_file" "L_${subnum}_${contact}_${amp}")

        echo "${subnum},L,${contact},${amp},${miv_mean},${miv_peak}" >> "$output_left"
    done
} < "$tremor_left_stn"

# -------------- Process right STN -----------------
{
    read header
    while IFS=, read -r subnum side contact amp rms; do
        subnum=$(echo "$subnum" | tr -d '"')
        contact=$(echo "$contact" | tr -d '"')
        amp=$(echo "$amp" | tr -d '"')
        contact_remapped=$((contact - 8))
        contact_formatted=$(printf "%02d" "$contact_remapped")

        loso_sweet_spot="${sweet_spot_dir}/LOSO_sub-subject${subnum}/sweet_spot_right.nii.gz"
        if [ ! -f "$loso_sweet_spot" ]; then
            echo "warning: loso map not found: $loso_sweet_spot" >&2
            continue
        fi

        vta_file="${vta_root}/sub-subject${subnum}/stimulations/MNI152NLin2009bAsym/R_contact-${contact_formatted}_amp-${amp}mA/sub-subject${subnum}_sim-binary_model-simbio_hemi-R_MNI_1mm.nii.gz"
        if [ ! -f "$vta_file" ]; then
            echo "warning: vta not found: $vta_file" >&2
            continue
        fi

        read miv_mean miv_peak < <(extract_miv "$loso_sweet_spot" "$vta_file" "R_${subnum}_${contact}_${amp}")

        echo "${subnum},R,${contact},${amp},${miv_mean},${miv_peak}" >> "$output_right"
    done
} < "$tremor_right_stn"

rmdir "$tmp_dir" 2>/dev/null || true