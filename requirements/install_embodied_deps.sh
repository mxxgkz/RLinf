#!/bin/bash

# Embodied dependencies
# Note: System package installation skipped (apt-get not available on this system)
# Ensure required system libraries are installed via your package manager if needed

# CRITICAL: Prevent Python from loading user site-packages to avoid conflicts
export PYTHONNOUSERSITE=1
# Remove Python 3.7 user site-packages from PYTHONPATH if present
export PYTHONPATH=$(echo $PYTHONPATH | tr ':' '\n' | grep -v "/home/kzy816/.local/lib/python3.7/site-packages" | tr '\n' ':' | sed 's/:$//')

# Download ManiSkill assets (non-interactive)
echo "Downloading ManiSkill assets..."
python -m mani_skill.utils.download_asset bridge_v2_real2sim -y 2>&1 || echo "Warning: bridge_v2_real2sim download failed (may already exist)"
python -m mani_skill.utils.download_asset widowx250s -y 2>&1 || echo "Warning: widowx250s download failed (may already exist)"

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


