module Experimenter

include("snapshots.jl")
include("experiment.jl")
include("database.jl")
include("runner.jl")

export open_db, export_db, Experiment, Trial
export LinearVariable, LogLinearVariable, RepeatVariable, IterableVariable, MatchIterableVariable
export get_experiment, get_experiments, get_trial, get_trials, get_experiment_by_name, complete_trial!, complete_trial_in_global_database, get_trials_by_name, get_trials_ids_by_name
export execute_trial, execute_trial_and_save_to_db_async, get_results_from_trial_global_database
export execute, Runner
export SerialMode, MultithreadedMode, DistributedMode
export restore_from_db
export merge_databases!
export get_snapshots, latest_snapshot, save_snapshot!, mark_trial_as_incomplete!
export get_ratio_completed_trials_by_name


end