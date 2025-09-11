%{
#include <stdio.h>
%}

%%

{line}\n {printf("%5d %s\n", yylineno-1, yytext);}
{line} {printf("%5d %s\n", yylineno, yytext);}

%%

int main(void) {
    yylex();
    return 0;
}
