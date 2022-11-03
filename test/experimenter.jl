using Experimenter
import Experimenter: open_db
using Test
import Base.Iterators: product

function get_test_config()
    return Dict{Symbol,Any}(
        :n => IterableVariable([3, 7]),
        :m => 5,
        :flag => false,
        :label => "configuration",
        :misc => LogLinearVariable(1.0, 1000.0, 4)
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

@testset "Database Creation" begin
    @test typeof(open_db("test"; in_memory=true)) <: Experimenter.ExperimentDatabase
end

@testset "Experiment creation" begin
    config = get_test_config()
    experiment = get_experiment("creation experiment", config)
    db = open_db("test"; in_memory=true)

    @test isnothing(push!(db, experiment))
end

@testset "Existing Experiment detection" begin
    config = get_test_config()
    original_experiment = get_experiment("existing experiment", config)
    db = open_db("test"; in_memory=true)
    push!(db, original_experiment)

    new_experiment = get_experiment("existing experiment", config)
    restored_experiment = restore_from_db(db, new_experiment)
    @test restored_experiment.id == original_experiment.id

    config = deepcopy(config)
    config[:m] = 1
    altered_experiment = get_experiment("existing experiment", config)
    @test_throws ErrorException restore_from_db(db, altered_experiment)
end

@testset "Iterate trials" begin
    config = get_test_config()
    experiment = get_experiment("creation experiment", config)
    trials = collect(experiment)

    misc_vals = [1.0, 10.0, 100.0, 1000.0]
    n_vals = [3, 7]

    config_tuples = Set((misc_val, n_val) for (misc_val, n_val) in product(misc_vals, n_vals))
    @test length(experiment) == length(config_tuples)
    trials = collect(experiment)
    @test length(trials) == length(config_tuples)

    for trial in trials
        misc_val = trial.configuration[:misc]
        n_val = trial.configuration[:n]
        # Test normal value
        @test trial.configuration[:flag] == false

        expected_tuple = (round(misc_val), n_val)
        @test expected_tuple in config_tuples
        # Remove the tuple
        pop!(config_tuples, expected_tuple)
    end

    @test length(config_tuples) == 0
end

