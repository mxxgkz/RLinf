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
#SBATCH --mail-type=BEGIN,FAIL,END,REQUEUE
#SBATCH --mail-user=zkghhg@gmail.com

# Setup environment
module purge
cd /projects/p30309/RL/RLinf/
conda init bash > /dev/null 2>&1
source .venv/bin/activate

# Python environment cleanup
export PYTHONNOUSERSITE=1
export PYTHONPATH=\$(echo \$PYTHONPATH | tr ':' '\n' | grep -v "/home/kzy816/.local/lib/python3.7/site-packages" | tr '\n' ':' | sed 's/:$//')

# Setup paths and directories
export HOME=\${HOME:-/home/kzy816}
export MS_ASSET_DIR="/home/kzy816/.maniskill"
mkdir -p /home/kzy816/.maniskill/data/{tasks,robots}

# Disable SSL verification for HPC environments
export CURL_CA_BUNDLE=""
export REQUESTS_CA_BUNDLE=""

# Helper function to download asset with fallback
download_asset() {
    local asset_name=\$1
    local check_file=\$2
    local download_url=\$3
    local extract_to=\$4
    
    if [ -f "\$check_file" ]; then
        echo "Assets for \$asset_name already present"
        return 0
    fi
    
    echo "Downloading \$asset_name assets..."
    timeout 120 python -m mani_skill.utils.download_asset \$asset_name -y >/dev/null 2>&1 || {
        local zip_file="/tmp/\${asset_name}.zip"
        local temp_extract="/tmp/\${asset_name}_extract"
        
        # Download with wget or curl
        if command -v wget &> /dev/null; then
            wget --no-check-certificate --timeout=30 --tries=3 -q "\$download_url" -O "\$zip_file" || return 1
        elif command -v curl &> /dev/null; then
            curl -k -L --connect-timeout 30 --max-time 600 -s "\$download_url" -o "\$zip_file" || return 1
        else
            echo "ERROR: No download tool available"
            return 1
        fi
        
        # Verify file size (> 1MB)
        [ \$(stat -c%s "\$zip_file" 2>/dev/null || echo 0) -lt 1048576 ] && { rm -f "\$zip_file"; return 1; }
        
        # Extract to temp directory
        mkdir -p "\$temp_extract"
        unzip -q "\$zip_file" -d "\$temp_extract" || { rm -rf "\$temp_extract" "\$zip_file"; return 1; }
        
        # Handle different archive structures
        local extracted_dir=\$(find "\$temp_extract" -maxdepth 1 -type d ! -path "\$temp_extract" | head -1)
        if [ -n "\$extracted_dir" ]; then
            if [ "\$asset_name" = "widowx250s" ]; then
                # For robot assets: look for widowx subdirectory or move contents
                if [ -d "\$extracted_dir/widowx" ]; then
                    mv "\$extracted_dir/widowx" "\$extract_to/"
                elif [ -f "\$extracted_dir/wx250s.urdf" ]; then
                    mkdir -p "\$extract_to/widowx"
                    mv "\$extracted_dir"/* "\$extract_to/widowx/"
                fi
            else
                # For dataset assets: extract directly
                unzip -q "\$zip_file" -d "\$extract_to"
            fi
        fi
        
        rm -rf "\$temp_extract" "\$zip_file"
    }
    
    [ -f "\$check_file" ] && echo "✓ \$asset_name downloaded successfully" || echo "⚠ Warning: \$asset_name may be incomplete"
}

# Download ManiSkill dataset assets
download_asset \
    "bridge_v2_real2sim" \
    "/home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset/custom/info_bridge_custom_v0.json" \
    "https://huggingface.co/datasets/haosulab/ManiSkill_bridge_v2_real2sim/resolve/main/bridge_v2_real2sim_dataset.zip" \
    "/home/kzy816/.maniskill/data/tasks"

# Download robot assets
download_asset \
    "widowx250s" \
    "/home/kzy816/.maniskill/data/robots/widowx/wx250s.urdf" \
    "https://github.com/haosulab/ManiSkill-WidowX250S/archive/refs/tags/v0.2.0.zip" \
    "/home/kzy816/.maniskill/data/robots"

# Verify critical assets exist
if [ ! -f /home/kzy816/.maniskill/data/tasks/bridge_v2_real2sim_dataset/custom/info_bridge_custom_v0.json ]; then
    echo "ERROR: Required ManiSkill assets missing"
    exit 1
fi

# Environment variables for GPU rendering and TensorFlow
export LD_LIBRARY_PATH="/home/kzy816/.mujoco/mujoco210/bin:/usr/lib/nvidia:\$LD_LIBRARY_PATH"
export NVIDIA_DRIVER_CAPABILITIES="all"
export MUJOCO_GL="egl"
export PYOPENGL_PLATFORM="egl"
export TF_CPP_MIN_LOG_LEVEL=3
export TF_XLA_FLAGS="--tf_xla_cpu_global_jit=false"

# Run training
export DPPO_DATA_DIR="/projects/p30309/RL/RLinf/data"
export DPPO_LOG_DIR="/projects/p30309/RL/RLinf/log"
bash examples/embodiment/run_embodiment.sh ${CFG_NAME}

EOJ
`

echo "JobID = \${JOB} for ${IDX} (${CFG_NAME}) submitted on \$(date)"
sleep 0.5

done < /projects/p30309/RL/RLinf/script/clusters/quest/param.info
exit
