---
applyTo: "**"
---

# Guia para o github copilot gerar mensagens de commit

## Priorize Conventional Commits: 
Ao sugerir mensagens de commit, sempre tente aderir à especificação Conventional Commits. Isso significa iniciar a mensagem de commit com um tipo (ex: feat, fix, docs, chore, refactor, perf, test, build, ci) seguido por um escopo opcional (scope) e dois pontos :, depois a descrição do commit.

## Extrair Número da Issue do GitHub do Nome da Branch: 
Quando possível, extraia o número da issue do GitHub diretamente do nome da branch atual. Nomes de branch frequentemente seguem padrões como refactor/123, chore/456, feat/789, etc. O número da issue estará no formato [#NÚMERO].

## Incluir Número da Issue no Título: 
O título da mensagem de commit deve incluir o número da issue do GitHub. O formato para o título deve ser: <tipo>(<contexto>): [#<NÚMERO>] <descrição curta>

> <tipo>: Representa o tipo de mudança (ex: feat, fix, docs, chore, refactor).
> <contexto> (opcional): Fornece contexto para a mudança (ex: auth, ui, api).
> [#<NÚMERO>]: O número da issue do GitHub, ex: [#123]. Isso deve idealmente ser extraído do nome da branch.
> <descrição curta>: Uma descrição concisa e imperativa da mudança, em minúsculas, sem ponto final.

## Exemplos de mensagens de commit válidas:
- feat(login): [#123] adicionar fluxo de autenticação do usuário
- fix(bugs): [#456] corrigir bug crítico de produção
- docs(readme): [#789] atualizar instruções de instalação
- chore(deps): [#321] atualizar pacotes de dependência
- refactor(code): [#654] simplificar lógica de processamento de dados

## Diretrizes Gerais:
- Use o imperativo, tempo presente na mensagem de commit (ex: "adicionar" não "adicionado", "corrigir" não "corrigido").
- Mantenha o título da mensagem de commit conciso (idealmente entre 50-72 caracteres).
- Foque cada commit em uma única mudança lógica.
- Evite terminar o título com ponto final.
- Se a branch não conter o número da issue do GitHub, apenas escreva a commit message após o :. Seguindo a estrutura <tipo><(contexto)>: <descrição curta>.