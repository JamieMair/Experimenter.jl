using Distributed
addprocs(2; exeflags=["--threads=4"])
using Base.Iterators
@everywhere using Experimenter
@everywhere using Dates

function init_pool(max_per_worker)
    return Experimenter.HeterogeneousWorkerPool(workers(), max_per_worker)
end

@everywhere function work()
    s = 0.0
    for i in 1:2000000000
        s += rand() * 2 - 1
    end
    return s
end

@everywhere function test_fn(index)
    start_time = now()
    sleep(1)
    s = work()
    end_time = now()
    return start_time, end_time
end


function test_no_pool()
    per_worker = 2
    idxs = collect(1:2*per_worker*length(workers()))
    results = map(test_fn, idxs)

    for (i, pair) in enumerate(results)
        @info "($(i)/$(length(idxs)))\tStart time: $(pair[1])\t\tEnd time: $(pair[2])"
    end
end
function test()
    per_worker = 2
    pool = init_pool(per_worker)
    idxs = collect(1:2*per_worker*length(workers()))
    results = pmap(test_fn, pool, idxs)

    for (i, pair) in enumerate(results)
        @info "($(i)/$(length(idxs)))\tStart time: $(pair[1])\t\tEnd time: $(pair[2])"
    end
end