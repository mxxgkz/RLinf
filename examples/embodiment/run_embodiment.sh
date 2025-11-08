#! /bin/bash

# Check folder name using function from bashrc
# Source bashrc in a way that doesn't fail if there are errors
set +u  # Temporarily disable unbound variable check
source ${HOME}/.bashrc 2>/dev/null || true
set -u  # Re-enable unbound variable check

# Source bashrc to get the get_rlinf_folder_name function (if available)
# Define function if it doesn't exist (fallback)
if ! declare -f get_rlinf_folder_name > /dev/null; then
    get_rlinf_folder_name() {
        local path="$1"
        if [[ "$path" == *"RLinf_openpi"* ]]; then
            echo "RLinf_openpi"
        elif [[ "$path" == *"RLinf_openvla_oft"* ]]; then
            echo "RLinf_openvla_oft"
        elif [[ "$path" == *"RLinf_openvla"* ]]; then
            echo "RLinf_openvla"
        else
            echo "RLinf"
        fi
    }
fi

export EMBODIED_PATH="$( cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd )"
export REPO_PATH=$(dirname $(dirname "$EMBODIED_PATH"))
export SRC_FILE="${EMBODIED_PATH}/train_embodied_agent.py"

# # Use null rendering for LIBERO (robosuite) - no video rendering, pure headless simulation
# # This avoids EGL/OSMesa dependency issues and is fastest for training
# # For ManiSkill tasks, EGL is still preferred (set in batch script)
# export MUJOCO_GL="osmesa"
# export PYOPENGL_PLATFORM="osmesa"  # PyOpenGL still needs a platform, but won't be used

# Check folder name using function from bashrc
FOLDER_NAME=$(get_rlinf_folder_name "$EMBODIED_PATH")

if [[ $(hostname) == magic* ]]; then
    ROOT_DIR="${HOME}/RL/${FOLDER_NAME}"
else
    ROOT_DIR="/projects/p30309/RL/${FOLDER_NAME}"
fi

# NOTE: set LIBERO_REPO_PATH to the path of the LIBERO repo
export LIBERO_REPO_PATH="${ROOT_DIR}/RL/libero"
export LIBERO_NO_INPUT=1 # disable the input prompt
export TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD=1 # Allow loading NumPy arrays in LIBERO init_states files
export RAY_DISABLE_PIDFD=1
# export RAY_LOCAL_MODE=1
# export CUDA_VISIBLE_DEVICES="6,7"

# Prevent Python from loading user site-packages to avoid conflicts
export PYTHONNOUSERSITE=1

# Suppress TensorFlow GPU warnings (TensorFlow is not used for computation)
# Level 3 suppresses all warnings except fatal errors
export TF_CPP_MIN_LOG_LEVEL=3

export XLA_PYTHON_CLIENT_MEM_FRACTION=0.8

# PyTorch uses expandable_segments:True by default for better memory management
# This requires the pidfd_open syscall for CUDA IPC between processes
# However, this syscall is not available on all systems, so we disable it by default.
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:False # Disable Expandable Segments (Immediate Fix)

# export PYTHONPATH="$HOME/RL/libero:$PYTHONPATH"

# Suppress cuDNN/cuFFT/cuBLAS factory registration warnings
export TF_XLA_FLAGS="--tf_xla_cpu_global_jit=false"

export PYTHONPATH=${REPO_PATH}:${LIBERO_REPO_PATH}:$PYTHONPATH

# Base path to the BEHAVIOR dataset, which is the BEHAVIOR-1k repo's dataset folder
# Only required when running the behavior experiment.
# Use default value if OMNIGIBSON_DATA_PATH is not set (for non-BEHAVIOR experiments)
export OMNIGIBSON_DATA_PATH=${OMNIGIBSON_DATA_PATH:-/path/to/omnigibson-data}
export OMNIGIBSON_DATASET_PATH=${OMNIGIBSON_DATASET_PATH:-$OMNIGIBSON_DATA_PATH/behavior-1k-assets/}
export OMNIGIBSON_KEY_PATH=${OMNIGIBSON_KEY_PATH:-$OMNIGIBSON_DATA_PATH/omnigibson.key}
export OMNIGIBSON_ASSET_PATH=${OMNIGIBSON_ASSET_PATH:-$OMNIGIBSON_DATA_PATH/omnigibson-robot-assets/}
export OMNIGIBSON_HEADLESS=${OMNIGIBSON_HEADLESS:-1}
# Base path to Isaac Sim, only required when running the behavior experiment.
export ISAAC_PATH=${ISAAC_PATH:-/path/to/isaac-sim}
export EXP_PATH=${EXP_PATH:-$ISAAC_PATH/apps}
export CARB_APP_PATH=${CARB_APP_PATH:-$ISAAC_PATH/kit}


if [ -z "$1" ]; then
    CONFIG_NAME="maniskill_ppo_openvlaoft"
else
    CONFIG_NAME=$1
fi
echo "CONFIG_NAME: ${CONFIG_NAME}"

echo "Using Python at $(which python)"
LOG_DIR="${REPO_PATH}/logs/$(date +'%Y%m%d-%H-%M-%S')" #/$(date +'%Y%m%d-%H:%M:%S')"
MEGA_LOG_FILE="${LOG_DIR}/run_embodiment.log"
mkdir -p "${LOG_DIR}"
CMD="python ${SRC_FILE} --config-path ${EMBODIED_PATH}/config/ --config-name ${CONFIG_NAME} runner.logger.log_path=${LOG_DIR}"
echo ${CMD} > ${MEGA_LOG_FILE}
${CMD} 2>&1 | tee -a ${MEGA_LOG_FILE}