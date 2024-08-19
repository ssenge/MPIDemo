using ArgParse
using Dates
using Logging

include("./Utils.jl")

function run_local(min_p, max_p, print_not_found_steps)
    start = Dates.now()
    for (i, p) in enumerate(min_p:max_p)
        job_start = Dates.now()
        if is_mersenne(p)
            @info found_str(p, "n/a", Dates.now() - job_start, Dates.now() - start, "local")
        elseif i % print_not_found_steps == 0 
            @info not_found_str("($p, $p)", Dates.now() - job_start, "local")
        end
    end
end

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin  
        "min"
            help = "Min exp"
            required = true
            #arg_type = Int
        "max"
            help = "Max exp"
            required = true
            #arg_type = Int
        "print_not_found_steps"
            help = "Print not found steps every n steps"
            arg_type = Int
            default = 500
    end

    return parse_args(s)
end

function main()
    args = parse_commandline()
    run_local(rstr2exp(args["min"]), rstr2exp(args["max"]), args["print_not_found_steps"])
end

main()