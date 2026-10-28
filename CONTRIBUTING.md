# Development workflow

`main` is the shared integration baseline. City is the selected design; the old
UI exploration branch is retained as historical reference.

1. Fetch the remote and update a clean `main` with `git pull --ff-only`.
   Preserve local changes before switching or updating a checkout.
2. Create one focused branch, for example `feature/household-email`,
   `fix/barcode-review`, or `chore/release-signing`.
3. Implement small working milestones with their regression tests. Use
   Conventional Commits: `feat(scope): outcome`, `fix(scope): outcome`,
   `docs(scope): outcome`, `test(scope): outcome`, or `chore(scope): outcome`.
4. Run formatting, analysis and relevant tests before each code commit. Run
   the complete app suite and relevant native build before integration.
5. Push the branch when publishing is authorised and open a pull request into
   `main`. Describe the behaviour, validation, migrations and remaining limits.
   Wait for CI and required reviews; never bypass protection or force-push main.
6. Merge the reviewed change, update local `main`, then branch the next feature
   from that new baseline. Preserve useful milestone history with a merge commit.
   Delete a remote branch only when its work is merged and it is no longer needed.

Do not commit credentials, signing keystores, private email-provider keys or
generated build outputs. Supabase public client configuration is distinct from
server secrets. Record schema changes as migrations and verify authorisation.

The original City/cloud baseline contains several connected features developed
before this workflow was adopted. Its integration is a one-time baseline merge;
subsequent work follows focused feature pull requests. Published historical
commits retain their original messages.
