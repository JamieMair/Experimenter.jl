import Base

"""
    Store(data::Dict{Symbol, Any})

Contains a set of data that can be reused by functions. This is
initialised once by a custom function ran by the user and passed
into the runner function.

# Examples

The store acts like a key-value store, where data can be accessed
via
```julia
store[:datakey]
```
"""
Base.@kwdef struct Store
    data::Dict{Symbol, Any} = Dict{Symbol, Any}()
end

Base.getindex(store::Store, key::Symbol) = Base.getindex(store.data, key)
Base.setindex!(store::Store, key::Symbol, value) = Base.setindex!(store.data, key, value)

export Store