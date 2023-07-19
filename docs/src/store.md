# Store

As many experiments may require a data of data to be preloaded for each trial, `Experiment.jl` provides a data store that can be initialised once on each worker to reduce the amount of time required for loading the same data.

This store is intended as a **read-only** store that is reused upon execution of each of the trials. 

## Usage

To start, you must create a function which creates the data to be stored, similar to the functions that runs the trial. As en example:
```julia
# Goes inside the same file as your experiment run file (i.e. the file that get's included).
function create_global_store(config)
    # config is the global configuration given to the experiment
    data = Dict{Symbol, Any}(
        :dataset => rand(1000),
        :flag => false,
        # etc...
    )
    return data
end
```
The variable `config` will be the configuration provided to the `Experiment` struct created for your experiment. Importantly, this function will return a `Dict{Symbol, Any}`.

The name of this function can be anything, but you need to supply it to the experiment when it is being created, i.e.
```julia
experiment = Experiment(
    name="Test Experiment",
    include_file="run.jl",
    function_name="run_trial",
    init_store_function_name="create_global_store",
    configuration=config
)
```

Inside your `run_trial` function, you can access the global store using `get_global_store`
```julia
using Experimenter # exports get_global_store
function run_trial(config, trial_id)
    store = get_global_store()
    dataset = store[:dataset]
    # gather your results
    return results
end
```