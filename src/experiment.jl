using Base
using Base.Iterators
using UUIDs

abstract type AbstractVariable end
abstract type AbstractProductVariable <: AbstractVariable end
abstract type AbstractMatchVariable <: AbstractVariable end
"""
    count_values(entry)

Counts the number of different values which 'variable' can take.
"""
count_values(variable) = 1
count_values(variable::AbstractVariable) = error("count_values is not defined for $(typeof(variable)).")

"""
    extract_value(variable, i)

Returns the i^th possible value of 'variable'. 
'i' follows 1 based indexing.
"""
extract_value(variable, i) = v
extract_value(variable::AbstractVariable, i) = error("extract_value is not defined for $(typeof(variable)).")


function checkbounds(v::AbstractVariable, i)
    (i < 1 || i > count_values(v)) && error("Cannot access $(typeof(v)) with $(count_values(v)) elements at index $i").
    nothing
end

# AbstractVariables should implement the iteration interfaces.
Base.iterate(v::AbstractVariable) = (extract_value(v, 1), 2)
function Base.iterate(v::AbstractVariable, i)
    if i <= length(v)
        return (extract_value(v, i), i + 1)
    else
        return nothing
    end
end
Base.length(v::AbstractVariable) = count_values(v)

"""
    LinearVariable(min, max, n)

Specifies a range for a parameter variable to take, from min to max inclusive with `n` total values.
"""
struct LinearVariable{T,Q<:Integer} <: AbstractProductVariable
    min_value::T
    max_value::T
    num_values::Q
end
count_values(v::LinearVariable) = v.num_values
function extract_value(v::LinearVariable, i)
    checkbounds(v, i)
    val = v.min_value + (v.max_value - v.min_value) * (i - 1) / (v.num_values - 1)
    return val
end
Base.eltype(::LinearVariable{T}) where {T} = promote(T, Float64)


"""
    RepeatVariable(val, n)

Specifies a parameter variable that outputs the same value `val` `n` times. 
"""
struct RepeatVariable{T,Q<:Integer} <: AbstractProductVariable
    value::T
    num_repeats::Q
end
count_values(v::RepeatVariable) = v.num_repeats
function extract_value(v::RepeatVariable, i)
    checkbounds(v, i)
    return v.value
end
Base.eltype(::RepeatVariable{T}) where {T} = T

"""
    LogLinearVariable(min, max, n)

A linearly spaced parameter variable in log space. If min=1 and max=100 and n=3 then the values are [1,10,100].
"""
struct LogLinearVariable{T,Q<:Integer} <: AbstractProductVariable
    min_value::T
    max_value::T
    num_values::Q
end
count_values(v::LogLinearVariable) = v.num_values
function extract_value(v::LogLinearVariable{T}, i) where {T}
    checkbounds(v, i)
    if i == 1
        return v.min_value
    elseif i == v.num_values
        return v.max_value
    end
    log_min_value = log10(v.min_value)
    log_max_value = log10(v.max_value)
    return convert(Float64, 10.0 .^ (log_min_value + (log_max_value - log_min_value) * (i - 1) / (v.num_values - 1)))
end
Base.eltype(::LogLinearVariable{T}) where {T} = promote(Float64, T)

"""
    IterableVariable(iter)

Wraps a given iterator `iter` to tell the experiment to perform a grid search over each element of the iterator for the given parameter.
"""
struct IterableVariable{Q,T<:AbstractArray{Q}} <: AbstractProductVariable
    iterator::T
end
count_values(v::IterableVariable) = length(v.iterator)
Base.eltype(::IterableVariable{Q,T}) where {Q,T} = Q
Base.iterate(v::IterableVariable) = iterate(v.iterator)
Base.iterate(v::IterableVariable, state) = iterate(v.iterator, state)
extract_value(v::IterableVariable, i) = getindex(v.iterator, i)

"""
    MatchIterableVariable(iter)

This type of variable matches with the product from the other `AbstractVariables` in the configuration.

This does not form part of the product variables (grid search), but instead uniques matches with that product.
"""
struct MatchIterableVariable{Q,T<:AbstractArray{Q}} <: AbstractMatchVariable
    iterator::T
end
count_values(v::MatchIterableVariable) = length(v.iterator)
Base.eltype(::MatchIterableVariable{Q,T}) where {Q,T} = Q
Base.iterate(v::MatchIterableVariable) = iterate(v.iterator)
Base.iterate(v::MatchIterableVariable, state) = iterate(v.iterator, state)
extract_value(v::MatchIterableVariable, i) = getindex(v.iterator, i)

"""
    Experiment

A database object for storing the configuration options of an experiment.

The signature of the function supplied should be:
```julia
fn(configuration::Dict{Symbol, Any}, trial_id::UUID)
```

The function should be available when including the file provided.

A name is required to uniquely label this experiment.
"""
Base.@kwdef struct Experiment
    id::UUID = uuid4()
    name::AbstractString
    include_file::Union{Missing,AbstractString} = missing
    function_name::AbstractString
    init_store_fn_name::Union{Missing,AbstractString} = missing
    configuration::Dict{Symbol,Any}
    num_trials::Int = count_trials(configuration)
end

Base.@kwdef struct Trial
    id::UUID = uuid4()
    experiment_id::UUID
    configuration::Dict{Symbol,Any}
    results::Union{Missing,Dict{Symbol,Any}} = missing
    trial_index::Int
    has_finished::Bool = false
end

function count_trails(experiment::Experiment)
    return count_trials(experiment.configuration)
end

function count_trials(config::Dict{Symbol,Any})
    product_count = mapreduce(count_values, *, (v for v in values(config) if typeof(v) <: AbstractProductVariable))
    match_counts = [length(v) for v in values(config) if typeof(v) <: AbstractMatchVariable]
    @assert all(match_counts .== product_count) "All matched variables should have a length of $(product_count) - same as from products."
    return product_count
end

function _construct_trial(id::UUID, experiment::Experiment, param_map, trial_index)
    config_dict = Dict{Symbol,Any}()

    for (key, value) in experiment.configuration
        if haskey(param_map, key)
            config_dict[key] = param_map[key]
        else
            config_dict[key] = value
        end
    end

    return Trial(id=id, configuration=config_dict, experiment_id=experiment.id, trial_index=trial_index)
end

function combinatorial_iterator(config)
    product_iterator = product((Iterators.map((v_i) -> (sym, v_i), v) for (sym, v) in config if typeof(v) <: AbstractProductVariable)...)
    match_vars = [(sym, v) for (sym, v) in config if typeof(v) <: AbstractMatchVariable]
    if length(match_vars) == 0
        return Iterators.map((p) -> (p...,), product_iterator)
    end
    match_iterator = Iterators.zip((Iterators.map((v_i) -> (sym, v_i), v) for (sym, v) in match_vars)...)
    return [(p..., m...) for (p, m) in Iterators.zip(product_iterator, match_iterator)]
end

function getrng(id::UUID)
    seed = id.value
    return UUIDs.Random.MersenneTwister(seed)
end

function Base.iterate(experiment::Experiment)
    isnothing(experiment.configuration) && return nothing

    config = experiment.configuration
    iter = combinatorial_iterator(config)

    rng = getrng(experiment.id)

    if (length(iter) == 0)
        return nothing
    end

    param_map_tuple, iter_state = iterate(iter)
    # Include empty dict to remove type from parameters
    param_map = Dict{Symbol,Any}(sym => val for (sym, val) in param_map_tuple)

    trial = _construct_trial(uuid4(rng), experiment, param_map, 1)

    next_state = (iter, iter_state, rng, 2)

    return trial, next_state
end

function Base.iterate(experiment::Experiment, state)
    (iter, last_state, rng, i) = state
    coll_iter = iterate(iter, last_state)
    if isnothing(coll_iter)
        return nothing
    end

    param_map_tuple, iter_state = coll_iter
    param_map = Dict{Symbol,Any}(sym => val for (sym, val) in param_map_tuple)

    trial = _construct_trial(uuid4(rng), experiment, param_map, i)

    next_state = (iter, iter_state, rng, i + 1)
    return trial, next_state
end

Base.length(experiment::Experiment) = count_trails(experiment)
Base.eltype(::Experiment) = Trial