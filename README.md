## GcC mini C compiler — Analisador Léxico

Projeto educacional de um analisador léxico (scanner) inspirado em C, escrito com Flex. O objetivo é aprender, de forma prática, como funcionam os estágios iniciais de um compilador: reconhecimento de tokens, tabela de símbolos e reporte de erros léxicos.

### Requisitos
- flex
- gcc
- make

Verifique a instalação (macOS/Linux):
```bash
flex --version
gcc --version
make --version
```

### Estrutura do projeto
```
GcC_mini-C-compiler/
  Makefile
  README.md
  src/
    scanner.l     # Especificação Flex
    lex.yy.c      # Gerado pelo flex (no build)
    scanner       # Binário (no build)
  tests/
    teste.txt
    teste_completo.txt
    teste_validos.txt
    teste_identificadores_invalidos.txt
```

### Construção e execução
Gerar o scanner e executar com o teste padrão (variável TEST no Makefile):
```bash
make
```

Rodar com um teste específico (sobrescrevendo TEST):
```bash
make clean && make TEST=tests/teste_validos.txt
```

Executar diretamente o binário com um arquivo de entrada:
```bash
src/scanner caminho/para/arquivo.c
```

### Tokens reconhecidos (resumo)
- Palavras-chave: `int`, `bool`, `if`, `else`, `while`, `print`, `read`, `true`, `false`
- Operadores relacionais: `==`, `!=`, `<=`, `>=`, `<`, `>`
- Operadores lógicos: `&&`, `||`, `!`
- Operadores aritméticos: `+`, `-`, `*`, `/`, `%`
- Atribuição: `=`
- Pontuação: `;`, `,`, `(`, `)`, `{`, `}`
- Identificadores: começam com letra `[a-zA-Z]`, seguidos de letras, dígitos ou `_`
- Inteiros: `-?` seguido de um ou mais dígitos (ex.: `42`, `-15`)
- Espaços e tabulações são ignorados; novas linhas atualizam a posição
- Comentários: `// até fim da linha` e `/* ... */` (múltiplas linhas)

### Regras de erro léxico
- Caractere não reconhecido: qualquer símbolo fora das regras acima gera um erro único, por exemplo `@`, `$`, `#`, `&` isolados.
- Número com sufixo inválido: sequências como `1inr`, `10abc` são tratadas como um único token inválido e reportadas como “Número inválido: sufixo inválido em literal inteiro `<lexema>`”. Isso evita quebrar em `INTEGER` + `IDENTIFIER` e facilita o diagnóstico.
- Identificadores com caracteres inválidos (ex.: `erro@`) serão reportados como erros de caractere não reconhecido no ponto do caractere inválido.

As mensagens são exibidas com linha e coluna e contabilizadas em `error_count`. O processo retorna código de saída `1` se houver erros, e `0` quando não houver.

### Tabela de símbolos
- Estrutura: hash table (`symbol_table`) com encadeamento por listas em cada bucket.
- Cada entrada guarda: `lexeme`, `token_type`, `line`, `column`.
- Duplicatas por `lexeme` são evitadas via `lookup` antes da inserção.
- Impressão ao final da análise, com contagem total de símbolos e erros.

Detalhes de implementação:
- `HASH_SIZE = 101` define o número de buckets.
- `hash_function` usa base polinomial 31 e aplica `% HASH_SIZE` para obter o índice do bucket.
- Complexidade média de `lookup`/`insert`: O(1), mantendo fator de carga razoável.

Observação: a tabela de símbolos será impressa na ordem de inserção do token na tabela, ou seja, o primeiro fator de comparação é a linha do token e o segundo a coluna em que o token se inicia.

### Exemplos rápidos
Executar com um arquivo simples:
```bash
src/scanner tests/teste.txt
```

### Projetos futuros
- Implementar _rehash_ para a tabela hash
- Suporte a literais de string: adicionar regra `"[^"\n]*"` (e escapar adequadamente) se desejar reconhecer strings.
- Implementação de análise sintática e semântica