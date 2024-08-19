#!/bin/bash

~/.julia/bin/mpiexecjl --project=. -n 2 julia src/examples/Mersenne/RunMPI.jl $1 $2 $3