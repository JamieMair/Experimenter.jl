using Experimenter
import Experimenter: open_db, @execute
using Test
import Base.Iterators: product
using Distributed

function get_test_config()
    return Dict{Symbol,Any}(
        :T => IterableVariable([10, 20]),
        :N => IterableVariable([5, 10]),
    )
end
function get_test_config(restore_from_experiment::Experiment)
    conf = get_test_config()
    conf[:restore_from_trial_id] = MatchIterableVariable([trial.id for trial in restore_from_experiment])
    return conf
end

function get_experiment(name, config)
    experiment = Experiment(
        name=name,
        include_file="trial_functions.jl",
        function_name="run_restore_experiment",
        configuration=config
    )
    return experiment
end

@testset "Restore from experiment" for mode in (SerialMode, MultithreadedMode, DistributedMode)
    if mode == DistributedMode
        ps = addprocs(2)
    end
    experiment = get_experiment("Initial trial", get_test_config())
    database = open_db("restore from trial test"; in_memory=true)

    file_path = @__FILE__
    directory = dirname(file_path)

    @execute experiment database mode false directory

    restore_experiment = get_experiment("Second trial", get_test_config(experiment))

    @execute restore_experiment database mode false directory

    first_trials = get_trials(database, experiment.id)
    restored_trials = get_trials(database, restore_experiment.id)

    @test length(first_trials) == length(restored_trials)

    for (original_trial, restored_trial) in zip(first_trials, restored_trials)
        @test !ismissing(original_trial.results)
        @test !ismissing(restored_trial.results)

        @test isapprox(original_trial.results[:final_state], restored_trial.results[:initial_state])
    end
    if mode == DistributedMode
        rmprocs(ps)
    end
end