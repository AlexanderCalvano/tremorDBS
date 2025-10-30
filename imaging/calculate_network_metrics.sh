#!/bin/bash

source ./tremorDBS/bin/activate
SUBDIR=$1

for vatdir in $(ls $SUBDIR/diffusion/stats); do
  python3 network_metrics.py $(basename $SUBDIR) $vatdir
done


