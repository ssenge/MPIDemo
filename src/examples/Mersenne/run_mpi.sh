#!/bin/bash

~/.julia/bin/mpiexecjl --project -f conf/mpihosts.conf julia src/examples/Mersenne/RunMPI.jl $1 $2 $3