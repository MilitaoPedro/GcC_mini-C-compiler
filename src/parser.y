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
extern int lexic_error_count;
extern int column_num;

int sintatic_error_count = 0;

/* Funções auxiliares que ainda estão no scanner.l */
extern void print_symbol_table();

void add_reduce_trace(const char *rule);

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

/* Variavel para impressão da análise sintática*/
char g_full_trace[65536] = "AÇÃO\tDETALHE\n";
%}

/* ----- Definição de Tokens ----- */
%token TK_INT TK_BOOL TK_IF TK_ELSE TK_WHILE TK_PRINT
%token TK_READ TK_TRUE TK_FALSE TK_RELOP TK_LOP TK_ARITHOP
%token TK_SEMICOLON TK_COMMA TK_LPAREN TK_RPAREN TK_LBRACE TK_RBRACE
%token TK_INTEGER TK_ID
%token TK_EQ TK_NE TK_LE TK_GE TK_LT TK_GT
%token TK_LOGICAL_AND TK_LOGICAL_OR TK_LOGICAL_NOT
%token TK_PLUS TK_MINUS TK_MULT TK_DIV TK_MOD
%token TK_ASSIGN

%debug

/* ----- PRECEDÊNCIA E ASSOCIATIVIDADE DOS OPERADORES ----- */
/* Menor precedência */
%left TK_LOGICAL_OR             /* || */
%left TK_LOGICAL_AND            /* && */
%left TK_EQ TK_NE               /* == != */
%left TK_LT TK_LE TK_GT TK_GE   /* < <= > >= */
%left TK_PLUS TK_MINUS          /* + - (binário) */
%left TK_MULT TK_DIV TK_MOD     /* * / % */
%right TK_LOGICAL_NOT           /* ! (unário) */
%right UMINUS                   /* Pseudo-token para Menos Unário */
/* Maior precedência */


/* ========================== Seção de Regras (Gramática) ========================== */
%%

program:
                        statements                                                              {add_reduce_trace("program -> statements: ACEITO!");}
                        ;

block:                  TK_LBRACE statements TK_RBRACE                                          {add_reduce_trace("block -> TK_LBRACE statements TK_RBRACE");}
                        ;

statements:                                                                                     {add_reduce_trace("statements ->");}
                        | statement statements                                                  {add_reduce_trace("statements -> statement statements");}
                        ;

statement:              declaration                                                             {add_reduce_trace("statement -> declaration");}
                        | assignment                                                            {add_reduce_trace("statement -> assignment");}
                        | read                                                                  {add_reduce_trace("statement -> read");}
                        | print                                                                 {add_reduce_trace("statement -> print");}
                        | while                                                                 {add_reduce_trace("statement -> while");}
                        | if                                                                    {add_reduce_trace("statement -> if");}
                        ;

declaration:            type id_list TK_SEMICOLON                                               {add_reduce_trace("declaration -> type id_list TK_SEMICOLON");}
                        ;

type:                   TK_INT                                                                  {add_reduce_trace("type -> TK_INT");}
                        | TK_BOOL                                                               {add_reduce_trace("type -> TK_BOOL");}
                        ;

id_list:                TK_ID                                                                   {add_reduce_trace("id_list -> TK_ID");}
                        | id_list TK_COMMA TK_ID                                                {add_reduce_trace("id_list -> id_list TK_COMMA TK_ID");}
                        ;

assignment:             TK_ID TK_ASSIGN expression TK_SEMICOLON                                 {add_reduce_trace("assignment -> TK_ID TK_ASSIGN expression TK_SEMICOLON");}
                        ;

read:                   TK_READ TK_LPAREN TK_ID TK_RPAREN TK_SEMICOLON                          {add_reduce_trace("read -> TK_READ TK_LPAREN TK_ID TK_RPAREN TK_SEMICOLON");}
                        ;

print:                  TK_PRINT TK_LPAREN expression TK_RPAREN TK_SEMICOLON                    {add_reduce_trace("print -> TK_PRINT TK_LPAREN expression TK_RPAREN TK_SEMICOLON");}
                        ;

while:                  TK_WHILE TK_LPAREN expression TK_RPAREN then                            {add_reduce_trace("while -> TK_WHILE TK_LPAREN expression TK_RPAREN then");}
                        ;

if:                     TK_IF TK_LPAREN expression TK_RPAREN then else                          {add_reduce_trace("if -> TK_IF TK_LPAREN expression TK_RPAREN then else");}
                        ;

else:                   TK_ELSE then                                                            {add_reduce_trace("else -> TK_ELSE then");}
                        |                                                                       {add_reduce_trace("else ->");}
                        ;

then:                   statement                                                               {add_reduce_trace("then -> statement");}
                        |block                                                                  {add_reduce_trace("then -> block");}
                        ;

expression:             TK_INTEGER {add_reduce_trace("expression -> TK_INTEGER");}
                        | TK_TRUE                                                               {add_reduce_trace("expression -> TK_TRUE");}
                        | TK_FALSE                                                              {add_reduce_trace("expression -> TK_FALSE");}
                        | TK_ID                                                                 {add_reduce_trace("expression -> TK_ID");}
                        | TK_LPAREN expression TK_RPAREN                                        {add_reduce_trace("expression -> TK_LPAREN expression TK_RPAREN");}

                        /* Expressões Aritméticas */
                        | expression TK_PLUS expression                                         {add_reduce_trace("expression -> expression TK_PLUS expression");}
                        | expression TK_MINUS expression                                        {add_reduce_trace("expression -> expression TK_MINUS expression");}
                        | expression TK_MULT expression                                         {add_reduce_trace("expression -> expression TK_MULT expression");}
                        | expression TK_DIV expression                                          {add_reduce_trace("expression -> expression TK_DIV expression");}
                        | expression TK_MOD expression                                          {add_reduce_trace("expression -> expression TK_MOD expression");}

                        /* Menos Unário (usando %prec) */
                        | TK_MINUS expression %prec UMINUS                                      {add_reduce_trace("expression -> TK_MINUS expression (Unary)");}

                        /* Expressões Relacionais */
                        | expression TK_EQ expression                                           {add_reduce_trace("expression -> expression TK_EQ expression");}
                        | expression TK_NE expression                                           {add_reduce_trace("expression -> expression TK_NE expression");}
                        | expression TK_LT expression                                           {add_reduce_trace("expression -> expression TK_LT expression");}
                        | expression TK_LE expression                                           {add_reduce_trace("expression -> expression TK_LE expression");}
                        | expression TK_GT expression                                           {add_reduce_trace("expression -> expression TK_GT expression");}
                        | expression TK_GE expression                                           {add_reduce_trace("expression -> expression TK_GE expression");}

                        /* Expressões Lógicas */
                        | expression TK_LOGICAL_AND expression                                  {add_reduce_trace("expression -> expression TK_LOGICAL_AND expression");}
                        | expression TK_LOGICAL_OR expression                                   {add_reduce_trace("expression -> expression TK_LOGICAL_OR expression");}
                        | TK_LOGICAL_NOT expression                                             {add_reduce_trace("expression -> TK_LOGICAL_NOT expression");}
                        ;                        

%%
/* ========================= Seção de Código C ========================= */

/* 
    Por enquanto, vamos apenas imprimir uma mensagem simples.
*/
void yyerror(const char *s) {
    char temp_str[256];
    
    // Formata a string de erro no formato do trace: "[LIN:COL]\tAÇÃO\tDETALHE\n"
    sprintf(temp_str, "[%03d:%03d]\tERRO\t%s\n", 
            yylineno, 
            column_num, 
            s); // 's' é a mensagem, ex: "syntax error"
    
    // Adiciona o erro ao trace global
    strcat(g_full_trace, temp_str);
    sintatic_error_count++;
}

void add_reduce_trace(const char *rule) {
    char temp_str[100];
    sprintf(temp_str, "[%03d:%03d]\tREDUCE\t%s\n", yylineno, column_num, rule);
    strcat(g_full_trace, temp_str);
}

void parsing_table(){
    printf("\n"); // Adiciona um espaço
    printf("╔══════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                                      " BOLD MAGENTA "ANÁLISE SINTÁTICA (Shift-Reduce)" RESET "                                    ║\n");
    printf("╠═══════════╦═══════════╦══════════════════════════════════════════════════════════════════════════════════╣\n");
    printf("║ " BOLD YELLOW "%-9s" RESET " ║ " BOLD CYAN "  %-9s" RESET " ║ " BOLD GREEN "%-82s" RESET " ║\n", "[Lin:Col]", "AÇÃO", "DETALHE (Token ou Produção)");
    printf("╠═══════════╬═══════════╬══════════════════════════════════════════════════════════════════════════════════╣\n");
    
    // Pula o cabeçalho que colocamos na string
    char* line = strtok(g_full_trace, "\n");
    line = strtok(NULL, "\n"); // Pega a primeira linha real
    
    while (line != NULL) {
        char position[20], action[100], detail[200];
        // Lê a string "POSICAO \t ACAO \t DETALHE"
        if (sscanf(line, "%[^\t]\t%[^\t]\t%[^\n]", position, action, detail) == 3) {
             
             if (strcmp(action, "ERRO") == 0) {
                 // Imprime a linha de erro em VERMELHO
                 printf("║ " BOLD YELLOW "%-9s" RESET " ║ " BOLD RED "%-9s" RESET " ║ " BOLD RED "%-80s" RESET " ║\n", 
                        position, action, detail);
             } else {
                
                    printf("║ " BOLD YELLOW "%-9s" RESET " ║ " CYAN "%-9s" RESET " ║ " GREEN "%-80s" RESET " ║\n", 
                        position, action, detail);
                
             }
        }
        line = strtok(NULL, "\n");
    }

    printf("╚═══════════╩═══════════╩══════════════════════════════════════════════════════════════════════════════════╝\n");

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
    
    if (lexic_error_count == 0) {
        printf(BOLD GREEN "\nAnálise Léxica concluída com sucesso!\n" RESET);
    } else{
        printf(BOLD RED "\nAnálise Léxica concluída com %d erro(s).\n" RESET, lexic_error_count);
    }

    /* Imprimir tabela da Análise Sintática */
    parsing_table();

    /* Imprimir tabela de símbolos */
    print_symbol_table();
    
    fclose(yyin);
    
    return 1;
}