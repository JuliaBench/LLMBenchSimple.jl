# Development Guidelines for LLMBenchSimple.jl

## Shipping Code

When asked to "ship it" or after making changes:

1. Stage all changes: `git add -A`
2. Create a descriptive commit message
3. Run tests locally and make sure they pass: `julia --project=. -e 'using Pkg; Pkg.test()'`
4. Push to the repository: `git push origin master`
5. **IMPORTANT**: Monitor the GitHub Actions CI run
   - Use: `gh run list --repo JuliaComputing/LLMBenchSimple.jl --branch master --limit 1` to find the run
   - Use: `gh run watch <run-id> --repo JuliaComputing/LLMBenchSimple.jl --exit-status` to monitor it (can take up to 10 minutes)
   - If it fails, investigate and fix before considering the task complete

## Testing

Always run tests before pushing:
```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

## Package Structure

- `src/LLMBenchSimple.jl` - Main module with macro definitions
- `examples/SimpleBenchmarks.jl` - Example benchmark module
- `test/runtests.jl` - Test suite

## Defining Benchmarks

Use the `@bench` macro with the `prompt"..."` string macro:

```julia
using LLMBenchSimple

@bench "problem_name" prompt"Your prompt here" == "expected_answer"
```

The `prompt"..."` macro can only be used inside `@bench` and will error otherwise.

## How It Works

1. `@bench` registers benchmarks in a global dictionary
2. `setup_problem` returns problem descriptions
3. `grade` evaluates expressions with answers substituted for prompts
4. Zero dependencies for maximum portability

## Integration with LLMBenchMCPServer

Modules using LLMBenchSimple automatically export compatible `setup_problem` and `grade` functions that work with LLMBenchMCPServer.