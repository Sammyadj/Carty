# Development workflow

- Develop in small, coherent milestones and commit each working milestone as it becomes ready, rather than collecting an entire development task into one bulk commit.
- Keep related implementation changes and their regression tests together. Each commit should be understandable and useful to review or revert on its own.
- Run formatting, analysis, and relevant tests in proportion to the change before committing. Documentation-only changes need an appropriate diff check.
- Use concise, descriptive commit messages explaining the outcome of the change.
- Commit only the changes belonging to the active task, preserving unrelated user work.
- Local milestone commits are part of the development workflow. Push them when the user authorizes publishing to the remote repository.
