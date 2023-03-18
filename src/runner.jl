using Base
using Distributed
using Base.Iterators
using Logging
using ProgressBars
using Pkg

@enum EXECUTEMODE SerialMode MultithreadedMode DistributedMode

@doc raw"Executes the trials of the experiment one of the other, sequentially." SerialMode
@doc raw"Executes the trials of the experiment in parallel using `Threads.@Threads`" MultithreadedMode
@doc raw"Executes the trials of the experiment in parallel using `Distributed.jl`s `pmap`." DistributedMode


Base.@kwdef struct Runner
    execution_mode::EXECUTEMODE
    experiment::Experiment
    database::ExperimentDatabase
end

"""
    @execute experiment database [mode=SerialMode use_progress=false directory=pwd()]

Runs the experiment out of global scope, saving results in the `database`, skipping all already executed trials.

# Args:
mode: Specifies SerialMode, MultithreadedMode or DistributedMode to execute serially or in parallel.
use_progress: Shows a progress bar
directory: Directory to change the current process (or worker processes) to for execution.
"""
macro execute(experiment, database, mode=SerialMode, use_progress=false, directory=pwd())
    quote
        $(esc(experiment)) = restore_from_db($(esc(database)), $(esc(experiment)))
        let runner = Runner(experiment=$(esc(experiment)), database=$(esc(database)), execution_mode=$(esc(mode)))
            push!(runner.database, runner.experiment)
            existing_trials = get_trials(runner.database, runner.experiment.id)

            completed_trials = [trial for trial in existing_trials if trial.has_finished]
            completed_uuids = Set(trial.id for trial in completed_trials)
            # Only take unrun trials
            incomplete_trials = [trial for trial in runner.experiment if !(trial.id in completed_uuids)]

            # Push all incomplete trials to the database
            for trial in incomplete_trials
                push!(runner.database, trial)
            end

            dir = $(esc(directory))
            if runner.execution_mode == DistributedMode
                current_environment = dirname(Pkg.project().path)
                @info "Activating environments..."
                @everywhere using Pkg
                wait.([remotecall(Pkg.activate, i, current_environment) for i in workers()])
                @everywhere using Experimenter
                # Make sure each worker is in the right directory
                @info "Switching to '$dir'..."
                wait.([remotecall(cd, i, dir) for i in workers()])
            end

            cd(dir)
            include_file = runner.experiment.include_file
            include_file_path = joinpath(dir, include_file)
            if !ismissing(include_file)
                if runner.execution_mode == DistributedMode
                    code = Meta.parse("Base.include(Main, raw\"$include_file_path\")")
                    includes_calls = [remotecall(Base.eval, i, code) for i in workers()]
                    wait.(includes_calls)
                end
                Base.include(Main, "$include_file_path")
            end


            run_trials(runner, incomplete_trials; use_progress=$(esc(use_progress)))
        end
    end
end

function execute_trial(function_name::AbstractString, trial::Trial)::Tuple{UUID,Dict{Symbol,Any}}
    fn = Base.eval(Main, Meta.parse("$function_name"))
    results = fn(trial.configuration, trial.id)
    return (trial.id, results)
end

function execute_trial_and_save_to_db_async(function_name::AbstractString, trial::Trial)
    (id, results) = execute_trial(function_name, trial)
    remotecall_wait(complete_trial_in_global_database, 1, id, results)
    nothing
end

function set_global_database(db::ExperimentDatabase)
    global global_experiment_database = db
    lck = ReentrantLock()
    global global_database_lock = lck
end
function unset_global_database()
    global global_experiment_database = nothing
    global global_database_lock = nothing
end
"""
    complete_trial_in_global_database(trial_id::UUID, results::Dict{Symbol,Any})

Marks a specific trial (with `trial_id`) complete in the global database and stores the supplied `results`. Redirects to the master node if on a worker node. Locks to secure access.
"""
function complete_trial_in_global_database(trial_id::UUID, results::Dict{Symbol,Any})
    global global_experiment_database, global_database_lock

    lock(global_database_lock) do
        complete_trial!(global_experiment_database, trial_id, results)
    end
end

"""
    get_results_from_trial_global_database(trial_id::UUID)

Gets the results of a specific trial from the global database. Redirects to the master node if on a worker node. Locks to secure access.
"""
function get_results_from_trial_global_database(trial_id::UUID)
    if myid() != 1
        return remotecall_fetch(get_results_from_trial_global_database, 1, trial_id)
    end

    global global_experiment_database, global_database_lock

    lock(global_database_lock) do
        trial = get_trial(global_experiment_database, trial_id)
        return trial.results
    end
end
"""
    save_snapshot_in_global_database(trial_id::UUID, state, [label])

Save the results of a specific trial from the global database, with the supplied `state` and optional `label`. Redirects to the master node if on a worker node. Locks to secure access.
"""
function save_snapshot_in_global_database(trial_id::UUID, state::Dict{Symbol,Any}, label=missing)
    # Redirect requests on worker nodes to the main node
    if myid() != 1
        remotecall_wait(save_snapshot_in_global_database, 1, trial_id, state, label)
        return nothing
    end

    global global_experiment_database, global_database_lock

    lock(global_database_lock) do
        save_snapshot!(global_experiment_database, trial_id, state, label)
    end
    nothing
end
"""
    get_latest_snapshot_from_global_database(trial_id::UUID)

Same as `get_latest_snapshot`, but in the given global database. Redirects to the master worker if on a distributed node. Only works when using `@execute`.
"""
function get_latest_snapshot_from_global_database(trial_id::UUID)
    # Redirect requests on worker nodes to main node
    if myid() != 1
        return remotecall_fetch(get_latest_snapshot_from_global_database, 1, trial_id)
    end

    global global_experiment_database, global_database_lock


    snapshot = lock(global_database_lock) do
        return latest_snapshot(global_experiment_database, trial_id)
    end
    return snapshot
end



function run_trials(runner::Runner, trials::AbstractArray{Trial}; use_progress=false)
    if length(trials) == 0
        @info "No incomplete trials found. Finished."
        return nothing
    end

    iter = use_progress ? ProgressBar(trials) : trials
    if runner == DistributedMode && length(workers()) <= 1
        @info "Only one worker found, switching to serial execution."
        runner = SerialMode
    end
    set_global_database(runner.database)
    if runner.execution_mode == DistributedMode
        @info "Running $(length(trials)) trials across $(length(workers())) workers"
        function_names = (_ -> runner.experiment.function_name).(trials)
        use_progress && @debug "Progress bar not supported in distributed mode."
        pmap(execute_trial_and_save_to_db_async, function_names, trials)
    elseif runner.execution_mode == MultithreadedMode
        @info "Running $(length(trials)) trials across $(Threads.nthreads()) threads"
        Threads.@threads for trial in iter
            (id, results) = execute_trial(runner.experiment.function_name, trial)
            complete_trial!(runner.database, id, results)
        end
    else
        @info "Running $(length(trials)) trials"
        for trial in iter
            (id, results) = execute_trial(runner.experiment.function_name, trial)
            complete_trial!(runner.database, id, results)
        end
    end
    unset_global_database()
    @info "Finished all trials."
    nothing
end

