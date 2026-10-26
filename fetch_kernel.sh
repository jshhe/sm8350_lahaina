#!/usr/bin/env bash
set -e

BRANCH="${1:-oneplus/sm8350_u_14.0.0_oneplus9}"
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Fetching OnePlus 9 Pro Linux 5.4 Kernel sources..."
echo "Branch: $BRANCH"
echo "Target directory: $WORKDIR"

# 1. Clone kernel base
if [ ! -d "$WORKDIR/kernel/msm-5.4" ]; then
    echo "Cloning android_kernel_oneplus_sm8350..."
    git clone --depth=1 -b "$BRANCH" https://github.com/OnePlusOSS/android_kernel_oneplus_sm8350.git "$WORKDIR/kernel/msm-5.4"
else
    echo "kernel/msm-5.4 already exists, skipping."
fi

# 2. Clone modules & devicetree
if [ ! -d "$WORKDIR/modules_and_devicetree" ]; then
    echo "Cloning android_kernel_modules_and_devicetree_oneplus_sm8350..."
    git clone --depth=1 -b "$BRANCH" https://github.com/OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8350.git "$WORKDIR/modules_and_devicetree"
else
    echo "modules_and_devicetree already exists, skipping."
fi

echo "Done! Intermediate files and sources are located inside $WORKDIR."
