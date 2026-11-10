# Publicar o Mandakaru Workspace 3.0 no GitHub — passo a passo

## 0. Preserve os dados antigos
Se você já usa a versão 2.1 com dados, exporte o JSON pelo painel e faça backup do banco Supabase antes da migração. Não descarte a versão atual até testar todas as contas.

## 1. Crie o Supabase
Entre em https://supabase.com/dashboard e crie um projeto (ou use seu projeto 2.1).

- **Novo banco:** execute `supabase/schema.sql` no SQL Editor.
- **Banco 2.1 existente:** execute apenas `supabase/migrar_2_1_para_3_0.sql` no SQL Editor. Este script **não apaga `records`**.
- Em Authentication > Providers > Email, mantenha o cadastro por e-mail e **confirmação de e-mail** habilitados. Avalie também CAPTCHA, proteção contra bots e limites de cadastro.
- Em Project Settings / API Keys, copie a *Project URL* e uma **Publishable key** (ou anon public key).

## 2. Edite apenas as credenciais públicas
Abra `docs/config.js` e preencha:

```js
window.MANDAKARU_CONFIG = {
  supabaseUrl: 'https://SEU-PROJETO.supabase.co',
  supabaseAnonKey: 'SUA_CHAVE_PUBLICAVEL',
};
```

**Nunca** use secret key, service_role, senha de usuário, PAT do GitHub ou qualquer segredo no código publicado.

## 3. Suba o repositório GitHub
1. Faça login no https://github.com .
2. Clique em **New repository** e use, por exemplo, `mandakaru-workspace`.
3. Descompacte o ZIP e envie o conteúdo da pasta raiz do projeto; `docs/index.html` deve existir.
4. Em **Settings > Pages**, escolha **Deploy from a branch** → `main` → `/docs` → Save.
5. O endereço ficará no formato `https://USUARIO.github.io/mandakaru-workspace/` (ajuste ao repositório real).

**Nota sobre hospedagem:** o GitHub Pages é hospedagem estática. Ele não armazena senhas nem registros do seu banco. Consulte seus limites e termos, especialmente se o sistema se tornar uma aplicação comercial. Você também pode manter o repositório no GitHub e publicar com Cloudflare Pages sem mudar o código.

## 4. Ajuste o endereço no Supabase Auth
Em Supabase > Authentication > URL Configuration:
- Site URL: endereço completo publicado pelo GitHub Pages, incluindo o caminho do repositório.
- Redirect URLs: inclua o endereço completo para permitir confirmação de e-mail e recuperação de senha.

Use a URL real, sem exemplos, pois o retorno do link de confirmação depende dela.

## 5. Crie a única conta administradora
1. No site publicado, clique **Criar minha conta**.
2. Cadastre **sua própria conta**, confirme seu e-mail e entre. Inicialmente aparecerá **Aguardando autorização**.
3. Em Supabase > SQL Editor, rode o seguinte comando, substituindo o endereço pelo **seu e-mail real**:

```sql
insert into public.members (user_id, role, department)
select id, 'admin', 'Direção geral e criativa'
from public.profiles
where email = lower('SEU-EMAIL@EXEMPLO.COM')
on conflict (user_id)
do update set role='admin', department='Direção geral e criativa';
```

A tabela possui restrição de uma única administradora. O painel não pode promover outra conta a admin. Execute a operação inicial apenas no painel confiável do Supabase.

4. Volte ao Workspace e clique **Verificar aprovação**.
5. Na aba Hardware, clique **Carregar inventário inicial** somente se o banco estiver vazio.

## 6. Crie as contas da equipe
1. Cada integrante abre o site e clica **Criar minha conta**.
2. Escolhe seu próprio e-mail e senha, confirma o e-mail e aguarda autorização.
3. Você entra no Workspace → **Equipe** → **Contas aguardando aprovação**.
4. Clique **Aprovar acesso** e escolha `Visualizador`, `Colaborador` ou `Head de equipe` e o departamento operacional.
5. Em **Tarefas**, edite uma tarefa e selecione a **Conta responsável**. A pessoa poderá clicar **Atualizar minha tarefa**, alterar andamento e incluir observação. Ela não altera nome, pontos, prazos ou estrutura da tarefa.

## 7. Verificação obrigatória antes de usar de verdade
- Login e confirmação de e-mail em desktop e celular.
- Pessoa sem aprovação não acessa nenhum dado do estúdio.
- A administradora cria/edita itens e aprova usuários.
- A equipe não pode alterar preços, peças, projetos, cargos ou tarefas-base.
- A pessoa atribuída à tarefa pode atualizar só o próprio andamento.
- Outro membro não pode atualizar uma tarefa atribuída a outra pessoa.
- Alterações feitas por uma conta ficam visíveis ao atualizar a página nas demais.
- Dados continuam preservados ao publicar nova versão do `docs/`.

Se qualquer teste falhar, **não utilize com dados comerciais reais** até corrigir a configuração.

## 8. Backups e atualização de versão
- Faça exportação JSON regularmente em Configurações e mantenha uma cópia segura fora do computador principal.
- O banco é independente do GitHub. Atualizar HTML/CSS/JS por commit não reinicializa os registros, desde que seja mantido o mesmo projeto Supabase.
- O modo local é só uma demonstração: seus dados locais não são compartilhados. Use o Supabase no endereço publicado.

## 9. Se quiser migrar depois para Cloudflare Pages
- Conecte o mesmo repositório GitHub em Cloudflare Pages.
- Output directory: `docs`.
- Build command: nenhum.
- Ajuste `Site URL` e redirects do Supabase para o novo endereço.
- A base de dados e as contas continuam no mesmo projeto Supabase.
