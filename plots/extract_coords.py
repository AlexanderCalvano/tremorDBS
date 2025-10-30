#!/usr/bin/env python3
"""
Extract Desikan Parcellation ROI Centroids from desikan_supratent_gm_coords.txt file

"""

import numpy as np
import pandas as pd

def extract_and_save_centroids(input_file='desikan_supratent_gm_coords.txt',
                                output_left='desikan_left_centroids_mni.csv',
                                output_right='desikan_right_centroids_mni.csv',
                                output_subcortical='desikan_subcortical_centroids_mni.csv'):
    """
    Parameters:
    -----------
    input_file : str
        Path to the input coordinate file
    output_left : str
        Output CSV file for left hemisphere cortical ROIs (1001-1035)
    output_right : str
        Output CSV file for right hemisphere cortical ROIs (2001-2035)
    output_subcortical : str
        Output CSV file for subcortical structures (10-54)
    """
    
    # Desikan-Killiany atlas ROI names
    cortical_labels = {
        # Left hemisphere (1001-1035)
        1001: 'ctx-lh-bankssts',
        1002: 'ctx-lh-caudalanteriorcingulate',
        1003: 'ctx-lh-caudalmiddlefrontal',
        1005: 'ctx-lh-cuneus',
        1006: 'ctx-lh-entorhinal',
        1007: 'ctx-lh-fusiform',
        1008: 'ctx-lh-inferiorparietal',
        1009: 'ctx-lh-inferiortemporal',
        1010: 'ctx-lh-isthmuscingulate',
        1011: 'ctx-lh-lateraloccipital',
        1012: 'ctx-lh-lateralorbitofrontal',
        1013: 'ctx-lh-lingual',
        1014: 'ctx-lh-medialorbitofrontal',
        1015: 'ctx-lh-middletemporal',
        1016: 'ctx-lh-parahippocampal',
        1017: 'ctx-lh-paracentral',
        1018: 'ctx-lh-parsopercularis',
        1019: 'ctx-lh-parsorbitalis',
        1020: 'ctx-lh-parstriangularis',
        1021: 'ctx-lh-pericalcarine',
        1022: 'ctx-lh-postcentral',
        1023: 'ctx-lh-posteriorcingulate',
        1024: 'ctx-lh-precentral',
        1025: 'ctx-lh-precuneus',
        1026: 'ctx-lh-rostralanteriorcingulate',
        1027: 'ctx-lh-rostralmiddlefrontal',
        1028: 'ctx-lh-superiorfrontal',
        1029: 'ctx-lh-superiorparietal',
        1030: 'ctx-lh-superiortemporal',
        1031: 'ctx-lh-supramarginal',
        1032: 'ctx-lh-frontalpole',
        1033: 'ctx-lh-temporalpole',
        1034: 'ctx-lh-transversetemporal',
        1035: 'ctx-lh-insula',
        
        # Right hemisphere (2001-2035)
        2001: 'ctx-rh-bankssts',
        2002: 'ctx-rh-caudalanteriorcingulate',
        2003: 'ctx-rh-caudalmiddlefrontal',
        2005: 'ctx-rh-cuneus',
        2006: 'ctx-rh-entorhinal',
        2007: 'ctx-rh-fusiform',
        2008: 'ctx-rh-inferiorparietal',
        2009: 'ctx-rh-inferiortemporal',
        2010: 'ctx-rh-isthmuscingulate',
        2011: 'ctx-rh-lateraloccipital',
        2012: 'ctx-rh-lateralorbitofrontal',
        2013: 'ctx-rh-lingual',
        2014: 'ctx-rh-medialorbitofrontal',
        2015: 'ctx-rh-middletemporal',
        2016: 'ctx-rh-parahippocampal',
        2017: 'ctx-rh-paracentral',
        2018: 'ctx-rh-parsopercularis',
        2019: 'ctx-rh-parsorbitalis',
        2020: 'ctx-rh-parstriangularis',
        2021: 'ctx-rh-pericalcarine',
        2022: 'ctx-rh-postcentral',
        2023: 'ctx-rh-posteriorcingulate',
        2024: 'ctx-rh-precentral',
        2025: 'ctx-rh-precuneus',
        2026: 'ctx-rh-rostralanteriorcingulate',
        2027: 'ctx-rh-rostralmiddlefrontal',
        2028: 'ctx-rh-superiorfrontal',
        2029: 'ctx-rh-superiorparietal',
        2030: 'ctx-rh-superiortemporal',
        2031: 'ctx-rh-supramarginal',
        2032: 'ctx-rh-frontalpole',
        2033: 'ctx-rh-temporalpole',
        2034: 'ctx-rh-transversetemporal',
        2035: 'ctx-rh-insula',
    }
    
    subcortical_labels = {
        10: 'Left-Thalamus-Proper',
        11: 'Left-Caudate',
        12: 'Left-Putamen',
        13: 'Left-Pallidum',
        17: 'Left-Hippocampus',
        18: 'Left-Amygdala',
        49: 'Right-Thalamus-Proper',
        50: 'Right-Caudate',
        51: 'Right-Putamen',
        52: 'Right-Pallidum',
        53: 'Right-Hippocampus',
        54: 'Right-Amygdala',
    }
    
    # Load the coordinate file
    print(f"Loading coordinates from: {input_file}")
    data = np.loadtxt(input_file)
    
    # Separate into different categories
    left_cortical = []
    right_cortical = []
    subcortical = []
    
    for row in data:
        roi_id = int(row[0])
        x, y, z = row[1], row[2], row[3]
        
        if roi_id in cortical_labels:
            roi_name = cortical_labels[roi_id]
            
            if roi_id < 2000:  # Left hemisphere
                left_cortical.append({
                    'ROI_ID': roi_id,
                    'ROI_name': roi_name,
                    'x': x,
                    'y': y,
                    'z': z
                })
            else:  # Right hemisphere
                right_cortical.append({
                    'ROI_ID': roi_id,
                    'ROI_name': roi_name,
                    'x': x,
                    'y': y,
                    'z': z
                })
        
        elif roi_id in subcortical_labels:
            subcortical.append({
                'ROI_ID': roi_id,
                'ROI_name': subcortical_labels[roi_id],
                'x': x,
                'y': y,
                'z': z
            })
    
    # Create DataFrames
    df_left = pd.DataFrame(left_cortical)
    df_right = pd.DataFrame(right_cortical)
    df_subcortical = pd.DataFrame(subcortical)
    
    # Save to CSV files
    df_left.to_csv(output_left, index=False)
    df_right.to_csv(output_right, index=False)
    df_subcortical.to_csv(output_subcortical, index=False)
    
    print(f"\nExtracted {len(df_left) + len(df_right) + len(df_subcortical)} ROIs:")
    print(f"  Left hemisphere: {len(df_left)}")
    print(f"  Right hemisphere: {len(df_right)}")
    print(f"  Subcortical: {len(df_subcortical)}")
    
    return df_left, df_right, df_subcortical


if __name__ == "__main__":
    df_left, df_right, df_subcortical = extract_and_save_centroids()
    print("Extraction complete.")
