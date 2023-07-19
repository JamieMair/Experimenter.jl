using Experimenter
using Experimenter: @execute
using Logging
using Distributed
include("trial_functions.jl")

file_path = @__FILE__
directory = dirname(file_path)

Logging.disable_logging(Logging.Info)

function get_store_test_config()
    return Dict{Symbol,Any}(
        :n => IterableVariable([3, 4, 5]),
        :m => 5,
        :flag => IterableVariable([false, true]),
        :label => "configuration",
        :param => (777, false) # test this param
    )
end

function get_store_experiment(name, config)
    experiment = Experiment(
        name=name,
        include_file="trial_functions.jl",
        function_name="run_experiment_with_store",
        init_store_function_name="init_store",
        configuration=config
    )
    return experiment
end

@testset "Local store init" for mode in (SerialMode, MultithreadedMode)
    database = open_db("store init test"; in_memory=true)
    config = get_store_test_config()
    experiment = get_store_experiment("local store init $(mode)", config)


    @execute experiment database mode false directory

    trials = get_trials_by_name(database, experiment.name)

    for trial in trials
        results = trial.results # should return the config        
        expected_results = init_store(config)
        @test expected_results == results 
    end
end


@testset "Distributed store init" begin
    ps = addprocs(2)
    database = open_db("store init test"; in_memory=true)
    config = get_store_test_config()
    experiment = get_store_experiment("distributed store init test", config)

    @execute experiment database DistributedMode false directory

    trials = get_trials_by_name(database, experiment.name)

    for trial in trials
        results = trial.results # should return the config        
        expected_results = init_store(config)
        @test expected_results == results 
    end
    # Cleanup 
    rmprocs(ps...)
end
