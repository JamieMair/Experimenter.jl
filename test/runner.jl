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
        :x => IterableVariable([1, 2, 3]),
        :y => IterableVariable(reverse([1, 2, 4, 8])),
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
    if get(ENV, "CI", "false") != "true"
        # Launch two processes with access to 2 threads
        ps = addprocs(2; exeflags=["--threads=2"])
        database = open_db("runner test"; in_memory=true)
        experiment = get_heterogeneous_experiment("heterogeneous distributed execution test", get_heterogeneous_config())

        # Launch 2 threads per node
        @execute experiment database HeterogeneousMode(2) false directory


        trials = get_trials_by_name(database, experiment.name)
        for pid in ps
            max_threads = maximum([t.results[:num_threads] for t in trials if t.results[:distributed_id] == pid])
            max_threads = min(max_threads, length([true for t in trials if t.results[:distributed_id] == pid]))
            thread_ids = [t.results[:thread_id] for t in trials if t.results[:distributed_id] == pid]
            unique_threads = length(unique(thread_ids))
            @test unique_threads == max_threads
        end
        # Cleanup 
        rmprocs(ps...)
    end
end

@testset "Force Overwrite" begin
    # Test default behavior (force_overwrite=false)
    @testset "Default behavior preserves existing experiment" begin
        database = open_db("force_overwrite_test"; in_memory=true)
        config = get_test_config()
        experiment1 = get_experiment("overwrite test default", config)
        
        @execute experiment1 database SerialMode false directory false
        
        trials1 = get_trials_by_name(database, experiment1.name)
        first_experiment_id = experiment1.id
        @test length(trials1) == 6
        
        # Run again with same name - should preserve
        experiment2 = get_experiment("overwrite test default", config)
        @execute experiment2 database SerialMode false directory false
        
        trials2 = get_trials_by_name(database, experiment2.name)
        @test length(trials2) == 6
        @test experiment2.id == first_experiment_id # Should be same experiment
    end
    
    # Test force_overwrite=true deletes and recreates
    @testset "force_overwrite=true deletes existing experiment" begin
        database = open_db("force_overwrite_test2"; in_memory=true)
        config = get_test_config()
        experiment1 = get_experiment("overwrite test force", config)
        
        @execute experiment1 database SerialMode false directory false
        
        trials1 = get_trials_by_name(database, experiment1.name)
        first_experiment_id = experiment1.id
        first_trial_ids = [t.id for t in trials1]
        @test length(trials1) == 6
        
        # Run again with force_overwrite=true - should delete and recreate
        experiment2 = get_experiment("overwrite test force", config)
        @execute experiment2 database SerialMode false directory true
        
        trials2 = get_trials_by_name(database, experiment2.name)
        second_trial_ids = [t.id for t in trials2]
        
        @test length(trials2) == 6
        @test experiment2.id != first_experiment_id # Should be new experiment
        @test !any(tid in first_trial_ids for tid in second_trial_ids) # All new trial IDs
        
        # Verify all trials completed successfully
        for trial in trials2
            @test trial.has_finished == true
            expected_results = run_experiment(trial.configuration, trial.id)
            @test trial.results == expected_results
        end
    end
    
    # Test force_overwrite with different configuration
    @testset "force_overwrite=true with different config" begin
        database = open_db("force_overwrite_test3"; in_memory=true)
        config1 = get_test_config()
        experiment1 = get_experiment("overwrite test diff config", config1)
        
        @execute experiment1 database SerialMode false directory false
        
        trials1 = get_trials_by_name(database, experiment1.name)
        @test length(trials1) == 6
        
        # Change configuration and force overwrite
        config2 = Dict{Symbol,Any}(
            :n => IterableVariable([10, 20]),
            :m => 10,
            :flag => IterableVariable([true]),
            :label => "new configuration",
        )
        experiment2 = get_experiment("overwrite test diff config", config2)
        @execute experiment2 database SerialMode false directory true
        
        trials2 = get_trials_by_name(database, experiment2.name)
        @test length(trials2) == 2 # New config has only 2 trials
        
        # Verify new config is used
        for trial in trials2
            @test trial.configuration[:n] in [10, 20]
            @test trial.configuration[:m] == 10
            @test trial.configuration[:label] == "new configuration"
        end
    end
end