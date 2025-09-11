%option noyywrap yylineno
%{
#include <stdio.h>
#include <stdlib.h>

FILE *yyin;
FILE *yyout;
%}

line .*

%%

{line}\n        { printf("%5d %s", yylineno-1, yytext); }
{line}          { printf("%5d %s", yylineno, yytext); }

%%

int main(int argc, char *argv[]){
    if(argc < 2){
        fprintf(stderr, "Uso: %s <arquivo>\n", argv[0]);
        return 1;
    }
    yyin = fopen(argv[1], "r");
    if(!yyin){
        perror("Erro ao abrir o arquivo");
        return 1;
    }
    yyout = stdout;
    yylex();
    fclose(yyin);
    return 0;
}
