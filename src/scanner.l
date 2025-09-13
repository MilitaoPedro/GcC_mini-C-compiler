/* ======================== Seção de definições ======================== */
%option noyywrap yylineno
%{
#include <stdio.h>
#include <stdlib.h>

/* Definições de cores ANSI */
#define RESET   "\033[0m"
#define RED     "\033[31m"
#define GREEN   "\033[32m"
#define YELLOW  "\033[33m"
#define BLUE    "\033[34m"
#define MAGENTA "\033[35m"
#define CYAN    "\033[36m"
#define BOLD    "\033[1m"

/* Declações de variáveis para contagem de linha e coluna */
int line_index = 1;
int column_index = 0;
%}

comment "//".*
space   [ \t]+

%x      IN_COMMENT

/* ========================== Seção de regras ========================== */
%%

\n               { column_index = 0; line_index++; }
{comment}        { column_index += yyleng; }
"/*"             { BEGIN(IN_COMMENT); column_index += yyleng;}
<IN_COMMENT>.    { column_index += yyleng;}
<IN_COMMENT>\n   { column_index = 0; line_index++; }
<IN_COMMENT>"*/" { BEGIN(INITIAL); column_index += yyleng;}
{space}          { column_index += yyleng; }
.                { column_index += yyleng; }

%%
/* ========================= Seção de código C ========================= */

int main(int argc, char *argv[]){
    if(argc < 2){
        fprintf(stderr, "Uso: %s <arquivo>\n", argv[0]);
        return 1;
    }
    yyin = fopen(argv[1], "r");
    if(!yyin){
        perror(BOLD RED "Erro ao abrir o arquivo" RESET);
        return 1;
    }
    yyout = stdout;
    printf(BOLD BLUE "Iniciando análise...\n" RESET);
    yylex();
    printf("Número de linhas: %d\n", line_index);
    printf(BOLD GREEN "Análise finalizada!\n" RESET);
    fclose(yyin);
    return 0;
}