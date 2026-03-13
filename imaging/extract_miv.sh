#!/bin/bash
# extract mean intensity values (miv) from effectiveness maps

vta_root="path/to/leaddbs/derivatives"
effectiveness_map_left="path/to/effectiveness_map_left.nii.gz"
effectiveness_map_right="path/to/effectiveness_map_right.nii.gz"
tremor_left_stn="path/to/tremor_leftSTN_final.csv"
tremor_right_stn="path/to/tremor_rightSTN_final.csv"
output_left="path/to/miv_leftSTN.csv"
output_right="path/to/miv_rightSTN.csv"


# left 
{ read header; while IFS=, read -r subnum side contact amp rms; do
    subnum=$(echo "$subnum" | tr -d '"')
    contact=$(echo "$contact" | tr -d '"')
    amp=$(echo "$amp" | tr -d '"')
    contact_formatted=$(printf "%02d" "$contact")
    vta_file="${vta_root}/sub-subject${subnum}/stimulations/MNI152NLin2009bAsym/L_contact-${contact_formatted}_amp-${amp}mA/sub-subject${subnum}_sim-binary_model-simbio_hemi-L_MNI_1mm.nii.gz"
    
    [ ! -f "$vta_file" ] && continue
    miv=$(fslstats "$effectiveness_map_left" -k "$vta_file" -m)
    [[ "$miv" == *"nan"* ]] || [[ -z "$miv" ]] && miv="0"
    echo "${subnum},L,${contact},${amp},${miv}" >> "$output_left"
done; } < "$tremor_left_stn"

# right
{ read header; while IFS=, read -r subnum side contact amp rms; do
    subnum=$(echo "$subnum" | tr -d '"')
    contact=$(echo "$contact" | tr -d '"')
    amp=$(echo "$amp" | tr -d '"')
    contact_remapped=$((contact - 8))
    contact_formatted=$(printf "%02d" "$contact_remapped")
    vta_file="${vta_root}/sub-subject${subnum}/stimulations/MNI152NLin2009bAsym/R_contact-${contact_formatted}_amp-${amp}mA/sub-subject${subnum}_sim-binary_model-simbio_hemi-R_MNI_1mm.nii.gz"
    
    [ ! -f "$vta_file" ] && continue
    miv=$(fslstats "$effectiveness_map_right" -k "$vta_file" -m)
    [[ "$miv" == *"nan"* ]] || [[ -z "$miv" ]] && miv="0"
    echo "${subnum},R,${contact},${amp},${miv}" >> "$output_right"
done; } < "$tremor_right_stn"
