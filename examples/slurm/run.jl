using Random
using Distributed
function run_trial(config::Dict{Symbol,Any}, trial_id)
    results = Dict{Symbol, Any}()
    sigma = config[:sigma]
    N = config[:N]
    seed = config[:seed]
    rng = Random.Xoshiro(seed)
    # Perform some calculation
    results[:distance] = sum(rand(rng) * sigma for _ in 1:N)
    results[:num_threads] = Threads.nthreads()
    results[:hostname] = gethostname()
    results[:pid] = Distributed.myid()
    # Must return a Dict{Symbol, Any}, with the data we want to save
    return results
end