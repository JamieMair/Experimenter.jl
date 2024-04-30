```@meta
CurrentModule = Experimenter
```

# Experimenter

*A package for easily running experiments for different parameters and saving the results in a centralised database*

## Package Features
- Create a local SQLite database to store the results of your experiment, removing the need to keep track of 1000s of results files for each parameter configuration.
- Provides a standard structure for executing code across a range of parameters.
- Provides saving of results into the database using standard Julia types.
- Promotes writing a script that can be easily committed to a Git repository to keep track of results and parameters used throughout development.
- Provides an `@execute` macro that will execute an experiment (consisting of many trials with different parameters). Can execute serially, or in parallel with a choice of multithreading or multiprocessing or even MPI mode.
- Provides an easy way to execute trials across a High Performance Cluster (HPC).
- Automatically skips completed trials, and provides a Snapshots API to allow for partial progress to be saved and reloaded.

Head over to [Getting Started](@ref) to get an overview of this package.

## Manual Outline

```@contents
Pages = [
    "getting_started.md",
    "execution.md",
    "distributed.md",
    "clusters.md",
    "store.md",
    "snapshots.md",
]
Depth = 2
```

Check out the API at [Public API](@ref).