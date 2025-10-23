# Lazy Scoped Value Implementation for LLMBENCH_WORKSPACE

## Summary

Replaced the environment variable handling for `LLMBENCH_WORKSPACE` with the new `LazyScopedValue` API introduced in Julia 1.13+ (PR #59372), providing lazy initialization that evaluates only once per process.

## Implementation

### Using LazyScopedValue with OncePerProcess

```julia
# Lazy scoped value for workdir - initialized from environment when first accessed
const WORKDIR_CONTEXT = LazyScopedValue{Union{String,Nothing}}(
    OncePerProcess{Union{String,Nothing}}() do
        get(ENV, "LLMBENCH_WORKSPACE", nothing)
    end
)
```

### Key Benefits

1. **Lazy Initialization**: The environment variable is only read when first accessed, not at module load time
2. **Once Per Process**: The value is computed exactly once and cached for the entire process lifetime
3. **Scoped Overrides**: Can still be temporarily overridden using `@with` for specific scopes
4. **Clean API**: Simplified `llmbench_workdir()` function that directly uses the lazy value

## Usage

```julia
# Set environment variable before loading module
ENV["LLMBENCH_WORKSPACE"] = "/path/to/workspace"

using LLMBenchSimple

# Access the workspace (computed on first access)
workdir = llmbench_workdir()  # Returns "/path/to/workspace"

# Temporarily override in a specific scope
with_workdir("/different/path") do
    workdir = llmbench_workdir()  # Returns "/different/path"
end

# Original value is preserved outside the scope
workdir = llmbench_workdir()  # Returns "/path/to/workspace"
```

## Testing

Created comprehensive tests in `test_lazy_workspace.jl` that verify:
1. Lazy initialization from environment variable
2. Value caching (changes to ENV after first access don't affect the cached value)
3. Scoped overrides work correctly
4. Original value is preserved after scoped overrides

## Requirements

- Julia 1.13+ (nightly) with `LazyScopedValue` support
- The PR #59372 implementation must be available

## Migration Notes

- Environment variable must be set BEFORE loading the module
- Once initialized, the value is cached for the entire process
- This is more efficient than checking ENV on every access
- Compatible with the existing `with_workdir` helper function