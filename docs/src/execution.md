# Running your Experiments

Once you have created an experiment you can run it with the `@execute` macro supplied by `Experimenter.jl`, suppose you already have an experiment stored in the `experiment` variable and a database opened with the variable `db`, then you can execute simply with:
```julia
@execute experiment db SerialMode
```
Which will only execute trials from the experiment that have not been completed. It is up to you to implement how to continue your simulations from snapshots, using the Snapshots API. 

## Single Node Parallel

There are two main ways of executing your experiments in parallel: multithreading (Threads) or multiprocessing (Distributed). The former has lower latency, but the latter scales to working on across a cluster. The easiest option if you are executing on a single computer, use:
```julia
@execute experiment db MultithreadedMode
```
By default, this will use as many threads as you have enabled. You can set this using the environment variable `JULIA_NUM_THREADS`, or by starting Julia with `--threads=X`, replacing `X` with the number you want. You can check what your current setting is with `Threads.nthreads()`.

Alternatively, we can change the execution mode to `DistributedMode`:
```julia
@execute experiment db DistributedMode
```
This internally uses `pmap` from the `Distributed.jl` standard library, parallelising across all open workers. You can check the number of distributed workers with:
```julia
using Distributed
nworkers()
```
`Experimenter.jl` will not spin up processes for you, this is something you have to do yourself, see [Distributed Execution](@ref) for an in depth example.

!!! info
    If your code has many [memory allocations](https://docs.julialang.org/en/v1/manual/performance-tips/#Measure-performance-with-[@time](@ref)-and-pay-attention-to-memory-allocation), it may be better to use `DistributedMode` instead of `MultithreadedMode`.

## Heterogeneous Execution

If you want each distributed worker to be able to run multiple jobs at the same time, you can select a heterogeneous execution scheduling mode, which will allow each worker to run multiple trials simultaneously using multithreading. An example use case for this is where you have multiple nodes, each with many cores, and you do not wish to pay the memory cost from each separate process. Additionally, you can load data in a single process which can be reused by each execution in the same process. This mode may also allow multiple trials to share resources, such as a GPU, which typically only supports one process.

To run this, you simply change the mode to the `HeterogeneousMode` option, providing the number of threads to use on each worker, e.g.
```julia
@execute experiment db HeterogeneousMode(2)
```
which will allow each distributed worker to run two trials simultaneously via multithreading. If this option is selected, it is encouraged that you enable multiple threads per worker when launching the process, e.g. with `addprocs`:
```julia
addprocs(4; exeflags=["--threads=2"])
```
Otherwise, each worker may only have access to a single thread and the overall performance throughput will be worse.

## MPI Execution

Most HPC clusters use a [Message Passing Interface](https://en.wikipedia.org/wiki/Message_Passing_Interface) implementation to handle communication between different processes and synchronise tasks. `Experimenter.jl` now has built-in support for execution via MPI, which has much lower overhead than the built-in `Distributed.jl` multiprocessing library. See more examples in the [Cluster Execution](@ref) page. 