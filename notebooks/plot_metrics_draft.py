# %%
import sys
sys.path.append("/projects/p30309/RL/RLinf")

from script.plot_metrics import parse_log_file, plot_metrics, plot_single_metric

# %%
# log_file = "/projects/p30309/RL/RLinf/script/clusters/std_output/maniskill1.log"
# This is the first running example of maniskill
log_file = "/projects/p30309/RL/RLinf/logs/20251103-06:10:02/run_embodiment.log"

# %%
# Parse with verbose mode to see what's happening
metrics = parse_log_file(log_file, verbose=True)
print(f"\nMetrics dictionary keys: {list(metrics.keys())}")
print(f"Total metrics: {len(metrics)}")
if metrics:
    print(f"\nSample metric data:")
    for key in list(metrics.keys())[:5]:
        print(f"  {key}: {len(metrics[key])} data points, first value: {metrics[key][0]}")

# %%
if metrics:
    # Filter to only success and reward related metrics
    success_reward_metrics = {
        'Success Metrics': [
            'env/success_once',
            'env/success_at_end',
        ],
        'Reward Metrics': [
            'env/reward',
            'env/return',
            'rollout/rewards',
        ],
    }
    
    # Filter to only include metrics that exist in the data
    filtered_groups = {}
    for group_name, metric_list in success_reward_metrics.items():
        existing_metrics = [m for m in metric_list if m in metrics]
        if existing_metrics:
            filtered_groups[group_name] = existing_metrics
    
    if filtered_groups:
        plot_metrics(metrics, metric_groups=filtered_groups)
    else:
        print("No success or reward metrics found in the data!")
        print(f"Available metrics: {list(metrics.keys())}")
else:
    print("No metrics found! Check the verbose output above for issues.")
# %%