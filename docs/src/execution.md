# Running your Experiments

Once you have created an experiment you can run it with the `@execute` macro supplied by `Experimenter.jl`, suppose you already have an experiment stored in the `experiment` variable and a database opened with the variable `db`, then you can execute simply with:
```julia
@execute experiment db SerialMode
```
Which will only execute trials from the experiment that have not been completed. It is up to you to implement how to continue your simulations from snapshots, using the Snapshots API. 

## Executing in Parallel

There are two main ways of executing your experiments in parallel: multithreading (Threads) or multiprocessing (Distributed). The former has lower latency, but the latter scales to working on across a cluster. The easiest option if you are executing on a single computer, use:
```julia
@execute experiment db MultithreadedMode
```
By default, this will use as many threads as you have enabled. You can set this using the environment variable `JULIA_NUM_THREADS`, or by starting Julia with `--threads=X`, replacing `X` with the number you want. You can check what your current setting is with `Threads.nthreads()`.

On a cluster, we can change the execution mode to `DistributedMode`:
```julia
@execute experiment db DistributedMode
```
This internally uses `pmap` from the `Distributed.jl` standard library, parallelising across all open workers. You can check the number of distributed workers with:
```julia
using Distributed
nworkers()
```
`Experimenter.jl` will not spin up processes for you, this is something you have to do yourself, see [Distributed Execution](@ref) for an in depth example. 