using Aqua
using BenchmarkToolsPlusLinuxPerf
using JuliaFormatter
using Test

if parse(Bool, get(ENV, "TEST_PERF_INTEGRATION", "true"))
    print("Testing Perf integration...")
    took_seconds = @elapsed include("IntegrationTests.jl")
    println("done (took ", took_seconds, " seconds)")
end

if parse(Bool, get(ENV, "TEST_PERF_INTEGRATION", "true"))
    print("Testing BaseBenchmarks integration...")
    took_seconds = @elapsed include("BaseBenchmarkIntegrationTests.jl")
    println("done (took ", took_seconds, " seconds)")
end

print("Testing code quality...")
took_seconds = @elapsed Aqua.test_all(BenchmarkToolsPlusLinuxPerf, piracies = false)
println("done (took ", took_seconds, " seconds)")

if VERSION >= v"1.6"
    print("Testing code formatting...")
    took_seconds = @elapsed @test JuliaFormatter.format(
        BenchmarkToolsPlusLinuxPerf;
        verbose = false,
        overwrite = false,
    )
    println("done (took ", took_seconds, " seconds)")
end
