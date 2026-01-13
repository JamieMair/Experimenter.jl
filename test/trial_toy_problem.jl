using Random

# Only define functions if not already defined (prevents redefinition warnings)
if !@isdefined(run_problem)
    function run_problem(config, trial_id)
        T = config[:T]
        info = init_info(config, trial_id)

        current_state = deepcopy(info[:initial_state])
        push!(info[:states], deepcopy(current_state))
        push!(info[:observations], sum(current_state))
        for t in 1:T
            current_state .+= rand((-1, 1), length(current_state))
            push!(info[:states], deepcopy(current_state))
            push!(info[:observations], sum(current_state))
            sleep(0.05) # Simulate work
            # Save snapshot
            if t % 2 == 0 || t == T
                cache = Dict{Symbol, Any}()
                cache[:rng_state] = copy(Random.default_rng())
                cache[:states] = deepcopy(info[:states])
                cache[:observations] = deepcopy(info[:observations])
                cache[:initial_state] = deepcopy(info[:initial_state])
                save_snapshot_in_global_database(trial_id, cache, "Snapshot Label")
            end
        end

        return info
    end

    function init_info(config, trial_id)
        cb_storage = Dict{Symbol,Any}()
        can_restore = false
        snapshot = get_latest_snapshot_from_global_database(trial_id)
        if !isnothing(snapshot)
            @debug "Using snapshot $(snapshot.id) from trial $(snapshot.trial_id)."
            cb_storage = snapshot.state
            can_restore = true
        end

        info = Dict{Symbol, Any}()
        info[:seed] = 1234
        if can_restore
            info[:initial_state] = cb_storage[:initial_state]
            info[:states] = cb_storage[:states]
            info[:observations] = cb_storage[:observations]
            # Load RNG
            copy!(Random.default_rng(), cb_storage[:rng_state])
        else
            Random.seed!(info[:seed])
            info[:initial_state] = [rand((-1, 1)) for _ in 0:config[:T]]
            info[:states] = []
            info[:observations] = []
        end
        return info
    end

    function save_snapshot(trial_id, state, label)
        save_snapshot_in_global_database(trial_id, state, label)
    end
end