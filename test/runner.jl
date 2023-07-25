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

function get_heterogeneous_config()
    return Dict{Symbol,Any}(
        :x => IterableVariable([1, 2]),
        :y => IterableVariable([1, 2]),
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
function get_heterogeneous_experiment(name, config)
    experiment = Experiment(
        name=name,
        include_file="trial_functions.jl",
        function_name="run_heterogeneous_experiment",
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

@testset "Heterogeneous Running" begin
    # Launch two processes with access to 2 threads
    ps = addprocs(2; exeflags=["--threads=2"])
    database = open_db("runner test"; in_memory=true)
    experiment = get_heterogeneous_experiment("heterogeneous distributed execution test", get_heterogeneous_config())

    # Launch 2 threads per node
    @execute experiment database HeterogeneousMode(2) false directory


    trials = get_trials_by_name(database, experiment.name)
    for pid in ps
        thread_ids = [t.results[:thread_id] for t in trials if t.results[:distributed_id] == pid]
        unique_threads = length(unique(thread_ids))
        @test unique_threads == 2
        @test unique_threads == length(thread_ids)

    end
    # Cleanup 
    rmprocs(ps...)
end