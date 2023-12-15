using Experimenter
db = open_db("experiments.db")
trials = get_trials_by_name(db, "Test Experiment")

for (i, t) in enumerate(trials)
    hostname = t.results[:hostname]
    id = t.results[:pid]
    println("Trial $i ran on $hostname on worker $id")
end