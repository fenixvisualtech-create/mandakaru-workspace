# Prod. Mandakaru — Workspace 3.0

Painel interno de gestão do estúdio familiar. Mantém a identidade Mandakaru, as peças dos dois computadores, metas e projetos editáveis pela administradora, contas individuais e acompanhamento de andamento das tarefas atribuídas.

- **Site estático:** `docs/` contém HTML, CSS, JS e logos vetoriais/PNG. Sem build.
- **Autenticação e dados:** Supabase Auth + PostgreSQL com RLS. Não use `localStorage` para sincronização.
- **Admin:** única conta que pode alterar peças, preços, projetos, tarefas, atribuições e cargos.
- **Equipe:** cadastro por e-mail e senha, confirmação e aprovação pela admin; pode acompanhar e atualizar apenas o progresso das próprias tarefas.
- **Deploy:** GitHub Pages em `main` / `/docs`. Alternativamente, GitHub como repositório + Cloudflare Pages com pasta de saída `docs`.

**Antes de publicar, leia [CONFIGURAR_GITHUB.md](CONFIGURAR_GITHUB.md).**

## Estrutura

```text
mandakaru-workspace/
  docs/
    index.html
    app.js
    styles.css
    config.js
    assets/brand/  # logos claras e escuras
  supabase/
    schema.sql                 # projeto novo
    migrar_2_1_para_3_0.sql   # banco existente 2.1
  CONFIGURAR_GITHUB.md
```

## Cuidados

- `config.js` deve conter somente a URL e a **publishable/anon key** do Supabase. Nunca insira senha, token pessoal, secret key ou `service_role` no repositório.
- A segurança de edição é controlada nas políticas SQL, não apenas no JavaScript.
- Não execute o arquivo de migração por cima do `schema.sql` num banco vazio; o `schema.sql` já inclui as extensões do 3.0.
- Faça backup JSON antes de migrar a versão que já esteja em uso.
- Para publicar como aplicativo comercial no futuro, confira as regras de GitHub Pages; recomenda-se hospedar a partir do mesmo repositório em um serviço de static hosting apropriado.

## Estado

Código pronto para configuração e implantação. **Ainda não conectado ao seu Supabase, não publicado na sua conta GitHub, e login real não testado** neste ambiente.
