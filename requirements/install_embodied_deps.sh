#!/bin/bash

# Embodied dependencies
# Note: System package installation skipped (apt-get not available on this system)
# Ensure required system libraries are installed via your package manager if needed

# CRITICAL: Prevent Python from loading user site-packages to avoid conflicts
export PYTHONNOUSERSITE=1
# Remove Python 3.7 user site-packages from PYTHONPATH if present
export PYTHONPATH=$(echo $PYTHONPATH | tr ':' '\n' | grep -v "/home/kzy816/.local/lib/python3.7/site-packages" | tr '\n' ':' | sed 's/:$//')

# Disable SSL verification for downloads (common in HPC/cluster environments)
export CURL_CA_BUNDLE=""
export REQUESTS_CA_BUNDLE=""
export PYTHONHTTPSVERIFY=0

# Download ManiSkill assets (non-interactive)
echo "Downloading ManiSkill assets..."

# Try Python download first, with SSL verification disabled via wrapper
python -c "
import ssl
import sys
ssl._create_default_https_context = ssl._create_unverified_context
from mani_skill.utils.download_asset import main, parse_args
args = parse_args(['bridge_v2_real2sim', '-y'])
main(args)
" 2>&1 || {
    echo "Python download failed, trying direct download..."
    ASSET_URL="https://huggingface.co/datasets/haosulab/ManiSkill_bridge_v2_real2sim/resolve/main/bridge_v2_real2sim_dataset.zip"
    ASSET_ZIP="${MS_ASSET_DIR:-$HOME/.maniskill/data}/bridge_v2_real2sim_dataset.zip"
    mkdir -p "$(dirname "$ASSET_ZIP")"
    if command -v wget &> /dev/null; then
        wget --no-check-certificate -O "$ASSET_ZIP" "$ASSET_URL" 2>&1 && unzip -q -o "$ASSET_ZIP" -d "$(dirname "$ASSET_ZIP")" && rm -f "$ASSET_ZIP"
    elif command -v curl &> /dev/null; then
        curl -k -L -o "$ASSET_ZIP" "$ASSET_URL" 2>&1 && unzip -q -o "$ASSET_ZIP" -d "$(dirname "$ASSET_ZIP")" && rm -f "$ASSET_ZIP"
    fi
}

python -c "
import ssl
import sys
ssl._create_default_https_context = ssl._create_unverified_context
from mani_skill.utils.download_asset import main, parse_args
args = parse_args(['widowx250s', '-y'])
main(args)
" 2>&1 || {
    echo "Python download failed, trying direct download..."
    ROBOT_URL="https://github.com/haosulab/ManiSkill-WidowX250S/archive/refs/tags/v0.2.0.zip"
    ROBOT_ZIP="/tmp/widowx250s.zip"
    ROBOT_DIR="${MS_ROBOT_DIR:-$HOME/.maniskill/data/robots}"
    mkdir -p "$ROBOT_DIR"
    if command -v wget &> /dev/null; then
        wget --no-check-certificate -O "$ROBOT_ZIP" "$ROBOT_URL" 2>&1 && unzip -q -o "$ROBOT_ZIP" -d "$ROBOT_DIR" && rm -f "$ROBOT_ZIP"
    elif command -v curl &> /dev/null; then
        curl -k -L -o "$ROBOT_ZIP" "$ROBOT_URL" 2>&1 && unzip -q -o "$ROBOT_ZIP" -d "$ROBOT_DIR" && rm -f "$ROBOT_ZIP"
    fi
}

# Download PhysX library for SAPIEN
PHYSX_VERSION=105.1-physx-5.3.1.patch0
PHYSX_DIR=~/.sapien/physx/$PHYSX_VERSION
if [ ! -f "$PHYSX_DIR/libPhysXGpu_64.so" ]; then
    echo "Downloading PhysX library..."
    mkdir -p $PHYSX_DIR
    if command -v wget &> /dev/null; then
        wget --no-check-certificate -O $PHYSX_DIR/linux-so.zip https://github.com/sapien-sim/physx-precompiled/releases/download/$PHYSX_VERSION/linux-so.zip && \
        echo "A" | unzip -q -o $PHYSX_DIR/linux-so.zip -d $PHYSX_DIR 2>/dev/null || unzip -q -o $PHYSX_DIR/linux-so.zip -d $PHYSX_DIR && rm $PHYSX_DIR/linux-so.zip
    elif command -v curl &> /dev/null; then
        curl -k -L -o $PHYSX_DIR/linux-so.zip https://github.com/sapien-sim/physx-precompiled/releases/download/$PHYSX_VERSION/linux-so.zip && \
        echo "A" | unzip -q -o $PHYSX_DIR/linux-so.zip -d $PHYSX_DIR 2>/dev/null || unzip -q -o $PHYSX_DIR/linux-so.zip -d $PHYSX_DIR && rm $PHYSX_DIR/linux-so.zip
    else
        echo "Warning: Neither wget nor curl available, skipping PhysX download"
    fi
else
    echo "PhysX library already present"
fi


