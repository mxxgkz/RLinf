#! /bin/bash

export EMBODIED_PATH="$( cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd )"
export REPO_PATH=$(dirname $(dirname "$EMBODIED_PATH"))
export SRC_FILE="${EMBODIED_PATH}/train_embodied_agent.py"

# # Use null rendering for LIBERO (robosuite) - no video rendering, pure headless simulation
# # This avoids EGL/OSMesa dependency issues and is fastest for training
# # For ManiSkill tasks, EGL is still preferred (set in batch script)
# export MUJOCO_GL="osmesa"
# export PYOPENGL_PLATFORM="osmesa"  # PyOpenGL still needs a platform, but won't be used

# NOTE: set LIBERO_REPO_PATH to the path of the LIBERO repo
export LIBERO_REPO_PATH="$HOME/RL/libero"
export LIBERO_NO_INPUT=1 # disable the input prompt
export TORCH_FORCE_WEIGHTS_ONLY_LOAD=0
export RAY_DISABLE_PIDFD=1
export RAY_LOCAL_MODE=1
export CUDA_VISIBLE_DEVICES="6,7"

# Prevent Python from loading user site-packages to avoid conflicts
export PYTHONNOUSERSITE=1

# Suppress TensorFlow GPU warnings (TensorFlow is not used for computation)
# Level 3 suppresses all warnings except fatal errors
export TF_CPP_MIN_LOG_LEVEL=3

export XLA_PYTHON_CLIENT_MEM_FRACTION=0.8

export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

# export PYTHONPATH="$HOME/RL/libero:$PYTHONPATH"

# Suppress cuDNN/cuFFT/cuBLAS factory registration warnings
export TF_XLA_FLAGS="--tf_xla_cpu_global_jit=false"

export PYTHONPATH=${REPO_PATH}:${LIBERO_REPO_PATH}:$PYTHONPATH

# Base path to the BEHAVIOR dataset, which is the BEHAVIOR-1k repo's dataset folder
# Only required when running the behavior experiment.
export OMNIGIBSON_DATA_PATH=$OMNIGIBSON_DATA_PATH
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
LOG_DIR="${REPO_PATH}/logs/$(date +'%Y%m%d-%H:%M:%S')" #/$(date +'%Y%m%d-%H:%M:%S')"
MEGA_LOG_FILE="${LOG_DIR}/run_embodiment.log"
mkdir -p "${LOG_DIR}"
CMD="python ${SRC_FILE} --config-path ${EMBODIED_PATH}/config/ --config-name ${CONFIG_NAME} runner.logger.log_path=${LOG_DIR}"
echo ${CMD} > ${MEGA_LOG_FILE}
${CMD} 2>&1 | tee -a ${MEGA_LOG_FILE}