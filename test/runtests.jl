using SafeTestsets

@safetestset "Experimenter.jl" begin
    include("experimenter.jl")
end
@safetestset "Runner" begin
    include("runner.jl")
end
@safetestset "Snapshots" begin
    include("snapshots.jl")
end
@safetestset "Restore from trial" begin
    include("restore_from_trial.jl")
end