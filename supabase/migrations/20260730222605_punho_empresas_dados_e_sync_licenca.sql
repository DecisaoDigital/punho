-- Recuperada a 2026-08-08 do registo de migrations aplicadas
-- (supabase_migrations.schema_migrations, versão 20260730222605). Estava em
-- produção sem ficheiro no repo.

-- Punho v0.0.14 — sincronizar dados da empresa Punho para o Control
-- Adiciona coluna `dados jsonb` a punho_empresas + trigger que cria/upsert
-- linha em licencas (app='punho') para o Control ver a empresa na sua lista.

-- 1. Coluna dados jsonb em punho_empresas
ALTER TABLE public.punho_empresas
  ADD COLUMN IF NOT EXISTS dados jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.punho_empresas.dados IS
  'Dados detalhados do onboarding: nif, nome_comercial, morada, codigo_postal, localidade, telefone, email, facturacao_*, custos_*, n_colaboradores, n_veiculos, n_maquinas. Populado pela Edge Function sincronizar-empresa-punho.';

-- 2. Função de sincronização: cria/actualiza linha em licencas app='punho'
CREATE OR REPLACE FUNCTION public.punho_sync_licenca_from_empresa()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $fn$
DECLARE
  v_nif text := NEW.dados->>'nif';
  v_nome_comercial text := NEW.dados->>'nome_comercial';
  v_machine_id text := 'punho:' || NEW.id::text;
  v_licenca_id uuid;
BEGIN
  IF v_nif IS NULL OR length(v_nif) < 9 THEN
    RETURN NEW;
  END IF;

  SELECT id INTO v_licenca_id
  FROM public.licencas
  WHERE app = 'punho' AND machine_id = v_machine_id
  LIMIT 1;

  IF v_licenca_id IS NULL THEN
    INSERT INTO public.licencas (
      app, machine_id, nif, nome, nome_comercial,
      plano, tier, validade, activa, info_host
    ) VALUES (
      'punho', v_machine_id, v_nif,
      COALESCE(v_nome_comercial, NEW.nome), v_nome_comercial,
      'beta', 'base', (CURRENT_DATE + INTERVAL '180 days')::date, true, NEW.dados
    );
  ELSE
    UPDATE public.licencas SET
      nif = v_nif,
      nome = COALESCE(v_nome_comercial, NEW.nome),
      nome_comercial = v_nome_comercial,
      info_host = NEW.dados
    WHERE id = v_licenca_id;
  END IF;

  RETURN NEW;
END;
$fn$;

COMMENT ON FUNCTION public.punho_sync_licenca_from_empresa() IS
  'Sync empresa Punho -> licenca. Corre AFTER INSERT/UPDATE de punho_empresas.dados. Só cria/actualiza licenca se dados->>nif for válido (>= 9 chars). machine_id convencionado como "punho:{empresa_uuid}".';

-- 3. Trigger AFTER INSERT/UPDATE OF dados
DROP TRIGGER IF EXISTS punho_empresas_sync_licenca ON public.punho_empresas;
CREATE TRIGGER punho_empresas_sync_licenca
AFTER INSERT OR UPDATE OF dados ON public.punho_empresas
FOR EACH ROW EXECUTE FUNCTION public.punho_sync_licenca_from_empresa();
