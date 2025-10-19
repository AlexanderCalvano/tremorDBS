#!/usr/bin/env python3
"""
Visualise PLS Component Loadings: VTA-ROI Connectivity

This script creates glass brain visualisations showing connections between
VTA centres and brain ROIs, coloured by PLS loading strength.
Separate visualisations are created for left and right hemispheres.
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
import nibabel as nib
from nilearn import plotting, image
from nilearn.image import coord_transform
import matplotlib.gridspec as gridspec

def get_roi_coordinates():
    """Load MNI co-ordinates for ROIs from CSV files"""
    df_left = pd.read_csv('desikan_left_centroids_mni.csv')
    df_right = pd.read_csv('desikan_right_centroids_mni.csv')
    df_subcortical = pd.read_csv('desikan_subcortical_centroids_mni.csv')
    
    roi_coords = {}
    
    for _, row in df_left.iterrows():
        roi_name = row['ROI_name'].replace('ctx-lh-', 'l-')
        roi_coords[roi_name] = [row['x'], row['y'], row['z']]
    
    for _, row in df_right.iterrows():
        roi_name = row['ROI_name'].replace('ctx-rh-', 'r-')
        roi_coords[roi_name] = [row['x'], row['y'], row['z']]
    
    for _, row in df_subcortical.iterrows():
        roi_name = row['ROI_name'].replace('Left-', 'l-').replace('Right-', 'r-')
        roi_coords[roi_name] = [row['x'], row['y'], row['z']]
    
    roi_coords['l-Cerebellum-Cortex'] = [-28, -60, -32]
    roi_coords['r-Cerebellum-Cortex'] = [28, -60, -32]
    
    return roi_coords

def get_vta_center_of_mass(vta_file):
    """Extract centre of mass from VTA NIfTI file"""
    vta_img = nib.load(vta_file)
    vta_data = vta_img.get_fdata()
    
    coords = np.where(vta_data > 0)
    if len(coords[0]) == 0:
        return None
    
    centre_voxel = [np.mean(coords[i]) for i in range(3)]
    centre_mni = coord_transform(centre_voxel[0], centre_voxel[1], centre_voxel[2], vta_img.affine)
    
    return centre_mni

def create_separate_hemisphere_plot():
    """
    Create glass brain plots showing VTA-ROI connectivity for both hemispheres.
    
    The plot shows:
    - Top 8 ROIs per hemisphere based on PLS Component 1 loadings
    - Connections from VTA centre to each ROI
    - Edge thickness/colour represents loading strength
    - Orange colourmap for left hemisphere, blue for right hemisphere
    """
    # Load PLS component data and select top 8 ROIs per hemisphere
    pls_data = pd.read_csv('component_1_sorted_both.csv')
    left_rois = pls_data[pls_data['name'].str.startswith('l-')].head(8)
    right_rois = pls_data[pls_data['name'].str.startswith('r-')].head(8)
    
    # Load VTA files and extract centre of mass co-ordinates
    vta_file_left = '../sweet_spot/nonweighted_sum_left.nii.gz'
    vta_file_right = '../sweet_spot/nonweighted_sum_right.nii.gz'
    vta_coord_left = get_vta_center_of_mass(vta_file_left)
    vta_coord_right = get_vta_center_of_mass(vta_file_right)
    
    # Load ROI co-ordinates from Desikan atlas
    roi_coordinates = get_roi_coordinates()
    
    # Create custom colourmaps: orange for left, blue for right hemisphere
    orange_cmap = LinearSegmentedColormap.from_list('orange', ['#FFD580', '#FF9933', '#E67300', '#993D00'], N=256)
    blue_cmap = LinearSegmentedColormap.from_list('blue', ['#D6E9FF', '#66B2FF', '#0073E6', '#003366'], N=256)
    
    # Setup figure: 2 rows (left/right), 4 columns (3 views + 1 colourbar)
    fig = plt.figure(figsize=(20, 16))
    gs = fig.add_gridspec(2, 4, width_ratios=[1, 1, 1, 0.15], hspace=0.4, wspace=0.1)
    
    views = ['x', 'y', 'z']
    left_titles = ['Left Hemisphere - X view', 'Left Hemisphere - Y view', 'Left Hemisphere - Z view']
    right_titles = ['Right Hemisphere - X view', 'Right Hemisphere - Y view', 'Right Hemisphere - Z view']
    left_cbar_data = None
    right_cbar_data = None
    
    # Plot left hemisphere (top row) - 3 orthogonal views
    for i, (view, title) in enumerate(zip(views, left_titles)):
        ax = fig.add_subplot(gs[0, i])
        
        # Prepare node co-ordinates: VTA centre + top 8 ROIs
        left_coords = [vta_coord_left]
        left_node_names = ['VTA_L']
        for _, roi in left_rois.iterrows():
            roi_name = roi['name']
            if roi_name in roi_coordinates:
                left_coords.append(roi_coordinates[roi_name])
                left_node_names.append(roi_name)
        
        left_coords = np.array(left_coords)
        n_left_nodes = len(left_coords)
        
        # Create adjacency matrix: connect VTA (node 0) to each ROI with loading strength
        left_adjacency = np.zeros((n_left_nodes, n_left_nodes))
        for j in range(1, n_left_nodes):
            roi_idx = j - 1
            loading_strength = abs(left_rois.iloc[roi_idx]['Comp 1'])
            left_adjacency[0, j] = loading_strength
            left_adjacency[j, 0] = loading_strength
        
        # Normalise loading values for colour scaling
        left_loadings = [abs(roi['Comp 1']) for _, roi in left_rois.iterrows()]
        left_min = np.percentile(left_loadings, 2) if len(left_loadings) > 0 else 0
        left_max = np.percentile(left_loadings, 98) if len(left_loadings) > 0 else 1
        
        # Set node colours and sizes: VTA in grey, ROIs in orange gradient
        left_node_colors = ['#808080']
        left_node_sizes = [150]
        for _, roi in left_rois.iterrows():
            loading_strength = abs(roi['Comp 1'])
            norm_strength = (loading_strength - left_min) / (left_max - left_min) if left_max > left_min else 0
            norm_strength = np.clip(norm_strength, 0, 1)
            color = orange_cmap(norm_strength)
            left_node_colors.append(color)
            left_node_sizes.append(80)
        
        # Scale edge colours based on loading strength
        left_values = left_adjacency[left_adjacency > 0]
        left_vmin = np.percentile(left_values, 2) if len(left_values) > 0 else 0
        left_vmax = np.percentile(left_values, 98) if len(left_values) > 0 else 1
        
        # Plot connections (edges)
        if np.any(left_adjacency > 0):
            plotting.plot_connectome(
                left_adjacency,
                left_coords,
                node_color='none',
                node_size=0,
                edge_cmap=orange_cmap,
                edge_vmin=left_vmin,
                edge_vmax=left_vmax,
                edge_threshold=0,
                edge_kwargs={'linewidth': 5},
                axes=ax,
                display_mode=view,
                colorbar=False
            )
            if i == 0:
                left_cbar_data = (left_values, orange_cmap, left_vmin, left_vmax)
        
        # Plot nodes (VTA and ROIs)
        plotting.plot_connectome(
            np.zeros_like(left_adjacency),
            left_coords,
            node_color=left_node_colors,
            node_size=left_node_sizes,
            axes=ax,
            display_mode=view,
            colorbar=False
        )
        
        ax.set_title(title, fontsize=12, fontweight='bold', y=1.05)
    
    # Plot right hemisphere (bottom row) - same process as left
    for i, (view, title) in enumerate(zip(views, right_titles)):
        ax = fig.add_subplot(gs[1, i])
        
        right_coords = [vta_coord_right]
        right_node_names = ['VTA_R']
        for _, roi in right_rois.iterrows():
            roi_name = roi['name']
            if roi_name in roi_coordinates:
                right_coords.append(roi_coordinates[roi_name])
                right_node_names.append(roi_name)
        
        right_coords = np.array(right_coords)
        n_right_nodes = len(right_coords)
        
        # Create adjacency matrix for right hemisphere
        right_adjacency = np.zeros((n_right_nodes, n_right_nodes))
        for j in range(1, n_right_nodes):
            roi_idx = j - 1
            loading_strength = abs(right_rois.iloc[roi_idx]['Comp 1'])
            right_adjacency[0, j] = loading_strength
            right_adjacency[j, 0] = loading_strength
        
        # Normalise loading values for colour scaling
        right_loadings = [abs(roi['Comp 1']) for _, roi in right_rois.iterrows()]
        right_min = np.percentile(right_loadings, 2) if len(right_loadings) > 0 else 0
        right_max = np.percentile(right_loadings, 98) if len(right_loadings) > 0 else 1
        
        # Set node colours: VTA in grey, ROIs in blue gradient
        right_node_colors = ['#808080']
        right_node_sizes = [150]
        for _, roi in right_rois.iterrows():
            loading_strength = abs(roi['Comp 1'])
            norm_strength = (loading_strength - right_min) / (right_max - right_min) if right_max > right_min else 0
            norm_strength = np.clip(norm_strength, 0, 1)
            color = blue_cmap(norm_strength)
            right_node_colors.append(color)
            right_node_sizes.append(80)
        
        # Scale edge colours
        right_values = right_adjacency[right_adjacency > 0]
        right_vmin = np.percentile(right_values, 2) if len(right_values) > 0 else 0
        right_vmax = np.percentile(right_values, 98) if len(right_values) > 0 else 1
        
        # Plot connections
        if np.any(right_adjacency > 0):
            plotting.plot_connectome(
                right_adjacency,
                right_coords,
                node_color='none',
                node_size=0,
                edge_cmap=blue_cmap,
                edge_vmin=right_vmin,
                edge_vmax=right_vmax,
                edge_threshold=0,
                edge_kwargs={'linewidth': 5},
                axes=ax,
                display_mode=view,
                colorbar=False
            )
            if i == 0:
                right_cbar_data = (right_values, blue_cmap, right_vmin, right_vmax)
        
        # Plot nodes
        plotting.plot_connectome(
            np.zeros_like(right_adjacency),
            right_coords,
            node_color=right_node_colors,
            node_size=right_node_sizes,
            axes=ax,
            display_mode=view,
            colorbar=False
        )
        
        if i >= 1:
            ax.set_title(title, fontsize=12, fontweight='bold', pad=20)
        else:
            ax.set_title(title, fontsize=12, fontweight='bold', y=1.05)
    
    # Add colourbars for both hemispheres
    if left_cbar_data is not None:
        cbar_ax_left = fig.add_subplot(gs[0, 3])
        left_values, left_cmap, left_vmin, left_vmax = left_cbar_data
        sm_left = plt.cm.ScalarMappable(cmap=left_cmap, norm=plt.Normalize(vmin=left_vmin, vmax=left_vmax))
        sm_left.set_array([])
        cbar_left = plt.colorbar(sm_left, cax=cbar_ax_left)
        cbar_left.set_label('Left Hemisphere\nPLS Loading', fontsize=10, fontweight='bold')
        cbar_left.ax.tick_params(labelsize=8)
        tick_values = np.linspace(left_vmin, left_vmax, 5)
        cbar_left.set_ticks(tick_values)
        cbar_left.set_ticklabels([f'{val:.3f}' for val in tick_values])
    
    if right_cbar_data is not None:
        cbar_ax_right = fig.add_subplot(gs[1, 3])
        right_values, right_cmap, right_vmin, right_vmax = right_cbar_data
        sm_right = plt.cm.ScalarMappable(cmap=right_cmap, norm=plt.Normalize(vmin=right_vmin, vmax=right_vmax))
        sm_right.set_array([])
        cbar_right = plt.colorbar(sm_right, cax=cbar_ax_right)
        cbar_right.set_label('Right Hemisphere\nPLS Loading', fontsize=10, fontweight='bold')
        cbar_right.ax.tick_params(labelsize=8)
        tick_values = np.linspace(right_vmin, right_vmax, 5)
        cbar_right.set_ticks(tick_values)
        cbar_right.set_ticklabels([f'{val:.3f}' for val in tick_values])
    
    # Add title and legend
    fig.suptitle('Component 1 Loadings: VTA-ROI Connectivity (Separate Hemispheres)', 
                 fontsize=16, fontweight='bold', y=0.95)
    
    legend_elements = [
        plt.Line2D([0], [0], marker='o', color='w', markerfacecolor='#808080', 
                  markersize=10, label='VTA Centers'),
        plt.Line2D([0], [0], marker='o', color='w', markerfacecolor='#FF9933', 
                  markersize=8, label='Left ROIs'),
        plt.Line2D([0], [0], marker='o', color='w', markerfacecolor='#66B2FF', 
                  markersize=8, label='Right ROIs')
    ]
    
    fig.legend(handles=legend_elements, loc='lower center', ncol=3, 
              bbox_to_anchor=(0.5, 0.02), fontsize=12)
    
    plt.tight_layout()
    plt.subplots_adjust(bottom=0.08)
    
    plt.savefig('component1_separate_hemispheres.png', dpi=300, bbox_inches='tight')
    plt.savefig('component1_separate_hemispheres.pdf', bbox_inches='tight')
    
    print("Plot saved: component1_separate_hemispheres.png/pdf")

if __name__ == "__main__":
    create_separate_hemisphere_plot()
