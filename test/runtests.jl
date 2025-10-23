using Test
using LLMBenchSimple

@testset "LLMBenchSimple.jl" begin
    
    @testset "split_problem_id" begin
        # Test with module prefix
        test_mod = Module(:TestModule)
        @test LLMBenchSimple.split_problem_id(test_mod, "TestModule-problem1") == "problem1"
        @test LLMBenchSimple.split_problem_id(test_mod, "TestModule-complex-problem-name") == "complex-problem-name"
        
        # Test without module prefix
        @test LLMBenchSimple.split_problem_id(test_mod, "problem1") == "problem1"
        @test LLMBenchSimple.split_problem_id(test_mod, "other-problem") == "other-problem"
        
        # Test with empty string
        @test LLMBenchSimple.split_problem_id(test_mod, "") == ""
    end
    
    @testset "result_to_score_dict" begin
        # Test with boolean result
        result = LLMBenchSimple.result_to_score_dict(true, "test")
        @test result["score"] == 1.0
        @test result["subscores"]["test"] == 1.0
        @test result["weights"]["test"] == 1.0
        
        result = LLMBenchSimple.result_to_score_dict(false, "test")
        @test result["score"] == 0.0
        @test result["subscores"]["test"] == 0.0
        
        # Test with dict that already has score
        input_dict = Dict("score" => 0.5, "subscores" => Dict("test" => 0.5))
        result = LLMBenchSimple.result_to_score_dict(input_dict, "test")
        @test result === input_dict  # Should return same dict
        
        # Test with dict without score
        input_dict = Dict("success" => true)
        result = LLMBenchSimple.result_to_score_dict(input_dict, "test")
        @test result["score"] == 1.0
        
        # Test with Test.Pass/Fail if available
        if isdefined(Test, :Pass)
            pass_result = Test.Pass(:test, nothing, nothing, nothing, LineNumberNode(1), false)
            result = LLMBenchSimple.result_to_score_dict(pass_result, "test")
            @test result["score"] == 1.0
        end
        
        if isdefined(Test, :Fail)
            fail_result = Test.Fail(:test, "1", "2", nothing, nothing, LineNumberNode(1), false)
            result = LLMBenchSimple.result_to_score_dict(fail_result, "test")
            @test result["score"] == 0.0
            @test haskey(result, "metadata")
        end
    end
    
    @testset "promptval string macro error" begin
        # The promptval"..." macro should error when used outside @bench
        @test isdefined(LLMBenchSimple, Symbol("@promptval_str"))
        # Test that the macro throws an error when used directly
        @test_throws LoadError @eval promptval"test"
    end
    
    @testset "@bench macro basic" begin
        # Create a test module to test the macro
        test_mod = Module(:TestMod)
        Base.eval(test_mod, :(using LLMBenchSimple))
        
        # Use the macro to define benchmarks
        Base.eval(test_mod, quote
            @bench "test_problem" promptval"What is 2+2?" == 4
        end)
        
        @test isdefined(test_mod, :BENCHMARKS)
        @test :test_problem in test_mod.BENCHMARKS
        @test isdefined(test_mod, :setup_problem)
        @test isdefined(test_mod, :grade)
    end
    
    @testset "setup_problem" begin
        # Create a test module with benchmarks
        test_mod = Module(:TestMod2)
        Base.eval(test_mod, :(using LLMBenchSimple))
        
        Base.eval(test_mod, quote
            @bench "test1" promptval"What is 2+2?" == 4
            @bench "test2" promptval"What is 3*3?" == 9
        end)
        
        # Test that problem_id is required
        result = test_mod.setup_problem("/tmp", "")
        @test occursin("Error: problem_id is required", result)
        @test occursin("test1", result)
        @test occursin("test2", result)
        
        # Test getting specific problem
        result = test_mod.setup_problem("/tmp", "test1")
        @test occursin("What is 2+2?", result)
        @test occursin("<answer>", result)  # Should have instructions about answer tags
        @test !occursin("test2", result)
        
        # Test with module prefix
        result = test_mod.setup_problem("/tmp", "TestMod2-test1")
        @test occursin("What is 2+2?", result)
        @test occursin("<answer>", result)
        
        # Test non-existent problem
        result = test_mod.setup_problem("/tmp", "nonexistent")
        @test occursin("Error: Problem 'nonexistent' not found", result)
        @test occursin("test1", result)
        @test occursin("test2", result)
    end
    
    @testset "grade" begin
        # Create a test module with benchmarks
        test_mod = Module(:TestMod3)
        Base.eval(test_mod, :(using LLMBenchSimple))
        
        Base.eval(test_mod, quote
            @bench "math_problem" promptval"What is 2+2?" == 4
            @bench "math_problem2" promptval"What is 3+3?" == 6
        end)
        
        # Test that problem_id is required
        result = test_mod.grade("/tmp", "4", "")
        @test result["score"] == 0.0
        @test haskey(result, "metadata") && occursin("Error: problem_id is required", result["metadata"]["error"])
        
        # Test correct answer from transcript
        transcript = "Some text... <answer>4</answer> more text"
        result = test_mod.grade("/tmp", transcript, "math_problem")
        @test result["score"] == 1.0
        @test haskey(result, "subscores")
        @test result["subscores"]["math_problem"] == 1.0
        @test haskey(result, "weights")
        @test result["weights"]["math_problem"] == 1.0
        
        # Test incorrect answer from transcript
        transcript = "Some text... <answer>5</answer> more text"
        result = test_mod.grade("/tmp", transcript, "math_problem")
        @test result["score"] == 0.0
        @test result["subscores"]["math_problem"] == 0.0
        
        # Test grading specific problem with correct answer
        transcript = "Some text... <answer>6</answer> more text"
        result = test_mod.grade("/tmp", transcript, "math_problem2")
        @test result["score"] == 1.0
        @test result["subscores"]["math_problem2"] == 1.0
        
        # Test with module prefix
        transcript = "Some text... <answer>4</answer> more text"
        result = test_mod.grade("/tmp", transcript, "TestMod3-math_problem")
        @test result["score"] == 1.0
        @test result["subscores"]["math_problem"] == 1.0
        
        # Test non-existent problem
        result = test_mod.grade("/tmp", transcript, "nonexistent")
        @test result["score"] == 0.0
        @test haskey(result, "metadata") && occursin("Error: Problem 'nonexistent' not found", result["metadata"]["error"])
    end
    
    
    @testset "promptdir macro" begin
        test_mod = Module(:TestDirMod)
        Base.eval(test_mod, :(using LLMBenchSimple))
        
        Base.eval(test_mod, quote
            @bench "create_file" begin
                workspace = promptdir"Create a file named 'hello.txt'"
                isfile(joinpath(workspace, "hello.txt"))
            end
        end)
        
        @test :create_file in test_mod.BENCHMARKS
        
        # Test setup
        mktempdir() do tmpdir
            result = test_mod.setup_problem(tmpdir, "create_file")
            @test occursin("Create a file named 'hello.txt'", result)
            @test occursin("workspace directory", result)
            @test occursin(tmpdir, result)
        end
        
        # Test grading
        mktempdir() do tmpdir
            # Create the expected file
            write(joinpath(tmpdir, "hello.txt"), "Hello")
            result = test_mod.grade(tmpdir, "", "create_file")
            @test result["score"] == 1.0
            
            # Remove file and test failure
            rm(joinpath(tmpdir, "hello.txt"))
            result = test_mod.grade(tmpdir, "", "create_file")
            @test result["score"] == 0.0
        end
    end
    
    @testset "promptcode macro" begin
        test_mod = Module(:TestCodeMod)
        Base.eval(test_mod, :(using LLMBenchSimple))
        
        Base.eval(test_mod, quote
            @bench "add_function" begin
                code = promptcode"Write a function add(a, b) that returns a + b"
                # Check if the parsed code defines a function called add that works correctly
                mod = Module()
                Base.eval(mod, code)
                Base.invokelatest() do
                    isdefined(mod, :add) && Base.invokelatest(mod.add, 2, 3) == 5
                end
            end
            
            @bench "multiple_expressions" begin
                code = promptcode"Write multiple functions: add(a,b) and multiply(a,b)"
                # Check if the parsed code defines both functions
                mod = Module()
                Base.eval(mod, code)
                Base.invokelatest() do
                    has_add = isdefined(mod, :add) && Base.invokelatest(mod.add, 2, 3) == 5
                    has_multiply = isdefined(mod, :multiply) && Base.invokelatest(mod.multiply, 2, 3) == 6
                    has_add && has_multiply
                end
            end
        end)
        
        @test :add_function in test_mod.BENCHMARKS
        @test :multiple_expressions in test_mod.BENCHMARKS
        
        # Test setup
        mktempdir() do tmpdir
            result = test_mod.setup_problem(tmpdir, "add_function")
            @test occursin("Write a function add(a, b)", result)
            @test occursin("answer.jl", result)
        end
        
        # Test grading with correct answer
        mktempdir() do tmpdir
            write(joinpath(tmpdir, "answer.jl"), "function add(a, b)\n    a + b\nend")
            result = test_mod.grade(tmpdir, "", "add_function")
            @test result["score"] == 1.0
            
            # Test with incorrect answer
            write(joinpath(tmpdir, "answer.jl"), "function add(a, b)\n    a * b\nend")
            result = test_mod.grade(tmpdir, "", "add_function")
            @test result["score"] == 0.0
        end
        
        # Test multiple expressions
        mktempdir() do tmpdir
            # Write a file with multiple expressions
            multi_code = """
            function add(a, b)
                a + b
            end
            
            function multiply(a, b)
                a * b
            end
            """
            write(joinpath(tmpdir, "answer.jl"), multi_code)
            result = test_mod.grade(tmpdir, "", "multiple_expressions")
            @test result["score"] == 1.0
            
            # Test with missing function
            single_code = """
            function add(a, b)
                a + b
            end
            """
            write(joinpath(tmpdir, "answer.jl"), single_code)
            result = test_mod.grade(tmpdir, "", "multiple_expressions")
            @test result["score"] == 0.0
        end
    end
    
    @testset "Interpolation" begin
        test_mod = Module(:TestInterpMod)
        Base.eval(test_mod, :(using LLMBenchSimple))
        
        Base.eval(test_mod, quote
            x = 42
            y = "world"
            
            @bench "interp" promptval"Hello $y, the answer is $x" == true
            @bench "raw" rawpromptval"Hello \$y, the answer is \$x" == true
        end)
        
        @test :interp in test_mod.BENCHMARKS
        @test :raw in test_mod.BENCHMARKS
        
        mktempdir() do tmpdir
            # Test interpolated prompt - NOTE: interpolation is not yet implemented
            result = test_mod.setup_problem(tmpdir, "interp")
            # For now, both regular and raw prompts behave the same (no interpolation)
            @test occursin("\$y", result)
            @test occursin("\$x", result)
            
            # Test raw prompt (no interpolation)
            result = test_mod.setup_problem(tmpdir, "raw")
            @test occursin("\$y", result)
            @test occursin("\$x", result)
        end
    end
    
    @testset "Test assertions in benchmarks" begin
        test_mod = Module(:TestAssertMod)
        Base.eval(test_mod, :(using LLMBenchSimple))
        Base.eval(test_mod, :(using Test))
        
        Base.eval(test_mod, quote
            @bench "with_test" begin
                answer = promptval"What is 2+2?"
                @test answer == 4
                @test answer > 0
            end
            
            @bench "failing_test" begin
                answer = promptval"What is 2+2?"
                @test answer == 5  # This should fail
            end
        end)
        
        @test :with_test in test_mod.BENCHMARKS
        @test :failing_test in test_mod.BENCHMARKS
        
        # Test passing case with @test assertions
        result = test_mod.grade("/tmp", "<answer>4</answer>", "with_test")
        @test result["score"] == 1.0
        
        # Test failing case with @test assertions
        result = test_mod.grade("/tmp", "<answer>4</answer>", "failing_test")
        @test result["score"] == 0.0  # Should fail because 4 != 5
    end
    
    @testset "unprivileged with addenv" begin
        # Test that unprivileged passes through without UID
        cmd = `echo hello`
        result = LLMBenchSimple.unprivileged(cmd, uid=nothing)
        @test result == cmd
        
        # Test that unprivileged works with Julia 1.13+ setuid or creates sudo command
        cmd = `echo hello`
        result = LLMBenchSimple.unprivileged(cmd, uid=1000)
        
        if isdefined(Base, :setuid)
            # Julia 1.13+ - should use native setuid
            @test result != cmd  # Should be modified
        else
            # Older Julia - should create sudo command
            @test result.exec[1] == "sudo"
            @test "-E" in result.exec
            @test occursin("#1000", result.exec[4])  # -u "#1000"
        end
        
        # Test that unprivileged passes through addenv'd variables (only for sudo version)
        if !isdefined(Base, :setuid)
            cmd = `printenv TEST_VAR`
            cmd_with_env = addenv(cmd, "TEST_VAR" => "test_value", "ANOTHER_VAR" => "another_value")
            result = LLMBenchSimple.unprivileged(cmd_with_env, uid=1000)
            
            # The result should have the environment variables
            # Check that the Cmd has environment variables set
            @test result.env !== nothing
            # result.env is a vector of "KEY=VALUE" strings
            env_strings = result.env
            @test "TEST_VAR=test_value" in env_strings
            @test "ANOTHER_VAR=another_value" in env_strings
            
            # Test with working directory preserved
            cmd = Cmd(`pwd`, dir="/tmp")
            result = LLMBenchSimple.unprivileged(cmd, uid=1000)
            @test result.dir == "/tmp"
        end
    end
    
end