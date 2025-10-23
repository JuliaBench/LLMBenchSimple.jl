module DirectoryBenchmarks

using LLMBenchSimple

# Example 1: Create a simple text file
@bench "create_readme" begin
    workspace = promptdir"Create a README.md file with the title '# My Project' and a brief description"
    isfile(joinpath(workspace, "README.md")) && 
    occursin("# My Project", read(joinpath(workspace, "README.md"), String))
end

# Example 2: Create a Julia package structure
@bench "create_package" begin
    workspace = promptdir"""
    Create a minimal Julia package structure with:
    - src/MyPackage.jl containing a module definition
    - Project.toml with name = "MyPackage"
    """
    isfile(joinpath(workspace, "src", "MyPackage.jl")) &&
    isfile(joinpath(workspace, "Project.toml")) &&
    occursin("MyPackage", read(joinpath(workspace, "Project.toml"), String))
end

# Example 3: Create and validate a data file
@bench "create_data" begin
    workspace = promptdir"""
    Create a CSV file named 'data.csv' with the following content:
    name,age
    Alice,30
    Bob,25
    """
    if isfile(joinpath(workspace, "data.csv"))
        content = read(joinpath(workspace, "data.csv"), String)
        occursin("Alice,30", content) && occursin("Bob,25", content)
    else
        false
    end
end

# Example 4: Create a working Julia function
@bench "create_function" begin
    workspace = promptdir"""
    Create a file 'math_utils.jl' with a function:
    factorial_iterative(n) that computes n! using iteration
    """
    if isfile(joinpath(workspace, "math_utils.jl"))
        try
            include(joinpath(workspace, "math_utils.jl"))
            # Test the function works correctly
            @isdefined(factorial_iterative) && 
            factorial_iterative(5) == 120 &&
            factorial_iterative(0) == 1
        catch
            false
        end
    else
        false
    end
end

# Example 5: Create multiple related files
@bench "create_web_project" begin
    workspace = promptdir"""
    Create a simple web project with:
    - index.html with a basic HTML5 template
    - style.css with body { margin: 0; }
    - script.js with console.log('Hello, World!')
    """
    isfile(joinpath(workspace, "index.html")) &&
    isfile(joinpath(workspace, "style.css")) &&
    isfile(joinpath(workspace, "script.js")) &&
    occursin("margin: 0", read(joinpath(workspace, "style.css"), String))
end

# Example 6: Create and validate JSON configuration
@bench "create_config" begin
    workspace = promptdir"""
    Create a config.json file with:
    {
      "name": "MyApp",
      "version": "1.0.0",
      "debug": true
    }
    """
    if isfile(joinpath(workspace, "config.json"))
        try
            using JSON
            config = JSON.parsefile(joinpath(workspace, "config.json"))
            config["name"] == "MyApp" && 
            config["version"] == "1.0.0" && 
            config["debug"] == true
        catch
            false
        end
    else
        false
    end
end

end # module