# Distributed Execution

If you want to execute on a single node, but using multiprocessing (i.e. `Distributed.jl`), then you can start Julia with
```sh
julia --project -p 8
```
To start Julia with `8` workers. Alternatively, you can add processes while running:
```julia
using Distributed
addprocs(8)
```
As long as `nworkers()` show more than one worker, then your execution of trials will occur in parallel, across these workers.

## Configuring SLURM

[SLURM](https://slurm.schedmd.com/overview.html) is one of the most popular schedulers on HPC clusters, which we can integrate with `Distributed.jl` to spawn our workers automatically. See [this gist](https://gist.github.com/JamieMair/0b1ffbd4ee424c173e6b42fe756e877a) for some scripts to make this process easier.

Let's start with spawning your processes:
```julia
using Distributed
using ClusterManagers
num_tasks = parse(Int, ENV["SLURM_NTASKS"]) # One process per task
cpus_per_task = parse(Int, ENV["SLURM_CPUS_PER_TASK"]) # Assign threads per process
addprocs(SlurmManager(num_tasks),
    exe_flags=[
        "--project",
        "--threads=$cpus_per_task"]
)

```
You can check out [`ClusterManagers.jl`](https://github.com/JuliaParallel/ClusterManagers.jl) for your own cluster software if you are not using SLURM, but the process will be similar to this.

Once this has been done, simply include your file which configures and runs your experiment using `DistributedMode` execution mode as detailed above and save in a file like `run_script.jl`.

For SLURM, you can make a slurm script to submit, for example:
```sh
#!/bin/bash

#SBATCH --ntasks=8
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=2G
#SBATCH --time=00:30:00

module load julia/1.8.2

julia --project run_script.jl
```
which can be saved to `launch_experiment.sh` and run with `sbatch launch_experiment.sh`. Note that you may need to include addition SBATCH directives like `--account` on your cluster. Check your cluster's documentation for more information.
