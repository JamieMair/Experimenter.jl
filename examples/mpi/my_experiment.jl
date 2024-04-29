using Experimenter

config = Dict{Symbol,Any}(
    :N => IterableVariable([Int(1e6), Int(2e6), Int(3e6)]),
    :seed => IterableVariable([1234, 4321, 3467, 134234, 121]),
    :sigma => 0.0001)
experiment = Experiment(
    name="Test Experiment",
    include_file="run.jl",
    function_name="run_trial",
    configuration=deepcopy(config)
)

db = open_db("experiments.db")

# Init the cluster
Experimenter.Cluster.init()

@execute experiment db MPIMode(1)