/* ======================== Seção de Definições (Bison) ======================== */
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tokens.h" // Seu header original, com o enum e a struct Symbol

/* ----- Protótipos e Globais do Lexer ----- */
/* Precisamos "enxergar" as funções e variáveis do scanner.l */
extern int yylex();
extern FILE *yyin;
extern int yylineno; // yylineno é fornecido pelo Flex
extern int error_count;
extern int column_num;

/* Funções auxiliares que ainda estão no scanner.l */
extern void print_symbol_table();

/* Definições de cores ANSI */
#define RESET   "\033[0m"
#define RED     "\033[31m"
#define GREEN   "\033[32m"
#define YELLOW  "\033[33m"
#define BLUE    "\033[34m"
#define MAGENTA "\033[35m"
#define CYAN    "\033[36m"
#define BOLD    "\033[1m"

/* A função de erro que o Bison vai chamar */
void yyerror(const char *s);
%}

/* ----- Definição de Tokens ----- */
%token TK_INT TK_BOOL TK_IF TK_ELSE TK_WHILE TK_PRINT
%token TK_READ TK_TRUE TK_FALSE TK_RELOP TK_LOP TK_ARITHOP
%token TK_SEMICOLON TK_COMMA TK_LPAREN TK_RPAREN TK_LBRACE TK_RBRACE
%token TK_INTEGER TK_ID

/* Ponto de partida da gramática */

/* ========================== Seção de Regras (Gramática) ========================== */
%%

program: program token_qualquer 
    |
    ;

token_qualquer: TK_INT | TK_BOOL | TK_IF | TK_ELSE | TK_WHILE | TK_PRINT
    | TK_READ | TK_TRUE | TK_FALSE | TK_RELOP | TK_LOP | TK_ARITHOP
    | TK_SEMICOLON | TK_COMMA | TK_LPAREN | TK_RPAREN | TK_LBRACE | TK_RBRACE
    | TK_INTEGER | TK_ID
    ;

%%
/* ========================= Seção de Código C ========================= */

/* 
    Por enquanto, vamos apenas imprimir uma mensagem simples.
*/
void yyerror(const char *s) {
    // Reutiliza o formato de tabela para erros sintáticos
    printf("║ " BOLD RED "[%03d:%03d]" RESET " ║ " BOLD RED "%-21s" RESET " ║ " BOLD RED "%-69s" RESET "  ║\n",
           yylineno, column_num, "ERRO SINTÁTICO", s);
    error_count++;
}


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
    
    /* Inicializar tabela de símbolos */
    /* symbol_count = 0; // Esta variável está no scanner.l */
    
    /* Imprime o cabeçalho da ANÁLISE LÉXICA */
    printf("╔══════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                                              " BOLD MAGENTA "ANÁLISE LÉXICA" RESET "                                              ║\n");
    printf("╠═══════════╦══════════════════════╦═══════════════════════════════════════════════════════════════════════╣\n");
    printf("║ " BOLD YELLOW "%-9s" RESET " ║ " BOLD CYAN "%-20s" RESET " ║ " BOLD GREEN "%-69s" RESET " ║\n", "[Lin:Col]", "TOKEN", "LEXEMA");
    printf("╠═══════════╬══════════════════════╬═══════════════════════════════════════════════════════════════════════╣\n");

    /* MUDANÇA CRÍTICA:
        Em vez de chamar yylex() em um loop, nós chamamos yyparse() UMA VEZ.
        O yyparse() é quem vai chamar o yylex() internamente para pedir tokens.
    */
    yyparse(); // Dispara o analisador sintático

    printf("╚═══════════╩══════════════════════╩═══════════════════════════════════════════════════════════════════════╝\n");
    
    /* Imprimir tabela de símbolos */
    print_symbol_table();
    
    fclose(yyin);
    
    if (error_count == 0) {
        printf(BOLD GREEN "\nAnálise concluída com sucesso!\n" RESET);
        return 0;
    }
    
    printf(BOLD RED "\nAnálise concluída com %d erro(s).\n" RESET, error_count);
    return 1;
}