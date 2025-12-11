
# GcC Mini C Compiler

![Language](https://img.shields.io/badge/language-C-blue)
![Tools](https://img.shields.io/badge/tools-Flex%20|%20Bison-green)
![Grade](https://img.shields.io/badge/Nota%20Final-91.25%25-brightgreen)

Este repositório contém a implementação completa de um compilador para a linguagem **Mini C** (um subconjunto educacional da linguagem C). O projeto foi desenvolvido como Trabalho Prático da disciplina **GCC130 - Compiladores** na **Universidade Federal de Lavras (UFLA)**.

O compilador realiza todas as etapas fundamentais de tradução: **Análise Léxica**, **Análise Sintática**, **Análise Semântica** e **Geração de Código Intermediário (IR)**.

> 🏆 **Resultado:** O projeto obteve a nota de **36,5 / 40,0 (91,25%)**.

---

## 📚 Funcionalidades Implementadas

O desenvolvimento foi dividido em três etapas incrementais:

### 1. Análise Léxica (Scanner)
* **Ferramenta:** Flex.
* **Funcionalidade:** Reconhecimento de tokens (palavras-chave, operadores, literais, identificadores).
* **Tratamento de Erros:** Reporta caracteres inválidos e números malformados com localização precisa (linha:coluna).
* **Ignora:** Espaços em branco e comentários (`//` e `/* ... */`).

### 2. Análise Sintática (Parser)
* **Ferramenta:** Bison (Gramática LR(1)).
* **Funcionalidade:** Validação da estrutura gramatical do código.
* **Resolução de Conflitos:**
    * **Dangling Else:** Resolvido via fatoração gramatical (divisão em `matched` e `unmatched statements`), garantindo uma gramática livre de conflitos *Shift/Reduce* sem depender de precedência forçada.
    * **Precedência:** Operadores matemáticos e lógicos configurados via diretivas `%left`/`%right`.
* **Recuperação de Erros:** Implementação do "Modo Pânico", sincronizando a recuperação em `;` ou `}` para reportar múltiplos erros em uma única compilação.
* **Trace:** Geração de uma tabela de rastreamento visual das ações *Shift/Reduce* para depuração.

### 3. Análise Semântica e Geração de Código (Codegen)
* **Tabela de Símbolos:** Estrutura Hash (DJB2) com **Escopos Aninhados** e encadeados. Suporta sombreamento de variáveis (*shadowing*).
* **Verificação de Tipos (Type Checking):**
    * Tipagem estrita (`int` e `bool`). Não há conversão implícita (cast).
    * Validação de operações aritméticas, relacionais e lógicas.
    * Verificação de declaração prévia e redeclaração de variáveis.
* **Geração de Código Intermediário (IR):**
    * Geração de **Código de Três Endereços** linear via Tradução Dirigida por Sintaxe.
    * **Renomeação de Variáveis:** Variáveis recebem sufixos de escopo (ex: `x_0`, `x_1`) para garantir unicidade e integridade no IR plano.
    * **Curto-Circuito:** Implementação lógica de *short-circuit* para operadores `&&` e `||` utilizando desvios condicionais.
    * **Controle de Fluxo:** Tradução de `if/else` e `while` utilizando *labels* e *jumps* (`ifFalse`, `goto`, `Label:`).

---

## 🚀 Como Executar

### Pré-requisitos
* GCC (GNU Compiler Collection)
* Make
* Flex
* Bison
* Graphviz (opcional, para visualizar o autômato gerado)

### Compilação
Para compilar o projeto e gerar o executável `src/compilador`:

```bash
make
````

Para limpar os arquivos gerados (objetos, binários e temporários):

```bash
make clean
```

### Execução

Para rodar o compilador com um arquivo de entrada (código fonte Mini C):

```bash
./src/compilador tests/teste_semantico_valido.mc
```

-----

## 📂 Estrutura do Projeto

```
GcC_mini-C-compiler/
├── docs/                 # Relatórios e enunciado do trabalho (PDF)
├── src/
│   ├── scanner.l         # Especificação Léxica (Flex)
│   ├── parser.y          # Especificação Sintática e Semântica (Bison)
│   ├── codegen.c/h       # Funções auxiliares para geração de IR e formatação
│   ├── automato.svg      # Visualização do autômato LR (gerado pelo make graph)
│   └── ...
├── tests/                # Casos de teste (válidos e inválidos)
├── Makefile              # Automação de build
└── README.md             # Documentação do projeto
```

-----

## 🖥️ Exemplo de Saída

Ao compilar um código fonte válido, o compilador gera três saídas principais no terminal, formatadas com cores ANSI para facilitar a leitura.

### 1\. Código Fonte (Exemplo)

```c
int x = 10;
if (x > 0) {
    bool x = true; // Shadowing: x bool esconde x int
    while (x) {
        x = false;
    }
}
```

### 2\. Tabela de Símbolos (Com Escopos)

O compilador exibe os identificadores, seus tipos e a profundidade do escopo.

| ID | [Lin:Col] | LEXEMA | TOKEN | TIPO | DEPTH | SCOPE |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| [001] | [001:005] | x | TK\_ID | INTEGER | 0 | 0 |
| [002] | [003:010] | x | TK\_ID | BOOL | 1 | 1 |

### 3\. Código Intermediário (IR)

Geração de código de três endereços com labels e temporários (`t0`, `t1`...). Note a renomeação das variáveis (`x_0` vs `x_1`) para tratar o escopo.

```text
╔══════════════════════════════════════════════════════════════════════════════════╗
║                      CÓDIGO INTERMEDIÁRIO (IR - 3 ENDEREÇOS)                     ║
╠════════════╦═════════════════════════════════════════════════════════════════════╣
║   LABELS   ║ INSTRUÇÕES                                                          ║
╠════════════╬═════════════════════════════════════════════════════════════════════╣
║            ║ x_0 = 10                                                            ║
║            ║ t0 = x_0 > 0                                                        ║
║            ║ ifFalse t0 goto L0                                                  ║
║            ║ x_1 = true                                                          ║
║ L1:        ║                                                                     ║
║            ║ ifFalse x_1 goto L2                                                 ║
║            ║ x_1 = false                                                         ║
║            ║ goto L1                                                             ║
║ L2:        ║                                                                     ║
║ L0:        ║                                                                     ║
╚════════════╩═════════════════════════════════════════════════════════════════════╝
```

-----

## 📄 Documentação

Para detalhes profundos sobre as decisões de projeto, gramática BNF completa, análise de conflitos LR e o enunciado original, consulte os arquivos disponíveis na pasta `docs/` ou nos links abaixo:

  * [Enunciado do Trabalho Prático](https://drive.google.com/file/d/1MCaAugoOb3N5t_xk0rJ-VCosgNUFB8Kk/view?usp=sharing)
  * [Relatório Etapa 1 - Análise Léxica](https://drive.google.com/file/d/13ZawfM8QE4xClFPvgkyB2De_BYDfX-fD/view?usp=sharing)
  * [Relatório Etapa 2 - Análise Sintática](https://drive.google.com/file/d/1zVxSE18Ssn2I64tDd4rgrbZRv-ReUyG7/view?usp=sharing)
  * [Relatório Etapa 3 - Semântica e Geração de Código](https://drive.google.com/file/d/1Hh6GqT89JFFSarFA7wnX_WOJ2f2Ynd-m/view?usp=sharing)

-----

## 👨‍💻 Autores

  * **Gustavo Costa Almeida**
  * **Henrique César Silva Soares**
  * **Pedro Militão Mello Reis**

<!-- end list -->

```
```
