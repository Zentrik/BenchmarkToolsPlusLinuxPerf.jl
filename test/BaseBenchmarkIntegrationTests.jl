module LinuxPerfIntegrationTests

using Test
using Pkg
Pkg.add(url="https://github.com/JuliaCI/BaseBenchmarks.jl")
using BenchmarkToolsPlusLinuxPerf, BaseBenchmarks, LinuxPerf

BaseBenchmarks.load!("problem")

res = @test_nowarn run(BaseBenchmarks.SUITE[["problem", "raytrace"]])["raytrace"]
@test !res.customisable_result_for_every_sample
@test minimum(res).time > 1e6
@test minimum(res).gctime >= 0
@test minimum(res).memory > 1e6
@test minimum(res).allocs > 1e5

@test res.customisable_result !== nothing
@test maximum(res).customisable_result == mean(res).customisable_result == minimum(res).customisable_result == res.customisable_result
@test any(res.customisable_result.threads) do thread
    instructions = LinuxPerf.scaledcount(thread["instructions"])
    !isnan(instructions) && instructions > 10^6
end
@test any(res.customisable_result.threads) do thread
    branch_instructions = LinuxPerf.scaledcount(thread["branch-instructions"])
    !isnan(branch_instructions) && branch_instructions > 10^5
end

results = @test_nowarn run(BaseBenchmarks.SUITE[@tagged "ziggurat" || "imdb" || "seismic"])
for (name, group_results) in BenchmarkTools.leaves(results)
    @test minimum(group_results).time > 1e3
    @test minimum(group_results).gctime >= 0
    @test minimum(group_results).memory > 1e3
    @test minimum(group_results).allocs >= 0

    @test group_results.customisable_result !== nothing
    @test maximum(group_results).customisable_result == mean(group_results).customisable_result == minimum(group_results).customisable_result == group_results.customisable_result
    @test any(group_results.customisable_result.threads) do thread
        instructions = LinuxPerf.scaledcount(thread["instructions"])
        !isnan(instructions) && instructions > 10^4
    end
    @test any(group_results.customisable_result.threads) do thread
        branch_instructions = LinuxPerf.scaledcount(thread["branch-instructions"])
        !isnan(branch_instructions) && branch_instructions > 10^3
    end
end

end
