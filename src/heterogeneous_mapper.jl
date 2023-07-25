import Distributed

struct HeterogeneousWorkerPool
    available_workers::Channel{Int}
    all_workers::Vector{Int}
    num_processes::Int
end


function Base.push!(pool::HeterogeneousWorkerPool, worker_id)
    push!(pool.available_workers, worker_id)
    push!(pool.all_workers, worker_id)
end
Base.put!(pool::HeterogeneousWorkerPool, worker_id) = put!(pool.available_workers, worker_id)
Base.take!(pool::HeterogeneousWorkerPool) = take!(pool.available_workers)

function HeterogeneousWorkerPool(workers::AbstractArray{Int}, threads_per_worker::Int)
    available = Channel{Int}(typemax(Int))
    for worker in workers
        for _ in 1:threads_per_worker
            put!(available, worker)
        end
    end
    return HeterogeneousWorkerPool(available, deepcopy(workers), length(workers))
end

struct _WorkItem{F, A}
    results::Vector{Ref{Any}}
    worker_pool::HeterogeneousWorkerPool
    index::Int
    f::F
    arguments::A
end

function (item::_WorkItem)()
    worker_id = take!(item.worker_pool)
    result = Distributed.remotecall_fetch(Experimenter.asyncfetch, worker_id, item.f, item.arguments...)
    put!(item.worker_pool, worker_id)
    # Store
    item.results[item.index] = Ref{Any}(result)
    nothing
end

function asyncfetch(f, args...)
    thread_handle = Threads.@spawn f(args...)
    fetch(thread_handle)
end

function Distributed.pmap(f, pool::HeterogeneousWorkerPool, cs...; kwargs...)
    if length(kwargs) > 0
        @error "Keyword arguments on pmap are not supported by HeterogeneousWorkerPool"
    end

    iterator = enumerate(zip(cs...))
    results = Vector{Ref{Any}}(undef, length(iterator))
    threads = map(iterator) do (i, arguments)
        work_item = _WorkItem(results, pool, i, f, arguments)
        thread = Threads.@spawn work_item()
        thread
    end
    wait.(threads)
    # Unwrap the results from the references
    return map(r->r[], results)
end