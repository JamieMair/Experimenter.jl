using Experimenter
using Documenter

DocMeta.setdocmeta!(Experimenter, :DocTestSetup, :(using Experimenter); recursive=true)

makedocs(;
    modules=[Experimenter],
    authors="Jamie Mair <JamieMair@users.noreply.github.com> and contributors",
    repo="https://github.com/JamieMair/Experimenter.jl/blob/{commit}{path}#{line}",
    sitename="Experimenter.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://JamieMair.github.io/Experimenter.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "Custom Snapshots" => "snapshots.md",
        "Running your Experiments" => "execution.md",
        "Distributed Execution" => "distributed.md",
        "Public API" => "api.md"
    ],
)

deploydocs(;
    repo="github.com/JamieMair/Experimenter.jl",
    devbranch="main",
)
