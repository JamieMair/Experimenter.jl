using Experimenter
db = open_db("experiments.db")
trials = get_trials_by_name(db, "Test Experiment")

for (i, t) in enumerate(trials)
    worker = t.results[:mpi_worker]
    hostname = t.results[:hostname]
    println("Trial $i ran on worker $worker on host $hostname")
end