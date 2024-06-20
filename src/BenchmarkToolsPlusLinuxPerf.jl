module BenchmarkToolsPlusLinuxPerf

using LinuxPerf, Reexport
using Compat: pkgversion
@reexport using BenchmarkTools

# Task clock has large overhead so is not useful for the short time we run functions under perf
# Further we benchmark anyways so no need for cycles or task clock
# I've tried to only use one group by getting rid of noisy or not useful metrics
function setup_prehook(params)
    linux_perf_groups = LinuxPerf.set_default_spaces(
        LinuxPerf.parse_groups("(instructions,branch-instructions)"),
        (true, false, false),
    )
    return LinuxPerf.make_bench_threaded(linux_perf_groups; threads = true)
end
teardown_posthook(_, linux_perf_bench) = close(linux_perf_bench)
sample_result(_, linux_perf_bench, _...) = LinuxPerf.Stats(linux_perf_bench)
prehook() = LinuxPerf.enable_all!()
posthook() = LinuxPerf.disable_all!()

# Recovers LinuxPerf.Stats from serialized form
BenchmarkTools.customisable_result_recover(d) = _convert(Union{Nothing,LinuxPerf.Stats}, d)
function _convert(::Type{Union{Nothing,LinuxPerf.Stats}}, d)
    if isnothing(d)
        return nothing
    end
    return LinuxPerf.Stats(_convert.(LinuxPerf.ThreadStats, d["threads"]))
end
function _convert(::Type{LinuxPerf.ThreadStats}, d::Dict{String})
    return LinuxPerf.ThreadStats(
        d["pid"],
        [
            [_convert(LinuxPerf.Counter, counter) for counter in group] for
            group in d["groups"]
        ],
    )
end
function _convert(::Type{LinuxPerf.Counter}, d::Dict{String})
    return LinuxPerf.Counter(
        _convert(LinuxPerf.EventType, d["event"]),
        d["value"],
        d["enabled"],
        d["running"],
    )
end
function _convert(::Type{LinuxPerf.EventType}, d::Dict{String})
    return LinuxPerf.EventType(d["category"], d["event"])
end

# Init
function __init__()
    BenchmarkTools.DEFAULT_PARAMETERS = BenchmarkTools.Parameters(;
        setup_prehook = setup_prehook,
        teardown_posthook = teardown_posthook,
        sample_result = sample_result,
        prehook = prehook,
        posthook = posthook,
        customisable_gcsample = true,
        enable_customisable_func = :LAST,
    )

    # Serialization
    BenchmarkTools.VERSIONS["LinuxPerf"] = pkgversion(LinuxPerf)
    BenchmarkTools.VERSIONS["BenchmarkToolsPlusLinuxPerf"] =
        pkgversion(BenchmarkToolsPlusLinuxPerf)
end

end # module BenchmarkToolsPlusLinuxPerf
