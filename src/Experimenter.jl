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
            init_cluster_support()
            init_slurm(; kwargs...)
        else
            @info "Cluster not detected, doing nothing."
        end
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
export get_experiment, get_experiments, get_experiment_by_name

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