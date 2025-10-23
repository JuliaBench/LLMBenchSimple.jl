#!/usr/bin/env julia

# Test that LLMBENCH_WORKSPACE is lazily evaluated

# Test 1: Set environment variable BEFORE loading the module
println("Test 1: Set LLMBENCH_WORKSPACE before module load")
ENV["LLMBENCH_WORKSPACE"] = "/test/workspace/before"

using LLMBenchSimple

workdir = LLMBenchSimple.llmbench_workdir()
if workdir == "/test/workspace/before"
    println("  ✓ Got workspace from lazy initialization: $workdir")
else
    println("  ERROR: Expected /test/workspace/before, got: $workdir")
end

# Test 2: Changing the environment variable after load doesn't affect the cached value
println("\nTest 2: Changing ENV after load doesn't affect cached value")
ENV["LLMBENCH_WORKSPACE"] = "/test/workspace/after"
workdir = LLMBenchSimple.llmbench_workdir()
if workdir == "/test/workspace/before"
    println("  ✓ Still using cached value: $workdir")
else
    println("  ERROR: Expected cached value /test/workspace/before, got: $workdir")
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

# Test 4: Original value still works after override
println("\nTest 4: Original cached value still works after override")
workdir = LLMBenchSimple.llmbench_workdir()
if workdir == "/test/workspace/before"
    println("  ✓ Back to cached value: $workdir")
else
    println("  ERROR: Expected /test/workspace/before, got: $workdir")
end

println("\nAll tests completed!")