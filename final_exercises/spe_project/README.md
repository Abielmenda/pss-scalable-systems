# SPE

SPE (Job Processing Engine) is an Elixir/OTP job processing engine for the
Programming Scalable Systems final project.

The current version implements the base layer of the system: public API,
supervisor tree, server state, job validation, and initial job lifecycle
management.

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

## Current status

The base API and validation layer are implemented. Real task execution, DAG
scheduling, worker control, timeout handling, crash handling, and execution
events remain pending integration through `SPE.JobRunner`.
