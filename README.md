# Programming Scalable Systems — PSS

Repository for the subject **Programming Scalable Systems**.

This repository is prepared to host both mandatory deliverables:

1. **Mandatory Final Exercises (ME — 20%)**
   - Located in `final_exercises/`.
   - Main file: `final_exercises/final.ex`.
   - Expected module: `Final`.

2. **Final Project SPE (PD — 50%)**
   - Located in `spe_project/`.
   - Elixir/Mix project.
   - Main module: `SPE`.
   - Uses OTP components and Phoenix PubSub.

3. **Presentation (PP — 30%)**
   - Located in `presentation/`.
   - Final expected file: `presentation.pdf`.

## Repository structure

```text
.
├── AUTHORS
├── README.md
├── docs/
│   ├── planning.md
│   ├── task-division.md
│   └── design-decisions.md
├── final_exercises/
│   ├── final.ex
│   └── test/
│       └── final_test.exs
├── spe_project/
│   ├── mix.exs
│   ├── lib/
│   │   ├── spe.ex
│   │   └── spe/
│   │       ├── supervisor.ex
│   │       ├── server.ex
│   │       ├── job_parser.ex
│   │       ├── job_runner.ex
│   │       ├── task_runner.ex
│   │       └── worker_pool.ex
│   └── test/
│       ├── spe_test.exs
│       └── test_helper.exs
├── presentation/
│   └── presentation.md
└── scripts/
    ├── test_final.sh
    └── test_spe.sh
```

## How to run the mandatory final exercises

From the repository root:

```bash
elixir final_exercises/final.ex
```

To run the optional ExUnit tests for this folder:

```bash
elixir final_exercises/test/final_test.exs
```

## How to run the SPE project

```bash
cd spe_project
mix deps.get
mix test
```

## Important notes

- The Moodle tests for SPE must be copied into `spe_project/test/` **without modifying them**.
- Every team member must commit regularly.
- Before final submission, this repository should be **private** and the professors should be added as collaborators.
- Complete the `AUTHORS` file with the exact names and UPM emails of all team members.

## Tested environment

Fill this section before submission:

```text
Elixir: TODO
Erlang/OTP: TODO
Operating system: TODO
```
