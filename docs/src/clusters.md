# Cluster Execution

This package is most useful for running grid search trials on a cluster environment (i.e. a HPC), or a single node with many CPUs. 

There are two main ways you can distribute your experiment over many processes - `DistributedMode` or `MPIMode`. 

For those using a distributed cluster, we recommend that you launch your jobs using the [MPI](https://en.wikipedia.org/wiki/Message_Passing_Interface) functionality, instead of the legacy [SLURM](https://slurm.schedmd.com/overview.html) support (see the [SLURM](#slurm) section below for details).

## MPI

### Installation

Most HPC environments have access to their own MPI implementation. These MPI implementations often take advantage of proprietary interconnect (networking) between the nodes that allow for low-latency and high-throughput communication. If you would like to find your local HPC's implementation, you may be able to look through the catalogue via a bash terminal, using the [Environment Modules](https://modules.sourceforge.net/) package available on most HPC systems:
```bash
module avail
```
or, for a more directed search:
```bash
module spider mpi
```

You may have multiple versions. If you are unsure as to which version to use, check the documentation for the HPC, contact your local System Administrator or simply use what is available. Using OpenMPI is often a reliable choice. 

You can load which version of MPI you would like by adding
```bash
module load mpi/latest
```
to your job script (remember to change `mpi/latest` to the package available on your system).


Make you have loaded the MPI version you wish to use by running the `module load ...` command in the same terminal before opening Julia in the terminal by using
```bash
julia --project
```
Run this command in the same directory as your project.

Now, you have to add the `MPI` package to your local environment using
```julia
import Pkg; Pkg.add("MPI")
```
Now you should be able to load `MPIPreferences` and tell MPI about using your system binary:
```julia
using MPI.MPIPreferences

MPIPreferences.use_system_binary()
exit()
```
This should create a new `LocalPreferences.toml` file. I would recommend adding this file to your `.gitignore` list and not committing it to your GitHub repository.

### Job Scripts

When you are running on a cluster, write your job script so that you load MPI and precompile Julia before launching your job. An example job script could look like the following:

```bash
#!/bin/bash

#SBATCH --ntasks=8
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=2048
#SBATCH --time=00:30:00
#SBATCH -o mpi_job_%j.out


module load mpi/latest
module load julia/1.10.2

# Precompile Julia first to avoid race conditions
julia --project --threads=4 -e 'import Pkg; Pkg.instantiate()'
julia --project --threads=4 -e 'import Pkg; Pkg.precompile()'

mpirun -n 8 julia --project --threads=4 my_experiment.jl
```

Use the above as a template and change the specifics to suit your specific workload and HPC.

!!! info Make sure that you launch your jobs with at least 2 processes (tasks), as one task is dedicated towards coordinating the execution of trials and saving the results.

## Experiment file

As usual, you should write a script to define your experiment and run the configuration. Below is an example, where it is assumed there is another file called `run.jl` which contains a function `run_trial` which takes a configuration dictionary and a trial `UUID`.

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

@execute experiment db MPIMode(1)
```

Note that we are calling `MPIMode(1)` which says that we want a communication batch size of `1`. If your jobs are small, and you want each worker to process a batch at a time, you can set this to a higher number.

## SLURM

!!! warning It is recommended that you use the above MPI mode to run jobs on a cluster, instead of relying on `ClusterManagers.jl`, as it is much slower to run jobs.

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

The function [`Experimenter.Cluster.create_slurm_template`] provides an easy way to create one of these bash scripts with everything you need to run.

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

julia --project --threads=1 my_experiment.jl

# Optional: Remove the files created by ClusterManagers.jl
rm -fr julia-*.out

```

Once written, we execute this on the cluster via
```bash
sbatch myrun.sh
```

We can then open a Julia REPL (once the job has finished) to see the results:
```julia
using Experimenter
db = open_db("experiments.db")
trials = get_trials_by_name(db, "Test Experiment")

for (i, t) in enumerate(trials)
    hostname = t.results[:hostname]
    id = t.results[:pid]
    println("Trial $i ran on $hostname on worker $id")
end
```

Support for running on SLURM is based on [this gist](https://gist.github.com/JamieMair/0b1ffbd4ee424c173e6b42fe756e877a) available on GitHub. This gist also provides information on how to adjust the SLURM script to allow for one GPU to be allocated to each worker.

