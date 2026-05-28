# SPE

SPE (Job Processing Engine) is a small Elixir/OTP job processing engine scaffold
for the Programming Scalable Systems final project.

The current version sets up the base Mix project, public API, supervisor tree,
job validation, and basic job lifecycle state. It does not yet execute the full
DAG of tasks, enforce dependencies, publish events, or manage worker scheduling.

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

This is the initial scaffold. The complete DAG execution engine, task workers,
timeouts, dependency handling, and Phoenix PubSub notifications are intentionally
left for later implementation steps.
