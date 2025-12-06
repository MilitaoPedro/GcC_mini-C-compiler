/* ======================== Seção de Definições (Bison) ======================== */
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Tipos de dados da linguagem */
#define DT_INTEGER 1
#define DT_BOOL    2
#define DT_ERROR  -1

/* Variavel global para armazenar o tipo atual sendo declarado (ex: int a, b, c;) */
int current_declaration_type;

/* ======================== ESTRUTURAS DA TABELA DE SÍMBOLOS ======================== */
typedef struct symbol {
    int id;                         /* Identificador único do símbolo */
    int token_type;                 /* Tipo do token (TK_INT, TK_BOOL, etc) */
    int data_type;                  /* DT_INTEGER ou DT_BOOL */
    int scope_depth;                /* Profundidade do escopo (0=global, 1,2,3...=aninhado) */
    int scope_id;                   /* ID único do escopo onde o símbolo foi declarado */
    int line;                       /* Linha onde o símbolo foi declarado */
    int column;                     /* Coluna onde o símbolo foi declarado */
    char *lexeme;                   /* Nome do símbolo (identificador) */
} Symbol;

typedef struct hash_node {
    Symbol *symbol;                 /* Ponteiro para o símbolo */
    struct hash_node *next;         /* Ponteiro para próximo nó (separate chaining) */
} HashNode;

/* Estrutura de uma tabela de símbolos (escopo) */
typedef struct scope_table {
    HashNode *hash_table[997];      /* Hash table para este escopo */
    int symbol_count;               /* Número de símbolos neste escopo */
    struct scope_table *parent;     /* Ponteiro para escopo pai (NULL para global) */
    Symbol **symbol_order;          /* Símbolos em ordem de inserção */
    char **symbol_lexeme;           /* Lexemas em ordem de inserção (para impressão) */
    int capacity;                   /* Capacidade do array */
    int id;                         /* ID único desta instância de escopo */
} ScopeTable;

/* Tabela de símbolos global e ponteiro para escopo atual */
ScopeTable *global_scope = NULL;
ScopeTable *current_scope = NULL;
int global_symbol_count = 0;        /* Contador global de IDs */
int current_scope_depth = 0;        /* Profundidade atual do escopo */
int global_scope_counter = 0;

/* Listas globais para impressão final */
Symbol **all_symbols = NULL;
int all_symbols_count = 0;
int all_symbols_capacity = 0;

/* Definições de cores ANSI */
#define RESET   "\033[0m"
#define RED     "\033[31m"
#define GREEN   "\033[32m"
#define YELLOW  "\033[33m"
#define BLUE    "\033[34m"
#define MAGENTA "\033[35m"
#define CYAN    "\033[36m"
#define BOLD    "\033[1m"

/* ======================== PROTÓTIPOS DE FUNÇÕES ======================== */
unsigned int hash_function(const char *lexeme);
void initialize_symbol_table();
void enter_scope();
void exit_scope();
void insert_symbol(char *lexeme, int token_type, int data_type);
Symbol* lookup_symbol(char *lexeme);
void print_symbol_table();
void collect_all_symbols(ScopeTable *scope);
const char* token_type_to_string(int type);

/* ======================== PROTÓTIPOS E GLOBAIS DO LEXER ======================== */
/* Declarações 'extern' informam ao Bison que estas funções/variáveis existem
   em outro arquivo (gerado pelo Flex, scanner.l) e serão ligadas na compilação. */

extern int yylex();                 // Função principal do analisador léxico (retorna o próximo token).
extern FILE *yyin;                  // Ponteiro para o arquivo de entrada sendo lido.
extern int yylineno;                // Variavel global do Flex que armazena o número da linha atual.
extern int lexic_error_count;       // Contador de erros léxicos (definido no scanner.l).
extern int column_num;              // Contador de coluna atual (definido no scanner.l).

/* Contador de erros sintáticos (definido neste arquivo). */
int sintatic_error_count = 0;

/* Protótipo da função que adiciona uma entrada ao trace de redução. */
void add_reduce_trace(const char *rule);

/* Definições de cores ANSI para formatação da saída no terminal. */
#define RESET   "\033[0m"
#define RED     "\033[31m"
#define GREEN   "\033[32m"
#define YELLOW  "\033[33m"
#define BLUE    "\033[34m"
#define MAGENTA "\033[35m"
#define CYAN    "\033[36m"
#define BOLD    "\033[1m"

/* A função de erro que o Bison vai chamar automaticamente ao detectar um erro sintático. */
void yyerror(const char *s);

/* Variavel global para armazenar a string completa do trace de parsing (Shift/Reduce/Erro). */
char g_full_trace[65536] = "AÇÃO\tDETALHE\n"; // Buffer inicializado com o cabeçalho.

%}

%union {
    int ival;       /* Para valores inteiros e tipos (DT_INTEGER, etc) */
    char *sval;     /* Para o nome dos identificadores (lexema) */
}
/* ------------------------------ Definição de Tokens ------------------------------ */
/* Lista todos os tokens terminais que o analisador léxico (yylex) pode retornar.
   O Bison usa esses nomes para gerar as definições numéricas em parser.tab.h. */

%token TK_INT TK_BOOL TK_IF TK_ELSE TK_WHILE TK_PRINT
%token TK_READ TK_TRUE TK_FALSE                                         /* TK_RELOP TK_LOP TK_ARITHOP <- Removidos/Substituídos */
%token TK_SEMICOLON TK_COMMA TK_LPAREN TK_RPAREN TK_LBRACE TK_RBRACE
%token <ival> TK_INTEGER 
%token <sval> TK_ID
%token TK_EQ TK_NE TK_LE TK_GE TK_LT TK_GT                              // Tokens específicos para operadores relacionais
%token TK_LOGICAL_AND TK_LOGICAL_OR TK_LOGICAL_NOT                      // Tokens específicos para operadores lógicos
%token TK_PLUS TK_MINUS TK_MULT TK_DIV TK_MOD                           // Tokens específicos para operadores aritméticos
%token TK_ASSIGN                                                        // Token específico para atribuição

/* Tipos dos não-terminais que carregam informação de tipo */
%type <ival> type expression

/* Diretiva para habilitar mensagens de erro mais detalhadas passadas para yyerror. */
%define parse.error verbose

/* Define o símbolo inicial da gramática (o não-terminal raiz). */
%start program

/* ------------------------------ PRECEDÊNCIA E ASSOCIATIVIDADE DOS OPERADORES ------------------------------ */
/* Define a ordem e como os operadores se agrupam em expressões. Linhas mais baixas têm MAIOR precedência. */

%left TK_LOGICAL_OR                 /* || (menor precedência, associa à esquerda) */
%left TK_LOGICAL_AND                /* && (associa à esquerda) */
%left TK_EQ TK_NE                   /* == != (associa à esquerda) */
%left TK_LT TK_LE TK_GT TK_GE       /* < <= > >= (associa à esquerda) */
%left TK_PLUS TK_MINUS              /* + - binários (associa à esquerda) */
%left TK_MULT TK_DIV TK_MOD         /* * / % (associa à esquerda) */
%right TK_LOGICAL_NOT               /* ! unário (associa à direita) */
%right UMINUS                       /* Pseudo-token para Menos Unário (alta precedência, associa à direita) */

/* ======================================= Seção de Regras (Gramática) ======================================= */
%%

/* Um programa é definido como uma sequência de 'statements'. */
program:
                        statements                                                                      { add_reduce_trace("program -> statements");} /* Ação executada ao reconhecer o programa inteiro */
                        ;

/* 'statements' representa uma lista de zero ou mais 'statement'. */
statements:
                        /* epsilon */                                                                   { add_reduce_trace("statements ->");} /* Regra para lista vazia */
                        | statements statement                                                          { add_reduce_trace("statements -> statements statement");} /* Regra recursiva: adiciona um statement à lista */

                        /* Regras de recuperação de erro em modo pânico: */
                        | statements error TK_SEMICOLON /* Descarta tokens até encontrar ';' */         { yyerrok; add_reduce_trace("statements -> statements error ; (Recuperacao)"); } /* yyerrok sai do modo erro */
                        | statements error TK_RBRACE    /* Descarta tokens até encontrar '}' */         { /* Não precisa yyerrok aqui, '}' fecha o contexto */ add_reduce_trace("statements -> statements error } (Recuperacao Fim Bloco)"); }
                        ;

/* 'statement' define os tipos de comandos individuais permitidos na linguagem.
   Usa a divisão matched/unmatched para resolver a ambiguidade do 'dangling else'. */
statement:
                        matched_statement                                                               { add_reduce_trace("statement -> matched_statement"); } /* Um statement pode ser um 'matched' */
                        | unmatched_statement                                                           { add_reduce_trace("statement -> unmatched_statement"); } /* Ou um 'unmatched' */
    ;

/* MATCHE_STATEMENT: Qualquer comando que está sintaticamente "completo"
   e não termina ambiguamente com um IF sem ELSE. */
matched_statement:
                        declaration                                                                     { add_reduce_trace("matched_statement -> declaration"); }
                        | assignment                                                                    { add_reduce_trace("matched_statement -> assignment"); }
                        | read                                                                          { add_reduce_trace("matched_statement -> read"); }
                        | print                                                                         { add_reduce_trace("matched_statement -> print"); }
                        | while_stmt                                                                    { add_reduce_trace("matched_statement -> while_stmt"); }

                        /* Um IF-ELSE completo é um matched_statement SE AMBOS os corpos (then/else)
                           também forem matched_statements. Isso força o ELSE a se ligar ao IF interno. */
                        | if_head then_part else_head then_part  { add_reduce_trace("matched_statement -> if_head then_part else_head then_part"); }
                        ;

/* UNMATCHED_STATEMENT: Um comando que termina em um IF sem ELSE,
   criando a potencial ambiguidade. */
unmatched_statement:
                        /* Um IF sem ELSE. O corpo (then) pode ser qualquer tipo de statement. */
                        if_head then_part                                                               { add_reduce_trace("unmatched_statement -> if_head then_part"); }

                        /* Um IF-ELSE onde a parte ELSE é ela mesma um unmatched_statement. */
                        | if_head then_part else_head unmatched_statement                               { exit_scope(); add_reduce_trace("unmatched_statement -> if_head then_part else_head unmatched_statement"); }
                        ;

/* 'then' representa o corpo de um comando IF ou WHILE.
   Pode ser um bloco {} ou um único matched_statement (para evitar ambiguidade). */
then:                   TK_LBRACE statements TK_RBRACE                                                  { add_reduce_trace("then -> { statements }"); }
                        | matched_statement                                                             { add_reduce_trace("then -> matched_statement"); }
                        ;

/* Regra auxiliar para unificar a abertura de escopo do IF */
if_head: 
    TK_IF TK_LPAREN expression TK_RPAREN                                                                {
                                                                                                            enter_scope();
                                                                                                            if ($3 != DT_BOOL) yyerror("Semantic Error: Operacao 'if' requer boleanos.");
                                                                                                            add_reduce_trace("if_head -> if ( expression )");
                                                                                                        }
    ;

/* Consome o ELSE e abre o escopo imediatamente */
else_head: 
    TK_ELSE                                                                                             { enter_scope(); add_reduce_trace("else_head -> else"); }
    ;

/* Regra auxiliar para consumir o 'then' e fechar o escopo imediatamente */
then_part:
    then                                                                                                { exit_scope(); add_reduce_trace("then_part -> then"); }
    ;

/* Regra para declaração de variáveis. */
declaration:            type id_list TK_SEMICOLON                                                       { add_reduce_trace("declaration -> type id_list TK_SEMICOLON");}
                        ;

/* Regra para os tipos de dados permitidos. */
type:                   TK_INT                                                                          { $$ = DT_INTEGER; current_declaration_type = DT_INTEGER; add_reduce_trace("type -> TK_INT");}
                        | TK_BOOL                                                                       { $$ = DT_BOOL; current_declaration_type = DT_BOOL;       add_reduce_trace("type -> TK_BOOL");}
                        ;

/* id_list agora é uma lista de 'declarator' */
id_list:
                        declarator                                                                      { add_reduce_trace("id_list -> declarator"); }
                        | id_list TK_COMMA declarator                                                   { add_reduce_trace("id_list -> id_list , declarator"); }
                        ;

/* 'declarator' pode ser apenas um ID ou um ID com inicialização */
declarator:
                        TK_ID                                                                           {
                                                                                                            /* Verifica se ja existe no escopo ATUAL */
                                                                                                            Symbol* s = lookup_symbol($1); 
                                                                                                            
                                                                                                            if (s != NULL && s->scope_depth == current_scope_depth) {
                                                                                                                char msg[200];
                                                                                                                sprintf(msg, "Semantic Error: Variavel '%s' ja declarada neste escopo.", $1);
                                                                                                                yyerror(msg);
                                                                                                            } else {
                                                                                                                /* Insere com o tipo guardado na variavel global */
                                                                                                                insert_symbol($1, TK_ID, current_declaration_type);
                                                                                                            }
                                                                                                            add_reduce_trace("declarator -> TK_ID"); 
                                                                                                        }
                        | TK_ID TK_ASSIGN expression                                                    {
                                                                                                            /* 1. Inserir a variavel */
                                                                                                            Symbol* s = lookup_symbol($1);
                                                                                                            if (s != NULL && s->scope_depth == current_scope_depth) {
                                                                                                                char msg[200]; sprintf(msg, "Semantic Error: Redeclaração de '%s'.", $1); yyerror(msg);
                                                                                                            } else {
                                                                                                                insert_symbol($1, TK_ID, current_declaration_type);
                                                                                                            }

                                                                                                            /* 2. Verificar tipo da atribuição */
                                                                                                            if (current_declaration_type != $3) {
                                                                                                                yyerror("Semantic Error: Tipo da expressao incompativel com a variavel na inicializacao.");
                                                                                                            }
                                                                                                            add_reduce_trace("declarator -> TK_ID = expression");
                                                                                                        }
                        ;
                    
/* Regra para comando de atribuição. */
assignment:             TK_ID TK_ASSIGN expression TK_SEMICOLON                                         {
                                                                                                            Symbol* s = lookup_symbol($1);
                                                                                                            if (s == NULL) {
                                                                                                                char msg[200]; sprintf(msg, "Semantic Error: Variavel '%s' nao declarada.", $1);
                                                                                                                yyerror(msg);
                                                                                                            } else {
                                                                                                                if (s->data_type != $3 && $3 != DT_ERROR) {
                                                                                                                    yyerror("Semantic Error: Atribuição com tipos incompatíveis.");
                                                                                                                }
                                                                                                            }
                                                                                                            add_reduce_trace("assignment");
                                                                                                        }
                        ;

/* Regra para comando de leitura. */
read:                   TK_READ TK_LPAREN TK_ID TK_RPAREN TK_SEMICOLON                                  { add_reduce_trace("read -> TK_READ ( TK_ID ) TK_SEMICOLON");}
                        ;

/* Regra para comando de impressão. */
print:                  TK_PRINT TK_LPAREN expression TK_RPAREN TK_SEMICOLON                            { add_reduce_trace("print -> TK_PRINT ( expression ) TK_SEMICOLON");}
                        ;

/* Regra para o comando 'while'. O corpo deve ser um bloco ou um matched_statement. */
while_stmt:
                        TK_WHILE TK_LPAREN expression TK_RPAREN { enter_scope(); } TK_LBRACE statements TK_RBRACE { exit_scope(); }     {
                                                                                                                                            if ($3 != DT_BOOL) yyerror("Semantic Error: Operacao 'while' requer boleanos.");
                                                                                                                                            add_reduce_trace("while_stmt -> WHILE ( expr ) { statements }");
                                                                                                                                        }
                        | TK_WHILE TK_LPAREN expression TK_RPAREN { enter_scope(); } matched_statement { exit_scope(); }                {
                                                                                                                                            if ($3 != DT_BOOL) yyerror("Semantic Error: Operacao 'while' requer boleanos.");
                                                                                                                                            add_reduce_trace("while_stmt -> WHILE ( expr ) matched_statement");
                                                                                                                                        }
                        ;

/* Regra para expressões. Cobre literais, identificadores, parênteses e todas as operações.
   A precedência e associatividade são resolvidas pelas diretivas %left/%right/%prec. */
expression:             TK_INTEGER                                                                      { $$ = DT_INTEGER; add_reduce_trace("expression -> TK_INTEGER");}
                        | TK_TRUE                                                                       { $$ = DT_BOOL; add_reduce_trace("expression -> TK_TRUE");}
                        | TK_FALSE                                                                      { $$ = DT_BOOL; add_reduce_trace("expression -> TK_FALSE");}
                        | TK_ID                                                                         {
                                                                                                            Symbol* s = lookup_symbol($1);
                                                                                                            if (s == NULL) {
                                                                                                                char msg[200]; sprintf(msg, "Semantic Error: Variavel '%s' não declarada.", $1);
                                                                                                                yyerror(msg);
                                                                                                                $$ = DT_ERROR;
                                                                                                            } else {
                                                                                                                $$ = s->data_type; /* O tipo da expressao é o tipo da variavel */
                                                                                                            }
                                                                                                            add_reduce_trace("expr -> id");
                                                                                                        }
                        | TK_LPAREN expression TK_RPAREN                                                { $$ = $2; add_reduce_trace("expression -> ( expression )");}

                        /* Expressões Aritméticas */
                        | expression TK_PLUS expression                                                 {
                                                                                                            if ($1 == DT_INTEGER && $3 == DT_INTEGER) $$ = DT_INTEGER;
                                                                                                            else { yyerror("Semantic Error: Operacao '+' requer inteiros."); $$ = DT_ERROR;}
                                                                                                            add_reduce_trace("expression -> expression - expression");
                                                                                                        }
                        | expression TK_MINUS expression                                                { 
                                                                                                            if ($1 == DT_INTEGER && $3 == DT_INTEGER) $$ = DT_INTEGER;
                                                                                                            else { yyerror("Semantic Error: Operacao '-' requer inteiros."); $$ = DT_ERROR;}
                                                                                                            add_reduce_trace("expression -> expression - expression");
                                                                                                        }
                        | expression TK_MULT expression                                                 { 
                                                                                                            if ($1 == DT_INTEGER && $3 == DT_INTEGER) $$ = DT_INTEGER;
                                                                                                            else { yyerror("Semantic Error: Operacao '*' requer inteiros."); $$ = DT_ERROR;}
                                                                                                            add_reduce_trace("expression -> expression * expression");
                                                                                                        }
                        | expression TK_DIV expression                                                  { 
                                                                                                            if ($1 == DT_INTEGER && $3 == DT_INTEGER) $$ = DT_INTEGER;
                                                                                                            else { yyerror("Semantic Error: Operacao '/' requer inteiros."); $$ = DT_ERROR;}
                                                                                                            add_reduce_trace("expression -> expression / expression");
                                                                                                        }
                        | expression TK_MOD expression                                                  { 
                                                                                                            if ($1 == DT_INTEGER && $3 == DT_INTEGER) $$ = DT_INTEGER;
                                                                                                            else { yyerror("Semantic Error: Operacao '%' requer inteiros."); $$ = DT_ERROR;}
                                                                                                            add_reduce_trace("expression -> expression % expression");
                                                                                                        }

                        /* Menos Unário (usa %prec UMINUS para maior precedência) */
                        | TK_MINUS expression %prec UMINUS                                              { 
                                                                                                            if ($2 == DT_INTEGER)  $$ = DT_INTEGER; 
                                                                                                             else { yyerror("Semantic Error: Operador unário '-' requer tipo inteiro."); $$ = DT_ERROR; }
                                                                                                            add_reduce_trace("expression -> - expression (Unary)");
                                                                                                        }

                        /* Expressões Relacionais */
                        | expression TK_EQ expression                                                   {
                                                                                                            if ($1 == $3 && $1 != DT_ERROR) $$ = DT_BOOL;
                                                                                                            else { yyerror("Semantic Error: Tipos incompatíveis na comparação '=='."); $$ = DT_ERROR; }
                                                                                                            add_reduce_trace("expression -> expression == expression");
                                                                                                        }
                        | expression TK_NE expression                                                   { 
                                                                                                            if ($1 == $3 && $1 != DT_ERROR) $$ = DT_BOOL;
                                                                                                            else { yyerror("Semantic Error: Tipos incompatíveis na comparação '!='."); $$ = DT_ERROR; }
                                                                                                            add_reduce_trace("expression -> expression != expression");
                                                                                                        }
                        | expression TK_LT expression                                                   { 
                                                                                                            if ($1 == DT_INTEGER && $3 == DT_INTEGER) $$ = DT_BOOL;
                                                                                                            else { yyerror("Semantic Error: Comparação '<' requer inteiros."); $$ = DT_ERROR;}
                                                                                                            add_reduce_trace("expression -> expression < expression");
                                                                                                        }
                        | expression TK_LE expression                                                   { 
                                                                                                            if ($1 == DT_INTEGER && $3 == DT_INTEGER) $$ = DT_BOOL;
                                                                                                            else { yyerror("Semantic Error: Comparação '<=' requer inteiros."); $$ = DT_ERROR;}
                                                                                                            add_reduce_trace("expression -> expression <= expression");
                                                                                                        }
                        | expression TK_GT expression                                                   { 
                                                                                                            if ($1 == DT_INTEGER && $3 == DT_INTEGER) $$ = DT_BOOL;
                                                                                                            else { yyerror("Semantic Error: Comparação '>' requer inteiros."); $$ = DT_ERROR;}
                                                                                                            add_reduce_trace("expression -> expression > expression");
                                                                                                        }
                        | expression TK_GE expression                                                   { 
                                                                                                            if ($1 == DT_INTEGER && $3 == DT_INTEGER) $$ = DT_BOOL;
                                                                                                            else { yyerror("Semantic Error: Comparação '>=' requer inteiros."); $$ = DT_ERROR;}
                                                                                                            add_reduce_trace("expression -> expression >= expression");
                                                                                                        }

                        /* Expressões Lógicas */
                        | expression TK_LOGICAL_AND expression                                          {
                                                                                                            if ($1 == DT_BOOL && $3 == DT_BOOL) $$ = DT_BOOL;
                                                                                                            else { yyerror("Semantic Error: Operacao '&&' requer booleanos."); $$ = DT_ERROR; }
                                                                                                            add_reduce_trace("expression -> expression && expression");
                                                                                                        }
                        | expression TK_LOGICAL_OR expression                                           {
                                                                                                            if ($1 == DT_BOOL && $3 == DT_BOOL) $$ = DT_BOOL;
                                                                                                            else { yyerror("Semantic Error: Operacao '||' requer booleanos."); $$ = DT_ERROR; }
                                                                                                            add_reduce_trace("expression -> expression || expression");
                                                                                                        }
                        | TK_LOGICAL_NOT expression                                                     {
                                                                                                            if ($2 == DT_BOOL) $$ = DT_BOOL;
                                                                                                            else { yyerror("Semantic Error: Operacao '!' requer booleanos."); $$ = DT_ERROR; }
                                                                                                            add_reduce_trace("expression -> ! expression");
                                                                                                        }
                        ;
%%
/* ======================================= Seção de Código C ======================================= */

/*
   Esta função é invocada automaticamente pelo parser quando um erro sintático
   é detectado. Ela formata a mensagem de erro (removendo prefixos genéricos
   se %define parse.error verbose estiver ativo), adiciona a posição do erro
   e registra a mensagem na string global g_full_trace para impressão posterior.
   Também incrementa o contador de erros sintáticos.
 */
void yyerror(const char *s) {
    char temp_str[512]; // Buffer para a linha completa do trace.
    char error_detail[400]; // Buffer para a mensagem de erro específica.

    // Tenta trocar o prefixo "syntax error, " para obter a mensagem mais útil.
    if (strncmp(s, "syntax error, ", 14) == 0) {
        snprintf(error_detail, sizeof(error_detail), "Sintatic Error: %s", s + 14);
    } else {
        snprintf(error_detail, sizeof(error_detail),
                "%s", s);
    }

    error_detail[sizeof(error_detail) - 1] = '\0'; // Garante terminação.

    // Formata a entrada do trace no padrão: "[Lin:Col]\tERRO\tDetalhe do erro\n"
    sprintf(temp_str, "[%03d:%03d]\tERRO\t%s\n",
            yylineno,     // Número da linha atual (do lexer).
            column_num,   // Número da coluna atual (do lexer).
            error_detail);// Mensagem específica do Bison.

    // Adiciona a linha de erro formatada ao buffer global do trace.
    strcat(g_full_trace, temp_str);
    sintatic_error_count++; // Incrementa o contador de erros sintáticos.
}

/*
   Esta função é chamada nas ações de cada regra gramatical. Ela formata
   a string da regra de redução junto com a posição atual (linha e coluna
   do último token consumido pela regra) e a anexa à string global g_full_trace.
 */
void add_reduce_trace(const char *rule) {
    char temp_str[256];             // Buffer aumentado para regras mais longas.

    // Formata a entrada do trace: "[Lin:Col]\tREDUCE\tDescrição da Regra\n"
    sprintf(temp_str, "[%03d:%03d]\tREDUCE\t%s\n", yylineno, column_num, rule);
    strcat(g_full_trace, temp_str); // Anexa ao buffer global.
}

/*
   Esta função lê a string global g_full_trace (preenchida durante o parsing),
   quebra-a em linhas e colunas (usando strtok_r e sscanf), e imprime
   uma tabela formatada no console com as colunas Posição, Ação e Detalhe.
   Linhas de erro são destacadas em vermelho.
 */
void parsing_table(){
    printf("\n"); // Adiciona um espaço antes da tabela.
    // Imprime o cabeçalho da tabela com bordas.
    printf("╔══════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                                       " BOLD MAGENTA "ANÁLISE SINTÁTICA E SEMÂNTICA" RESET "                                      ║\n");
    printf("╠═══════════╦═══════════╦══════════════════════════════════════════════════════════════════════════════════╣\n");
    printf("║ " BOLD YELLOW "%-9s" RESET " ║ " BOLD CYAN "  %-9s" RESET " ║ " BOLD GREEN "%-82s" RESET " ║\n", "[Lin:Col]", "AÇÃO", "DETALHE (Token ou Produção)");
    printf("╠═══════════╬═══════════╬══════════════════════════════════════════════════════════════════════════════════╣\n");

    char* saved_ptr; // Ponteiro de contexto para strtok_r.
    char* trace_copy = strdup(g_full_trace); // Cria uma cópia, pois strtok_r modifica a string.
    if (!trace_copy) { perror("Falha ao duplicar trace string para parsing_table"); return; }

    char* line = strtok_r(trace_copy, "\n", &saved_ptr); // Primeira chamada (pega o cabeçalho "AÇÃO\tDETALHE").
    line = strtok_r(NULL, "\n", &saved_ptr); // Segunda chamada (pega a primeira linha real do trace).

    // Itera sobre cada linha do trace.
    while (line != NULL) {
        char position[20], action[100], detail[200];
        // Tenta parsear a linha no formato "POSICAO \t ACAO \t DETALHE".
        if (sscanf(line, "%[^\t]\t%[^\t]\t%[^\n]", position, action, detail) == 3) {
             // Verifica se a ação é um erro para aplicar a cor vermelha.
             if (strcmp(action, "ERRO") == 0) {
                 printf("║ " BOLD YELLOW "%-9s" RESET " ║ " BOLD RED "%-9s" RESET " ║ " BOLD RED "%-80s" RESET " ║\n",
                        position, action, detail);
             } else { // Imprime linhas normais (SHIFT ou REDUCE).
                    // printf("║ " BOLD YELLOW "%-9s" RESET " ║ " CYAN "%-9s" RESET " ║ " GREEN "%-80s" RESET " ║\n", position, action, detail);
             }
        } else {
             // Linha mal formatada no trace (não deve acontecer se add_reduce_trace e yyerror estiverem corretos)
             fprintf(stderr, "Aviso: Linha mal formatada no trace interno: %s\n", line);
        }
        line = strtok_r(NULL, "\n", &saved_ptr); // Pega a próxima linha.
    }
    free(trace_copy); // Libera a memória da cópia da string do trace.

    // Imprime o rodapé da tabela com o status final.
    printf("╠═══════════╩═══════════╩══════════════════════════════════════════════════════════════════════════════════╣\n");
    if (sintatic_error_count == 0) {
        printf("║ " BOLD GREEN "Análise concluída com sucesso!                                                                          "RESET"║\n");
    } else{
        // Usa %.3d para garantir 3 dígitos na contagem (ex: 001 erro).
        printf("║ " BOLD RED "Análise concluída com %.3d erro(s).                                                                       "RESET"║\n", sintatic_error_count);
    }
    printf("╚══════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n");
}

/* ======================== IMPLEMENTAÇÃO DA TABELA DE SÍMBOLOS ======================== */

/* Função hash DJB2 */
unsigned int hash_function(const char *lexeme) {
    unsigned int hash = 5381;
    int c;
    while ((c = *lexeme++)) {
        hash = ((hash << 5) + hash) + c;
    }
    return hash % 997;
}

/* Inicializar tabela de símbolos global */
void initialize_symbol_table() {
    global_scope = (ScopeTable *)malloc(sizeof(ScopeTable));
    memset(global_scope, 0, sizeof(ScopeTable));

    global_scope->id = global_scope_counter++;
    global_scope->parent = NULL;

    current_scope = global_scope;
    current_scope_depth = 0;
}

/* Entrar em novo escopo (criar nova tabela de símbolos filha) */
void enter_scope() {
    ScopeTable *new_scope = (ScopeTable *)malloc(sizeof(ScopeTable));
    memset(new_scope, 0, sizeof(ScopeTable));

    new_scope->id = global_scope_counter++;
    new_scope->parent = current_scope;

    current_scope = new_scope;
    current_scope_depth++;
}

/* Sair do escopo atual (voltar ao escopo pai) */
void exit_scope() {
    if (current_scope->parent != NULL) {
        current_scope = current_scope->parent;
        current_scope_depth--;
    }
}

/* Inserir símbolo no escopo atual */
void insert_symbol(char *lexeme, int token_type, int data_type) {
    if (lookup_symbol(lexeme) != NULL)
        return; /* Ja existe em algum escopo, não insere duplicata */

    /* Criar novo símbolo com id, type e scope_depth */
    Symbol *new_symbol = (Symbol *)malloc(sizeof(Symbol));
    new_symbol->id = ++global_symbol_count;
    new_symbol->token_type = token_type;
    new_symbol->data_type = data_type;
    new_symbol->scope_depth = current_scope_depth;
    new_symbol->lexeme = strdup(lexeme);
    new_symbol->scope_id = current_scope->id;
    new_symbol->line = yylineno;         
    new_symbol->column = column_num;

    /* Calcular índice de hash */
    unsigned int idx = hash_function(lexeme);

    /* Criar novo nó e inserir no escopo atual */
    HashNode *new_node = (HashNode *)malloc(sizeof(HashNode));
    new_node->symbol = new_symbol;
    new_node->next = current_scope->hash_table[idx];
    current_scope->hash_table[idx] = new_node;

    /* Manter ordem de inserção para impressão neste escopo */
    if (current_scope->symbol_count >= current_scope->capacity) {
        current_scope->capacity = (current_scope->capacity == 0) ? 10 : current_scope->capacity * 2;
        current_scope->symbol_order = (Symbol **)realloc(current_scope->symbol_order, current_scope->capacity * sizeof(Symbol *));
        current_scope->symbol_lexeme = (char **)realloc(current_scope->symbol_lexeme, current_scope->capacity * sizeof(char *));
    }
    current_scope->symbol_order[current_scope->symbol_count] = new_symbol;
    current_scope->symbol_lexeme[current_scope->symbol_count] = new_symbol->lexeme;
    current_scope->symbol_count++;

    /* Adicionar à lista global */
    if (all_symbols_count >= all_symbols_capacity) {
        all_symbols_capacity = (all_symbols_capacity == 0) ? 20 : all_symbols_capacity * 2;
        all_symbols = (Symbol **)realloc(all_symbols, all_symbols_capacity * sizeof(Symbol *));
    }
    all_symbols[all_symbols_count] = new_symbol;
    all_symbols_count++;
}

/* Buscar símbolo na árvore de escopos (começa no escopo atual e sobe para o pai) */
Symbol* lookup_symbol(char *lexeme) {
    ScopeTable *scope = current_scope;

    while (scope != NULL) {
        unsigned int idx = hash_function(lexeme);
        HashNode *node = scope->hash_table[idx];

        while (node != NULL) {
            if (strcmp(node->symbol->lexeme, lexeme) == 0) {
                return node->symbol;
            }
            node = node->next;
        }
        scope = scope->parent; /* Busca no escopo pai */
    }
    return NULL;
}

/* Converter token_type (int) em string para impressão */
const char* token_type_to_string(int type) {
    switch (type) {

        case DT_INTEGER: return "INTEGER";
        case DT_BOOL: return "BOOL";
        case DT_ERROR: return "DT_ERROR";

        /* Palavras-chave e Tipos */
        case TK_INT: return "TK_INT";
        case TK_BOOL: return "TK_BOOL";
        case TK_IF: return "TK_IF";
        case TK_ELSE: return "TK_ELSE";
        case TK_WHILE: return "TK_WHILE";
        case TK_PRINT: return "TK_PRINT";
        case TK_READ: return "TK_READ";
        case TK_TRUE: return "TK_TRUE";
        case TK_FALSE: return "TK_FALSE";

        /* Pontuação */
        case TK_SEMICOLON: return "TK_SEMICOLON";
        case TK_COMMA: return "TK_COMMA";
        case TK_LPAREN: return "TK_LPAREN";
        case TK_RPAREN: return "TK_RPAREN";
        case TK_LBRACE: return "TK_LBRACE";
        case TK_RBRACE: return "TK_RBRACE";

        /* Literais */
        case TK_INTEGER: return "TK_INTEGER";
        case TK_ID: return "TK_ID";

        /* Operadores Relacionais */
        case TK_EQ: return "TK_EQ";
        case TK_NE: return "TK_NE";
        case TK_LE: return "TK_LE";
        case TK_GE: return "TK_GE";
        case TK_LT: return "TK_LT";
        case TK_GT: return "TK_GT";

        /* Operadores Lógicos */
        case TK_LOGICAL_AND: return "TK_LOGICAL_AND";
        case TK_LOGICAL_OR: return "TK_LOGICAL_OR";
        case TK_LOGICAL_NOT: return "TK_LOGICAL_NOT";

        /* Aritméticos */
        case TK_PLUS: return "TK_PLUS";
        case TK_MINUS: return "TK_MINUS";
        case TK_MULT: return "TK_MULT";
        case TK_DIV: return "TK_DIV";
        case TK_MOD: return "TK_MOD";

        /* Atribuição */
        case TK_ASSIGN: return "TK_ASSIGN";

        /* Operador Unário */
        case UMINUS: return "UMINUS";

        default:
            return "UNKNOWN_TOKEN";
    }
}

/* Imprimir tabela de símbolos */
void print_symbol_table() {
    printf("╔══════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                                            " BOLD MAGENTA "TABELA DE SÍMBOLOS" RESET"                                            ║\n");
    printf("╠═══════╦═══════════╦══════════════════════════════╦═════════════════╦═════════════════╦═════════╦═════════╣\n");
    printf("║ " BOLD BLUE "%-5s" RESET " ║ " BOLD YELLOW "%-5s" RESET " ║ " BOLD CYAN "%-28s" RESET " ║ " BOLD GREEN "%-15s" RESET " ║ " BOLD GREEN "%-15s" RESET " ║ " BOLD MAGENTA "%-7s" RESET " ║ " BOLD BLUE "%-7s" RESET " ║\n", "[ID]", "[Lin:Col]", "LEXEMA", "TOKEN",  "TIPO", "DEPTH", "ESCOPO");
    printf("╠═══════╬═══════════╬══════════════════════════════╬═════════════════╬═════════════════╬═════════╬═════════╣\n");

    /* Usar lista global de símbolos mantendo ordem de inserção */
    for (int i = 0; i < all_symbols_count; i++) {
        printf("║ " BOLD BLUE "[%03d]" RESET " ║ " BOLD YELLOW "[%03d:%03d]" RESET " ║ " BOLD CYAN "%-28s" RESET " ║ " BOLD GREEN "%-15s" RESET " ║ " BOLD GREEN "%-15s" RESET " ║ " BOLD MAGENTA "%-7d" RESET " ║ " BOLD BLUE "%-7d" RESET " ║\n",
                all_symbols[i]->id,
                all_symbols[i]->line,
                all_symbols[i]->column,
                all_symbols[i]->lexeme,
                token_type_to_string(all_symbols[i]->token_type),
                token_type_to_string(all_symbols[i]->data_type),
                all_symbols[i]->scope_depth,
                all_symbols[i]->scope_id);
    }
    printf("╠═══════╩═══════════╩══════════════════════════════╩═════════════════╩═════════════════╩═════════╩═════════╣\n");
    printf("║ " BOLD "Total de símbolos:" RESET "%-56d                               ║\n", all_symbols_count);
    printf("╚══════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n");
}

/*
   Responsável por:
   1. Validar argumentos de linha de comando.
   2. Abrir o arquivo de entrada.
   3. Imprimir o cabeçalho da tabela de análise léxica.
   4. Chamar yyparse() para iniciar a análise sintática (que por sua vez chama yylex()).
   5. Imprimir o rodapé e status da análise léxica.
   6. Chamar parsing_table() para imprimir a tabela de trace sintático.
   7. Imprimir o status da análise sintática.
   8. Chamar print_symbol_table() para imprimir a tabela de símbolos (preenchida pelo lexer).
   9. Fechar o arquivo e retornar o status de sucesso (0) ou erro (1).
 */
int main(int argc, char *argv[]) {
    // Verifica se o nome do arquivo foi passado como argumento.
    if (argc < 2) {
        fprintf(stderr, "Uso: %s <arquivo>\n", argv[0]);
        return 1; // Retorna erro.
    }

    // Tenta abrir o arquivo de entrada para leitura.
    yyin = fopen(argv[1], "r");
    if (!yyin) {
        perror("Erro ao abrir o arquivo"); // Exibe erro do sistema.
        return 1; // Retorna erro.
    }

    /* Inicialização da tabela de símbolos com escopo global */
    initialize_symbol_table();

    /* Imprime o cabeçalho da tabela de ANÁLISE LÉXICA. */
    printf("╔══════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                                              " BOLD MAGENTA "ANÁLISE LÉXICA" RESET "                                              ║\n");
    printf("╠═══════════╦══════════════════════╦═══════════════════════════════════════════════════════════════════════╣\n");
    printf("║ " BOLD YELLOW "%-9s" RESET " ║ " BOLD CYAN "%-20s" RESET " ║ " BOLD GREEN "%-69s" RESET " ║\n", "[Lin:Col]", "TOKEN", "LEXEMA");
    printf("╠═══════════╬══════════════════════╬═══════════════════════════════════════════════════════════════════════╣\n");

    /* Chama a função principal do Bison para iniciar o parsing.
       yyparse() chamará yylex() repetidamente para obter tokens.
       yylex() chamará print_token(), que imprime a tabela léxica e preenche g_full_trace com SHIFTs.
       As ações das regras gramaticais chamarão add_reduce_trace(), preenchendo g_full_trace com REDUCEs.
       Se ocorrer um erro sintático, yyerror() será chamada, preenchendo g_full_trace com ERROs. */
    yyparse();

    /* Imprime o rodapé e o status da ANÁLISE LÉXICA. */
    printf("╠═══════════╩══════════════════════╩═══════════════════════════════════════════════════════════════════════╣\n");
    if (lexic_error_count == 0) {
        printf("║ " BOLD GREEN "Análise Léxica concluída com sucesso!                                                                    " RESET "║\n");
    } else{
        printf("║ " BOLD RED "Análise Léxica concluída com %.3d erro(s).                                                                " RESET "║\n", lexic_error_count);
    }
    printf("╚══════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n");


    /* Imprime a tabela de ANÁLISE SINTÁTICA (trace) que foi preenchida durante o yyparse(). */
    parsing_table();

    /* Imprime a TABELA DE SÍMBOLOS que foi preenchida pelo analisador léxico. */
    print_symbol_table();

    // Fecha o arquivo de entrada.
    fclose(yyin);

    // Retorna 0 se não houve erros, 1 caso contrário.
    return (lexic_error_count == 0 && sintatic_error_count == 0) ? 0 : 1;
}