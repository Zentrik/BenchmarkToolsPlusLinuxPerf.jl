module LinuxPerfIntegrationTests

using Test
using BenchmarkToolsPlusLinuxPerf
using LinuxPerf

### Serialization Test ###
b = @benchmarkable sin(1) enable_customisable_func = :LAST
tune!(b)
bb = run(b)

function eq(x::T, y::T) where {T<:Union{values(BenchmarkTools.SUPPORTED_TYPES)...}}
    return all(i -> eq(getfield(x, i), getfield(y, i)), 1:fieldcount(T))
end
function eq(x::BenchmarkTools.Parameters, y::BenchmarkTools.Parameters)
    return all(
        i -> eq(getfield(x, i), getfield(y, i)),
        1:fieldcount(BenchmarkTools.Parameters),
    )
end
eq(x::T, y::T) where {T} = x == y
function eq(x::LinuxPerf.Stats, y::LinuxPerf.Stats)
    return all(a -> eq(a[1], a[2]), zip(x.threads, y.threads))
end
function eq(x::LinuxPerf.ThreadStats, y::LinuxPerf.ThreadStats)
    return x.pid == y.pid && x.groups == y.groups
end
function eq(x::Function, y::Function)
    x == BenchmarkTools._nothing_func
end
function withtempdir(f::Function)
    d = mktempdir()
    try
        cd(f, d)
    finally
        rm(d; force = true, recursive = true)
    end
    return nothing
end
withtempdir() do
    tmp = joinpath(pwd(), "tmp.json")

    BenchmarkTools.save(tmp, b.params, bb)
    @test isfile(tmp)

    results = BenchmarkTools.load(tmp)
    @test results isa Vector{Any}
    @test length(results) == 2
    @test eq(results[1], b.params)
    @test eq(results[2], bb)
end

##################################
# Linux Perf Integration #
##################################

b = @benchmarkable sin($(Ref(42.0))[])
results = run(b; seconds = 1, enable_customisable_func = :FALSE)
@test results.customisable_result === nothing

b = @benchmarkable sin($(Ref(42.0))[])
results = run(b; seconds = 1)
@test results.customisable_result !== nothing
@test any(results.customisable_result.threads) do thread
    instructions = LinuxPerf.scaledcount(thread["instructions"])
    !isnan(instructions) && instructions > 10
end

b = @benchmarkable sin($(Ref(42.0))[])
results = run(b; seconds = 1, enable_customisable_func = :LAST, evals = 10^3)
@test results.customisable_result !== nothing
@test any(results.customisable_result.threads) do thread
    instructions = LinuxPerf.scaledcount(thread["instructions"])
    !isnan(instructions) && instructions > 10^4
end

#########
# setup #
#########

groups = BenchmarkGroup()
groups["sum"] = BenchmarkGroup(["arithmetic"])
groups["sin"] = BenchmarkGroup(["trig"])
groups["special"] = BenchmarkGroup()

sizes = (5, 10, 20)

for s in sizes
    A = rand(s, s)
    groups["sum"][s] = @benchmarkable sum($A) seconds = 3
    groups["sin"][s] = @benchmarkable(sin($s), seconds = 1, gctrial = false)
end

groups["special"]["macro"] = @benchmarkable @test(1 == 1)
groups["special"]["nothing"] = @benchmarkable nothing
groups["special"]["block"] = @benchmarkable begin
    rand(3)
end
groups["special"]["comprehension"] = @benchmarkable [s^2 for s in sizes]

tune!(groups)
results = run(groups; enable_customisable_func = :LAST)
for (name, group_results) in BenchmarkTools.leaves(results)
    @test group_results.customisable_result !== nothing
    @test any(group_results.customisable_result.threads) do thread
        instructions = LinuxPerf.scaledcount(thread["instructions"])
        !isnan(instructions) && instructions > 10^3
    end
end

end
