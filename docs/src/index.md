```@meta
CurrentModule = Experimenter
```

# Experimenter

*A package for easily running experiments for different parameters and saving the results in a centralised database*

## Package Features
- Create a local SQLite database to store the results of your experiment.
- Provides a standard structure for executing code across a range of parameters.
- Provides saving of results into the database using standard Julia types.
- Provides an `@execute` macro that will execute an experiment (consisting of many trials with different parameters). Can execute serially, or in parallel with a choice of multithreading or multiprocessing.
- Automatically skips completed trials.

Head over to [Getting Started](@ref) to get an overview of this package.

## Manual Outline

```@contents
Pages = [
    "getting_started.md",
    "execution.md",
    "distributed.md",
    "store.md",
    "snapshots.md",
    "clusters.md"
]
Depth = 2
```

Check out the API at [Public API](@ref).