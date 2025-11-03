#!/bin/bash
while IFS=$' ' read IDX HOUR CORE MEM CFG_NAME
do
STD_OUTPUT_FILE="/projects/p30309/RL/RLinf/script/clusters/std_output/${IDX}.log"

JOB=`sbatch << EOJ
#!/bin/bash
#SBATCH -J ${IDX}
#SBATCH -A p30309
#SBATCH -p gengpu
#SBATCH -t ${HOUR}:59:59
#SBATCH --gres=gpu:2
#SBATCH --mem=${MEM}G
#SBATCH --cpus-per-task=${CORE}
#SBATCH --output=${STD_OUTPUT_FILE}
#SBATCH --mail-type=BEGIN,FAIL,END,REQUEUE #BEGIN,END,FAIL,REQUEUE
#SBATCH --mail-user=zkghhg@gmail.com

#Delete any preceding space after 'EOJ'. OW, there will be some error.

# unload any modules that carried over from your command line session
module purge

# Set your working directory
cd /projects/p30309/RL/RLinf/   #$PBS_O_WORKDIR

# load modules you need to use
# module load python/anaconda3.6

conda init bash

which conda

source .venv/bin/activate

# Prevent Python from loading user site-packages to avoid conflicts
export PYTHONNOUSERSITE=1
# Remove Python 3.7 user site-packages from PYTHONPATH if present
export PYTHONPATH=$(echo $PYTHONPATH | tr ':' '\n' | grep -v "/home/kzy816/.local/lib/python3.7/site-packages" | tr '\n' ':' | sed 's/:$//')

# Download ManiSkill assets if not already present (non-interactive mode)
# Ensure HOME is set (batch jobs may not have it)
export HOME=\${HOME:-/home/kzy816}

# Use absolute path for ManiSkill assets directory
# Create directory using absolute path directly to avoid variable expansion issues
mkdir -p /home/kzy816/.maniskill/data/tasks
if [ ! -d /home/kzy816/.maniskill/data/tasks ]; then
    echo "ERROR: Could not create asset directory: /home/kzy816/.maniskill/data/tasks"
    exit 1
fi
# MS_ASSET_DIR should point to the base .maniskill directory, not data/tasks
# ManiSkill will append /data/tasks automatically
export MS_ASSET_DIR="/home/kzy816/.maniskill"

# Verify MS_ASSET_DIR is set correctly
echo "MS_ASSET_DIR is set to: /home/kzy816/.maniskill"
echo "Expected asset path will be: /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset"

# Verify asset directory structure  
ASSET_DIR="/home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset"
REQUIRED_FILE="/home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset/custom/info_bridge_custom_v0.json"

echo "ASSET_DIR: \${ASSET_DIR}"
echo "REQUIRED_FILE: \${REQUIRED_FILE}"

if [ ! -f /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset/custom/info_bridge_custom_v0.json ]; then
    echo "ManiSkill assets missing or incomplete, attempting to download..."
    
    # Clean up partial downloads
    [ -d /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset ] && rm -rf /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset
    
    # Disable SSL verification for downloads (common in HPC environments)
    export CURL_CA_BUNDLE=""
    export REQUESTS_CA_BUNDLE=""
    
    # Try downloading with timeout and better error handling
    # Python download often fails in HPC due to SSL issues, so we'll try it but quickly fallback
    echo "Attempting Python-based download..."
    timeout 120 python -m mani_skill.utils.download_asset bridge_v2_real2sim -y 2>&1 || {
        echo "Python download failed, trying direct download..."
        # Alternative: download directly from Hugging Face
        ASSET_URL="https://huggingface.co/datasets/haosulab/ManiSkill_bridge_v2_real2sim/resolve/main/bridge_v2_real2sim_dataset.zip"
        ASSET_ZIP="/home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset.zip"
        
        echo "Download URL: https://huggingface.co/datasets/haosulab/ManiSkill_bridge_v2_real2sim/resolve/main/bridge_v2_real2sim_dataset.zip"
        echo "Download destination: /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset.zip"
        
        # Ensure directory exists before downloading
        mkdir -p /home/kzy816/.maniskill/data/tasks
        
        if command -v wget &> /dev/null; then
            echo "Attempting wget download..."
            wget --no-check-certificate --timeout=30 --tries=3 --progress=bar:force "https://huggingface.co/datasets/haosulab/ManiSkill_bridge_v2_real2sim/resolve/main/bridge_v2_real2sim_dataset.zip" -O "/home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset.zip" 2>&1
            WGET_EXIT=\$?
            # Check if file exists and has reasonable size (> 10MB)
            if [ -f /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset.zip ]; then
                FILE_SIZE=\$(stat -c%s /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset.zip 2>/dev/null || echo 0)
                if [ "\${FILE_SIZE}" -gt 10485760 ]; then
                    echo "Download completed, file size: \$(du -h /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset.zip | cut -f1)"
                    echo "Extracting..."
                    unzip -q /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset.zip -d /home/kzy816/.maniskill/data/tasks
                    if [ \$? -eq 0 ]; then
                        rm -f /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset.zip
                        echo "Direct download successful via wget"
                    else
                        echo "ERROR: Extraction failed"
                    fi
                else
                    echo "ERROR: Downloaded file is too small (\${FILE_SIZE} bytes), download may have failed"
                    rm -f /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset.zip
                fi
            else
                echo "ERROR: wget download failed (exit code: \${WGET_EXIT})"
                echo "No file was downloaded - checking network connectivity..."
                if ping -c 1 huggingface.co > /dev/null 2>&1; then
                    echo "Network is reachable, but download failed"
                else
                    echo "Network connectivity issue - huggingface.co is not reachable"
                fi
            fi
        elif command -v curl &> /dev/null; then
            echo "Attempting curl download..."
            curl -k -L --connect-timeout 30 --max-time 600 --progress-bar "https://huggingface.co/datasets/haosulab/ManiSkill_bridge_v2_real2sim/resolve/main/bridge_v2_real2sim_dataset.zip" -o "/home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset.zip" 2>&1
            CURL_EXIT=\$?
            # Check if file exists and has reasonable size (> 10MB)
            if [ -f /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset.zip ]; then
                FILE_SIZE=\$(stat -c%s /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset.zip 2>/dev/null || echo 0)
                if [ "\${FILE_SIZE}" -gt 10485760 ]; then
                    echo "Download completed, file size: \$(du -h /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset.zip | cut -f1)"
                    echo "Extracting..."
                    unzip -q /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset.zip -d /home/kzy816/.maniskill/data/tasks
                    if [ \$? -eq 0 ]; then
                        rm -f /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset.zip
                        echo "Direct download successful via curl"
                    else
                        echo "ERROR: Extraction failed"
                    fi
                else
                    echo "ERROR: Downloaded file is too small (\${FILE_SIZE} bytes), download may have failed"
                    rm -f /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset.zip
                fi
            else
                echo "ERROR: curl download failed (exit code: \${CURL_EXIT})"
                echo "No file was downloaded - checking network connectivity..."
                if ping -c 1 huggingface.co > /dev/null 2>&1 || curl -k -s --connect-timeout 5 https://huggingface.co > /dev/null 2>&1; then
                    echo "Network is reachable, but download failed"
                else
                    echo "Network connectivity issue - huggingface.co is not reachable"
                fi
            fi
        else
            echo "ERROR: Neither wget nor curl available, and Python download failed"
            echo "Please pre-download assets or ensure network connectivity"
            exit 1
        fi
    }
    
    # Verify the asset was downloaded correctly
    echo "Checking for required file: /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset/custom/info_bridge_custom_v0.json"
    if [ -f /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset/custom/info_bridge_custom_v0.json ]; then
        echo "Asset download verified successfully"
    else
        echo "ERROR: Asset download incomplete"
        echo "Expected file: /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset/custom/info_bridge_custom_v0.json"
        echo "ASSET_DIR exists: $([ -d /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset ] && echo "yes" || echo "no")"
        if [ -d /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset ]; then
            echo "Contents of ASSET_DIR:"
            ls -la /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset | head -20
        fi
        echo "Please check network connectivity or manually download assets"
        echo "You can download manually with:"
        echo "  export MS_ASSET_DIR=/home/kzy816/.maniskill"
        echo "  python -m mani_skill.utils.download_asset bridge_v2_real2sim -y"
        exit 1
    fi
else
    echo "ManiSkill assets already present and verified at /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset"
fi

# Download robot assets (widowx250s) if not present
ROBOT_ASSET_DIR="/home/kzy816/.maniskill/data/robots/widowx"
ROBOT_URDF="/home/kzy816/.maniskill/data/robots/widowx/wx250s.urdf"
if [ ! -f /home/kzy816/.maniskill/data/robots/widowx/wx250s.urdf ]; then
    echo "Robot assets (widowx250s) missing, attempting to download..."
    export CURL_CA_BUNDLE=""
    export REQUESTS_CA_BUNDLE=""
    
    # Try Python download first (with timeout to quickly fallback if SSL fails)
    timeout 120 python -m mani_skill.utils.download_asset widowx250s -y 2>&1 || {
        echo "Python download failed, trying direct download..."
        # Download directly from GitHub with SSL verification disabled
        ROBOT_URL="https://github.com/haosulab/ManiSkill-WidowX250S/archive/refs/tags/v0.2.0.zip"
        ROBOT_ZIP="/tmp/widowx250s.zip"
        ROBOT_EXTRACT_DIR="/home/kzy816/.maniskill/data/robots"
        
        # Ensure directory exists
        mkdir -p /home/kzy816/.maniskill/data/robots
        
        if command -v wget &> /dev/null; then
            echo "Attempting wget download of robot assets..."
            wget --no-check-certificate --timeout=30 --tries=3 --progress=bar:force "\${ROBOT_URL}" -O "\${ROBOT_ZIP}" 2>&1
            if [ -f "\${ROBOT_ZIP}" ]; then
                FILE_SIZE=\$(stat -c%s "\${ROBOT_ZIP}" 2>/dev/null || echo 0)
                if [ "\${FILE_SIZE}" -gt 1048576 ]; then
                    echo "Download completed, extracting..."
                    TEMP_EXTRACT="/tmp/widowx_extract"
                    mkdir -p "\${TEMP_EXTRACT}"
                    unzip -q "\${ROBOT_ZIP}" -d "\${TEMP_EXTRACT}"
                    if [ $? -eq 0 ]; then
                        # Find and move the widowx directory to correct location
                        if [ -d "\${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0/widowx" ]; then
                            mkdir -p "\${ROBOT_EXTRACT_DIR}"
                            mv "\${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0/widowx" "\${ROBOT_EXTRACT_DIR}/"
                        elif [ -d "\${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0" ]; then
                            # If the widowx folder is at root of extracted archive
                            mkdir -p "\${ROBOT_EXTRACT_DIR}"
                            if [ -f "\${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0/wx250s.urdf" ]; then
                                mkdir -p "\${ROBOT_EXTRACT_DIR}/widowx"
                                mv "\${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0"/* "\${ROBOT_EXTRACT_DIR}/widowx/"
                            else
                                mv "\${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0" "\${ROBOT_EXTRACT_DIR}/widowx"
                            fi
                        fi
                        rm -rf "\${TEMP_EXTRACT}" "\${ROBOT_ZIP}"
                        echo "Robot assets downloaded successfully via wget"
                    else
                        echo "ERROR: Extraction failed"
                        rm -rf "\${TEMP_EXTRACT}" "\${ROBOT_ZIP}"
                    fi
                else
                    echo "ERROR: Downloaded file is too small"
                    rm -f "\${ROBOT_ZIP}"
                fi
            else
                echo "ERROR: wget download failed"
            fi
        elif command -v curl &> /dev/null; then
            echo "Attempting curl download of robot assets..."
            curl -k -L --connect-timeout 30 --max-time 600 --progress-bar "\${ROBOT_URL}" -o "\${ROBOT_ZIP}" 2>&1
            if [ -f "\${ROBOT_ZIP}" ]; then
                FILE_SIZE=\$(stat -c%s "\${ROBOT_ZIP}" 2>/dev/null || echo 0)
                if [ "\${FILE_SIZE}" -gt 1048576 ]; then
                    echo "Download completed, extracting..."
                    TEMP_EXTRACT="/tmp/widowx_extract"
                    mkdir -p "\${TEMP_EXTRACT}"
                    unzip -q "\${ROBOT_ZIP}" -d "\${TEMP_EXTRACT}"
                    if [ $? -eq 0 ]; then
                        # Find and move the widowx directory to correct location
                        if [ -d "\${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0/widowx" ]; then
                            mkdir -p "\${ROBOT_EXTRACT_DIR}"
                            mv "\${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0/widowx" "\${ROBOT_EXTRACT_DIR}/"
                        elif [ -d "\${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0" ]; then
                            # If the widowx folder is at root of extracted archive
                            mkdir -p "\${ROBOT_EXTRACT_DIR}"
                            if [ -f "\${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0/wx250s.urdf" ]; then
                                mkdir -p "\${ROBOT_EXTRACT_DIR}/widowx"
                                mv "\${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0"/* "\${ROBOT_EXTRACT_DIR}/widowx/"
                            else
                                mv "\${TEMP_EXTRACT}/ManiSkill-WidowX250S-0.2.0" "\${ROBOT_EXTRACT_DIR}/widowx"
                            fi
                        fi
                        rm -rf "\${TEMP_EXTRACT}" "\${ROBOT_ZIP}"
                        echo "Robot assets downloaded successfully via curl"
                    else
                        echo "ERROR: Extraction failed"
                        rm -rf "\${TEMP_EXTRACT}" "\${ROBOT_ZIP}"
                    fi
                else
                    echo "ERROR: Downloaded file is too small"
                    rm -f "\${ROBOT_ZIP}"
                fi
            else
                echo "ERROR: curl download failed"
            fi
        else
            echo "ERROR: Neither wget nor curl available, and Python download failed"
            echo "Please pre-download robot assets manually"
        fi
    }
    
    # Verify the robot asset was downloaded
    if [ -f /home/kzy816/.maniskill/data/robots/widowx/wx250s.urdf ]; then
        echo "Robot assets (widowx250s) downloaded and verified successfully"
    else
        echo "WARNING: Robot asset download may have failed"
        echo "Expected file: /home/kzy816/.maniskill/data/robots/widowx/wx250s.urdf"
        if [ -d /home/kzy816/.maniskill/data/robots/widowx ]; then
            echo "Contents of robot directory:"
            ls -la /home/kzy816/.maniskill/data/robots/widowx/ | head -10
        fi
    fi
else
    echo "Robot assets (widowx250s) already present at /home/kzy816/.maniskill/data/robots/widowx/wx250s.urdf"
fi

export LD_LIBRARY_PATH="/home/kzy816/.mujoco/mujoco210/bin:/usr/lib/nvidia:\$LD_LIBRARY_PATH"

# GPU rendering support (needed for ManiSkill/SAPIEN rendering)
export NVIDIA_DRIVER_CAPABILITIES="all"
export MUJOCO_GL="egl"
export PYOPENGL_PLATFORM="egl"

# Suppress TensorFlow GPU warnings (TensorFlow is not used for computation)
# Level 3 suppresses all warnings except fatal errors
export TF_CPP_MIN_LOG_LEVEL=3

# Suppress cuDNN/cuFFT/cuBLAS factory registration warnings
export TF_XLA_FLAGS="--tf_xla_cpu_global_jit=false"

export DPPO_DATA_DIR="/projects/p30309/RL/RLinf/data"
export DPPO_LOG_DIR="/projects/p30309/RL/RLinf/log"

echo "=== Debug LD_LIBRARY_PATH ==="
echo "LD_LIBRARY_PATH: \$LD_LIBRARY_PATH"
echo "Python path: \$(which python)"

# # A command you actually want to execute:
# java -jar <someinput> <someoutput>
# # Another command you actually want to execute, if needed:
# python myscript.py

which python

bash examples/embodiment/run_embodiment.sh ${CFG_NAME}

EOJ
`

# print out the job id for reference later
echo "JobID = ${JOB} for indices ${IDX} and parameters ${CFG_NAME} submitted on `date`"

sleep 0.5

done < /projects/p30309/RL/RLinf/script/clusters/quest/param.info
# done < ./command_script/param_unet_exp.info
# done < ./command_script/param_trex_online.info
# done < ./command_script/param_ar_lin_2d.info
exit

# make this file executable and then run from the command line
# chmod u+x submit.sh
# ./submit.sh
# The last line of params.txt have to be an empty line.
