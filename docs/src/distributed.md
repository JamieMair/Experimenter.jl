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

Once the workers have been added, make sure to change your execution mode to `DistributedMode` to take advantage of the parallelism.

If you have access to a HPC cluster and would like to use multiple nodes, you can do this easily with `Experimenter.jl` - see more in [Cluster Execution](@ref).