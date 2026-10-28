-- Cover the accepted-user FK when deleting an account with invitation history.
create index carty_shared_invitations_accepted_by_idx
  on public.carty_shared_invitations(accepted_by);
