# Clusters

This package provides some basic support for running an experiment on a HPC. This uses `ClusterManagers.jl` under the hood.

At the moment, we only support running on a SLURM cluster, but any PRs to support other clusters are welcome.

## SLURM

Normally when running on SLURM, one creates a bash script to tell the scheduler about the resource requirements for a job. The following is an example:
```bash
#!/bin/bash

#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=1024
#SBATCH --time=00:30:00
#SBATCH -o hpc/output/test_job_%j.out
```

The function [`Experimenter.Cluster.create_slurm_template`](@ref) provides an easy way to create one of these bash scripts with everything you need to run.

### Example

Let us take the following end-to-end example. Say that we have an experiment script at `my_experiment.jl` (contents below), which now initialises the cluster:
```julia
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

@execute experiment db DistributedMode
```
Additionally, we have the file `run.jl` containing:
```julia
using Random
using Distributed
function run_trial(config::Dict{Symbol,Any}, trial_id)
    results = Dict{Symbol, Any}()
    sigma = config[:sigma]
    N = config[:N]
    seed = config[:seed]
    rng = Random.Xoshiro(seed)
    # Perform some calculation
    results[:distance] = sum(rand(rng) * sigma for _ in 1:N)
    results[:num_threads] = Threads.nthreads()
    results[:hostname] = gethostname()
    results[:pid] = Distributed.myid()
    # Must return a Dict{Symbol, Any}, with the data we want to save
    return results
end
```
We can now create a bash script to run our experiment. We create a template by running the following in the terminal (or adjust or the REPL)
```bash
julia --project -e 'using Experimenter; Experimenter.Cluster.create_slurm_template("myrun.sh")'
```
We then modify the create `myrun.sh` file to the following:
```bash
#!/bin/bash

#SBATCH --ntasks=4
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=1024
#SBATCH --time=00:30:00
#SBATCH -o hpc/logs/job_%j.out

julia --project my_experiment.jl --threads=1

# Optional: Remove the files created by ClusterManagers.jl
rm -fr julia-*.out

```

Once written, we execute this on the cluster via
```bash
sbatch myrun.sh
```

We can then open a Julia REPL (once the job has finished) to see the results:
```julia
using Experimeter
db = open_db("experiments.db")
trials = get_trials_by_name(db, "Test Experiment")

for (i, t) in enumerate(trials)
    hostname = t.results[:hostname]
    id = t.results[:pid]
    println("Trial $i ran on $hostname on worker $id")
end
```

Support for running on SLURM is based on [this gist](https://gist.github.com/JamieMair/0b1ffbd4ee424c173e6b42fe756e877a) available on GitHub. This gist also provides information on how to adjust the SLURM script to allow for one GPU to be allocated to each worker.

