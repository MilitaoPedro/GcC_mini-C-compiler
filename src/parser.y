/* ======================== Seção de Definições (Bison) ======================== */
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tokens.h" // Seu header original

#include <unistd.h> // Para dup, dup2, close, STDERR_FILENO
#include <fcntl.h>  // Para open

/* Inclui o protótipo da nossa nova função de impressão */
#include "trace_printer.h"

/* ----- Protótipos e Globais do Lexer ----- */
extern int yylex();
extern FILE *yyin;
extern int yylineno;
extern int lexic_error_count; // Renomeei para evitar conflito
extern int column_num;

/* Contador de erros sintáticos */
int sintatic_error_count = 0;

/* Funções auxiliares que ainda estão no scanner.l */
extern void print_symbol_table();

/* Definições de cores ANSI (Apenas as usadas aqui no main/yyerror) */
#define RESET   "\033[0m"
#define RED     "\033[31m"
#define GREEN   "\033[32m"
#define BLUE    "\033[34m"
#define MAGENTA "\033[35m"
#define CYAN    "\033[36m"
#define YELLOW  "\033[33m"
#define BOLD    "\033[1m"

/* A função de erro que o Bison vai chamar (simplificada) */
void yyerror(const char *s);

%}

/* ----- Definição de Tokens ----- */
%token TK_INT TK_BOOL TK_IF TK_ELSE TK_WHILE TK_PRINT
%token TK_READ TK_TRUE TK_FALSE
%token TK_SEMICOLON TK_COMMA TK_LPAREN TK_RPAREN TK_LBRACE TK_RBRACE
%token TK_INTEGER TK_ID
%token TK_EQ TK_NE TK_LE TK_GE TK_LT TK_GT
%token TK_LOGICAL_AND TK_LOGICAL_OR TK_LOGICAL_NOT
%token TK_PLUS TK_MINUS TK_MULT TK_DIV TK_MOD
%token TK_ASSIGN

%debug // Mantém a geração do código de debug

/* ----- PRECEDÊNCIA E ASSOCIATIVIDADE DOS OPERADORES ----- */
%left TK_LOGICAL_OR
%left TK_LOGICAL_AND
%left TK_EQ TK_NE
%left TK_LT TK_LE TK_GT TK_GE
%left TK_PLUS TK_MINUS
%left TK_MULT TK_DIV TK_MOD
%right TK_LOGICAL_NOT
%right UMINUS
%start program

%%
/* ========================== Seção de Regras (Gramática) ========================== */
/* AS REGRAS AGORA NÃO TÊM MAIS AÇÕES DE TRACE */

program:
                        statements
                        ;

block:                  TK_LBRACE statements TK_RBRACE
                        ;

statements:
                        | statement statements
                        ;

statement:              declaration
                        | assignment
                        | read
                        | print
                        | while
                        | if
                        ;

declaration:            type id_list TK_SEMICOLON
                        ;

type:                   TK_INT
                        | TK_BOOL
                        ;

id_list:                TK_ID
                        | id_list TK_COMMA TK_ID
                        ;

assignment:             TK_ID TK_ASSIGN expression TK_SEMICOLON
                        ;

read:                   TK_READ TK_LPAREN TK_ID TK_RPAREN TK_SEMICOLON
                        ;

print:                  TK_PRINT TK_LPAREN expression TK_RPAREN TK_SEMICOLON
                        ;

while:                  TK_WHILE TK_LPAREN expression TK_RPAREN then
                        ;

if:                     TK_IF TK_LPAREN expression TK_RPAREN then else
                        ;

else:                   TK_ELSE then
                        | /* epsilon */
                        ;

then:                   statement
                        | block
                        ;

expression:             TK_INTEGER
                        | TK_TRUE
                        | TK_FALSE
                        | TK_ID
                        | TK_LPAREN expression TK_RPAREN
                        | expression TK_PLUS expression
                        | expression TK_MINUS expression
                        | expression TK_MULT expression
                        | expression TK_DIV expression
                        | expression TK_MOD expression
                        | TK_MINUS expression %prec UMINUS
                        | expression TK_EQ expression
                        | expression TK_NE expression
                        | expression TK_LT expression
                        | expression TK_LE expression
                        | expression TK_GT expression
                        | expression TK_GE expression
                        | expression TK_LOGICAL_AND expression
                        | expression TK_LOGICAL_OR expression
                        | TK_LOGICAL_NOT expression
                        ;
%%
/* ========================= Seção de Código C ========================= */

/* Função de erro simplificada: apenas conta */
void yyerror(const char *s) {
    // Poderia imprimir um erro básico no stderr real, caso o log falhe
    // fprintf(stderr, "Erro Sintatico: Linha %d, Coluna %d: %s\n", yylineno, column_num, s);
    sintatic_error_count++;
}


/* Função Main: Controla o fluxo, redireciona stderr, chama parse e imprime tabelas */
int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Uso: %s <arquivo>\n", argv[0]);
        return 1;
    }

    yyin = fopen(argv[1], "r");
    if (!yyin) {
        perror("Erro ao abrir o arquivo");
        return 1;
    }

    /* ----- REDIRECIONAMENTO DE STDERR ----- */
    int original_stderr_fd = -1;
    int log_fd = -1;
    const char* log_filename = "src/debug_trace.log"; // Nome do arquivo de log

    original_stderr_fd = dup(STDERR_FILENO);
    if (original_stderr_fd != -1) {
        log_fd = open(log_filename, O_WRONLY | O_CREAT | O_TRUNC, 0666);
        if (log_fd != -1) {
            if (dup2(log_fd, STDERR_FILENO) != -1) {
                close(log_fd); // stderr agora aponta para o arquivo
                printf(BOLD BLUE "[INFO] Trace de debug do Bison será salvo em %s\n" RESET, log_filename);
            } else {
                perror("Erro ao redirecionar stderr para o arquivo");
                close(log_fd);
                close(original_stderr_fd);
                original_stderr_fd = -1; // Falha no redirecionamento
            }
        } else {
            perror("Erro ao abrir arquivo de log");
            close(original_stderr_fd);
            original_stderr_fd = -1; // Falha no redirecionamento
        }
    } else {
        perror("Erro ao duplicar stderr");
        // Continua sem redirecionamento
    }
    /* ----- FIM DO REDIRECIONAMENTO ----- */


    /* Habilita o debug do Bison ANTES de yyparse */
    yydebug = 1;

    /* Imprime o cabeçalho da ANÁLISE LÉXICA */
    printf("╔══════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                                              " BOLD MAGENTA "ANÁLISE LÉXICA" RESET "                                              ║\n");
    printf("╠═══════════╦══════════════════════╦═══════════════════════════════════════════════════════════════════════╣\n");
    printf("║ " BOLD YELLOW "%-9s" RESET " ║ " BOLD CYAN "%-20s" RESET " ║ " BOLD GREEN "%-69s" RESET " ║\n", "[Lin:Col]", "TOKEN", "LEXEMA");
    printf("╠═══════════╬══════════════════════╬═══════════════════════════════════════════════════════════════════════╣\n");

    /* Executa a análise (o trace vai para o arquivo de log) */
    yyparse();

    /* ----- RESTAURAÇÃO DE STDERR ----- */
    if (original_stderr_fd != -1) {
        fflush(stderr); // Garante escrita no arquivo
        if (dup2(original_stderr_fd, STDERR_FILENO) == -1) {
             perror("Erro ao restaurar stderr");
        }
        close(original_stderr_fd);
    }
    /* ----- FIM DA RESTAURAÇÃO ----- */

    /* Imprime o rodapé da ANÁLISE LÉXICA */
    printf("╚═══════════╩══════════════════════╩═══════════════════════════════════════════════════════════════════════╝\n");

    // Imprime status da análise léxica
    if (lexic_error_count == 0) {
        printf(BOLD GREEN "\nAnálise Léxica concluída com sucesso!\n" RESET);
    } else {
        printf(BOLD RED "\nAnálise Léxica concluída com %d erro(s).\n" RESET, lexic_error_count);
    }

    /* CHAMA A FUNÇÃO EXTERNA para imprimir a tabela sintática */
    print_syntactic_table_from_log(log_filename);

    // Imprime status da análise sintática
    if (sintatic_error_count == 0) {
        printf(BOLD GREEN "\nAnálise Sintática concluída com sucesso!\n" RESET);
    } else {
        printf(BOLD RED "\nAnálise Sintática concluída com %d erro(s).\n" RESET, sintatic_error_count);
    }


    /* Imprimir tabela de símbolos */
    print_symbol_table();

    fclose(yyin);

    // Retorna 0 se SÓ HOUVE SUCESSO, 1 caso contrário
    return (lexic_error_count == 0 && sintatic_error_count == 0) ? 0 : 1;
}