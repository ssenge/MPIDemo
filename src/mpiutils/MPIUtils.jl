module MPIUtils

using MPI
using Underscores
using Lazy
using Dates

export init, read, arecv, asend, terminate, DATA_TAG, TERMINATION_TAG, Workers, init_workers, update_busy_workers, update_free_workers, free_workers, busy_workers, WorkerStatus, Result, string

const DATA_TAG = 0
const TERMINATION_TAG = 1

function init()
    MPI.Init()
    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank(comm)
    n_workers = MPI.Comm_size(comm) - 1
    MPI.Barrier(comm)
    comm, rank, n_workers
end

function read(comm; src=MPI.ANY_SOURCE, tag=MPI.ANY_TAG, dataT=MPI.INT)
    status = MPI.Probe(comm, MPI.Status; source=src, tag=tag)
    status_tag = MPI.Get_tag(status)
    status_src = MPI.Get_source(status)
    buf = Array{dataT}(undef, MPI.Get_count(status, dataT))
    MPI.Recv!(buf, comm; source=status_src, tag=status_tag)
    buf, status_src, status_tag
end

struct Result{T}
    job::Any
    data::T
    src::Int
    start_time::Dates.DateTime
    job_start_time::Dates.DateTime
    job_end_time::Dates.DateTime
end

function string(r::Result{T}) where T
    total_time = r.job_end_time - r.start_time
    job_time = r.job_end_time - r.job_start_time
    "Job result: $(r.job) -> $(r.data) from worker $(r.src) took $job_time and total time: $total_time"
end

string(rs::Vector{Result{T}}) where T = @> map(string, rs) join("\n")

function arecv(workers, comm, dataT, tag)
    probes = @_ map(MPI.Iprobe(comm, MPI.Status; source=_, tag=tag), workers)
    probes, workers = findall(((ismessage, status),) -> ismessage, probes) |> idx -> (probes[idx], workers[idx])

    isempty(probes) && return Dict()

    msgs = Dict{Int64,Array{dataT}}()
    values = @_ map(Array{dataT}(undef, MPI.Get_count(_, dataT)), map(last, probes))
    setindex!.(Ref(msgs), values, workers)

    reqs = Dict{Int64,MPI.Request}()
    values = @_ map(MPI.Irecv!(msgs[_], comm; source=_, tag=tag), workers)
    setindex!.(Ref(reqs), values, workers)

    ready_workers = filter(w -> MPI.Test(reqs[w]), workers)
    res = filter(((k, v),) -> k in ready_workers, msgs)
    res
end

asend(msgs, comm, tag) = Dict(dst => (msg, MPI.Isend(msg, comm; dest=dst, tag=tag)) for (dst, msg) in msgs)

terminate(comm, workers) = map(worker -> MPI.Isend(nothing, comm; dest=worker, tag=TERMINATION_TAG), workers) |> MPI.Waitall

@enum WorkerStatus FREE BUSY

struct Workers
    n_workers::Int
    status::Vector{WorkerStatus}
    start_time::Vector{Union{Nothing, Dates.DateTime}}
    end_time::Vector{Union{Nothing, Dates.DateTime}}
    jobs::Vector{Any}
end

function init_workers(n_workers)
    Workers(n_workers, fill(FREE, n_workers), fill(nothing, n_workers), fill(nothing, n_workers), fill(nothing, n_workers))
end

function update_busy_workers(workers, jobs, busy_workers)
    workers.status[busy_workers] .= BUSY
    workers.start_time[busy_workers] .= Dates.now()
    workers.end_time[busy_workers] .= nothing
    workers.jobs[busy_workers] .= jobs
    workers
end

function update_free_workers(workers, free_workers)
    workers.status[free_workers] .= FREE
    workers.end_time[free_workers] .= Dates.now()
    workers
end

function free_workers(workers)
    filter(w -> workers.status[w] == FREE, 1:workers.n_workers)
end

function busy_workers(workers)
    filter(w -> workers.status[w] == BUSY, 1:workers.n_workers)
end


module JobScheduler

using Lazy
using MPI
using Dates

using ..MPIUtils

include("../utils/PipeUtils.jl")

using .PipeUtils

export job_scheduler, worker, master, @mpimap

function master(comm, nworkers, jobs, dataT, interim)
    start_time = Dates.now()
    workers = init_workers(nworkers)

    prep_jobs = () -> @> workers MPIUtils.free_workers zip(jobs)
    mpi_send = msgs -> @> msgs MPIUtils.asend(comm, MPIUtils.DATA_TAG)
    update_busy = reqs -> @>> reqs keys collect MPIUtils.update_busy_workers(workers, map(first, values(reqs)))
    send_jobs = () -> @> prep_jobs() mpi_send update_busy

    mpi_receive = workers -> @> workers MPIUtils.busy_workers MPIUtils.arecv(comm, dataT, MPIUtils.DATA_TAG)
    update_free = msgs -> @>> msgs keys collect MPIUtils.update_free_workers(workers)
    to_results = msgs -> [Result(workers.jobs[k], v, k, start_time, workers.start_time[k], workers.end_time[k]) for (k,v) in msgs]
    process_responses = busy -> @> busy mpi_receive PipeUtils.pass_arg(update_free) to_results

    step = () -> @> send_jobs() process_responses interim PipeUtils.pipe_sleep(0.001)

    done = _ -> isempty(jobs) && length(MPIUtils.busy_workers(workers)) == 0

    result = @> Lazy.takeuntil(done, Lazy.repeatedly(step)) Iterators.flatten collect

    MPIUtils.terminate(comm, 1:nworkers)

    result
end


worker(comm, rank, root, dataT, f) =
    (((msg, _, tag)=MPIUtils.read(comm, src=root, dataT=dataT))[3] != MPIUtils.TERMINATION_TAG) ?
        (@> msg f MPI.Send(comm, dest=root, tag=MPIUtils.DATA_TAG); worker(comm, rank, root, dataT, f)) :
        nothing


function job_scheduler(; jobs, worker_func, root_rank=0, intermediate_func)
    comm, rank, nworkers = MPIUtils.init()

    jobs = Iterators.Stateful(jobs)
    dataT = typeof(peek(jobs)[1])

    result = rank == root_rank ? 
        master(comm, nworkers, jobs, dataT, intermediate_func) : 
        worker(comm, rank, root_rank, dataT, worker_func)

    MPI.Barrier(comm)
    MPI.Finalize()

    rank, result, root_rank
end

macro mpimap(worker_func, iter, intermediate_func=identity)
    return quote
        job_scheduler(jobs=$(esc(iter)), worker_func=$(esc(worker_func)), intermediate_func=$(esc(intermediate_func)))
    end
end


end
end


