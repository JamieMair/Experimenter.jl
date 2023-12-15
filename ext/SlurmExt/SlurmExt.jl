module SlurmExt

############ Module dependencies ############
if isdefined(Base, :get_extension)
    using Experimenter
    using Distributed
    using ClusterManagers
else
    using ..Experimenter
    using ..Distributed
    using ..ClusterManagers
end


############     Module Code     ############
function Experimenter.Cluster.init_slurm(; sysimage_path::Union{String, Nothing}=nothing)
    @info "Setting up SLURM"
    # Setup SLURM
    num_tasks = parse(Int, ENV["SLURM_NTASKS"])
    cpus_per_task = parse(Int, ENV["SLURM_CPUS_PER_TASK"])
    @info "Using $cpus_per_task threads on each worker"
    exeflags = ["--project", "-t$cpus_per_task"]
    if !isnothing(sysimage_path)
        @info "Using the sysimage: $sysimage_path"
        push!(exeflags, "--sysimage")
        push!(exeflags, "\"$sysimage_path\"")
    end
    addprocs(SlurmManager(num_tasks); exeflags=exeflags, topology=:master_worker)
    
    @info "SLURM workers launched: $(length(workers()))"
end

# @doc """
# init_slurm(; sysimage_path=nothing)

# Spins up all the processes as indicated by the SLURM environment variables.

# # Arguments

# - `sysimage_path`: A path to the sysimage that the workers should use to avoid unneccessary precompilation
# """ Experimenter.Cluster.init_slurm


end