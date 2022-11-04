# Custom Snapshots

Most simulated experiments take a long time to run, and may be cancelled part way. It is important to be able to save progress on these long-running simulations. For this example, we will take the idea of simulating a Monte-Carlo process. Imagine that your process looks like the below function: 
```julia
using Random
function run_simulation(config::Dict{Symbol, Any}, trial_id)
    epochs = config[:epochs]
    T = Float64
    positions = zeros(T, epochs)
    x = zero(T)
    for t in 2:epochs
        x += randn(T)
        positions[t] = x
    end

    results = Dict{Symbol, Any}(
        mean_position => sum(positions) / length(positions)
    )
    return results
end
```
If we want to be able to replicate this process, we should take in a `seed` for the random values and save a snapshot every so often:
```julia
using Random
using Experimenter
function run_simulation(config::Dict{Symbol, Any}, trial_id)
    epochs = config[:epochs]
    seed = config[:seed]
    snapshot_interval = config[:snapshot_interval]
    snapshot_label = config[:snapshot_label]

    rng = Random.Xoshiro(seed)
    T = Float64
    positions = zeros(T, epochs)
    x = zero(T)
    for t in 2:epochs
        x += randn(rng, T)
        positions[t] = x
        if t % snapshot_interval == 0
            state = Dict{Symbol, Any}(
                :rng_state => copy(rng),
                :positions => positions[begin:t]
            )
            # Global will only work when executing globally with @execute!
            save_snapshot_in_global_database(trial_id, state, snapshot_label)
        end
    end

    results = Dict{Symbol, Any}(
        :mean_position => sum(positions) / length(positions)
    )
    return results
end
```
This will save a snapshot associated with the `trial_id` supplied, whose key is based on the current time. So far, we have only saved the snapshot, but we should implement a method which initialises our simulation, loading from snapshot:
```julia
using Logging
function init_sim(config::Dict{Symbol,Any}, trial_id)
    snapshot = get_latest_snapshot_from_global_database(trial_id)

    rng = Random.Xoshiro(config[:seed])
    T = Float64
    positions = zeros(T, config[:epochs])
    x = zero(T)
    start_t = 2
    if !isnothing(snapshot)
        state = snapshot.state # Dict we saved earlier
        copy!(rng, state[:rng_state]) # Reset RNG
        saved_positions = state[:positions]
        # Load existing positions
        positions[begin:length(saved_positions)] .= saved_positions
        x = last(saved_positions)
        start_t = length(saved_positions) + 1
        @info "Restored trial $trial_id from snapshot - $(length(saved_positions)) epochs restored."
    end

    return x, positions, start_t, rng, T
end
```
Finally, we put it altogether:
```julia
# saved in `run.jl`
using Random
using Experimenter
function run_simulation(config::Dict{Symbol, Any}, trial_id)
    epochs = config[:epochs]
    snapshot_interval = config[:snapshot_interval]
    snapshot_label = config[:snapshot_label]

    x, positions, start_t, rng, T = init_sim(config, trial_id)

    for t in start_t:epochs
        x += randn(rng, T)
        positions[t] = x

        if t % snapshot_interval == 0
            state = Dict{Symbol, Any}(
                :rng_state => copy(rng),
                :positions => positions[begin:t]
            )
            # Global will only work when executing globally with @execute!
            save_snapshot_in_global_database(trial_id, state, snapshot_label)
        end
    end

    results = Dict{Symbol, Any}(
        :mean_position => sum(positions) / length(positions)
    )
    return results
end
# ... include definiton for init_sim function.
```
Now we can create a script to execute this project:
```julia
using Experimenter

config = Dict{Symbol, Any}(
    :seed => IterableVariable([1234,4567,8910]),
    :epochs => IterableVariable([500_000, 1_000_000]),
    :snapshot_interval => 100_000,
    :snapshot_label => "MC Snapshots"
)
experiment = Experiment(
    name="Snapshot Experiment",
    include_file="run.jl",
    function_name="run_simulation",
    configuration=deepcopy(config)
)
db = open_db("experiments.db")
@execute experiment db SerialMode true
```
You can use `Ctrl+C` to cancel the execution before it is complete, and run again to see if the logger has been triggered (i.e. a snapshot has been loaded). If the program runs too quickly, try adding a `sleep(0.1)` whenever a snapshot is saved, so you get a chance to cancel it to see if it works.