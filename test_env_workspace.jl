#!/usr/bin/env julia

# Test that LLMBENCH_WORKSPACE environment variable is properly picked up

using LLMBenchSimple

# Test 1: Without environment variable set
println("Test 1: Without LLMBENCH_WORKSPACE")
try
    workdir = LLMBenchSimple.llmbench_workdir()
    println("  ERROR: Should have thrown an error but got: $workdir")
catch e
    println("  ✓ Correctly threw error: ", split(string(e), '\n')[1])
end

# Test 2: With environment variable set
println("\nTest 2: With LLMBENCH_WORKSPACE set")
ENV["LLMBENCH_WORKSPACE"] = "/test/workspace"
workdir = LLMBenchSimple.llmbench_workdir()
if workdir == "/test/workspace"
    println("  ✓ Got workspace from environment: $workdir")
else
    println("  ERROR: Expected /test/workspace, got: $workdir")
end

# Test 3: With explicit context override
println("\nTest 3: With explicit context override")
LLMBenchSimple.with_workdir("/override/workspace") do
    workdir = LLMBenchSimple.llmbench_workdir()
    if workdir == "/override/workspace"
        println("  ✓ Got overridden workspace: $workdir")
    else
        println("  ERROR: Expected /override/workspace, got: $workdir")
    end
end

# Test 4: Environment variable still works after override
println("\nTest 4: Environment variable still works after override")
workdir = LLMBenchSimple.llmbench_workdir()
if workdir == "/test/workspace"
    println("  ✓ Environment workspace still active: $workdir")
else
    println("  ERROR: Expected /test/workspace, got: $workdir")
end

println("\nAll tests completed!")