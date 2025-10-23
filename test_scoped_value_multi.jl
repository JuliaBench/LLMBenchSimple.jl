#!/usr/bin/env julia

# Test that the scoped value works correctly when called from different contexts

# Don't set LLMBENCH_WORKSPACE initially
if haskey(ENV, "LLMBENCH_WORKSPACE")
    delete!(ENV, "LLMBENCH_WORKSPACE")
end

using LLMBenchSimple

# Define a simple test benchmark
module TestBench
using LLMBenchSimple

@bench "test1" begin
    workdir = llmbench_workdir()
    println("  In test1 setup, workdir = $workdir")

    promptval"What is 2+2?"

    workdir = llmbench_workdir()
    println("  In test1 grade, workdir = $workdir")
    var"##answer##" == 4
end
end

println("Test: Multiple workdirs with scoped values")
println("=" ^ 50)

# Test setup with different workdirs
println("\n1. Setting up in /tmp/workspace1")
result1 = TestBench.setup_problem("/tmp/workspace1", "test1")
println("  Setup returned: ", result1[1:min(50, length(result1))] * "...")

println("\n2. Setting up in /tmp/workspace2")
result2 = TestBench.setup_problem("/tmp/workspace2", "test1")
println("  Setup returned: ", result2[1:min(50, length(result2))] * "...")

# Test grading with different workdirs
println("\n3. Grading with /tmp/workspace1")
grade1 = TestBench.grade("/tmp/workspace1", "assistant: 4", "test1")
println("  Grade score: ", grade1["score"])

println("\n4. Grading with /tmp/workspace2")
grade2 = TestBench.grade("/tmp/workspace2", "assistant: 4", "test1")
println("  Grade score: ", grade2["score"])

# Test that llmbench_workdir() without context fails
println("\n5. Testing llmbench_workdir() without context:")
try
    workdir = llmbench_workdir()
    println("  ERROR: Should have failed but got: $workdir")
catch e
    println("  ✓ Correctly threw error: ", split(string(e), '\n')[1])
end

println("\n✓ Test completed successfully!")