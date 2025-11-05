# Copyright 2025 The RLinf Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import json
import logging
import os

import hydra
import torch.multiprocessing as mp
from omegaconf.omegaconf import OmegaConf

from rlinf.config import validate_cfg
from rlinf.runners.embodied_runner import EmbodiedRunner
from rlinf.scheduler import Cluster
from rlinf.utils.placement import HybridComponentPlacement
from rlinf.workers.actor.fsdp_actor_worker import EmbodiedFSDPActor
from rlinf.workers.env.env_worker import EnvWorker
from rlinf.workers.rollout.hf.huggingface_worker import MultiStepRolloutWorker


format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
logging.basicConfig(format=format)
# Get a logger
logger = logging.getLogger(__name__)
logging.getLogger(__name__).setLevel(logging.INFO)

mp.set_start_method("spawn", force=True)


@hydra.main(
    version_base="1.1", config_path="config", config_name="maniskill_ppo_openvlaoft"
)
def main(cfg) -> None:
    cfg = validate_cfg(cfg)
    print("!"*50)
    logger.info(json.dumps(OmegaConf.to_container(cfg, resolve=True), indent=2))

    # Set local_mode=True if needed for debugging
    # You can also set environment variable: export RAY_LOCAL_MODE=true
    logger.info("!"*50)
    logger.info(f"cfg.ray.local_mode: {cfg.ray.local_mode}")
    logger.info(f"os.environ.get('RAY_LOCAL_MODE', 'not set'): {os.environ.get('RAY_LOCAL_MODE', 'not set')}")
    
    # Extract ray.init() kwargs from config (excluding local_mode which is handled separately)
    ray_init_kwargs = {}
    if hasattr(cfg.ray, 'init_kwargs'):
        ray_init_kwargs = OmegaConf.to_container(cfg.ray.init_kwargs, resolve=True) or {}
    
    cluster = Cluster(
        num_nodes=cfg.cluster.num_nodes, 
        local_mode=cfg.ray.local_mode,
        ray_init_kwargs=ray_init_kwargs
    )
    component_placement = HybridComponentPlacement(cfg, cluster)

    # Create actor worker group
    actor_placement = component_placement.get_strategy("actor")
    actor_group = EmbodiedFSDPActor.create_group(cfg).launch(
        cluster, name=cfg.actor.group_name, placement_strategy=actor_placement
    )
    # Create rollout worker group
    rollout_placement = component_placement.get_strategy("rollout")
    rollout_group = MultiStepRolloutWorker.create_group(cfg).launch(
        cluster, name=cfg.rollout.group_name, placement_strategy=rollout_placement
    )
    # Create env worker group
    env_placement = component_placement.get_strategy("env")
    env_group = EnvWorker.create_group(cfg).launch(
        cluster, name=cfg.env.group_name, placement_strategy=env_placement
    )

    runner = EmbodiedRunner(
        cfg=cfg,
        actor=actor_group,
        rollout=rollout_group,
        env=env_group,
    )

    runner.init_workers()
    runner.run()


if __name__ == "__main__":
    main()
