using MPI
using IterTools
using Underscores
using Lazy
using Dates
using Logging, LoggingExtras
using Crayons, Crayons.Box
using Primes
using ArgParse

is_prime(n) = isprime(n)
is_mersenne_prime(n) = ismersenneprime(n, check=false)
check_exp1(p) = true  # isodd(p) # does not lead to a speed up as this is also checked in isprime()
check_exp2(p) = true
is_mersenne(p) = check_exp1(p) && is_prime(p) && check_exp2(p) && is_mersenne_prime(2^BigInt(p) - 1)
gen_mersenne(min_p, max_p) = (p for p = min_p:max_p if is_mersenne(p))
get_mersenne(min_p, max_p) = collect(gen_mersenne(min_p, max_p))
get_mersenne(ps) = get_mersenne(ps...)

# https://www.mersenne.org/primes/
const EXPS = [2, 3, 5, 7, 13, 17, 19, 31, 61, 89, 107, 127, 521, 607, 1279, 2203, 2281, 3217, 4253, 4423, 9689, 9941, 11213, 19937, 21701, 23209, 44497, 86243, 110503, 132049, 216091, 756839, 859433, 1257787, 1398269, 2976221, 3021377, 6972593, 13466917, 20996011, 24036583, 25964951, 30402457, 32582657, 37156667, 42643801, 43112609, 57885161, 74207281, 77232917, 82589933]

const EXP_TO_RANK = zip(EXPS, 1:length(EXPS)) |> Dict

const RANK_TO_EXP = zip(1:length(EXPS), EXPS) |> Dict

const logger = TeeLogger(global_logger(), FileLogger("log/Mersenne_$(Dates.format(Dates.now(), "yyyy-mm-dd_HH_MM_SS")).log", always_flush = true, append = true))

function found_str(p, job, job_duration, total_duration, worker)
	shorten = (n, max_len, lead, trail) -> begin
		nlen = length(Base.string(n))
		str = Base.string(n)
		omitted = nlen - lead - trail
		nlen > max_len ? (str[1:lead] * "..." * str[end-trail+1:end] * " ($nlen digits, $omitted omitted)") : str
	end
    m = 2^BigInt(p) - 1
    rank = get(EXP_TO_RANK, p, -1)
    proc_time = Dates.canonicalize(Dates.CompoundPeriod(Dates.Millisecond(job_duration)))
    total_time = Dates.canonicalize(Dates.CompoundPeriod(Dates.Millisecond(total_duration))) 
    Base.string(GREEN_FG("+++ Mersenne prime found: ")) *
        "\n\tRank: $rank Exp: $p Prime: $(shorten(m, 20, 5, 5))" *
        "\n\tType: $(rank == -1 ? "UNKNOWN (potentially NEW MERSENNE found ;-) )" : "KNOWN")" *
        "\n\tTime: $(Dates.now())" *
        "\n\tRange: $job" *
        "\n\tWorker: $worker" *
        "\n\tJob duration: $proc_time" *
        "\n\tRun duration: $total_time"
end

function not_found_str(job, job_duration, worker)
    proc_time = Dates.canonicalize(Dates.CompoundPeriod(Dates.Millisecond(job_duration)))
    Base.string(RED_FG("--- No Mersenne primes found: ")) * " Range: $job | Worker: $worker | Job duration: $proc_time"
end

partition_bounds(min, max, step) =
    zip(min:step:max, lazymap(x-> Base.min(x, max), min+(step-1):step:max+(step-1)))

rstr2exp = s -> startswith(s, "r") ? get(RANK_TO_EXP, parse(Int, s[2:end]), -1) : parse(Int64, s)






