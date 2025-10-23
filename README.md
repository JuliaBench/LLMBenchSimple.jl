# LLMBenchSimple.jl

A Julia package providing a simple macro interface for defining LLM benchmarks that integrate with LLMBenchMCPServer.

## Features

- Simple `@bench` macro for defining benchmarks
- `promptval"..."` string macro for LLM prompts that expect a value answer
- `promptdir"..."` string macro for LLM prompts that expect file/directory output
- Automatic setup_problem and grade function generation
- Workspace directory support with environment variable configuration
- Zero dependencies
- Seamless integration with LLMBenchMCPServer

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/JuliaComputing/LLMBenchSimple.jl")
```

## Usage

### Defining Benchmarks

#### Value-based Benchmarks (promptval)

Use `promptval"..."` when you expect the LLM to provide a specific answer value:

```julia
module MyBenchmarks

using LLMBenchSimple

# Simple string equality
@bench "addition" promptval"What is 2 + 2?" == 4

# Multiple choice
@bench "multiplication" promptval"What is 3 * 3?" == 9

# Numeric comparison with tolerance
@bench "sin_problem" parse(Float64, promptval"Compute sin(π/2) to 2 decimal places") ≈ 1.0 atol=0.01

# Complex expressions
@bench "sqrt_problem" parse(Float64, promptval"What is the square root of 16?")^2 == 16

end # module
```

#### Directory-based Benchmarks (promptdir)

Use `promptdir"..."` when you expect the LLM to create files or directories:

```julia
module FileBenchmarks

using LLMBenchSimple

# Create a simple file
@bench "create_readme" begin
    workspace = promptdir"Create a README.md file with title '# My Project'"
    isfile(joinpath(workspace, "README.md")) && 
    occursin("# My Project", read(joinpath(workspace, "README.md"), String))
end

# Create multiple files
@bench "create_package" begin
    workspace = promptdir"""
    Create a Julia package structure with:
    - src/MyPackage.jl with module definition
    - Project.toml with name = "MyPackage"
    """
    isfile(joinpath(workspace, "src", "MyPackage.jl")) &&
    isfile(joinpath(workspace, "Project.toml"))
end

# Create and validate a working function
@bench "create_function" begin
    workspace = promptdir"Create add.jl with function add(x, y) = x + y"
    if isfile(joinpath(workspace, "add.jl"))
        include(joinpath(workspace, "add.jl"))
        @isdefined(add) && add(2, 3) == 5
    else
        false
    end
end

end # module
```

The workspace directory defaults to `/workspace` but can be configured via the `LLMBENCH_WORKSPACE` environment variable:

```bash
export LLMBENCH_WORKSPACE=/tmp/my_workspace
```

### Using with LLMBenchMCPServer

The module automatically exports `setup_problem` and `grade` functions that are compatible with LLMBenchMCPServer:

```julia
using LLMBenchMCPServer
using MyBenchmarks

# Create MCP server with your benchmarks
server = LLMBenchServer(
    setup_fn=MyBenchmarks.setup_problem,
    grade_fn=MyBenchmarks.grade
)

# Run as MCP server
run_stdio_server(server)
```

### Manual Usage

You can also use the functions directly:

```julia
using MyBenchmarks

# Get problem descriptions
all_problems = MyBenchmarks.setup_problem("/tmp", "")
specific_problem = MyBenchmarks.setup_problem("/tmp", "addition")

# Grade solutions
result = MyBenchmarks.grade("/tmp", "4", "addition")
# Returns: Dict("score" => 1.0, "details" => "Correct")

result = MyBenchmarks.grade("/tmp", "5", "addition")  
# Returns: Dict("score" => 0.0, "details" => "Incorrect")
```

## How It Works

1. The `@bench` macro registers benchmarks with a name and evaluation expression
2. The `prompt"..."` string macro acts as a placeholder for the LLM's answer
3. During grading, the prompt placeholder is replaced with the actual answer
4. The expression is evaluated to determine if the answer is correct

## API

### `@bench name expr`

Define a benchmark with a given name and evaluation expression.

- `name`: String identifier for the benchmark
- `expr`: Expression containing `prompt"..."` and evaluation logic

### `promptval"..."`

String macro that marks where the LLM's answer value should be inserted. Can only be used inside `@bench`. The LLM should provide the answer wrapped in `<answer>` tags.

### `promptdir"..."`

String macro that prompts the LLM to create files/directories in a workspace. Can only be used inside `@bench`. Returns the workspace path where files should be created. The workspace location can be configured via the `LLMBENCH_WORKSPACE` environment variable (defaults to `/workspace`).

### `setup_problem(workdir::String, problem_id::String="")`

Returns a description of the problem(s) to solve.

- `workdir`: Working directory (currently unused)
- `problem_id`: Specific problem ID, or empty for all problems

### `grade(workdir::String, transcript::String, problem_id::String="")`

Grades the solution based on the transcript.

- `workdir`: Working directory (currently unused)
- `transcript`: The LLM's answer/transcript
- `problem_id`: Specific problem ID, or empty to grade all problems

Returns a Dict with:
- `score`: Overall score (0.0 to 1.0)
- `subscores`: Individual problem scores (when grading all)
- `weights`: Problem weights (when grading all)
- `details`: Human-readable grading details

## License

MIT