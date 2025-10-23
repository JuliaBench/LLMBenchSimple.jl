module SimpleBenchmarks

using LLMBenchSimple

# Define some simple benchmarks
@bench "addition" prompt"What is 2 + 2?" == "4"
@bench "multiplication" prompt"What is 3 * 3?" == "9"
@bench "sin_problem" parse(Float64, prompt"Compute sin(π/2) to 2 decimal places") ≈ 1.0 atol=0.01

end # module