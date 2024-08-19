using ArgParse
using Dates
using Logging
using Lazy 

include("./Utils.jl")
include("../../mpiutils/MPIUtils.jl")

using .MPIUtils
using .MPIUtils.JobScheduler

function handle_intermediates(results)
    found = [r for r in results if length(r.data) > 0]
    not_found = setdiff(results, found)
    found_strs = map(r -> map(exp -> found_str(exp, r.job, r.job_end_time - r.job_start_time, r.job_end_time - r.start_time, r.src), r.data), found) |> Iterators.flatten
    not_found_strs = map(r -> not_found_str(r.job, r.job_end_time - r.job_start_time, r.src), not_found)

    with_logger(logger) do 
        foreach(s -> (@info s), found_strs)
        foreach(s -> (@info s), not_found_strs)
    end
	results
end

function run_mpi(min_p, max_p, step)
    rank, result, root = @mpimap get_mersenne partition_bounds(min_p, max_p, step) handle_intermediates

    if rank == root
        mersennes = @> map(r -> r.data, result) Iterators.flatten collect sort
        with_logger(logger) do
            @info "Done. Mersenne primes found: $mersennes"
        end
    end
end

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "min"
            help = "Min exp"
            required = true
        "max"
            help = "Max exp"
            required = true
        "step"
            help = "Job size for each MPI worker"
            arg_type = Int
            default = 250
    end

    return parse_args(s)
end

function main()
    args = parse_commandline()
    run_mpi(rstr2exp(args["min"]), rstr2exp(args["max"]), args["step"])
end

main()