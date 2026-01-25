using Experimenter
using Experimenter: @execute
using Logging
using Distributed

Logging.disable_logging(Logging.Info)

function get_test_config()
    return Dict{Symbol,Any}(
        :T => IterableVariable([10, 20]),
    )
end

function get_experiment(name, config)
    experiment = Experiment(
        name=name,
        include_file="trial_toy_problem.jl",
        function_name="run_problem",
        configuration=config
    )
    return experiment
end

file_path = @__FILE__
directory = dirname(file_path)

@testset "Create and restore snapshots" for mode in (SerialMode, MultithreadedMode, DistributedMode)
    if mode == DistributedMode
        ps = addprocs(2)
    end
    database = open_db("snapshots"; in_memory=true)
    experiment = get_experiment("Snapshot Test", get_test_config())

    @execute experiment database mode directory=directory

    trials = get_trials_by_name(database, experiment.name)
    @test length(trials) == 2

    original_results = (x -> x.results).(trials)

    # Allow trials to restart
    for trial in trials
        mark_trial_as_incomplete!(database, trial.id)
    end

    @execute experiment database mode directory=directory

    new_trials = get_trials_by_name(database, experiment.name)

    for (new_trial, old_trial) in zip(new_trials, trials)
        @test new_trial.results != old_trial.results
        old_obs = old_trial.results[:observations]
        new_obs = new_trial.results[:observations]
        # New obs should have old ones included
        @test isapprox(new_obs[1:length(old_obs)], old_obs)
        # As well as new obs
        @test length(new_obs) > length(old_obs)
    end

    if mode == DistributedMode
        rmprocs(ps)
    end
end
