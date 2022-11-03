using Experimenter
using Experimenter: @execute
using Logging
using Distributed
include("trial_functions.jl")

Logging.disable_logging(Logging.Info)

function get_test_config()
    return Dict{Symbol,Any}(
        :n => IterableVariable([3, 4, 5]),
        :m => 5,
        :flag => IterableVariable([false, true]),
        :label => "configuration",
    )
end

function get_experiment(name, config)
    experiment = Experiment(
        name=name,
        include_file="trial_functions.jl",
        function_name="run_experiment",
        configuration=config
    )
    return experiment
end


file_path = @__FILE__
directory = dirname(file_path)

@testset "Local running" for mode in (SerialMode, MultithreadedMode)
    database = open_db("runner test"; in_memory=true)
    experiment = get_experiment("serial execution test", get_test_config())


    @execute experiment database mode false directory

    trials = get_trials_by_name(database, experiment.name)
    @test length(trials) == 6
    @test typeof(trials) <: AbstractArray{Trial}

    for trial in trials
        expected_results = run_experiment(trial.configuration, trial.id)
        @test trial.results == expected_results
    end
end

@testset "Distributed Running" begin
    ps = addprocs(2)
    database = open_db("runner test"; in_memory=true)
    experiment = get_experiment("distributed execution test", get_test_config())

    @execute experiment database DistributedMode false directory

    trials = get_trials_by_name(database, experiment.name)
    @test length(trials) == 6
    @test typeof(trials) <: AbstractArray{Trial}

    for trial in trials
        expected_results = run_experiment(trial.configuration, trial.id)
        @test trial.results == expected_results
    end
    # Cleanup 
    rmprocs(ps...)
end