using SQLite
using Logging
using Base
using UUIDs
using DataFrames
using .Snapshots
import Serialization

"""
A struct containing the connections and queries needed to insert data into the database. Should not be created manually but by using `open_db`.
"""
struct ExperimentDatabase
    experiment_folder::AbstractString
    database_name::AbstractString
    _db::SQLite.DB
    _experimentInsertStmt::SQLite.Stmt
    _trialInsertStmt::SQLite.Stmt
    _snapshotInsertStmt::SQLite.Stmt
end

function get_experiment_insert_stmt(db::SQLite.DB)
    sql = raw"""
    INSERT OR IGNORE INTO Experiments (id, name, include_file, function_name, init_store_function_name, configuration, num_trials) VALUES (?, ?, ?, ?, ?, ?, ?)
    """
    return SQLite.Stmt(db, sql)
end
function get_trial_insert_stmt(db::SQLite.DB)
    sql = raw"""
    INSERT OR IGNORE INTO Trials (id, experiment_id, configuration, results, trial_index, has_finished) VALUES (?, ?, ?, ?, ?, ?)
    """
    return SQLite.Stmt(db, sql)
end
function Base.push!(db::ExperimentDatabase, experiment::Experiment)
    vs = (string(experiment.id), experiment.name, experiment.include_file, experiment.function_name, experiment.init_store_function_name, experiment.configuration, experiment.num_trials)
    SQLite.execute(db._experimentInsertStmt, vs)
    nothing
end
function Base.push!(db::ExperimentDatabase, trial::Trial)
    vs = (string(trial.id), string(trial.experiment_id), trial.configuration, trial.results, trial.trial_index, trial.has_finished)
    SQLite.execute(db._trialInsertStmt, vs)
    nothing
end
function Base.push!(db::ExperimentDatabase, snapshot::Snapshot)
    vs = (string(snapshot.id), string(snapshot.trial_id), snapshot.state, snapshot.label, snapshot.created_at)
    SQLite.execute(db._snapshotInsertStmt, vs)
    nothing
end


Experiment(row::DataFrameRow) = Experiment(UUID(row.id), row.name, row.include_file, row.function_name, row.init_store_function_name, row.configuration, row.num_trials)
Trial(row::DataFrameRow) = Trial(
    id=UUID(row.id),
    experiment_id=UUID(row.experiment_id),
    configuration=row.configuration,
    results=row.results,
    trial_index=row.trial_index,
    has_finished=row.has_finished
)

function prepare_db(db::SQLite.DB)
    # Create a table for the experiments
    experiments_query = raw"""
    CREATE TABLE IF NOT EXISTS Experiments (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        include_file TEXT,
        function_name TEXT,
        init_store_function_name TEXT,
        configuration BLOB,
        num_trials INTEGER NOT NULL
    );
    """

    trials_query = raw"""
    CREATE TABLE IF NOT EXISTS Trials (
        id TEXT NOT NULL PRIMARY KEY,
        experiment_id TEXT NOT NULL,
        configuration BLOB,
        results BLOB,
        trial_index INTEGER NOT NULL,
        has_finished BOOLEAN NOT NULL, 
        FOREIGN KEY (experiment_id) REFERENCES Experiments (id)
            ON DELETE CASCADE ON UPDATE CASCADE
    );
    """

    snapshots_query = Snapshots.snapshot_table_query

    # Allow foreign keys
    SQLite.execute(db, "PRAGMA foreign_keys = ON;")

    SQLite.execute(db, experiments_query)
    SQLite.execute(db, trials_query)
    SQLite.execute(db, snapshots_query)
    nothing
end

"""
    open_db(database_name, [experiment_folder, create_folder]; in_memory=false)

Opens a database and prepares it with the Experimenter.jl schema with tables for Experiment, Trial and Snapshot.
If the database already exists, it will open it and not overwrite the existing data.

Setting `in_memory` to `true` will skip all of the arguments and create the database "in memory" and hence, will not persist.
"""
function open_db(database_name, experiment_folder=joinpath(pwd(), "experiments"), create_folder=true; in_memory=false)::Union{Nothing, ExperimentDatabase}

    if !Cluster._is_master_mpi_node()
        return nothing
    end

    if !in_memory && (!Base.Filesystem.isdir(experiment_folder))
        if create_folder
            @info "Creating $experiment_folder for experiments folder."
            Base.Filesystem.mkdir(experiment_folder)
        else
            error_msg = "$experiment_folder does not exist for database, and create_folder is set to false."
            @error error_msg
            error(error_msg)
        end
    end
    _sqliteDB = in_memory ? SQLite.DB() : SQLite.DB(joinpath(experiment_folder, database_name))
    prepare_db(_sqliteDB)
    experiment_stmt = get_experiment_insert_stmt(_sqliteDB)
    trial_stmt = get_trial_insert_stmt(_sqliteDB)
    snapshot_stmt = Snapshots.get_snapshot_insert_stmt(_sqliteDB)
    db = ExperimentDatabase(experiment_folder, database_name, _sqliteDB, experiment_stmt, trial_stmt, snapshot_stmt)

    return db
end

"""
    get_experiment(db::ExperimentDatabase, experiment_id)

Searches the db for the given `experiment_id` which can be given as a string or UUID.
"""
function get_experiment(db::ExperimentDatabase, experiment_id)
    experiment_id = SQLite.esc_id(string(experiment_id))
    df = _deserialize_columns(SQLite.DBInterface.execute(db._db, "SELECT * FROM Experiments WHERE id = $experiment_id") |> DataFrame)
    return Experiment(first(eachrow(df)))
end

"""
    get_experiment(db::ExperimentDatabase, name)

Searches the db for an experiment with the experiment name set to `name`. Returns that experiment.
"""
function get_experiment_by_name(db::ExperimentDatabase, name)
    name = SQLite.esc_id(string(name))
    df = _deserialize_columns(SQLite.DBInterface.execute(db._db, "SELECT * FROM Experiments WHERE name = $name") |> DataFrame)
    return Experiment(first(eachrow(df)))
end

"""
    get_progress(db::ExperimentDatabase, name)

Returns a table of the trials of an experiment, identified by the name parameter. Returns details of the progress and configuration, but not the results.
"""
function get_progress(db::ExperimentDatabase, name)
    name = SQLite.esc_id(string(name))

    df = _deserialize_columns(SQLite.DBInterface.execute(db._db, "SELECT Trials.id, Experiments.id as experiment_id, Experiments.name as name, Trials.configuration, Trials.has_finished FROM Trials INNER JOIN Experiments ON Trials.experiment_id=Experiments.id WHERE Experiments.name = $name") |> DataFrame)
    return df
end


function check_overlap(experimentA::Experiment, experimentB::Experiment)
    if experimentA.name !== experimentB.name
        return false
    elseif experimentA.function_name !== experimentB.function_name
        return false
    elseif experimentA.num_trials !== experimentB.num_trials
        return false
    elseif experimentA.init_store_function_name !== experimentB.init_store_function_name
        return false
    else
        trials_a = collect(experimentA)
        trials_b = collect(experimentB)

        for (a, b) in zip(trials_a, trials_b)
            if a.configuration != b.configuration
                return false
            end
        end
    end

    return true
end

"""
    restore_from_db(db::ExperimentDatabase, experiment::Experiment)

Searches the `db` for the supplied experiment, matching on the configuration and the name, disregarding the unique ID.

If experiment already exists in the db, returns that experiment with the db's UUID for it, otherwise return the input experiment.

Will error if the experiment exists but does not match the input experiment configuration.
"""
function restore_from_db(db::ExperimentDatabase, experiment::Experiment)
    name = SQLite.esc_id(string(experiment.name))
    df = _deserialize_columns(SQLite.DBInterface.execute(db._db, "SELECT * FROM Experiments WHERE name = $name") |> DataFrame)
    if length(eachrow(df)) > 0
        existing_experiment = Experiment(first(eachrow(df)))
        if (!check_overlap(experiment, existing_experiment))
            error("Found existing experiment with name \"$(experiment.name)\", but with different parameters. Use a different name.")
        end
        return existing_experiment
    end

    return experiment
end

"""
    get_experiments(db::ExperimentDatabase)

Returns a vector of all experiments in the database.
"""
function get_experiments(db::ExperimentDatabase)
    df = _deserialize_columns(SQLite.DBInterface.execute(db._db, "SELECT * FROM Experiments") |> DataFrame)
    return [Experiment(row) for row in eachrow(df)]
end

function _deserialize_columns(df::DataFrame)
    for colname in names(df)
        col = df[!, colname]
        if eltype(col) <: Vector{UInt8} # raw binary
            df[!, colname] = map(col) do c
                io = IOBuffer(c)
                obj = Serialization.deserialize(io)
                if typeof(obj) <: SQLite.Serialized
                    return obj.object
                else
                    return obj
                end
            end
        end
    end
    return df
end


"""
    get_trial(db::ExperimentDatabase, trial_id)

Gets the trial with the matching `trial_id` (string or UUID) from the database.
"""
function get_trial(db::ExperimentDatabase, trial_id)
    trial_id = SQLite.esc_id(string(trial_id))
    df = _deserialize_columns(SQLite.DBInterface.execute(db._db, "SELECT * FROM Trials WHERE id = $trial_id") |> DataFrame)
    return Trial(first(eachrow(df)))
end
"""
    get_trial(db::ExperimentDatabase, experiment_id)

Gets all trials from the database under the `experiment_id` supplied.
"""
function get_trials(db::ExperimentDatabase, experiment_id)
    experiment_id = SQLite.esc_id(string(experiment_id))
    df = _deserialize_columns(SQLite.DBInterface.execute(db._db, "SELECT * FROM Trials WHERE experiment_id = $experiment_id ORDER BY trial_index ASC") |> DataFrame)
    return [Trial(row) for row in eachrow(df)]
end
"""
    get_trials_by_name(db::ExperimentDatabase, name)

Gets all trials from the database for the experiment with the name `name`.
"""
function get_trials_by_name(db::ExperimentDatabase, name)
    sql = raw"""
    SELECT name, Trials.id as id, experiment_id, Trials.configuration as configuration, results, trial_index, has_finished 
    FROM Trials 
    INNER JOIN Experiments ON Experiments.id == Trials.experiment_id 
    WHERE name = ? 
    ORDER BY trial_index
    """
    df = _deserialize_columns(SQLite.DBInterface.execute(db._db, sql, (name,)) |> DataFrame)
    return [Trial(row) for row in eachrow(df)]
end
"""
    get_trials_ids_by_name(db::ExperimentDatabase, name)

Gets just the trial IDs from the database for the experiment with the name `name`.
"""
function get_trials_ids_by_name(db::ExperimentDatabase, name)
    sql = raw"""
    SELECT name, Trials.id as id, trial_index 
    FROM Trials 
    INNER JOIN Experiments ON Experiments.id == Trials.experiment_id 
    WHERE name = ? 
    ORDER BY trial_index
    """
    df = _deserialize_columns(SQLite.DBInterface.execute(db._db, sql, (name,)) |> DataFrame)
    return [UUID(row.id) for row in eachrow(df)]
end

"""
    get_ratio_completed_trials_by_name(db::ExperimentDatabase, name)

Calculates the ratio of completed trials for the given experiment with name `name`, without fetching the results.
"""
function get_ratio_completed_trials_by_name(db::ExperimentDatabase, name)
    sql = raw"""
    SELECT Avg(CAST(has_finished as REAL)) as ratio_finished
    FROM Trials
    INNER JOIN Experiments ON Experiments.id == Trials.experiment_id 
    WHERE name = ?
    """
    df = _deserialize_columns(SQLite.DBInterface.execute(db._db, sql, (name,)) |> DataFrame)
    return first([row.ratio_finished for row in eachrow(df)])
end

"""
    complete_trial!(db::ExperimentDatabase, trial_id::UUID, results::Dict{Symbol,Any})

Marks a specific trial (with `trial_id`) complete in the database and stores the supplied `results`.
"""
function complete_trial!(db::ExperimentDatabase, trial_id::UUID, results::Dict{Symbol,Any})
    stmt = SQLite.Stmt(db._db, "UPDATE Trials SET results = @results, has_finished = @finished WHERE id = @id")
    vs = Dict{Symbol,Any}(:results => results, :finished => true, :id => string(trial_id))
    DBInterface.execute(stmt, vs)
    nothing
end
"""
    mark_trial_as_incomplete!(db::ExperimentDatabase, trial_id)

Marks a specific trial (with `trial_id`) as incomplete, which means it will run again from scratch upon the next execution.
"""
function mark_trial_as_incomplete!(db::ExperimentDatabase, trial_id)
    stmt = SQLite.Stmt(db._db, "UPDATE Trials SET has_finished = @finished WHERE id = @id")
    vs = Dict{Symbol,Any}(:finished => false, :id => string(trial_id))
    DBInterface.execute(stmt, vs)
    nothing
end
"""
    save_snapshot!(db::ExperimentDatabase, trial_id::UUID, state::Dict{Symbol,Any}, [label])

Saves the snapshot with given `state` in the database, associating with the trial with matching `trial_id`. Automatically saves the time of the snapshot.
"""
function save_snapshot!(db::ExperimentDatabase, trial_id::UUID, state::Dict{Symbol,Any}, label=missing)
    snapshot = Snapshots.Snapshot(trial_id=trial_id, state=state, label=label, created_at=time())
    push!(db, snapshot)
    nothing
end
"""
    latest_snapshot(db::ExperimentDatabase, trial_id)

Gets the latest snapshot from the database for a given trial with matching `trial_id`, using the date of the most recent snapshot.
    
Known to have issues when snapshots are created within the same second.
"""
function latest_snapshot(db::ExperimentDatabase, trial_id)
    trial_id = SQLite.esc_id(string(trial_id))
    df = _deserialize_columns(SQLite.DBInterface.execute(db._db, "SELECT * FROM Snapshots WHERE trial_id = $trial_id ORDER BY created_at DESC LIMIT 1") |> DataFrame)
    results = [Snapshot(row) for row in eachrow(df)]
    if length(results) == 0
        return nothing
    else
        return first(results)
    end
end

"""
    get_snapshots(db::ExperimentDatabase, trial_id)

Gets all the associated snapshots (as a vector) from the database for a given trial with matching `trial_id`.
"""
function get_snapshots(db::ExperimentDatabase, trial_id)
    trial_id = SQLite.esc_id(string(trial_id))
    df = _deserialize_columns(SQLite.DBInterface.execute(db._db, "SELECT * FROM Snapshots WHERE trial_id = $trial_id ORDER BY created_at DESC") |> DataFrame)
    results = [Snapshot(row) for row in eachrow(df)]
    return results
end


"""
    merge_databases!(primary_db, secondary_db)

Searches all of the records from the secondary database and adds them to the first database.
"""
function merge_databases!(primary_db::ExperimentDatabase, secondary_db::ExperimentDatabase)
    primary_experiments = get_experiments(primary_db)
    primary_experiment_dict = Dict{String,Experiment}(ex.name => ex for ex in primary_experiments)
    secondary_experiments = get_experiments(secondary_db)

    for experiment in secondary_experiments
        if haskey(primary_experiment_dict, experiment.name)
            @debug "Found $(experiment.name) in primary database."
            existing_experiment = primary_experiment_dict[experiment.name]
            if check_overlap(experiment, existing_experiment)
                primary_trials = get_trials_by_name(primary_db, experiment.name)
                secondary_trials = get_trials_by_name(secondary_db, experiment.name)

                for (a, b) in zip(primary_trials, secondary_trials)
                    if (!a.has_finished && b.has_finished)
                        # Add results from trials
                        @debug "Updating trial $(trial.trial_index) with results in primary database."
                        complete_trial!(primary_db, a.id, b.results)
                    end
                end
            else
                error("Experiment named '$(experiment.name)' found in primary database, but does not match configuration of the first.")
            end
        else
            new_trials = get_trials_by_name(secondary_db, experiment.name)
            push!(primary_db, experiment)
            for trial in new_trials
                push!(primary_db, trial)
            end
        end
    end

    df = _deserialize_columns(SQLite.DBInterface.execute(primary_db._db, "SELECT id FROM Snapshots") |> DataFrame)
    existing_snapshot_ids = Set(df.id)
    secondary_snapshots = [Snapshot(row) for row in eachrow(_deserialize_columns(SQLite.DBInterface.execute(secondary_db._db, "SELECT * FROM Snapshots") |> DataFrame))]
    

    for snapshot in secondary_snapshots
        if snapshot.id in existing_snapshot_ids
            continue
        end

        push!(primary_db, snapshot)
    end

    nothing
end
"""
    export_db(db::ExperimentDatabase, outfile::AbstractString, experiment_names...)

Opens a new database at `outfile` and inserts experiments from `db` into the new db, where the names of the experiment are listed in the final input.
"""
function export_db(db::ExperimentDatabase, outfile::AbstractString, experiment_names...)
    export_db = open_db(outfile, dirname(outfile))
    if isempty(experiment_names)
        experiments = get_experiments(db)
    else
        experiments = (x -> get_experiment_by_name(db, x)).(experiment_names)
    end

    for experiment in experiments
        push!(export_db, experiment)
        for trial in get_trials(db, experiment.id)
            push!(export_db, trial)

            for snapshot in get_snapshots(db, trial.id)
                push!(export_db, snapshot)
            end
        end
    end

    return export_db
end