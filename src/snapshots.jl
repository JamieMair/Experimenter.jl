module Snapshots
using UUIDs
using Base
using DataFrames
using SQLite

Base.@kwdef struct Snapshot{L<:Union{Missing,AbstractString}, D<:Union{Missing,AbstractString}}
    id::UUID = uuid4()
    trial_id::UUID
    state::Dict{Symbol, Any}
    label::L = missing
    created_at::D = missing
end 

const snapshot_table_query = raw"""
CREATE TABLE IF NOT EXISTS Snapshots (
    id TEXT NOT NULL PRIMARY KEY,
    trial_id TEXT NOT NULL,
    state BLOB,
    label TEXT,
    created_at DATETIME DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now')),
    FOREIGN KEY (trial_id) REFERENCES Trials (id)
        ON DELETE NO ACTION ON UPDATE NO ACTION
);
"""

function get_snapshot_insert_stmt(db::SQLite.DB)
    sql = raw"""
    INSERT INTO Snapshots (id, trial_id, state, label) VALUES (?, ?, ?, ?)
    """
    return SQLite.Stmt(db, sql)
end


Snapshot(row::DataFrameRow) = Snapshot(
    id=UUID(row.id),
    trial_id=UUID(row.trial_id),
    state=row.state,
    label=row.label,
    created_at=row.created_at
)

export Snapshot


end