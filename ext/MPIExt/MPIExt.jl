module MPIExt

############ Module dependencies ############
if isdefined(Base, :get_extension)
    using Experimenter
    using MPI
else
    using ..Experimenter
    using ..MPI
end

include("utils.jl")


############     Module Code     ############
function Experimenter.Cluster.init_mpi()
    # Setup SLURM
    MPI.Init(; threadlevel=:multiple)
    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank(comm)
    comm_size = MPI.Comm_size(comm)
    if comm_size < 2
        error("Not enough MPI processes were launched to run experiments in MPI mode. MPI mode requires at least two processes.")
        exit(1)
    end

    if rank == 0
        @info "Initialised MPI with $(comm_size-1) workers and 1 coordinator."
    end
end

function Experimenter._mpi_run_job(runner::Experimenter.Runner, trials::AbstractArray{Experimenter.Trial})
    @assert runner.execution_mode isa MPIMode
    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank(comm)
    if rank == 0
        coordinator_loop(runner.experiment, runner.database, trials)
    else
        @warn "[WORKER $(rank)] Reached a function that it should not be able to reach."
    end
end

function Experimenter._mpi_worker_loop(batch_size::Int, trial_fn::Function)
    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank(comm)
    if rank == 0
        error("The first process is reserved for the coordinator and cannot be a worker.")
    end

    worker = WorkerNode(
        comm,
        rank,
        false,
        0,
        trial_fn
    )

    job_size = batch_size
    job_request = JobRequest(worker.mpi_rank, job_size)

    @debug "[WORKER $(rank)] Loaded."

    while !worker.has_stopped
        @debug "[WORKER $(rank)] Loaded."
        send_variable_message(worker.comm, job_request, 0; should_block = true)
        response, source = recieve_variable_message(worker.comm)
        handle_response!(worker, response)
    end

    MPI.Finalize()
end

function coordinator_loop(experiment::Experiment, db::ExperimentDatabase, trials::AbstractArray{Experimenter.Trial})
    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank(comm)
    if rank != 0
        error("The coordinator job should be run on the first process.")
    end
    comm_size = MPI.Comm_size(comm)
    coordinator = Coordinator(
        comm,
        length(trials),
        1,
        0,
        0,
        comm_size-1,
        experiment,
        trials,
        db
    )

    @info "[COORDINATOR] $(comm_size - 1) workers ready. Starting experiment with $(length(trials)) trials."

    while coordinator.num_workers_closed != coordinator.num_workers
        # Listen for messages
        request, _ = recieve_variable_message(coordinator.comm)
        handle_request!(coordinator, request)
    end

    @info "[COORDINATOR] Finished."

    MPI.Finalize()
end

end