/* ======================== Seção de Definições (Bison) ======================== */
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "codegen.h"

/* Tipos de dados da linguagem */
#define DT_INTEGER 1
#define DT_BOOL    2
#define DT_ERROR  -1

/* Contexto global para declarações (ex: int a, b, c;) */
int current_declaration_type;

/* ======================== ESTRUTURAS DA TABELA DE SÍMBOLOS ======================== */
typedef struct symbol {
    int id;                         /* ID único */
    int token_type;                 /* TK_INT, TK_BOOL */
    int data_type;                  /* DT_INTEGER, DT_BOOL */
    int scope_depth;                /* Profundidade do escopo */
    int scope_id;                   /* ID do escopo */
    int line;
    int column;
    char *lexeme;
} Symbol;

typedef struct hash_node {
    Symbol *symbol;
    struct hash_node *next;
} HashNode;

typedef struct scope_table {
    HashNode *hash_table[997];
    int symbol_count;
    struct scope_table *parent;
    Symbol **symbol_order;          /* Para impressão ordenada */
    char **symbol_lexeme;
    int capacity;
    int id;
} ScopeTable;

/* Globais da Tabela de Símbolos */
ScopeTable *global_scope = NULL;
ScopeTable *current_scope = NULL;
int global_symbol_count = 0;
int current_scope_depth = 0;
int global_scope_counter = 0;

/* Lista global para relatório final */
Symbol **all_symbols = NULL;
int all_symbols_count = 0;
int all_symbols_capacity = 0;

/* Cores ANSI */
#define RESET   "\033[0m"
#define RED     "\033[31m"
#define GREEN   "\033[32m"
#define YELLOW  "\033[33m"
#define BLUE    "\033[34m"
#define MAGENTA "\033[35m"
#define CYAN    "\033[36m"
#define BOLD    "\033[1m"

/* Protótipos */
unsigned int hash_function(const char *lexeme);
void initialize_symbol_table();
void enter_scope();
void exit_scope();
void insert_symbol(char *lexeme, int token_type, int data_type);
Symbol* lookup_symbol(char *lexeme);
void print_symbol_table();
const char* token_type_to_string(int type);

/* Protótipos Externos (Lexer e Codegen) */
extern int yylex();
extern FILE *yyin;
extern int yylineno;
extern int lexic_error_count;
extern int column_num;
extern void emit_flush();

int sintatic_error_count = 0;

void add_reduce_trace(const char *rule);
void yyerror(const char *s);
char g_full_trace[65536] = "AÇÃO\tDETALHE\n";

%}

%code requires {
    /* Estrutura para atributos sintetizados de expressões */
    typedef struct {
        int type;       /* Tipo semântico (DT_INTEGER, DT_BOOL) */
        char *addr;     /* Endereço no Código Intermediário (t1, x, 10) */
    } ExprInfo;
}

%union {
    int ival;           /* Valores inteiros e tipos */
    char *sval;         /* Lexemas e Labels */
    ExprInfo expr_val;  /* Atributos de expressão */
}

/* ======================== Definição de Tokens ======================== */

%token TK_INT TK_BOOL TK_IF TK_ELSE TK_WHILE TK_PRINT
%token TK_READ TK_TRUE TK_FALSE
%token TK_SEMICOLON TK_COMMA TK_LPAREN TK_RPAREN TK_LBRACE TK_RBRACE
%token <ival> TK_INTEGER 
%token <sval> TK_ID
%token TK_EQ TK_NE TK_LE TK_GE TK_LT TK_GT
%token TK_LOGICAL_AND TK_LOGICAL_OR TK_LOGICAL_NOT
%token TK_PLUS TK_MINUS TK_MULT TK_DIV TK_MOD
%token TK_ASSIGN

/* Tipos dos não-terminais */
%type <ival> type
%type <expr_val> expression
%type <sval> if_head while_start else_jump if_else_bridge

/* Configurações do Bison */
%define parse.error verbose
%start program

/* ======================== Precedência de Operadores ======================== */
/* Ordem crescente de precedência */
%left TK_LOGICAL_OR
%left TK_LOGICAL_AND
%left TK_EQ TK_NE
%left TK_LT TK_LE TK_GT TK_GE
%left TK_PLUS TK_MINUS
%left TK_MULT TK_DIV TK_MOD
%right TK_LOGICAL_NOT
%right UMINUS

/* ======================== Gramática ======================== */
%%

program:
    statements { add_reduce_trace("program -> statements"); }
    ;

statements:
    /* epsilon */ { add_reduce_trace("statements -> epsilon"); }
    | statements statement { add_reduce_trace("statements -> statements statement"); }
    
    /* Recuperação de Erro (Modo Pânico) */
    | statements error TK_SEMICOLON { yyerrok; add_reduce_trace("statements -> error ; (Recuperacao)"); }
    | statements error TK_RBRACE    { add_reduce_trace("statements -> error } (Recuperacao Fim Bloco)"); }
    ;

/* Resolução do Dangling Else via fatoração gramatical (Matched/Unmatched) */
statement:
    matched_statement { add_reduce_trace("statement -> matched"); }
    | unmatched_statement { add_reduce_trace("statement -> unmatched"); }
    ;

matched_statement:
    declaration { add_reduce_trace("matched -> declaration"); }
    | assignment { add_reduce_trace("matched -> assignment"); }
    | read { add_reduce_trace("matched -> read"); }
    | print { add_reduce_trace("matched -> print"); }
    | while_stmt { add_reduce_trace("matched -> while"); }
    
    /* IF-ELSE completo (ambos os ramos fechados) */
    | if_head then_part if_else_bridge then_part { 
        emitLabel($3); /* Label de fim */
        add_reduce_trace("matched -> if-else"); 
    }
    ;

unmatched_statement:
    /* IF sem ELSE */
    if_head then_part { 
        emitLabel($1); /* Label de falso */
        add_reduce_trace("unmatched -> if"); 
    }
    
    /* IF-ELSE incompleto (o else contém um unmatched) */
    | if_head then_part if_else_bridge unmatched_statement { 
        exit_scope(); 
        emitLabel($3); /* Label de fim */
        add_reduce_trace("unmatched -> if-else-incompleto"); 
    }
    ;

then:
    TK_LBRACE statements TK_RBRACE { add_reduce_trace("then -> block"); }
    | matched_statement { add_reduce_trace("then -> stmt"); }
    ;

/* --- Auxiliares de Controle de Fluxo --- */

/* Gera teste condicional do IF e label de falso */
if_head: 
    TK_IF TK_LPAREN expression TK_RPAREN {
        enter_scope();
        char *L_false = newLabel();
        
        if ($3.type != DT_BOOL) {
            yyerror("Semantic Error: Condicao do 'if' deve ser booleana.");
        } else {
            emit("ifFalse %s goto %s", $3.addr, L_false);
        }
        $$ = L_false;
        add_reduce_trace("if_head");
    }
    ;

/* Gera salto incondicional para pular o ELSE */
else_jump: /* epsilon */ {
    $$ = newLabel();
    emit("goto %s", $$);
};

/* Ponto de junção IF/ELSE para evitar conflitos de redução */
if_else_bridge: else_jump {
    /* Imprime o label de falso do IF (guardado na pilha em $-1) */
    emitLabel($<sval>-1); 
} else_head {
    /* Propaga o label de fim para a regra pai */
    $$ = $1;
};

else_head: 
    TK_ELSE { enter_scope(); add_reduce_trace("else_head"); }
    ;

then_part:
    then { exit_scope(); add_reduce_trace("then_part"); }
    ;

/* --- Declarações --- */

declaration:
    type id_list TK_SEMICOLON { add_reduce_trace("declaration"); }
    ;

type:
    TK_INT { $$ = DT_INTEGER; current_declaration_type = DT_INTEGER; add_reduce_trace("type -> int"); }
    | TK_BOOL { $$ = DT_BOOL; current_declaration_type = DT_BOOL; add_reduce_trace("type -> bool"); }
    ;

id_list:
    declarator { add_reduce_trace("id_list -> declarator"); }
    | id_list TK_COMMA declarator { add_reduce_trace("id_list -> list, declarator"); }
    ;

declarator:
    TK_ID {
        /* Apenas declaração */
        Symbol* s = lookup_symbol($1);
        if (s != NULL && s->scope_depth == current_scope_depth) {
            char msg[200]; sprintf(msg, "Semantic Error: Variavel '%s' ja declarada neste escopo.", $1);
            yyerror(msg);
        } else {
            insert_symbol($1, TK_ID, current_declaration_type);
            s = lookup_symbol($1);
        }
        add_reduce_trace("declarator -> id"); 
    }
    | TK_ID TK_ASSIGN expression {
        /* Declaração com inicialização */
        Symbol* s = lookup_symbol($1);
        if (s != NULL && s->scope_depth == current_scope_depth) {
            char msg[200]; sprintf(msg, "Semantic Error: Redeclaração de '%s'.", $1);
            yyerror(msg);
        } else {
            insert_symbol($1, TK_ID, current_declaration_type);
            s = lookup_symbol($1);
        }

        if (current_declaration_type != $3.type) {
            yyerror("Semantic Error: Tipo incompativel na inicializacao.");
        } else {
            char unique_target[100];
            sprintf(unique_target, "%s_%d", s->lexeme, s->scope_id);
            emit("%s = %s", unique_target, $3.addr);
        }
        add_reduce_trace("declarator -> id = expr");
    }
    ;
                    
/* --- Comandos --- */

assignment:
    TK_ID TK_ASSIGN expression TK_SEMICOLON {
        Symbol* s = lookup_symbol($1);
        if (s == NULL) {
            char msg[200]; sprintf(msg, "Semantic Error: Variavel '%s' nao declarada.", $1);
            yyerror(msg);
        } else {
            if (s->data_type != $3.type && $3.type != DT_ERROR) {
                yyerror("Semantic Error: Atribuicao com tipos incompativeis.");
            } else {
                char unique_target[100];
                sprintf(unique_target, "%s_%d", s->lexeme, s->scope_id);
                emit("%s = %s", unique_target, $3.addr);
            }
        }
        add_reduce_trace("assignment");
    }
    ;

read:
    TK_READ TK_LPAREN TK_ID TK_RPAREN TK_SEMICOLON {
        Symbol* s = lookup_symbol($3);
        if (s == NULL) {
            char msg[200]; sprintf(msg, "Semantic Error: Variavel '%s' nao declarada no 'read'.", $3);
            yyerror(msg);
        } else {
            char unique_name[100];
            sprintf(unique_name, "%s_%d", s->lexeme, s->scope_id);
            emit("read %s", unique_name);
        }
        add_reduce_trace("read");
    }
    ;

print:
    TK_PRINT TK_LPAREN expression TK_RPAREN TK_SEMICOLON {
        if ($3.type != DT_ERROR) {
            emit("print %s", $3.addr);
        }
        add_reduce_trace("print");
    }
    ;

while_start:
    TK_WHILE {
        char *L_start = newLabel();
        emitLabel(L_start);
        $$ = L_start;
    }
    ;

while_stmt:
    /* Loop com bloco */
    while_start TK_LPAREN expression TK_RPAREN { 
        /* Ação Média: Teste condicional antes do corpo */
        char *L_end = newLabel();
        if ($3.type != DT_BOOL) {
            yyerror("Semantic Error: Condicao do 'while' deve ser booleana.");
        } else {
            emit("ifFalse %s goto %s", $3.addr, L_end);
        }
        enter_scope(); 
        $<sval>$ = L_end; 
    } 
    TK_LBRACE statements TK_RBRACE { 
        exit_scope(); 
        char *L_start = $1;
        char *L_end = $<sval>5;
        emit("goto %s", L_start);
        emitLabel(L_end);
        add_reduce_trace("while (block)"); 
    }
    
    /* Loop com comando único */
    | while_start TK_LPAREN expression TK_RPAREN { 
        char *L_end = newLabel();
        if ($3.type != DT_BOOL) {
            yyerror("Semantic Error: Condicao do 'while' deve ser booleana.");
        } else {
            emit("ifFalse %s goto %s", $3.addr, L_end);
        }
        enter_scope(); 
        $<sval>$ = L_end; 
    } 
    matched_statement { 
        exit_scope(); 
        char *L_start = $1;
        char *L_end = $<sval>5;
        emit("goto %s", L_start);
        emitLabel(L_end);
        add_reduce_trace("while (single)"); 
    }
    ;

/* --- Expressões --- */

expression:
    TK_INTEGER {
        $$.type = DT_INTEGER;
        $$.addr = (char*)malloc(20); 
        sprintf($$.addr, "%d", $1);
        add_reduce_trace("expr -> int");
    }
    | TK_TRUE { 
        $$.type = DT_BOOL; 
        $$.addr = "true"; 
        add_reduce_trace("expr -> true");
    }
    | TK_FALSE { 
        $$.type = DT_BOOL; 
        $$.addr = "false"; 
        add_reduce_trace("expr -> false");
    }
    | TK_ID {
        Symbol* s = lookup_symbol($1);
        if (s == NULL) {
            char msg[200]; sprintf(msg, "Semantic Error: Variavel '%s' nao declarada.", $1);
            yyerror(msg);
            $$.type = DT_ERROR;
            $$.addr = "ERR";
        } else {
            $$.type = s->data_type;
            char unique_name[100];
            sprintf(unique_name, "%s_%d", s->lexeme, s->scope_id); // Ex: x_1
            $$.addr = strdup(unique_name);
        }
        add_reduce_trace("expr -> id");
    }
    | TK_LPAREN expression TK_RPAREN { 
        $$ = $2; 
        add_reduce_trace("expr -> ( expr )");
    }

    /* Aritmética */
    | expression TK_PLUS expression {
        if ($1.type == DT_INTEGER && $3.type == DT_INTEGER){
            $$.type = DT_INTEGER;
            $$.addr = newTemp();
            emit("%s = %s + %s", $$.addr, $1.addr, $3.addr); 
        } else { 
            yyerror("Semantic Error: Operacao '+' requer inteiros."); 
            $$.type = DT_ERROR; $$.addr = "ERR";
        }
        add_reduce_trace("expr -> +");
    }
    | expression TK_MINUS expression { 
        if ($1.type == DT_INTEGER && $3.type == DT_INTEGER) {
            $$.type = DT_INTEGER;
            $$.addr = newTemp();
            emit("%s = %s - %s", $$.addr, $1.addr, $3.addr); 
        } else { 
            yyerror("Semantic Error: Operacao '-' requer inteiros."); 
            $$.type = DT_ERROR; $$.addr = "ERR";
        }
        add_reduce_trace("expr -> -");
    }
    | expression TK_MULT expression { 
        if ($1.type == DT_INTEGER && $3.type == DT_INTEGER) {
            $$.type = DT_INTEGER;
            $$.addr = newTemp();
            emit("%s = %s * %s", $$.addr, $1.addr, $3.addr); 
        } else { 
            yyerror("Semantic Error: Operacao '*' requer inteiros."); 
            $$.type = DT_ERROR; $$.addr = "ERR";
        }
        add_reduce_trace("expr -> *");
    }
    | expression TK_DIV expression { 
        if ($1.type == DT_INTEGER && $3.type == DT_INTEGER) {
            $$.type = DT_INTEGER;
            $$.addr = newTemp();
            emit("%s = %s / %s", $$.addr, $1.addr, $3.addr); 
        } else { 
            yyerror("Semantic Error: Operacao '/' requer inteiros."); 
            $$.type = DT_ERROR; $$.addr = "ERR";
        }
        add_reduce_trace("expr -> /");
    }
    | expression TK_MOD expression { 
        if ($1.type == DT_INTEGER && $3.type == DT_INTEGER) {
            $$.type = DT_INTEGER;
            $$.addr = newTemp();
            emit("%s = %s %% %s", $$.addr, $1.addr, $3.addr); 
        } else { 
            yyerror("Semantic Error: Operacao '%%' requer inteiros."); 
            $$.type = DT_ERROR; $$.addr = "ERR";
        }
        add_reduce_trace("expr -> %");
    }

    /* Menos Unário */
    | TK_MINUS expression %prec UMINUS { 
        if ($2.type == DT_INTEGER) {
            $$.type = DT_INTEGER;
            $$.addr = newTemp();
            emit("%s = -%s", $$.addr, $2.addr); 
        } else { 
            yyerror("Semantic Error: Operador unario '-' requer inteiro."); 
            $$.type = DT_ERROR; $$.addr = "ERR";
        }
        add_reduce_trace("expr -> unary -");
    }

    /* Relacional */
    | expression TK_EQ expression {
        if ($1.type == $3.type && $1.type != DT_ERROR) {
            $$.type = DT_BOOL;
            $$.addr = newTemp();
            emit("%s = %s == %s", $$.addr, $1.addr, $3.addr); 
        } else { 
            yyerror("Semantic Error: Tipos incompativeis em '=='."); 
            $$.type = DT_ERROR; $$.addr = "ERR";
        }
        add_reduce_trace("expr -> ==");
    }
    | expression TK_NE expression { 
        if ($1.type == $3.type && $1.type != DT_ERROR) {
            $$.type = DT_BOOL;
            $$.addr = newTemp();
            emit("%s = %s != %s", $$.addr, $1.addr, $3.addr); 
        } else { 
            yyerror("Semantic Error: Tipos incompativeis em '!='."); 
            $$.type = DT_ERROR; $$.addr = "ERR"; 
        }
        add_reduce_trace("expr -> !=");
    }
    | expression TK_LT expression { 
        if ($1.type == DT_INTEGER && $3.type == DT_INTEGER) {
            $$.type = DT_BOOL;
            $$.addr = newTemp();
            emit("%s = %s < %s", $$.addr, $1.addr, $3.addr); 
        } else { 
            yyerror("Semantic Error: '<' requer inteiros."); 
            $$.type = DT_ERROR; $$.addr = "ERR";
        }
        add_reduce_trace("expr -> <");
    }
    | expression TK_LE expression { 
        if ($1.type == DT_INTEGER && $3.type == DT_INTEGER) {
            $$.type = DT_BOOL;
            $$.addr = newTemp();
            emit("%s = %s <= %s", $$.addr, $1.addr, $3.addr); 
        } else { 
            yyerror("Semantic Error: '<=' requer inteiros."); 
            $$.type = DT_ERROR; $$.addr = "ERR";
        }
        add_reduce_trace("expr -> <=");
    }
    | expression TK_GT expression { 
        if ($1.type == DT_INTEGER && $3.type == DT_INTEGER) {
            $$.type = DT_BOOL;
            $$.addr = newTemp();
            emit("%s = %s > %s", $$.addr, $1.addr, $3.addr); 
        } else { 
            yyerror("Semantic Error: '>' requer inteiros."); 
            $$.type = DT_ERROR; $$.addr = "ERR";
        }
        add_reduce_trace("expr -> >");
    }
    | expression TK_GE expression { 
        if ($1.type == DT_INTEGER && $3.type == DT_INTEGER) {
            $$.type = DT_BOOL;
            $$.addr = newTemp();
            emit("%s = %s >= %s", $$.addr, $1.addr, $3.addr); 
        } else { 
            yyerror("Semantic Error: '>=' requer inteiros."); 
            $$.type = DT_ERROR; $$.addr = "ERR";
        }
        add_reduce_trace("expr -> >=");
    }
/* Lógica E (AND) com Curto-Circuito Explícito */
    | expression TK_LOGICAL_AND {
        /* Ação de Meio de Regra: Avaliou o primeiro operando (A) */
        char *L_false = newLabel();
        
        /* Se A for Falso, já sabemos o resultado: pula tudo para definir como false */
        emit("ifFalse %s goto %s", $1.addr, L_false);
        
        /* Passa o label L_false para a parte final */
        $<sval>$ = L_false; 
    } expression {
        /* Parte Final: Avaliou o segundo operando (B) */
        char *L_false = $<sval>3; 
        char *L_end = newLabel(); 
        
        $$.type = DT_BOOL;
        $$.addr = newTemp(); // Temporário para o resultado final
        
        /* Neste ponto, A é com certeza Verdadeiro (senão teria pulado).
           Agora testamos B. Se B for Falso, também pulamos para L_false. */
        emit("ifFalse %s goto %s", $4.addr, L_false);
        
        /* Se chegou aqui, A é True E B é True. Resultado = True */
        emit("%s = true", $$.addr);
        emit("goto %s", L_end);
        
        /* Bloco Falso: Chega aqui se A for False OU se B for False */
        emitLabel(L_false);
        emit("%s = false", $$.addr);
        
        /* Fim da operação */
        emitLabel(L_end);
        
        /* Verificação Semântica */
        if ($1.type == DT_BOOL && $4.type == DT_BOOL) $$.type = DT_BOOL;
        else { yyerror("Semantic Error: Operacao '&&' requer booleanos."); $$.type = DT_ERROR; }
        
        add_reduce_trace("expr -> &&");
    }

    /* Lógica OU (OR) com Curto-Circuito Explícito */
    | expression TK_LOGICAL_OR {
        /* Ação de Meio de Regra: Avaliou o primeiro operando (A) */
        char *L_true = newLabel();
        
        /* Se A for Verdadeiro, já sabemos o resultado: pula tudo para definir como true */
        emit("ifTrue %s goto %s", $1.addr, L_true); 
        
        /* Passa o label L_true para a parte final */
        $<sval>$ = L_true; 
    } expression {
        /* Parte Final: Avaliou o segundo operando (B) */
        char *L_true = $<sval>3;
        char *L_end = newLabel();
        
        $$.type = DT_BOOL;
        $$.addr = newTemp();
        
        /* Neste ponto, A é com certeza Falso (senão teria pulado).
           Agora testamos B. Se B for Verdadeiro, pulamos para L_true. */
        emit("ifTrue %s goto %s", $4.addr, L_true);
        
        /* Se chegou aqui, A é False E B é False. Resultado = False */
        emit("%s = false", $$.addr);
        emit("goto %s", L_end);
        
        /* Bloco Verdadeiro: Chega aqui se A for True OU se B for True */
        emitLabel(L_true);
        emit("%s = true", $$.addr);
        
        /* Fim da operação */
        emitLabel(L_end);
        
        /* Verificação Semântica */
        if ($1.type == DT_BOOL && $4.type == DT_BOOL) $$.type = DT_BOOL;
        else { yyerror("Semantic Error: Operacao '||' requer booleanos."); $$.type = DT_ERROR; }
        
        add_reduce_trace("expr -> ||");
    }

    | TK_LOGICAL_NOT expression {
        if ($2.type == DT_BOOL) $$.type = DT_BOOL;
        else { yyerror("Semantic Error: '!' requer booleano."); $$.type = DT_ERROR; }
        
        $$.addr = newTemp();
        emit("%s = !%s", $$.addr, $2.addr);
        add_reduce_trace("expr -> !");
    }
    ;
%%

/* ======================== Seção de Código C ======================== */

/* Função de Erro do Bison */
void yyerror(const char *s) {
    char temp_str[512];
    char error_detail[400];

    if (strncmp(s, "syntax error, ", 14) == 0) {
        snprintf(error_detail, sizeof(error_detail), "Sintatic Error: %s", s + 14);
    } else {
        snprintf(error_detail, sizeof(error_detail), "%s", s);
    }
    error_detail[sizeof(error_detail) - 1] = '\0';

    sprintf(temp_str, "[%03d:%03d]\tERRO\t%s\n", yylineno, column_num, error_detail);
    strcat(g_full_trace, temp_str);
    sintatic_error_count++;
}

/* Rastreamento de Reduções */
void add_reduce_trace(const char *rule) {
    char temp_str[256];
    sprintf(temp_str, "[%03d:%03d]\tREDUCE\t%s\n", yylineno, column_num, rule);
    strcat(g_full_trace, temp_str);
}

/* Impressão da Tabela de Trace */
void parsing_table(){
    printf("\n");
    printf("╔══════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                                       " BOLD MAGENTA "ANÁLISE SINTÁTICA E SEMÂNTICA" RESET "                                      ║\n");
    printf("╠═══════════╦═══════════╦══════════════════════════════════════════════════════════════════════════════════╣\n");
    printf("║ " BOLD YELLOW "%-9s" RESET " ║ " BOLD CYAN "  %-9s" RESET " ║ " BOLD GREEN "%-82s" RESET " ║\n", "[Lin:Col]", "AÇÃO", "DETALHE (Token ou Produção)");
    printf("╠═══════════╬═══════════╬══════════════════════════════════════════════════════════════════════════════════╣\n");

    char* saved_ptr;
    char* trace_copy = strdup(g_full_trace);
    if (!trace_copy) return;

    char* line = strtok_r(trace_copy, "\n", &saved_ptr);
    line = strtok_r(NULL, "\n", &saved_ptr); // Pula cabeçalho

    while (line != NULL) {
        char position[20], action[100], detail[200];
        if (sscanf(line, "%[^\t]\t%[^\t]\t%[^\n]", position, action, detail) == 3) {
             if (strcmp(action, "ERRO") == 0) {
                 printf("║ " BOLD YELLOW "%-9s" RESET " ║ " BOLD RED "%-9s" RESET " ║ " BOLD RED "%-80s" RESET " ║\n", position, action, detail);
             } 
             // Linhas SHIFT/REDUCE omitidas para limpeza, descomente se necessário
        }
        line = strtok_r(NULL, "\n", &saved_ptr);
    }
    free(trace_copy);

    printf("╠═══════════╩═══════════╩══════════════════════════════════════════════════════════════════════════════════╣\n");
    if (sintatic_error_count == 0) {
        printf("║ " BOLD GREEN "Análise concluída com sucesso!                                                                           "RESET"║\n");
    } else{
        printf("║ " BOLD RED "Análise concluída com %.3d erro(s).                                                                       "RESET"║\n", sintatic_error_count);
    }
    printf("╚══════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n");
}

/* ======================== TABELA DE SÍMBOLOS ======================== */

unsigned int hash_function(const char *lexeme) {
    unsigned int hash = 5381;
    int c;
    while ((c = *lexeme++)) hash = ((hash << 5) + hash) + c;
    return hash % 997;
}

void initialize_symbol_table() {
    global_scope = (ScopeTable *)malloc(sizeof(ScopeTable));
    memset(global_scope, 0, sizeof(ScopeTable));
    global_scope->id = global_scope_counter++;
    current_scope = global_scope;
}

void enter_scope() {
    ScopeTable *new_scope = (ScopeTable *)malloc(sizeof(ScopeTable));
    memset(new_scope, 0, sizeof(ScopeTable));
    new_scope->id = global_scope_counter++;
    new_scope->parent = current_scope;
    current_scope = new_scope;
    current_scope_depth++;
}

void exit_scope() {
    if (current_scope->parent != NULL) {
        current_scope = current_scope->parent;
        current_scope_depth--;
    }
}

void insert_symbol(char *lexeme, int token_type, int data_type) {
    /* Insere sempre no escopo atual. A verificação de redeclaração ilegal
       deve ser feita pelo parser antes de chamar esta função. */
    
    Symbol *new_symbol = (Symbol *)malloc(sizeof(Symbol));
    new_symbol->id = ++global_symbol_count;
    new_symbol->token_type = token_type;
    new_symbol->data_type = data_type;
    new_symbol->scope_depth = current_scope_depth;
    new_symbol->lexeme = strdup(lexeme);
    new_symbol->scope_id = current_scope->id;
    new_symbol->line = yylineno;
    new_symbol->column = column_num;

    unsigned int idx = hash_function(lexeme);
    HashNode *new_node = (HashNode *)malloc(sizeof(HashNode));
    new_node->symbol = new_symbol;
    new_node->next = current_scope->hash_table[idx];
    current_scope->hash_table[idx] = new_node;

    /* Controle para impressão sequencial */
    if (current_scope->symbol_count >= current_scope->capacity) {
        current_scope->capacity = (current_scope->capacity == 0) ? 10 : current_scope->capacity * 2;
        current_scope->symbol_order = (Symbol **)realloc(current_scope->symbol_order, current_scope->capacity * sizeof(Symbol *));
    }
    current_scope->symbol_order[current_scope->symbol_count++] = new_symbol;

    /* Lista Global */
    if (all_symbols_count >= all_symbols_capacity) {
        all_symbols_capacity = (all_symbols_capacity == 0) ? 20 : all_symbols_capacity * 2;
        all_symbols = (Symbol **)realloc(all_symbols, all_symbols_capacity * sizeof(Symbol *));
    }
    all_symbols[all_symbols_count++] = new_symbol;
}

Symbol* lookup_symbol(char *lexeme) {
    ScopeTable *scope = current_scope;
    while (scope != NULL) {
        unsigned int idx = hash_function(lexeme);
        HashNode *node = scope->hash_table[idx];
        while (node != NULL) {
            if (strcmp(node->symbol->lexeme, lexeme) == 0) return node->symbol;
            node = node->next;
        }
        scope = scope->parent;
    }
    return NULL;
}

const char* token_type_to_string(int type) {
    switch (type) {
        case DT_INTEGER: return "INTEGER";
        case DT_BOOL: return "BOOL";
        case DT_ERROR: return "ERROR";
        case TK_ID: return "ID";
        default: return "TOKEN";
    }
}

void print_symbol_table() {
    printf("╔══════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                                            " BOLD MAGENTA "TABELA DE SÍMBOLOS" RESET"                                            ║\n");
    printf("╠═══════╦═══════════╦══════════════════════════════╦═════════════════╦═════════════════╦═════════╦═════════╣\n");
    printf("║ " BOLD BLUE "%-5s" RESET " ║ " BOLD YELLOW "%-5s" RESET " ║ " BOLD CYAN "%-28s" RESET " ║ " BOLD GREEN "%-15s" RESET " ║ " BOLD GREEN "%-15s" RESET " ║ " BOLD MAGENTA "%-7s" RESET " ║ " BOLD BLUE "%-7s" RESET " ║\n", "[ID]", "[Lin:Col]", "LEXEMA", "TOKEN",  "TIPO", "DEPTH", "SCOPE");
    printf("╠═══════╬═══════════╬══════════════════════════════╬═════════════════╬═════════════════╬═════════╬═════════╣\n");

    for (int i = 0; i < all_symbols_count; i++) {
        printf("║ " BOLD BLUE "[%03d]" RESET " ║ " BOLD YELLOW "[%03d:%03d]" RESET " ║ " BOLD CYAN "%-28s" RESET " ║ " BOLD GREEN "%-15s" RESET " ║ " BOLD GREEN "%-15s" RESET " ║ " BOLD MAGENTA "%-7d" RESET " ║ " BOLD BLUE "%-7d" RESET " ║\n",
                all_symbols[i]->id, all_symbols[i]->line, all_symbols[i]->column, all_symbols[i]->lexeme,
                token_type_to_string(all_symbols[i]->token_type),
                token_type_to_string(all_symbols[i]->data_type),
                all_symbols[i]->scope_depth, all_symbols[i]->scope_id);
    }
    printf("╠═══════╩═══════════╩══════════════════════════════╩═════════════════╩═════════════════╩═════════╩═════════╣\n");
    printf("║ " BOLD "Total de símbolos:" RESET "%-56d                               ║\n", all_symbols_count);
    printf("╚══════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n");
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Uso: %s <arquivo>\n", argv[0]);
        return 1;
    }
    yyin = fopen(argv[1], "r");
    if (!yyin) {
        perror("Erro ao abrir arquivo");
        return 1;
    }

    initialize_symbol_table();
    
    printf("Iniciando análise...\n");
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

    
    parsing_table();
    print_symbol_table();
    emit_flush(); // Imprime o código intermediário gerado

    fclose(yyin);
    return (lexic_error_count == 0 && sintatic_error_count == 0) ? 0 : 1;
}