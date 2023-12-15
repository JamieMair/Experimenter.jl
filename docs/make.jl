using Experimenter
using Documenter

DocMeta.setdocmeta!(Experimenter, :DocTestSetup, :(using Experimenter); recursive=true)

makedocs(;
    modules=[Experimenter],
    authors="Jamie Mair <JamieMair@users.noreply.github.com> and contributors",
    sitename="Experimenter.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://JamieMair.github.io/Experimenter.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "Running your Experiments" => "execution.md",
        "Distributed Execution" => "distributed.md",
        "Data Store" => "store.md",
        "Custom Snapshots" => "snapshots.md",
        "Cluster Support" => "clusters.md",
        "Public API" => "api.md"
    ],
)

deploydocs(;
    repo="github.com/JamieMair/Experimenter.jl"
)
