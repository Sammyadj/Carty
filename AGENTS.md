# Development workflow

- Develop in small, coherent milestones and commit each working milestone as it becomes ready, rather than collecting an entire development task into one bulk commit.
- Keep related implementation changes and their regression tests together. Each commit should be understandable and useful to review or revert on its own.
- Run formatting, analysis, and relevant tests in proportion to the change before committing. Documentation-only changes need an appropriate diff check.
- Use concise, descriptive commit messages explaining the outcome of the change.
- Commit only the changes belonging to the active task, preserving unrelated user work.
- Local milestone commits are part of the development workflow. Push them when the user authorizes publishing to the remote repository.
- Keep `main` as the integration baseline. Start each new feature or fix from an updated `main` on a focused branch named `codex/feat-<topic>`, `codex/fix-<topic>`, or `codex/chore-<topic>`.
- Use Conventional Commits for new work, such as `feat(lists): ...`, `fix(scanner): ...`, `docs(workflow): ...`, or `chore(release): ...`. Do not rewrite published milestone history just to rename older commits.
- Integrate through a pull request with a clear scope and validation results. Wait for required checks; do not bypass branch protection or force-push shared branches. Preserve milestone commits with a merge commit when useful.
