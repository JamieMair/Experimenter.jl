using Experimenter

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