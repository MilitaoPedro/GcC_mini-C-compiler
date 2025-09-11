%option noyywrap yylineno
%{
/* −−−−−−−−−−−−−−−−−−−−−−−−−− D e f i n i t i o n s −−−−−−−−−−−−−−−−−−−−−−−−−− */
#include %}

line .*

%%
{line}\n {printf("%5d %s\n", yylineno-1, yytext);}
{line} {printf("%5d %s\n", yylineno, yytext);}
%%
/* −−−−−−−−−−−−−−−−−−−−−−−− User s u b r o t i n e s −−−−−−−−−−−−−−−−−−−−−−−− */
int main(int argc, char *argv[]){
yyin = fopen(argv[1], "r");
yyout = stdout;
yylex();
fclose(yyin);
return 0;
}

