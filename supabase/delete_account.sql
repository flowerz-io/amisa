-- =============================================================================
-- Amisa — suppression de compte in-app (conforme Apple)
-- =============================================================================
-- Où exécuter : Supabase Dashboard → SQL Editor → New query → Run
--
-- Supprime le profil et le compte auth de l'utilisateur connecté.
-- Appelé depuis l'app via RPC `delete_own_account`.
-- =============================================================================

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not_authenticated';
  end if;

  delete from public.profiles where id = uid;
  delete from auth.users where id = uid;
end;
$$;

comment on function public.delete_own_account() is
  'Suppression définitive du compte connecté (profil + auth.users). Appel in-app uniquement.';

revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;
