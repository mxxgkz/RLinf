#!/bin/bash
# Setup script for embodiment training environment
# This script handles venv detection, activation, environment setup, and asset downloads
# Called from ft_batch.sh to avoid heredoc variable expansion issues

set -e  # Exit on error

REPO_DIR="${1:-/projects/p30309/RL/RLinf}"
HOME_DIR="${2:-/home/kzy816}"

# Change to repository directory
cd "${REPO_DIR}" || {
    echo "ERROR: Failed to change directory to ${REPO_DIR}"
    exit 1
}

# Detect and activate the correct venv
# Try to find the venv based on common patterns or use .venv as default
VENV_PATH=""
if [ -d "${REPO_DIR}/.venv-openvla-oft-behavior" ]; then
    VENV_PATH="${REPO_DIR}/.venv-openvla-oft-behavior"
elif [ -d "${REPO_DIR}/.venv-openvla-oft" ]; then
    VENV_PATH="${REPO_DIR}/.venv-openvla-oft"
elif [ -d "${REPO_DIR}/.venv-openvla" ]; then
    VENV_PATH="${REPO_DIR}/.venv-openvla"
elif [ -d "${REPO_DIR}/.venv-openpi" ]; then
    VENV_PATH="${REPO_DIR}/.venv-openpi"
elif [ -d "${REPO_DIR}/.venv" ]; then
    VENV_PATH="${REPO_DIR}/.venv"
else
    echo "ERROR: No virtual environment found in ${REPO_DIR}"
    echo "Available venv directories:"
    ls -d ${REPO_DIR}/.venv* 2>/dev/null || echo "None found"
    exit 1
fi

# Verify VENV_PATH is actually set
if [ -z "${VENV_PATH}" ]; then
    echo "ERROR: VENV_PATH is empty after detection"
    exit 1
fi

# Verify venv has activate script
ACTIVATE_SCRIPT="${VENV_PATH}/bin/activate"
if [ ! -f "${ACTIVATE_SCRIPT}" ]; then
    echo "ERROR: Virtual environment activate script not found: ${ACTIVATE_SCRIPT}"
    exit 1
fi

# Activate the venv
source "${ACTIVATE_SCRIPT}"

# Verify activation succeeded
if [ -z "${VIRTUAL_ENV:-}" ]; then
    echo "ERROR: Failed to activate virtual environment"
    exit 1
fi

VENV_ABS_PATH="${VENV_PATH}"
echo "Activated virtual environment: ${VENV_ABS_PATH}"

# Get Python version and interpreter path
PYTHON_EXE=$(which python)
if [ -z "${PYTHON_EXE:-}" ]; then
    echo "ERROR: Python not found in PATH after venv activation"
    exit 1
fi

PYTHON_VER=$(python -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
VENV_SITE_PACKAGES="${VENV_ABS_PATH}/lib/python${PYTHON_VER}/site-packages"

# Set Python and Ray environment variables (critical for multiprocessing spawn)
export PYTHON="${PYTHON_EXE}"
export RAY_PYTHON="${PYTHON_EXE}"
export VIRTUAL_ENV="${VENV_ABS_PATH}"

# Set PYTHONPATH: venv site-packages first (Ray needs this to find worker files)
# Remove Python 3.7 user site-packages if present
PYTHONPATH_CLEAN=$(echo $PYTHONPATH | tr ':' '\n' | grep -v "/home/kzy816/.local/lib/python3.7/site-packages" | tr '\n' ':' | sed 's/:$//')
export PYTHONPATH="${VENV_SITE_PACKAGES}:${PYTHONPATH_CLEAN}"

# Prevent Python from loading user site-packages to avoid conflicts
export PYTHONNOUSERSITE=1

echo "Using Python: ${PYTHON}"
echo "Python executable: ${PYTHON_EXE}"
echo "Virtual environment: ${VIRTUAL_ENV}"

# Set HOME if not set
export HOME="${HOME:-${HOME_DIR}}"

# Setup ManiSkill assets directory
MS_ASSET_BASE="${HOME_DIR}/.maniskill"
MS_ASSET_DIR="${MS_ASSET_BASE}/data/tasks"
MS_ROBOT_DIR="${MS_ASSET_BASE}/data/robots"

mkdir -p "${MS_ASSET_DIR}"
if [ ! -d "${MS_ASSET_DIR}" ]; then
    echo "ERROR: Could not create asset directory: ${MS_ASSET_DIR}"
    exit 1
fi

# MS_ASSET_DIR should point to the base .maniskill directory, not data/tasks
# ManiSkill will append /data/tasks automatically
export MS_ASSET_DIR="${MS_ASSET_BASE}"

echo "MS_ASSET_DIR is set to: ${MS_ASSET_DIR}"
echo "Expected asset path will be: ${MS_ASSET_BASE}/data/tasks/bridge_v2_real2sim_dataset"

# Verify asset directory structure
ASSET_DIR="${MS_ASSET_BASE}/data/tasks/bridge_v2_real2sim_dataset"
REQUIRED_FILE="${ASSET_DIR}/custom/info_bridge_custom_v0.json"

echo "ASSET_DIR: ${ASSET_DIR}"
echo "REQUIRED_FILE: ${REQUIRED_FILE}"

# Download ManiSkill assets if not already present
if [ ! -f "${REQUIRED_FILE}" ]; then
    echo "ManiSkill assets missing or incomplete, attempting to download..."
    
    # Clean up partial downloads
    [ -d "${ASSET_DIR}" ] && rm -rf "${ASSET_DIR}"
    
    # Disable SSL verification for downloads (common in HPC environments)
    export CURL_CA_BUNDLE=""
    export REQUESTS_CA_BUNDLE=""
    
    # Try downloading with timeout and better error handling
    echo "Attempting Python-based download..."
    timeout 120 python -m mani_skill.utils.download_asset bridge_v2_real2sim -y 2>&1 || {
        echo "Python download failed, trying direct download..."
        ASSET_URL="https://huggingface.co/datasets/haosulab/ManiSkill_bridge_v2_real2sim/resolve/main/bridge_v2_real2sim_dataset.zip"
        ASSET_ZIP="${MS_ASSET_DIR}/bridge_v2_real2sim_dataset.zip"
        
        echo "Download URL: ${ASSET_URL}"
        echo "Download destination: ${ASSET_ZIP}"
        
        mkdir -p "${MS_ASSET_DIR}"
        
        if command -v wget &> /dev/null; then
            echo "Attempting wget download..."
            wget --no-check-certificate --timeout=30 --tries=3 --progress=bar:force "${ASSET_URL}" -O "${ASSET_ZIP}" 2>&1
            WGET_EXIT=$?
            if [ -f "${ASSET_ZIP}" ]; then
                FILE_SIZE=$(stat -c%s "${ASSET_ZIP}" 2>/dev/null || echo 0)
                if [ "${FILE_SIZE}" -gt 10485760 ]; then
                    echo "Download completed, file size: $(du -h ${ASSET_ZIP} | cut -f1)"
                    echo "Extracting..."
                    unzip -q -o "${ASSET_ZIP}" -d "${MS_ASSET_DIR}"
                    if [ $? -eq 0 ]; then
                        rm -f "${ASSET_ZIP}"
                        echo "Direct download successful via wget"
                    else
                        echo "ERROR: Extraction failed"
                    fi
                else
                    echo "ERROR: Downloaded file is too small (${FILE_SIZE} bytes)"
                    rm -f "${ASSET_ZIP}"
                fi
            else
                echo "ERROR: wget download failed (exit code: ${WGET_EXIT})"
            fi
        elif command -v curl &> /dev/null; then
            echo "Attempting curl download..."
            curl -k -L --connect-timeout 30 --max-time 600 --progress-bar "${ASSET_URL}" -o "${ASSET_ZIP}" 2>&1
            CURL_EXIT=$?
            if [ -f "${ASSET_ZIP}" ]; then
                FILE_SIZE=$(stat -c%s "${ASSET_ZIP}" 2>/dev/null || echo 0)
                if [ "${FILE_SIZE}" -gt 10485760 ]; then
                    echo "Download completed, file size: $(du -h ${ASSET_ZIP} | cut -f1)"
                    echo "Extracting..."
                    unzip -q -o "${ASSET_ZIP}" -d "${MS_ASSET_DIR}"
                    if [ $? -eq 0 ]; then
                        rm -f "${ASSET_ZIP}"
                        echo "Direct download successful via curl"
                    else
                        echo "ERROR: Extraction failed"
                    fi
                else
                    echo "ERROR: Downloaded file is too small (${FILE_SIZE} bytes)"
                    rm -f "${ASSET_ZIP}"
                fi
            else
                echo "ERROR: curl download failed (exit code: ${CURL_EXIT})"
            fi
        else
            echo "ERROR: Neither wget nor curl available, and Python download failed"
            exit 1
        fi
    }
    
    # Verify the asset was downloaded correctly
    if [ ! -f "${REQUIRED_FILE}" ]; then
        echo "ERROR: Asset download incomplete"
        echo "Expected file: ${REQUIRED_FILE}"
        exit 1
    fi
    echo "Asset download verified successfully"
else
    echo "ManiSkill assets already present and verified at ${ASSET_DIR}"
fi

# Download robot assets (widowx250s) if not present
ROBOT_URDF="${MS_ROBOT_DIR}/widowx/wx250s.urdf"
if [ ! -f "${ROBOT_URDF}" ]; then
    echo "Robot assets (widowx250s) missing, attempting to download..."
    export CURL_CA_BUNDLE=""
    export REQUESTS_CA_BUNDLE=""
    
    timeout 120 python -m mani_skill.utils.download_asset widowx250s -y 2>&1 || {
        echo "Python download failed, trying direct download..."
        ROBOT_URL="https://github.com/haosulab/ManiSkill-WidowX250S/archive/refs/tags/v0.2.0.zip"
        ROBOT_ZIP="/tmp/widowx250s.zip"
        ROBOT_EXTRACT_DIR="${MS_ROBOT_DIR}"
        
        mkdir -p "${MS_ROBOT_DIR}"
        
        if command -v wget &> /dev/null; then
            echo "Attempting wget download of robot assets..."
            wget --no-check-certificate --timeout=30 --tries=3 --progress=bar:force "${ROBOT_URL}" -O "${ROBOT_ZIP}" 2>&1
            if [ -f "${ROBOT_ZIP}" ]; then
                FILE_SIZE=$(stat -c%s "${ROBOT_ZIP}" 2>/dev/null || echo 0)
                if [ "${FILE_SIZE}" -gt 1048576 ]; then
                    echo "Download completed, extracting..."
                    TEMP_EXTRACT="/tmp/widowx_extract"
                    mkdir -p "${TEMP_EXTRACT}"
                    unzip -q -o "${ROBOT_ZIP}" -d "${TEMP_EXTRACT}"
                    if [ $? -eq 0 ]; then
                        if [ -d "${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0/widowx" ]; then
                            mkdir -p "${ROBOT_EXTRACT_DIR}"
                            mv "${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0/widowx" "${ROBOT_EXTRACT_DIR}/"
                        elif [ -f "${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0/wx250s.urdf" ]; then
                            mkdir -p "${ROBOT_EXTRACT_DIR}/widowx"
                            mv "${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0"/* "${ROBOT_EXTRACT_DIR}/widowx/"
                        fi
                        rm -rf "${TEMP_EXTRACT}" "${ROBOT_ZIP}"
                        echo "Robot assets downloaded successfully via wget"
                    else
                        echo "ERROR: Extraction failed"
                        rm -rf "${TEMP_EXTRACT}" "${ROBOT_ZIP}"
                    fi
                else
                    echo "ERROR: Downloaded file is too small"
                    rm -f "${ROBOT_ZIP}"
                fi
            else
                echo "ERROR: wget download failed"
            fi
        elif command -v curl &> /dev/null; then
            echo "Attempting curl download of robot assets..."
            curl -k -L --connect-timeout 30 --max-time 600 --progress-bar "${ROBOT_URL}" -o "${ROBOT_ZIP}" 2>&1
            if [ -f "${ROBOT_ZIP}" ]; then
                FILE_SIZE=$(stat -c%s "${ROBOT_ZIP}" 2>/dev/null || echo 0)
                if [ "${FILE_SIZE}" -gt 1048576 ]; then
                    echo "Download completed, extracting..."
                    TEMP_EXTRACT="/tmp/widowx_extract"
                    mkdir -p "${TEMP_EXTRACT}"
                    unzip -q -o "${ROBOT_ZIP}" -d "${TEMP_EXTRACT}"
                    if [ $? -eq 0 ]; then
                        if [ -d "${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0/widowx" ]; then
                            mkdir -p "${ROBOT_EXTRACT_DIR}"
                            mv "${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0/widowx" "${ROBOT_EXTRACT_DIR}/"
                        elif [ -f "${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0/wx250s.urdf" ]; then
                            mkdir -p "${ROBOT_EXTRACT_DIR}/widowx"
                            mv "${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0"/* "${ROBOT_EXTRACT_DIR}/widowx/"
                        fi
                        rm -rf "${TEMP_EXTRACT}" "${ROBOT_ZIP}"
                        echo "Robot assets downloaded successfully via curl"
                    else
                        echo "ERROR: Extraction failed"
                        rm -rf "${TEMP_EXTRACT}" "${ROBOT_ZIP}"
                    fi
                else
                    echo "ERROR: Downloaded file is too small"
                    rm -f "${ROBOT_ZIP}"
                fi
            else
                echo "ERROR: curl download failed"
            fi
        fi
    }
    
    if [ -f "${ROBOT_URDF}" ]; then
        echo "Robot assets (widowx250s) downloaded and verified successfully"
    else
        echo "WARNING: Robot asset download may have failed"
        echo "Expected file: ${ROBOT_URDF}"
    fi
else
    echo "Robot assets (widowx250s) already present at ${ROBOT_URDF}"
fi
