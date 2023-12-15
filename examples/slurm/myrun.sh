#!/bin/bash

#SBATCH --ntasks=4
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=1024
#SBATCH --time=00:30:00
#SBATCH -o hpc/logs/job_%j.out

julia --project my_experiment.jl --threads=1

# Optional: Remove the files created by ClusterManagers.jl
rm -fr julia-*.out