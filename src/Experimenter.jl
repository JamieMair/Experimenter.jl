module Experimenter

include("store.jl")
include("snapshots.jl")
include("experiment.jl")
include("database.jl")
include("heterogeneous_mapper.jl")
include("runner.jl")


module Cluster
    function init_cluster_support()
        @eval Main using ClusterManagers
        if isdefined(Base, :get_extension)
            @eval Main Base.retry_load_extensions()
        end
    end
    function install_cluster_support()
        @eval Main import Pkg
        @eval Main Pkg.add(["ClusterManagers"])
    end

    """
        init(; kwargs...)

    Checks the environment variables to see if a script is running on a cluster 
    and then launches the processes as determined by the environment variables.

    # Arguments

    The keyword arguments are forwarded to the init function for each cluster
    management system. Check the `ext` folder for extensions to see which
    keywords are supported.
    """
    function init(; kwargs...)
        if haskey(ENV, "SLURM_JOB_NAME")
            @eval Main Experimenter.Cluster.init_cluster_support()
            @eval Main Experimenter.Cluster.init_slurm(; $(kwargs)...)
        else
            @info "Cluster not detected, doing nothing."
        end
    end

    """
        create_slurm_template(file_loc; job_logs_dir="hpc/logs")

    Creates a template bash script at the supplied file location and
    creates the log directory used for the outputs. You should modify
    this script to adjust the resources required.
    """
    function create_slurm_template(file_loc::AbstractString;
        job_logs_dir::AbstractString="hpc/logs")

        log_dir = joinpath(dirname(file_loc), job_logs_dir)
        if !isdir(log_dir) && isdirpath(log_dir)
            @info "Creating directory at $log_dir to store the log files"
            mkdir(log_dir)
        end


        file_contents = """#!/bin/bash

        #SBATCH --nodes=1
        #SBATCH --ntasks=1
        #SBATCH --cpus-per-task=2
        #SBATCH --mem-per-cpu=1024
        #SBATCH --time=00:30:00
        #SBATCH -o $log_dir/job_%j.out
        #SBATCH --partition=compute

        # Change below to load version of Julia used
        module load julia

        # Change directory if needed
        # cd "experiments"

        julia --project myscript.jl --threads=1

        # Optional: Remove the files created by ClusterManagers.jl
        # rm -fr julia-*.out
        """

        open(file_loc, "w") do io
            print(io, file_contents)
        end

        @info "Wrote template file to $(abspath(file_loc))"

        nothing
    end
    function init_slurm end

    export init, install_cluster_support, init_cluster_support
end

using PackageExtensionCompat
function __init__()
    @require_extensions
end



## API

### Database
export ExperimentDatabase
export open_db, export_db
export restore_from_db
export merge_databases!

### Experiments
export Experiment
export get_experiment, get_experiments, get_experiment_by_name, get_progress

### Trials
export Trial
export get_trial, get_trials, get_trials_by_name, get_trials_ids_by_name, get_results_from_trial_global_database
export complete_trial!, complete_trial_in_global_database, mark_trial_as_incomplete!

### Execution
export execute_trial, execute_trial_and_save_to_db_async, get_global_store
export @execute
export SerialMode, MultithreadedMode, DistributedMode, HeterogeneousMode

### Snapshots
export Snapshot
export get_snapshots, latest_snapshot, save_snapshot!
export get_latest_snapshot_from_global_database, save_snapshot_in_global_database


## Misc
export LinearVariable, LogLinearVariable, RepeatVariable, IterableVariable, MatchIterableVariable
export get_ratio_completed_trials_by_name

end