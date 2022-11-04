# Getting Started

`Experimenter.jl` is a package that is designed to help you keep track of your experiments and their results. It is built to work with `Distributed.jl` for parallel writing of results to a SQLite database file.

## Opening the database

To get started, first import the library with:
```julia
using Experimenter
```
After this one needs to create a database to store the results:
```julia
db = open_db("experiments.db")
```
One can always supply a given directory for the database as well, for example:
```julia
db = open_db("experiments.db", joinpath(pwd(), "results"))
```
The first call to `open_db` will check if a file already exists. If the file does not exist, `Experimenter.jl` will create the file and the schema for the database.

## Defining the work we want to process

To run an experiment we need to first define a function which runs our experiment:
```julia
# in run.jl
using Random
function run_trial(config::Dict{Symbol,Any}, trial_id)
    results = Dict{Symbol, Any}()
    sigma = config[:sigma]
    N = config[:N]
    seed = config[:seed]
    rng = Random.Xoshiro(seed)
    # Perform some calculation
    results[:distance] = sum(rand(rng) * sigma for _ in 1:N)
    # Must return a Dict{Symbol, Any}, with the data we want to save
    return results
end
```
## Creating an experiment

Now we can define a configuration for our experiment:
```julia
# in a script
config = Dict{Symbol,Any}(
    :N => IterableVariable([10, 20]),
    :seed => IterableVariable([1234, 4321]),
    :sigma => 1.0
)
```
This is just a dictionary, with some special wrappers `IterableVariable` for some of the config values. When we create our experiment, we pass in this configuration and the path to the file with the function to run our experiment:
```julia
experiment = Experiment(
    name="Test Experiment",
    include_file="run.jl",
    function_name="run_trial",
    configuration=deepcopy(config)
)
```

## Examining the trials of an experiment
We can look at the set of trials this experiment will create:
``` julia
for trial in experiment
    println(trial.configuration)
end
# Dict{Symbol, Any}(:N => 10, :sigma => 1.0, :seed => 1234)
# Dict{Symbol, Any}(:N => 20, :sigma => 1.0, :seed => 1234)
# Dict{Symbol, Any}(:N => 10, :sigma => 1.0, :seed => 4321)
# Dict{Symbol, Any}(:N => 20, :sigma => 1.0, :seed => 4321)
```
or, alternatively:
```julia
trials = collect(experiment)
```
There are multiple trials in this experiment as we used an `IterableVariable` wrapper, which says that we want to run a grid search over these specific variables.

## Executing an experiment

To execute our experiment, we use the `@execute` macro. To execute the experiment serially:

```julia
@execute experiment db SerialMode
```

Instead of `SerialMode`, we can use `ThreadedMode` to execute via `Threads.@threads`, or use `DistributedMode` to execute via a `pmap` and run across different workers.

## Getting the results

Once the experiments are completed, we can run:
```julia
trials = get_trials_by_name(db, "Test Experiment");
```

This will return a `Vector{Trial}`, where `Trial` has a `results` field which is the dictionary we returned from the `run_trial` function. To get the results we write:
```julia
results = [t.results for t in trials]
```

## Re-running failed trials

If a trial did not finish, then the `results` field will be missing. Whenever we run the `@execute` macro, it will skip any trial that already has results, and only run the next trials. Therefore 
```julia
@execute experiment db SerialMode
```
will not run any more trials, as they have already been completed. However, if the execution stopped (for example killed by the SLURM scheduler due to wall time), then it will only run the trials that have not been completed.

## Saving part way

If your trials take a long time to finish and may be cancelled during their run, you can always implement a way to save a `Snapshot`, which allows you to save data you need to restore a trial part way through running. The API for this has not yet been documented, but examples can be seen in the unit tests.

## What is an `Experiment`?

An experiment sets up a configuration that specifies (by default) a grid search over variables. If none of the special classes such as `IterableVariable`, `LinearVariable`, `LogLinearVariable` etc are used as values in the configuration dictionary, this will specify only a single trial. However, if these special types are used, an experiment will have multiple trials, whose configurations are created via a grid search over the special `AbstractVariable`s provided, with each of these values being replaced by a single element in these iterables.

As an example the following configuration:
```julia
config = Dict{Symbol, Any}(
    :a => IterableVariable(["a", "b"]),
    :b => LinearVariable(1, 4, 5),
    :c => "constant value"
)
```
Since the first two parts are marked with a type of `AbstractVariable` (or concrete type of), these will form our grid search. The actual configurations will look like the following code:
```julia
for a in ["a", "b"]
    for b in LinRange(1, 4, 5)
        trial_config = Dict{Symbol, Any}(
            :a => a,
            :b => b,
            :c => "constant value"
        )
    end
end
```

A matched variable will not form part of the grid, but works as follows:
```julia
matched = rand(2*5)
i = 1
for a in ["a", "b"]
    for b in LinRange(1, 4, 5)
        trial_config = Dict{Symbol, Any}(
            :a => a,
            :b => b,
            :c => "constant value",
            :matched => matched[i]
        )
        i += 1
    end
end
```
The matched variable must have as many entries as there are in the grid search.