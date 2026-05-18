# Design decisions

## Mandatory final exercises

The mandatory final exercises are kept in a separate folder to avoid mixing them with the Mix project.

The file `final_exercises/final.ex` must define one single top-level module named `Final`.

## SPE project

The SPE project is implemented as a Mix project.

Main design idea:

- `SPE` exposes the public API required by the statement.
- `SPE.Supervisor` starts the internal services.
- `SPE.Server` stores submitted jobs and coordinates job execution.
- `SPE.JobParser` validates and normalizes job descriptions.
- `SPE.JobRunner` coordinates the execution of one job.
- `SPE.TaskRunner` executes individual task functions safely.
- `SPE.WorkerPool` will enforce the global `:num_workers` limit.

## PubSub

The SPE server will start Phoenix PubSub registered as `SPE.PubSub`.

The expected events are:

- `{:spe, time, {job_id, :task_started, task_name}}`
- `{:spe, time, {job_id, :task_terminated, task_name}}`
- `{:spe, time, {job_id, :result, {status, results}}}`

## Testing strategy

- Keep Moodle tests unchanged.
- Add own tests for basic execution, dependency order, timeouts, crashes and worker limits.
