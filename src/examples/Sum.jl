using MPI
using IterTools
using Underscores
using Lazy

include("../mpiutils/MPIUtils.jl")
include("../utils/PrimeUtils.jl")
include("../utils/PipeUtils.jl")
include("../utils/Utils.jl")

using .MPIUtils
using .MPIUtils.JobScheduler
using .PrimeUtils

# Variant 1 - Building a job scheduler
# mpi_sum(iter) =
#     MPIUtils.JobScheduler.job_scheduler(
#         jobs=Iterators.Stateful(iter),
#         worker_func=sum)

#rank, result, root = mpi_sum(zip(1:10, 101:110))

# Variant 2 - Using the @schedule macro
rank, result, root = MPIUtils.JobScheduler.@mpimap sum zip(1:10, 101:110)

# Or even shorter: 
# rank, result, root = @mpimap sum zip(1:10, 101:110)

# Using a lambda
#rank, result, root = MPIUtils.JobScheduler.@mpimap xs -> sum(xs)+1 zip(1:10, 101:110)


if rank == root
    @> MPIUtils.string(result) println

    (@>> result map(r -> "$(r.job[1]) + $(r.job[2]) = $(r.data[1])")) .|> println
end
