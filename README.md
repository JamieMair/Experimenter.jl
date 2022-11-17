# Experimenter

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JamieMair.github.io/Experimenter.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JamieMair.github.io/Experimenter.jl/dev/)
[![Build Status](https://github.com/JamieMair/Experimenter.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JamieMair/Experimenter.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JamieMair/Experimenter.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JamieMair/Experimenter.jl)

*A package for easily running experiments for different parameters and saving the results in a centralised database*

## Package Features
- Create a local SQLite database to store the results of your experiment.
- Provides a standard structure for executing code across a range of parameters.
- Provides saving of results into the database using standard Julia types.
- Provides an `@execute` macro that will execute an experiment (consisting of many trails with different parameters). Can execute serially, or in parallel with a choice of multithreading or multiprocessing.
- Automatically skips completed trials.

Head over to the [Getting Started](https://jamiemair.github.io/Experimenter.jl/stable/getting_started/) section of the documentation to see how to use this package.
