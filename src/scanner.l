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
int column_index = 1;

int add_symbol(char* lexeme) {
    // LÓGICA FUTURA A SER IMPLEMENTADA 
    return 1; // Retorna a posição na tabela de simbolos
}

void process_token(const char* token_name, int is_symbol) {
    char formatted_lexeme[256];
    // Se o token for um símbolo (identificador, número, etc.)
    if (is_symbol) {
        int table_pos = add_symbol(yytext);
        // Formata o lexema para o estilo '<'lexema', pos>'
        sprintf(formatted_lexeme, "<'%s', %d>", yytext, table_pos);
    } else {
        // Para tokens simples (palavras-chave), apenas usa o lexema
        sprintf(formatted_lexeme, "'%s'", yytext);
    }

    // Dentro da função process_token
    printf("║ " YELLOW "[%03d:%03d]" RESET " ║ " CYAN "%-20s" RESET " ║ " GREEN "%-40s" RESET " ║\n",
        line_index,
        column_index,
        token_name,
        formatted_lexeme
        );

    // Atualiza a coluna para a posição logo após o token atual
    column_index += yyleng; // yyleng contém o tamanho do lexema
}

void process_error(){
    // Cria uma string descritiva para o "lexema" do erro
    char error_lexeme[64];
    sprintf(error_lexeme, "'%s' <- Inválido", yytext);

    // Imprime a linha de erro usando o mesmo formato de tabela
    printf("║ " BOLD RED "[%03d:%03d]" RESET " ║ " BOLD RED "%-21s" RESET " ║ " BOLD RED "%-40s" RESET "  ║\n",
            line_index,
            column_index,
            "ERRO LÉXICO",  // O "tipo de token" do erro
            error_lexeme);  // A descrição do erro

    column_index += yyleng;
}

%}

/* ==== DEFINIÇÕES CORRIGIDAS ==== */
comment             "//".*
space               [ \t]+
letter              [a-zA-Z_]
digit               [0-9]
identifier          {letter}({letter}|{digit})*
no_identifier       {digit}({letter}|{digit})*
exponent            [eE][+-]?{digit}+
number              [+-]?((({digit}+\.{digit}*|\.{digit}+)({exponent})?)|{digit}+{exponent}|{digit}+)

%x           IN_COMMENT

/* ========================== Seção de regras ========================== */
%%

\n                  { column_index = 1; line_index++; }
{comment}           ;
"/*"                { BEGIN(IN_COMMENT); column_index += yyleng;}
<IN_COMMENT>.       { column_index += yyleng;}
<IN_COMMENT>\n      { column_index = 1; line_index++; }
<IN_COMMENT>"*/"    { BEGIN(INITIAL); column_index += yyleng;}
{space}             { column_index += yyleng; }

"if"                { process_token("TK_IF", 0); }
"else"              { process_token("TK_ELSE", 0); }
"while"             { process_token("TK_WHILE", 0); }
"print"             { process_token("TK_PRINT", 0); }
"read"              { process_token("TK_READ", 0); }
"true"              { process_token("TK_TRUE", 0); }
"false"             { process_token("TK_FALSE", 0); }
"int"               { process_token("TK_INT_TYPE", 0); }
"bool"              { process_token("TK_BOOL_TYPE", 0); }

{number}            { process_token("TK_NUMBER", 1); }
{identifier}        { process_token("TK_IDENTIFIER", 1); }

"=="                { process_token("TK_OP_EQ", 0); }
"!="                { process_token("TK_OP_NE", 0); }
"<="                { process_token("TK_OP_LE", 0); }
">="                { process_token("TK_OP_GE", 0); }
"&&"                { process_token("TK_LOGICAL_AND", 0); }
"||"                { process_token("TK_LOGICAL_OR", 0); }
"+"                 { process_token("TK_PLUS", 0); }
"-"                 { process_token("TK_MINUS", 0); }
"*"                 { process_token("TK_MULT", 0); }
"/"                 { process_token("TK_DIV", 0); }
"<"                 { process_token("TK_OP_LT", 0); }
">"                 { process_token("TK_OP_GT", 0); }
"!"                 { process_token("TK_LOGICAL_NOT", 0); }
"="                 { process_token("TK_ASSIGN", 0); }

";"                 { process_token("TK_SEMICOLON", 0); }
","                 { process_token("TK_COMMA", 0); }
"("                 { process_token("TK_OPEN_PAREN", 0); }
")"                 { process_token("TK_CLOSE_PAREN", 0); }
"{"                 { process_token("TK_OPEN_BRACE", 0); }
"}"                 { process_token("TK_CLOSE_BRACE", 0); }

{no_identifier}     { process_error(); }
.                   { process_error(); }

%%
/* ========================= Seção de código C ========================= */

int main(int argc, char *argv[]){
    if (argc < 2){
        fprintf(stderr, "Uso: %s <arquivo>\n", argv[0]);
        return 1;
    }
    
    yyin = fopen(argv[1], "r");
    if (!yyin){
        perror(BOLD RED "Erro ao abrir o arquivo" RESET);
        return 1;
    }
    
    yyout = stdout;
    printf(BOLD BLUE "Iniciando análise...\n" RESET);
    printf("╔═══════════╦══════════════════════╦══════════════════════════════════════════╗\n");
    printf("║ " BOLD YELLOW "%-9s" RESET " ║ " BOLD CYAN "%-20s" RESET " ║ " BOLD GREEN "%-40s" RESET " ║\n", "[Lin:Col]", "Token", "Lexema");
    printf("╠═══════════╬══════════════════════╬══════════════════════════════════════════╣\n");
    yylex();   
    
    printf("╚═══════════╩══════════════════════╩══════════════════════════════════════════╝\n");
    printf(BOLD GREEN "Análise finalizada!\n" RESET);
    
    fclose(yyin);
    return 0;
}