import os
import sys
import numpy as np
import pandas as pd
import bct

# Get command-line arguments
sub    = sys.argv[1]  # subject
vatdir = sys.argv[2]  # VAT directory containing probtrackx output

def symmetricize_matrix(M):
    M = M.copy()                        # Avoid modifying the original matrix
    zero_mask = (M == 0) | (M.T == 0)   # find zeroes in either of the two corresponding entries
    M_symmetric = (M + M.T) / 2         # average all entries with their symmetric counterpart
    M_symmetric[zero_mask] = 0          # set pairs with one zero both to zero

    return M_symmetric

def calc_metrics(sub, vatdir, l_thr=60, u_thr=80):
    """creates normalized matrices between user defined density limits"""
    """calculates degree/bc for each density and saves an array of these degrees per subject"""
    """default are 60th and 80th percentile = 20-40% density"""
    
    thresh_list = [i for i in range(l_thr, u_thr+1)]
    imgdir = "/home/armink/tremorDBS/imaging_tremorDBS"
    netfile = os.path.join(imgdir, sub, "diffusion", "stats", vatdir, "fdt_network_matrix")    
    wtfile  = os.path.join(imgdir, sub, "diffusion", "stats", vatdir, "waytotal")    
    outfile = os.path.join(imgdir, sub, "diffusion", "stats", vatdir, "network_metrics.csv")    

    m  = np.loadtxt(netfile)                         # load connectivities
    wt = np.loadtxt(wtfile)                          # load waytotals
    m = m / wt.reshape(-1,1)                         # normalize by waytotal per row
    m = symmetricize_matrix(m)                       # make matrix symmetric by averaging
    
    thresh_list = [i for i in range(l_thr, u_thr+1)]   # list of thresholds
    node_list   = [i for i in range(1, m.shape[0]+1)]  # list of nodes for output
    subdg = []; subbc = []; nodes = []; threshs = [];  # prepare output

    for thr in thresh_list:
       # calculate percentiles and binarize matrix based on threshold
        m_bin = np.where(m < np.percentile(m, int(thr)), 0, 1)   

        subdg.extend(bct.degrees_und(m_bin))     # calc and append degree
        subbc.extend(bct.betweenness_bin(m_bin)) # calc and append betweenness
        nodes.extend(node_list)
        threshs.extend([thr for _ in range(m.shape[0])])
       
   # save to file
    df = pd.DataFrame({'sub': sub, 'thresh': threshs, 'node': nodes, 'deg': subdg, 'bc': subbc})
    df.to_csv(outfile, index=False)
            

print(vatdir)
calc_metrics(sub, vatdir)
