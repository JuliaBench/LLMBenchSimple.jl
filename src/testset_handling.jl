# Testset handling for LLMBenchSimple
# Uses ScopedValues and new Test APIs from Julia 1.13+ (PR #53462 and #59357)

using Test
using Base.ScopedValues: ScopedValue, @with

mutable struct GradingTestSet <: Test.AbstractTestSet
    description::String
    results::Vector{Any}
    n_passed::Int
    verbose::Bool
    showtiming::Bool
    time_start::Float64
    failfast::Bool

    function GradingTestSet(desc::String; verbose::Bool=false, showtiming::Bool=false, failfast::Bool=false)
        new(desc, [], 0, verbose, showtiming, time(), failfast)
    end
end

Test.results(ts::GradingTestSet) = ts.results

Test.record(ts::GradingTestSet, res::Test.Pass) = (ts.n_passed += 1; res)
Test.record(ts::GradingTestSet, res::Union{Test.Fail, Test.Error}) = (push!(ts.results, res); ts.failfast && throw(Test.FailFastError()); res)
Test.record(ts::GradingTestSet, res::Test.Broken) = (push!(ts.results, res); res)
Test.record(ts::GradingTestSet, res::Test.AbstractTestSet) = (push!(ts.results, res); res)

Test.finish(ts::GradingTestSet; print_results::Bool=false) = ts

function has_test_failures(ts::Union{GradingTestSet, Test.AbstractTestSet})
    for r in ts.results
        if isa(r, Test.Fail) || isa(r, Test.Error)
            return true
        elseif isa(r, Test.AbstractTestSet) && has_test_failures(r)
            return true
        end
    end
    return false
end

function format_test_errors(ts::Union{GradingTestSet, Test.AbstractTestSet})
    io = IOBuffer()
    Test.print_test_errors(io, ts)
    String(take!(io))
end

function format_test_results(ts::Union{GradingTestSet, Test.AbstractTestSet})
    io = IOBuffer()
    Test.print_test_results(io, ts, 0)
    String(take!(io))
end

function evaluate_with_test_capture(f)
    grading_testset = GradingTestSet("grading_eval")

    result = nothing
    error_info = nothing

    result = @with Test.CURRENT_TESTSET => grading_testset Test.TESTSET_DEPTH => 1 Test.TESTSET_PRINT_ENABLE => false begin
        try
            f()
        finally
            if has_test_failures(grading_testset)
                error_info = format_test_errors(grading_testset)
                @debug "Test failures detected during grading" errors=error_info
                return (false, error_info)
            end
        end
    end

    # If result is a tuple with error info, return it as-is
    if isa(result, Tuple) && length(result) == 2
        return result
    end
    
    # Otherwise return result with no error info
    return (result, nothing)
end

export evaluate_with_test_capture, GradingTestSet, has_test_failures, format_test_errors, format_test_results
