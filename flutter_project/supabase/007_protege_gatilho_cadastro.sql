-- O gatilho que cria o perfil após o cadastro (handle_new_user) não deve ser
-- chamado diretamente pela API. Também fixa o search_path, como as demais
-- funções. O gatilho em auth.users continua funcionando normalmente.
-- Aplicar somente se a função existir no seu projeto (criada pelo painel).
begin;
do $$
begin
  if to_regprocedure('public.handle_new_user()') is not null then
    alter function public.handle_new_user() set search_path = '';
    revoke execute on function public.handle_new_user() from public, anon, authenticated;
  end if;
end $$;
commit;
