using Serialization
using Logging
import Base: UUID

function send_variable_message(comm, data, dest; tag=MPI.ANY_TAG, should_block=false)
    if tag == MPI.ANY_TAG # Override any tag
        tag = 0117
    end
    send_req = MPI.isend(data, comm; dest, tag=tag)
    if should_block
        MPI.wait(send_req)
    end
    return nothing
end
function recieve_variable_message(comm; source=MPI.ANY_SOURCE, tag=MPI.ANY_TAG)
    x, status = MPI.recv(comm, MPI.Status; source, tag)
    return x, status.source
end


abstract type AbstractRequest end
abstract type AbstractResponse end

struct JobRequest <: AbstractRequest
    from::Int
    num_jobs::Int
end
struct GetLatestSnapshotRequest <: AbstractRequest
    from::Int
    trial_id::UUID
end
struct SaveSnapshotRequest <: AbstractRequest
    trial_id::UUID
    state::Dict{Symbol, Any}
    label::Union{Missing, String}
end
struct GetResultsRequest <: AbstractRequest
    from::Int
    trial_id::UUID
end

struct SnapshotResponse <: AbstractResponse
    snapshot::Union{Missing, Experimenter.Snapshot}
end
struct ResultsResponse <: AbstractResponse
    results::Union{Missing, Dict{Symbol, Any}}
end

struct JobResponse
    num_jobs::Int
    trial_details::Vector{Tuple{UUID, Dict{Symbol, Any}}}
end

struct SaveRequest <: AbstractRequest
    from::Int
    trial_results::Vector{Tuple{UUID, Dict{Symbol, Any}}}
end

struct NoMoreJobsResponse <: AbstractResponse end


mutable struct Coordinator
    comm::MPI.Comm
    num_jobs::Int
    job_id::Int
    num_saved::Int
    num_workers_closed::Int
    num_workers::Int
    experimenter::Experimenter.Experiment
    trials::Vector{Experimenter.Trial}
    database::Experimenter.ExperimentDatabase
end

mutable struct WorkerNode
    comm::MPI.Comm
    mpi_rank::Int
    has_stopped::Bool
    jobs_completed::Int
    run_fn::Function
end


function handle_request!(::Coordinator, request::AbstractRequest)
    @warn "[COORDINATOR] Recieved request of type $(typeof(request)), with no implementation"
end
function handle_response!(worker::WorkerNode, response::AbstractResponse)
    @warn "[WORKER $(worker.mpi_rank)] Recieved response of type $(typeof(response)), with no implementation"
end

function handle_response!(worker::WorkerNode, ::NoMoreJobsResponse)
    worker.has_stopped = true
    @debug "[WORKER $(worker.mpi_rank)] Finished."
    nothing
end
function handle_response!(worker::WorkerNode, response::JobResponse)
    results = map(response.trial_details) do (trial_id, configuration)
        result = worker.run_fn(configuration, trial_id)
        worker.jobs_completed += 1
        return (trial_id, result)
    end
    save_req = SaveRequest(worker.mpi_rank, results)
    send_variable_message(worker.comm, save_req, 0)
    @debug "[WORKER $(worker.mpi_rank)] Completed $(response.num_jobs) jobs."
    nothing
end
function send_quit_response!(coordinator::Coordinator, target::Int)
    coordinator.num_workers_closed += 1
    send_variable_message(coordinator.comm, NoMoreJobsResponse(), target)

    @debug "[COORDINATOR] No more jobs to send to Worker $(target)."
end
function handle_request!(coordinator::Coordinator, request::JobRequest)
    job_id = coordinator.job_id

    n = request.num_jobs
    n = min(length(coordinator.trials)-job_id+1, n)

    target = request.from
    if n == 0 # If there are no more jobs left, tell requesting node
        send_quit_response!(coordinator, target)
        return nothing
    end

    trial_data = map(job_id:(job_id+n-1)) do id
        t = coordinator.trials[id]
        (t.id, t.configuration)
    end
    response = JobResponse(n, trial_data)
    send_variable_message(coordinator.comm, response, target)
    @debug "[COORDINATOR] Sent $(n) jobs to Worker $(target)."

    coordinator.job_id = job_id + n
    nothing
end
function handle_request!(coordinator::Coordinator, request::SaveRequest)
    results = request.trial_results
    @debug "[COORDINATOR] Recieved $(length(results)) results from Worker $(request.from)."

    for (trial_id, result) in results
        Experimenter.complete_trial!(coordinator.database, trial_id, result)
    end

    nothing
end

# Snapshots
function handle_request!(coordinator::Coordinator, request::GetLatestSnapshotRequest)
    @debug "[COORDINATOR] Recieved latest snapshot request from Worker $(request.from)."

    snapshot = Experimenter.latest_snapshot(coordinator.database, request.trial_id)

    send_variable_message(coordinator.comm, SnapshotResponse(snapshot), request.from)
    nothing
end
function handle_request!(coordinator::Coordinator, request::SaveSnapshotRequest)
    @debug "[COORDINATOR] Recieved save snapshot request from Worker $(request.from)."

    Experimenter.save_snapshot!(coordinator.database, request.trial_id, request.state, request.label)
    nothing
end
function handle_request!(coordinator::Coordinator, request::GetResultsRequest)
    @debug "[COORDINATOR] Recieved save snapshot request from Worker $(request.from)."

    trial = get_trial(coordinator.database, request.trial_id)
    results = trial.results
    
    send_variable_message(coordinator.comm, ResultsResponse(results), request.from)
    nothing
end