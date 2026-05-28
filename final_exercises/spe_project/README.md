# SPE

SPE (Job Processing Engine) is an Elixir/OTP job processing engine for the
Programming Scalable Systems final project.

The current version implements the public API, supervisor tree, server state,
job validation, DAG task execution, PubSub execution events, task timeouts, crash
handling, and global worker limits.

## Install dependencies

```bash
mix deps.get
```

## Run tests

```bash
mix test
```

## Public API

- `SPE.start_link(options \\ [])`
- `SPE.stop(options \\ [])`
- `SPE.submit_job(job_description)`
- `SPE.start_job(job_id)`

## Main modules

- `SPE`: public API.
- `SPE.Supervisor`: root supervisor.
- `SPE.Server`: job state and lifecycle.
- `SPE.Validator`: job description validation.
- `SPE.JobRunner`: per-job DAG execution.
- `SPE.WorkerPool`: global worker limit and queue.
- `SPE.Worker`: isolated task execution.

## Execution

Tasks are executed according to their `enables` dependencies. Task start,
termination, and final job result events are published through `SPE.PubSub`.
Each task can define a timeout, and task crashes are isolated from the main SPE
server.
