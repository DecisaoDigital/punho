-- Comprovativos privados: apenas autor e gestores da mesma empresa têm leitura.
insert into storage.buckets (id, name, public)
values ('punho-documentos', 'punho-documentos', false)
on conflict (id) do update set public = false;

drop policy if exists "empresa_membros" on public.punho_documentos;
create policy "autor ou gestor le documentos" on public.punho_documentos for select using (
  empresa_id = public.punho_empresa_atual() and (created_by = auth.uid() or public.punho_e_gestor())
);
create policy "membro cria proprio documento" on public.punho_documentos for insert with check (
  empresa_id = public.punho_empresa_atual() and created_by = auth.uid() and public.punho_membro_ativo()
);
create policy "autor ou gestor altera documento" on public.punho_documentos for update using (
  empresa_id = public.punho_empresa_atual() and (created_by = auth.uid() or public.punho_e_gestor())
) with check (
  empresa_id = public.punho_empresa_atual() and (created_by = auth.uid() or public.punho_e_gestor())
);
create policy "autor ou gestor apaga documento" on public.punho_documentos for delete using (
  empresa_id = public.punho_empresa_atual() and (created_by = auth.uid() or public.punho_e_gestor())
);

create policy "membro envia comprovativo da empresa" on storage.objects for insert to authenticated with check (
  bucket_id = 'punho-documentos' and (storage.foldername(name))[1] = public.punho_empresa_atual()::text and public.punho_membro_ativo()
);
create policy "autor ou gestor le comprovativo" on storage.objects for select to authenticated using (
  bucket_id = 'punho-documentos' and exists (
    select 1 from public.punho_documentos documento
    where documento.empresa_id = public.punho_empresa_atual()
      and documento.dados->>'storage_path' = name
      and (documento.created_by = auth.uid() or public.punho_e_gestor())
  )
);
create policy "autor ou gestor apaga comprovativo" on storage.objects for delete to authenticated using (
  bucket_id = 'punho-documentos' and exists (
    select 1 from public.punho_documentos documento
    where documento.empresa_id = public.punho_empresa_atual()
      and documento.dados->>'storage_path' = name
      and (documento.created_by = auth.uid() or public.punho_e_gestor())
  )
);

-- Fotografias de mÃ¡quinas pertencem Ã  empresa: qualquer membro pode enviar
-- e todos os membros ativos da mesma empresa podem consultar.
create policy "membros leem imagens de maquinas" on storage.objects for select to authenticated using (
  bucket_id = 'punho-documentos'
  and (storage.foldername(name))[1] = public.punho_empresa_atual()::text
  and (storage.foldername(name))[2] = 'machines'
  and public.punho_membro_ativo()
);
