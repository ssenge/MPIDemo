module PipeUtils

export pass_arg, ignore_arg, pipe_sleep

pass_arg = (x, f) -> begin f(x); x end
ignore_arg = (x, f) -> begin f(); x end

pipe_sleep = (x, secs) -> ignore_arg(x, () -> sleep(secs))

end