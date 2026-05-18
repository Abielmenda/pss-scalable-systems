# Planning

## Deliverables

| Deliverable | Weight | Folder | Priority |
|---|---:|---|---|
| Mandatory final exercises (ME) | 20% | `final_exercises/` | High, close early |
| SPE project development (PD) | 50% | `spe_project/` | Highest |
| Project presentation (PP) | 30% | `presentation/` | Prepare progressively |

## Suggested phases

### Phase 1 — Repository setup

- Create project structure.
- Complete `AUTHORS`.
- Keep the repository private before final submission.
- Add professors and team members as collaborators.

### Phase 2 — Mandatory final exercises

- Implement pure functions first.
- Add `Final.GenBank`.
- Add `Final.SuperBank`.
- Run manual tests.

### Phase 3 — SPE MVP

- Implement `SPE.start_link/1` and `SPE.stop/1`.
- Add Supervisor and Phoenix PubSub.
- Submit jobs without starting them.
- Start simple jobs with independent tasks.

### Phase 4 — SPE full behaviour

- Parse task dependencies as a DAG.
- Execute ready tasks concurrently.
- Enforce `:num_workers`.
- Handle task timeout.
- Handle task crash.
- Mark dependent tasks as `:not_run` when required.
- Broadcast task and job events through PubSub.

### Phase 5 — Quality and presentation

- Add Moodle tests unchanged.
- Add own tests.
- Document design decisions.
- Prepare `presentation.pdf`.

## Commit policy

Use small commits with clear messages:

```text
feat(final): implement matrix operations
feat(final): implement GenBank API
feat(spe): add supervisor and PubSub
feat(spe): submit and start jobs
test(spe): add timeout and crash tests
docs: document architecture decisions
```
