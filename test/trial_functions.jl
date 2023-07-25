using Experimenter
using Distributed
using Test

function init_store(config)
    return Dict{Symbol, Any}(
        :magic_number => 42,
        :data => [1,101,1001],
        :config_param => config[:param]
    )
end

function run_experiment_with_store(config, trial_id)
    store = get_global_store()
    @assert store[:config_param] == config[:param]

    return Dict{Symbol, Any}(
        :data=>store[:data],
        :magic_number=>store[:magic_number],
        :config_param=>store[:config_param]
    )
end

function run_experiment(config, trial_id)
    info = Dict{Symbol,Any}()

    info[:value] = config[:n] * config[:m]
    info[:config] = config
    info[:trial_id] = trial_id

    return info
end

function run_restore_experiment(config, trial_id)
    info = Dict{Symbol,Any}()
    info[:trial_id] = trial_id
    N = config[:N]
    T = config[:T]
    if haskey(config, :restore_from_trial_id)
        restore_trial_id = config[:restore_from_trial_id]
        results = get_results_from_trial_global_database(restore_trial_id)
        info[:initial_state] = results[:final_state]
    else
        info[:initial_state] = rand(N)
    end
    current_state = deepcopy(info[:initial_state])
    for _ in 1:T
        current_state .+= rand(N)
    end
    info[:final_state] = current_state

    return info
end

function run_heterogeneous_experiment(config, trial_id)
    results = Dict{Symbol, Any}(
        :thread_id => Threads.threadid(),
        :distributed_id => Distributed.myid(),
        :num_threads => Threads.nthreads()
    )

    # Simulate work
    s = 0.0
    for i in 1:500000000
        s += rand() / 1000
    end

    return results
end