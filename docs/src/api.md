## Public API

## Database Management
```@docs
open_db
export_db
restore_from_db
merge_databases!
```

## Experiments
```@docs
Experiment
get_progress
get_experiment
get_experiments
get_experiment_by_name
get_ratio_completed_trials_by_name
``` 

## Data Storage
```@docs
get_global_store
get_results_from_trial_global_database
```

## Trials
```@docs
get_trial
get_trials
get_trials_by_name
get_trials_ids_by_name
```

## Execution
```@docs
@execute
SerialMode
MultithreadedMode
DistributedMode
HeterogeneousMode
MPIMode
```

## Cluster Management
```@docs
Experimenter.Cluster.init

```


## Snapshots
```@docs
get_snapshots
latest_snapshot
save_snapshot!
get_latest_snapshot_from_global_database
save_snapshot_in_global_database
```

## Misc
```@docs
LinearVariable
LogLinearVariable
RepeatVariable
IterableVariable
MatchIterableVariable
```