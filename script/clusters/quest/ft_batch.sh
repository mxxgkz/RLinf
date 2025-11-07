#!/bin/bash

# Get the repo root path and folder name BEFORE the loop (needed for the done < redirection)
source ${HOME}/.bashrc
SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "REPO_PATH = ${SCRIPT_DIR}"
FOLDER_NAME=$(get_rlinf_folder_name "$SCRIPT_DIR")
echo "FOLDER_NAME = ${FOLDER_NAME}"

while IFS=$' ' read IDX PAR HOUR CORE MEM NGPU CFG_NAME
do
STD_OUTPUT_FILE="/projects/p30309/RL/${FOLDER_NAME}/script/clusters/std_output/${IDX}.log"

JOB=`sbatch << EOJ
#!/bin/bash
#SBATCH -J ${IDX}
#SBATCH -A p30309
#SBATCH -p ${PAR}
#SBATCH -t ${HOUR}:59:59
#SBATCH --gres=gpu:${NGPU}
#SBATCH --mem=${MEM}G
#SBATCH --cpus-per-task=${CORE}
#SBATCH --output=${STD_OUTPUT_FILE}
#SBATCH --mail-type=BEGIN,FAIL,END,REQUEUE #BEGIN,END,FAIL,REQUEUE
#SBATCH --mail-user=zkghhg@gmail.com

#Delete any preceding space after 'EOJ'. OW, there will be some error.

# unload any modules that carried over from your command line session
module purge

# Set your working directory
cd "/projects/p30309/RL/${FOLDER_NAME}"

# load modules you need to use
# module load python/anaconda3.6

conda init bash

which conda

# Source the setup script that handles venv detection, environment setup, and asset downloads
# This avoids heredoc variable expansion issues - all variables work normally in a separate script
source "/projects/p30309/RL/${FOLDER_NAME}/script/clusters/setup_embodiment_env.sh"

# GPU rendering support (needed for ManiSkill/SAPIEN rendering)
export NVIDIA_DRIVER_CAPABILITIES="all"
export MUJOCO_GL="egl"
export PYOPENGL_PLATFORM="egl"

# Suppress TensorFlow GPU warnings (TensorFlow is not used for computation)
# Level 3 suppresses all warnings except fatal errors
export TF_CPP_MIN_LOG_LEVEL=3

# Suppress cuDNN/cuFFT/cuBLAS factory registration warnings
export TF_XLA_FLAGS="--tf_xla_cpu_global_jit=false"

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

done < /projects/p30309/RL/${FOLDER_NAME}/script/clusters/quest/param.info
# done < ./command_script/param_unet_exp.info
# done < ./command_script/param_trex_online.info
# done < ./command_script/param_ar_lin_2d.info
exit

# make this file executable and then run from the command line
# chmod u+x submit.sh
# ./submit.sh
# The last line of params.txt have to be an empty line.
