module Cluster
    function init_slurm_support()
        @eval Main using ClusterManagers
        if isdefined(Base, :get_extension)
            @eval Main Base.retry_load_extensions()
        end
    end
    function install_slurm_support()
        @eval Main import Pkg
        @eval Main Pkg.add(["ClusterManagers"])
    end
    function init_mpi_support()
        @eval Main using MPI
        if isdefined(Base, :get_extension)
            @eval Main Base.retry_load_extensions()
        end
    end
    function install_mpi_support()
        @eval Main import Pkg
        @eval Main Pkg.add(["MPI"])
    end

    function _try_detect_mpi()
        haskey(ENV, "OMPI_COMM_WORLD_RANK") && return true
        haskey(ENV, "PMI_RANK") && return true
        haskey(ENV, "MV2_COMM_WORLD_RANK") && return true
        return false
    end


    function _is_master_mpi_node()
        if _try_detect_mpi()
            haskey(ENV, "OMPI_COMM_WORLD_RANK") && return parse(Int, ENV["OMPI_COMM_WORLD_RANK"]) == 0
            haskey(ENV, "PMI_RANK") && return parse(Int, ENV["PMI_RANK"]) == 0
            haskey(ENV, "MV2_COMM_WORLD_RANK") && return parse(Int, ENV["MV2_COMM_WORLD_RANK"]) == 0
        end

        return true
    end

    function _is_mpi_worker_node()
        if _try_detect_mpi()
            is_master = is_master()
            return !is_master
        else
            return false
        end
    end

    """
        init(; kwargs...)

    Checks the environment variables to see if a script is running on a cluster 
    and then launches the processes as determined by the environment variables.

    # Arguments

    The keyword arguments are forwarded to the init function for each cluster
    management system. Check the `ext` folder for extensions to see which
    keywords are supported.
    """
    function init(; force_mpi=false, force_slurm=false, kwargs...)
        (force_mpi && force_slurm) && error("Must set only one of `force_mpi` and `force_slurm` to true at a time.")
        if !force_slurm && (force_mpi || _try_detect_mpi())
            @eval Main Experimenter.Cluster.init_mpi_support()
            @eval Main Experimenter.Cluster.init_mpi(; $(kwargs)...)
        elseif force_slurm || haskey(ENV, "SLURM_JOB_NAME")
            @eval Main Experimenter.Cluster.init_slurm_support()
            @eval Main Experimenter.Cluster.init_slurm(; $(kwargs)...)
        else
            @info "Cluster not detected, doing nothing."
        end
    end

    """
        create_slurm_template(file_loc; job_logs_dir="hpc/logs")

    Creates a template bash script at the supplied file location and
    creates the log directory used for the outputs. You should modify
    this script to adjust the resources required.
    """
    function create_slurm_template(file_loc::AbstractString;
        job_logs_dir::AbstractString="hpc/logs")

        log_dir = joinpath(dirname(file_loc), job_logs_dir)
        if !isdir(log_dir) && isdirpath(log_dir)
            @info "Creating directory at $log_dir to store the log files"
            mkdir(log_dir)
        end


        file_contents = """#!/bin/bash

        #SBATCH --nodes=1
        #SBATCH --ntasks=1
        #SBATCH --cpus-per-task=2
        #SBATCH --mem-per-cpu=1024
        #SBATCH --time=00:30:00
        #SBATCH -o $log_dir/job_%j.out
        #SBATCH --partition=compute

        # Change below to load version of Julia used
        module load julia

        # Change directory if needed
        # cd "experiments"

        julia --project myscript.jl --threads=1

        # Optional: Remove the files created by ClusterManagers.jl
        # rm -fr julia-*.out
        """

        open(file_loc, "w") do io
            print(io, file_contents)
        end

        @info "Wrote template file to $(abspath(file_loc))"

        nothing
    end
    function init_slurm end
    function init_mpi end

    export init, install_slurm_support, init_slurm_support
end