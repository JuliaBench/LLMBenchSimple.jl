# Patch utilities for LLMBenchSimple
# Uses LibGit2 APIs to generate and compare patches

using LibGit2
using LibGit2_jll

export compare_commit_with_file_patch, get_commit_patch, get_commit_diff, compare_diffs

"""
    get_commit_diff(commit::LibGit2.GitCommit, repo::LibGit2.GitRepo)

Get the GitDiff object for a commit using LibGit2 APIs.

# Arguments
- `commit`: LibGit2.GitCommit object
- `repo`: LibGit2.GitRepo object

# Returns
Ptr{Cvoid} to the GitDiff object (caller must free with git_diff_free)
"""
function get_commit_diff(commit::LibGit2.GitCommit, repo::LibGit2.GitRepo)
    LibGit2.ensure_initialized()
    
    # Use the commit's owner repository if available, otherwise use the provided repo
    # This handles cases where the commit was created with a different GitRepo instance
    commit_repo = commit.owner
    
    # Get the parent commit (if any)
    parent_count = LibGit2.parentcount(commit)
    
    # Get tree id from commit
    tree_id_ptr = ccall((:git_commit_tree_id, LibGit2_jll.libgit2), Ptr{LibGit2.GitHash},
                        (Ptr{Cvoid},), commit.ptr)
    
    if parent_count == 0
        # For root commits, diff against empty tree
        tree_ptr = Ref{Ptr{Cvoid}}(C_NULL)
        LibGit2.@check ccall((:git_tree_lookup, LibGit2_jll.libgit2), Cint,
                            (Ptr{Ptr{Cvoid}}, Ptr{Cvoid}, Ptr{LibGit2.GitHash}),
                            tree_ptr, commit_repo.ptr, tree_id_ptr)
        tree = LibGit2.GitTree(commit_repo, tree_ptr[])
        
        try
            # Create diff from empty to tree
            diff_ptr = Ref{Ptr{Cvoid}}(C_NULL)
            LibGit2.@check ccall((:git_diff_tree_to_tree, LibGit2_jll.libgit2), Cint,
                                (Ptr{Ptr{Cvoid}}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
                                diff_ptr, commit_repo.ptr, C_NULL, tree.ptr, C_NULL)
            return diff_ptr[]
        finally
            close(tree)
        end
    else
        # Normal commit with parent - diff parent to commit
        parent = LibGit2.parent(commit, 1)
        
        # Get parent tree id
        parent_tree_id_ptr = ccall((:git_commit_tree_id, LibGit2_jll.libgit2), Ptr{LibGit2.GitHash},
                                   (Ptr{Cvoid},), parent.ptr)
        
        # Look up both trees
        parent_tree_ptr = Ref{Ptr{Cvoid}}(C_NULL)
        LibGit2.@check ccall((:git_tree_lookup, LibGit2_jll.libgit2), Cint,
                            (Ptr{Ptr{Cvoid}}, Ptr{Cvoid}, Ptr{LibGit2.GitHash}),
                            parent_tree_ptr, commit_repo.ptr, parent_tree_id_ptr)
        parent_tree = LibGit2.GitTree(commit_repo, parent_tree_ptr[])
        
        commit_tree_ptr = Ref{Ptr{Cvoid}}(C_NULL)
        LibGit2.@check ccall((:git_tree_lookup, LibGit2_jll.libgit2), Cint,
                            (Ptr{Ptr{Cvoid}}, Ptr{Cvoid}, Ptr{LibGit2.GitHash}),
                            commit_tree_ptr, commit_repo.ptr, tree_id_ptr)
        commit_tree = LibGit2.GitTree(commit_repo, commit_tree_ptr[])
        
        try
            # Create diff between parent tree and commit tree
            diff_ptr = Ref{Ptr{Cvoid}}(C_NULL)
            LibGit2.@check ccall((:git_diff_tree_to_tree, LibGit2_jll.libgit2), Cint,
                                (Ptr{Ptr{Cvoid}}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
                                diff_ptr, commit_repo.ptr, parent_tree.ptr, commit_tree.ptr, C_NULL)
            return diff_ptr[]
        finally
            close(parent)
            close(parent_tree)
            close(commit_tree)
        end
    end
end

"""
    get_commit_patch(commit::LibGit2.GitCommit, repo::LibGit2.GitRepo)

Get the patch content for a commit as a string using LibGit2 APIs.

# Arguments
- `commit`: LibGit2.GitCommit object
- `repo`: LibGit2.GitRepo object

# Returns
String containing the patch in unified diff format
"""
function get_commit_patch(commit::LibGit2.GitCommit, repo::LibGit2.GitRepo)
    diff_ptr = get_commit_diff(commit, repo)
    
    try
        # Convert diff to patch string
        buf_ref = Ref(LibGit2.Buffer())
        LibGit2.@check ccall((:git_diff_to_buf, LibGit2_jll.libgit2), Cint,
                            (Ptr{LibGit2.Buffer}, Ptr{Cvoid}, Cint),
                            buf_ref, diff_ptr, 1) # GIT_DIFF_FORMAT_PATCH = 1
        
        # Get the string from buffer
        patch_str = unsafe_string(buf_ref[].ptr, buf_ref[].size)
        
        # Free the buffer
        ccall((:git_buf_free, LibGit2_jll.libgit2), Cvoid, (Ptr{LibGit2.Buffer},), buf_ref)
        
        return patch_str
    finally
        # Free the diff
        ccall((:git_diff_free, LibGit2_jll.libgit2), Cvoid, (Ptr{Cvoid},), diff_ptr)
    end
end

"""
    compare_diffs(diff1_ptr::Ptr{Cvoid}, diff2_ptr::Ptr{Cvoid}; ignore_whitespace::Bool=true)

Compare two GitDiff objects using LibGit2 APIs.

# Arguments
- `diff1_ptr`: Pointer to first GitDiff
- `diff2_ptr`: Pointer to second GitDiff
- `ignore_whitespace`: If true, ignore whitespace differences

# Returns
true if the diffs are equivalent, false otherwise
"""
function compare_diffs(diff1_ptr::Ptr{Cvoid}, diff2_ptr::Ptr{Cvoid}; ignore_whitespace::Bool=true)
    LibGit2.ensure_initialized()
    
    # Get number of deltas (changed files) in each diff
    num_deltas1 = ccall((:git_diff_num_deltas, LibGit2_jll.libgit2), Csize_t, (Ptr{Cvoid},), diff1_ptr)
    num_deltas2 = ccall((:git_diff_num_deltas, LibGit2_jll.libgit2), Csize_t, (Ptr{Cvoid},), diff2_ptr)
    
    if num_deltas1 != num_deltas2
        @debug "Different number of deltas" num1=num_deltas1 num2=num_deltas2
        return false
    end
    
    # Compare each delta
    for idx in 0:(num_deltas1-1)
        # Get patches for this delta from both diffs
        patch1_ptr = Ref{Ptr{Cvoid}}(C_NULL)
        patch2_ptr = Ref{Ptr{Cvoid}}(C_NULL)
        
        LibGit2.@check ccall((:git_patch_from_diff, LibGit2_jll.libgit2), Cint,
                            (Ptr{Ptr{Cvoid}}, Ptr{Cvoid}, Csize_t),
                            patch1_ptr, diff1_ptr, idx)
        
        LibGit2.@check ccall((:git_patch_from_diff, LibGit2_jll.libgit2), Cint,
                            (Ptr{Ptr{Cvoid}}, Ptr{Cvoid}, Csize_t),
                            patch2_ptr, diff2_ptr, idx)
        
        try
            # Get delta (file change info) from each patch
            delta1_ptr = ccall((:git_patch_get_delta, LibGit2_jll.libgit2), Ptr{LibGit2.DiffDelta},
                              (Ptr{Cvoid},), patch1_ptr[])
            delta2_ptr = ccall((:git_patch_get_delta, LibGit2_jll.libgit2), Ptr{LibGit2.DiffDelta},
                              (Ptr{Cvoid},), patch2_ptr[])
            
            delta1 = unsafe_load(delta1_ptr)
            delta2 = unsafe_load(delta2_ptr)
            
            # Compare file paths
            if unsafe_string(delta1.old_file.path) != unsafe_string(delta2.old_file.path) ||
               unsafe_string(delta1.new_file.path) != unsafe_string(delta2.new_file.path)
                @debug "File path mismatch" old1=unsafe_string(delta1.old_file.path) old2=unsafe_string(delta2.old_file.path)
                return false
            end
            
            # Compare status (added/deleted/modified)
            if delta1.status != delta2.status
                @debug "Status mismatch" status1=delta1.status status2=delta2.status
                return false
            end
            
            # Get number of hunks in each patch
            num_hunks1 = ccall((:git_patch_num_hunks, LibGit2_jll.libgit2), Csize_t, (Ptr{Cvoid},), patch1_ptr[])
            num_hunks2 = ccall((:git_patch_num_hunks, LibGit2_jll.libgit2), Csize_t, (Ptr{Cvoid},), patch2_ptr[])
            
            if num_hunks1 != num_hunks2
                @debug "Different number of hunks" file=unsafe_string(delta1.new_file.path) hunks1=num_hunks1 hunks2=num_hunks2
                return false
            end
            
            # Compare each hunk
            for hunk_idx in 0:(num_hunks1-1)
                # Get hunk info
                hunk1_ptr = Ref{Ptr{Cvoid}}(C_NULL)
                hunk2_ptr = Ref{Ptr{Cvoid}}(C_NULL)
                num_lines1 = Ref{Csize_t}(0)
                num_lines2 = Ref{Csize_t}(0)
                
                LibGit2.@check ccall((:git_patch_get_hunk, LibGit2_jll.libgit2), Cint,
                                    (Ptr{Ptr{Cvoid}}, Ptr{Csize_t}, Ptr{Cvoid}, Csize_t),
                                    hunk1_ptr, num_lines1, patch1_ptr[], hunk_idx)
                
                LibGit2.@check ccall((:git_patch_get_hunk, LibGit2_jll.libgit2), Cint,
                                    (Ptr{Ptr{Cvoid}}, Ptr{Csize_t}, Ptr{Cvoid}, Csize_t),
                                    hunk2_ptr, num_lines2, patch2_ptr[], hunk_idx)
                
                if num_lines1[] != num_lines2[]
                    @debug "Different number of lines in hunk" hunk=hunk_idx lines1=num_lines1[] lines2=num_lines2[]
                    return false
                end
                
                # Compare each line in the hunk
                for line_idx in 0:(num_lines1[]-1)
                    line1_ptr = Ref{Ptr{Cvoid}}(C_NULL)
                    line2_ptr = Ref{Ptr{Cvoid}}(C_NULL)
                    
                    LibGit2.@check ccall((:git_patch_get_line_in_hunk, LibGit2_jll.libgit2), Cint,
                                        (Ptr{Ptr{Cvoid}}, Ptr{Cvoid}, Csize_t, Csize_t),
                                        line1_ptr, patch1_ptr[], hunk_idx, line_idx)
                    
                    LibGit2.@check ccall((:git_patch_get_line_in_hunk, LibGit2_jll.libgit2), Cint,
                                        (Ptr{Ptr{Cvoid}}, Ptr{Cvoid}, Csize_t, Csize_t),
                                        line2_ptr, patch2_ptr[], hunk_idx, line_idx)
                    
                    # git_diff_line structure (from libgit2 headers)
                    # struct git_diff_line {
                    #     char origin;
                    #     int old_lineno;
                    #     int new_lineno;
                    #     int num_lines;
                    #     size_t content_len;
                    #     git_off_t content_offset;
                    #     const char *content;
                    # }
                    
                    # Read the fields directly from memory
                    origin1 = unsafe_load(Ptr{Cchar}(line1_ptr[]))
                    origin2 = unsafe_load(Ptr{Cchar}(line2_ptr[]))
                    
                    # Compare line origin (context/addition/deletion)
                    if origin1 != origin2
                        @debug "Line origin mismatch" hunk=hunk_idx line=line_idx origin1=origin1 origin2=origin2
                        return false
                    end
                    
                    # Get content_len (at offset 16 bytes on 64-bit systems)
                    content_len1 = unsafe_load(Ptr{Csize_t}(line1_ptr[] + 16))
                    content_len2 = unsafe_load(Ptr{Csize_t}(line2_ptr[] + 16))
                    
                    # Get content pointer (at offset 32 bytes on 64-bit systems)
                    content_ptr1 = unsafe_load(Ptr{Ptr{Cchar}}(line1_ptr[] + 32))
                    content_ptr2 = unsafe_load(Ptr{Ptr{Cchar}}(line2_ptr[] + 32))
                    
                    # Compare line content
                    content1 = unsafe_string(content_ptr1, content_len1)
                    content2 = unsafe_string(content_ptr2, content_len2)
                    
                    if ignore_whitespace
                        # Strip and compare
                        if strip(content1) != strip(content2)
                            @debug "Line content mismatch" hunk=hunk_idx line=line_idx
                            return false
                        end
                    else
                        if content1 != content2
                            @debug "Line content mismatch" hunk=hunk_idx line=line_idx
                            return false
                        end
                    end
                end
            end
        finally
            # Free the patches
            ccall((:git_patch_free, LibGit2_jll.libgit2), Cvoid, (Ptr{Cvoid},), patch1_ptr[])
            ccall((:git_patch_free, LibGit2_jll.libgit2), Cvoid, (Ptr{Cvoid},), patch2_ptr[])
        end
    end
    
    return true
end

"""
    compare_commit_with_file_patch(commit::LibGit2.GitCommit, repo::LibGit2.GitRepo, patch_file::String; ignore_whitespace=true)

Compare a commit's changes with a patch file using LibGit2 diff APIs.

# Arguments
- `commit`: The commit to compare
- `repo`: The repository
- `patch_file`: Path to the patch file to compare against
- `ignore_whitespace`: If true, ignore whitespace differences

# Returns
true if the commit matches the patch file, false otherwise
"""
function compare_commit_with_file_patch(commit::LibGit2.GitCommit, repo::LibGit2.GitRepo, patch_file::String; ignore_whitespace=true)
    LibGit2.ensure_initialized()
    
    # Get the commit's diff
    commit_diff_ptr = get_commit_diff(commit, repo)
    
    try
        # Read the patch file
        file_patch_content = read(patch_file, String)
        
        # Create a diff from the patch file content using git_diff_from_buffer
        file_diff_ptr = Ref{Ptr{Cvoid}}(C_NULL)
        LibGit2.@check ccall((:git_diff_from_buffer, LibGit2_jll.libgit2), Cint,
                            (Ptr{Ptr{Cvoid}}, Cstring, Csize_t),
                            file_diff_ptr, file_patch_content, sizeof(file_patch_content))
        
        try
            # Compare the two diffs
            return compare_diffs(commit_diff_ptr, file_diff_ptr[]; ignore_whitespace=ignore_whitespace)
        finally
            # Free the file diff
            ccall((:git_diff_free, LibGit2_jll.libgit2), Cvoid, (Ptr{Cvoid},), file_diff_ptr[])
        end
    finally
        # Free the commit diff
        ccall((:git_diff_free, LibGit2_jll.libgit2), Cvoid, (Ptr{Cvoid},), commit_diff_ptr)
    end
end

