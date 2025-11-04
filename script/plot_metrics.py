#!/usr/bin/env python3
"""
Plot metrics from ManiSkill training logs.
Extracts metrics from log files and creates visualizations.
"""

import re
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path
from typing import Dict, List, Tuple, Optional
import argparse


def parse_log_file(log_path: str, verbose: bool = False) -> Dict[str, List[Tuple[int, float]]]:
    """
    Parse a log file and extract metrics from Global Step lines.
    
    Args:
        log_path: Path to the log file
        verbose: If True, print debug information
        
    Returns:
        Dictionary mapping metric names to lists of (step, value) tuples
    """
    metrics = {}
    
    # Pattern to match Global Step lines with metrics
    # Format: Global Step: X%| | Y/1000 [...], metric1=value1, metric2=value2, ...
    # The bracket format is complex, so we use a simpler approach:
    # Match the step number and then find where metrics start (first metric=value pattern)
    step_pattern = re.compile(r'Global Step:.*?\|\s+(\d+)/\d+')
    
    # Remove ANSI escape codes
    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    
    line_count = 0
    with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            # Remove ANSI escape codes first
            line_clean = ansi_escape.sub('', line)
            
            # Match Global Step lines - find the step number
            match = step_pattern.search(line_clean)
            
            if match:
                line_count += 1
                step = int(match.group(1))
                # Find where metrics start (look for first metric=value pattern)
                # Metrics start after the bracket/time info
                step_end = match.end()
                remaining_line = line_clean[step_end:]
                
                # Find the first metric pattern (metric_name=value)
                metric_start = re.search(r'([a-z_/]+=[-\d.e+inf]+)', remaining_line)
                if not metric_start:
                    if verbose:
                        print(f"Warning: No metrics found in step {step}")
                    continue  # Skip this line if no metrics found
                
                metrics_str = remaining_line[metric_start.start():]
                
                # Stop at any non-metric text (like worker process info)
                # Look for pattern like "(WorkerName pid=..." which indicates end of metrics
                end_match = re.search(r'\s*\([A-Za-z]+Worker', metrics_str)
                if end_match:
                    metrics_str = metrics_str[:end_match.start()]
                
                # Parse individual metrics: key=value pairs
                # Pattern: metric_name=value (value can be number, scientific notation, or inf)
                # Values can be: integers, floats, scientific notation (e.g., 3.58e-8), or 'inf'
                metric_pattern = re.compile(r'([a-z_/]+)=([-\d.e+inf]+)')
                
                for metric_match in metric_pattern.finditer(metrics_str):
                    metric_name = metric_match.group(1)
                    value_str = metric_match.group(2).strip()
                    
                    # Skip if no value (empty string)
                    if not value_str:
                        continue
                    
                    # Skip pid (from worker process info, not a real metric)
                    if metric_name == 'pid':
                        continue
                    
                    try:
                        # Handle inf values
                        if value_str.lower() == 'inf':
                            value = float('inf')
                        else:
                            value = float(value_str)
                        
                        if metric_name not in metrics:
                            metrics[metric_name] = []
                        metrics[metric_name].append((step, value))
                    except ValueError:
                        # Skip invalid values
                        if verbose:
                            print(f"Warning: Could not parse value '{value_str}' for metric '{metric_name}'")
                        continue
    
    if verbose:
        print(f"Parsed {line_count} Global Step lines, found {len(metrics)} unique metrics")
    
    return metrics


def plot_metrics(
    metrics: Dict[str, List[Tuple[int, float]]],
    output_path: Optional[str] = None,
    metric_groups: Optional[Dict[str, List[str]]] = None,
    figsize: Tuple[int, int] = (16, 10)
):
    """
    Plot metrics organized by groups.
    
    Args:
        metrics: Dictionary of metric names to (step, value) lists
        output_path: Path to save the plot (if None, displays interactively)
        metric_groups: Dictionary mapping group names to lists of metric names
        figsize: Figure size (width, height)
    """
    if not metrics:
        print("No metrics found to plot!")
        return
    
    # Default metric groups if not provided
    if metric_groups is None:
        metric_groups = {
            'Environment Metrics': [
                'env/success_once',
                'env/success_at_end',
                'env/return',
                'env/reward',
                'env/episode_len',
            ],
            'Training - Actor': [
                'train/actor/policy_loss',
                'train/actor/approx_kl',
                'train/actor/clip_fraction',
                'train/actor/grad_norm',
                'train/actor/lr',
                'train/actor/ratio',
            ],
            'Training - Critic': [
                'train/critic/value_loss',
                'train/critic/value_clip_ratio',
                'train/critic/lr',
            ],
            'Rollout Metrics': [
                'rollout/rewards',
                'rollout/returns_mean',
                'rollout/advantages_mean',
            ],
            'Time Metrics': [
                'time/rollout',
                'time/actor_training',
                'time/step',
            ],
        }
    
    # Filter to only include metrics that exist in the data
    filtered_groups = {}
    for group_name, metric_list in metric_groups.items():
        existing_metrics = [m for m in metric_list if m in metrics]
        if existing_metrics:
            filtered_groups[group_name] = existing_metrics
    
    if not filtered_groups:
        print("No matching metrics found!")
        return
    
    # Create subplots
    n_groups = len(filtered_groups)
    n_cols = 2
    n_rows = (n_groups + n_cols - 1) // n_cols
    
    fig, axes = plt.subplots(n_rows, n_cols, figsize=figsize)
    if n_groups == 1:
        axes = [axes]
    else:
        axes = axes.flatten()
    
    for idx, (group_name, metric_list) in enumerate(filtered_groups.items()):
        ax = axes[idx]
        
        for metric_name in metric_list:
            if metric_name in metrics:
                steps, values = zip(*metrics[metric_name])
                # Filter out inf values for plotting
                valid_mask = np.isfinite(values)
                if np.any(valid_mask):
                    steps_clean = np.array(steps)[valid_mask]
                    values_clean = np.array(values)[valid_mask]
                    ax.plot(steps_clean, values_clean, label=metric_name, marker='o', markersize=2, alpha=0.7)
        
        ax.set_xlabel('Global Step')
        ax.set_ylabel('Value')
        ax.set_title(group_name)
        ax.legend(fontsize=8, loc='best')
        ax.grid(True, alpha=0.3)
    
    # Hide empty subplots
    for idx in range(n_groups, len(axes)):
        axes[idx].set_visible(False)
    
    plt.tight_layout()
    
    if output_path:
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        print(f"Plot saved to {output_path}")
    else:
        plt.show()


def plot_single_metric(
    metrics: Dict[str, List[Tuple[int, float]]],
    metric_name: str,
    output_path: Optional[str] = None,
    figsize: Tuple[int, int] = (10, 6)
):
    """
    Plot a single metric.
    
    Args:
        metrics: Dictionary of metric names to (step, value) lists
        metric_name: Name of the metric to plot
        output_path: Path to save the plot
        figsize: Figure size
    """
    if metric_name not in metrics:
        print(f"Metric '{metric_name}' not found!")
        print(f"Available metrics: {list(metrics.keys())}")
        return
    
    steps, values = zip(*metrics[metric_name])
    
    # Filter out inf values
    valid_mask = np.isfinite(values)
    steps_clean = np.array(steps)[valid_mask]
    values_clean = np.array(values)[valid_mask]
    
    plt.figure(figsize=figsize)
    plt.plot(steps_clean, values_clean, marker='o', markersize=3, linewidth=1.5)
    plt.xlabel('Global Step')
    plt.ylabel('Value')
    plt.title(f'{metric_name}')
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    
    if output_path:
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        print(f"Plot saved to {output_path}")
    else:
        plt.show()


def main():
    parser = argparse.ArgumentParser(description='Plot metrics from ManiSkill training logs')
    parser.add_argument('log_file', type=str, help='Path to the log file')
    parser.add_argument('--output', '-o', type=str, default=None, help='Output path for the plot (default: display)')
    parser.add_argument('--metric', '-m', type=str, default=None, help='Plot a single metric (default: plot all)')
    parser.add_argument('--list', '-l', action='store_true', help='List all available metrics and exit')
    
    args = parser.parse_args()
    
    # Parse the log file
    print(f"Parsing log file: {args.log_file}")
    metrics = parse_log_file(args.log_file)
    
    if not metrics:
        print("No metrics found in the log file!")
        return
    
    print(f"Found {len(metrics)} metrics")
    
    # List metrics if requested
    if args.list:
        print("\nAvailable metrics:")
        for metric_name in sorted(metrics.keys()):
            print(f"  - {metric_name}")
        return
    
    # Plot metrics
    if args.metric:
        plot_single_metric(metrics, args.metric, args.output)
    else:
        plot_metrics(metrics, args.output)


if __name__ == '__main__':
    main()


