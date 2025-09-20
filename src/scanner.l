/* ======================== Seção de definições ======================== */
%option noyywrap yylineno
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tokens.h"

/* Definições de cores ANSI */
#define RESET   "\033[0m"
#define RED     "\033[31m"
#define GREEN   "\033[32m"
#define YELLOW  "\033[33m"
#define BLUE    "\033[34m"
#define MAGENTA "\033[35m"
#define CYAN    "\033[36m"
#define BOLD    "\033[1m"

/* Tabela de símbolos (declaração e estado) */
#define SYMBOL_TABLE_SIZE 999
Symbol symbol_table[SYMBOL_TABLE_SIZE];
int symbol_count = 0;

/* Variáveis para controle de posição */
int column_num = 1;
int error_count = 0;

/* Protótipos das funções */
void insert_symbol(char *lexeme, TokenType token_type);
Symbol* lookup_symbol(char *lexeme);
void print_symbol_table();
void print_token(TokenType token_type, char *lexeme);
void report_error(char *message);
const char* token_type_to_string(TokenType type);

FILE *yyin;
FILE *yyout;
%}

/* Definições de padrões */
DIGIT       [0-9]
LETTER      [a-zA-Z]
IDENTIFIER  {LETTER}({LETTER}|{DIGIT}|_)*
INTEGER     ((-[1-9])|{DIGIT}){DIGIT}*([+-]?e{DIGIT}+)?
WHITESPACE  [ \t]+
NEWLINE     \n

%%

"//".*                  { column_num += yyleng; }
"/*"([^*]|\*+[^*/])*\*+"/"  { 
    for(int i = 0; yytext[i]; i++) {
        if(yytext[i] == '\n') {
            column_num = 1;
        } else {
            column_num++;
        }
    }
}
"int"           { print_token(TK_INT, yytext); column_num += yyleng; }
"bool"          { print_token(TK_BOOL, yytext); column_num += yyleng; }
"if"            { print_token(TK_IF, yytext); column_num += yyleng; }
"else"          { print_token(TK_ELSE, yytext); column_num += yyleng; }
"while"         { print_token(TK_WHILE, yytext); column_num += yyleng; }
"print"         { print_token(TK_PRINT, yytext); column_num += yyleng; }
"read"          { print_token(TK_READ, yytext); column_num += yyleng; }
"true"          { print_token(TK_TRUE, yytext); column_num += yyleng; }
"false"         { print_token(TK_FALSE, yytext); column_num += yyleng; }

"=="            { print_token(TK_RELOP, yytext); column_num += yyleng; }
"!="            { print_token(TK_RELOP, yytext); column_num += yyleng; }
"<="            { print_token(TK_RELOP, yytext); column_num += yyleng; }
">="            { print_token(TK_RELOP, yytext); column_num += yyleng; }
"<"             { print_token(TK_RELOP, yytext); column_num += yyleng; }
">"             { print_token(TK_RELOP, yytext); column_num += yyleng; }

"&&"            { print_token(TK_LOP, yytext); column_num += yyleng; }
"||"            { print_token(TK_LOP, yytext); column_num += yyleng; }
"!"             { print_token(TK_LOP, yytext); column_num += yyleng; }

"+"             { print_token(TK_ARITHOP, yytext); column_num += yyleng; }
"-"             { print_token(TK_ARITHOP, yytext); column_num += yyleng; }
"*"             { print_token(TK_ARITHOP, yytext); column_num += yyleng; }
"/"             { print_token(TK_ARITHOP, yytext); column_num += yyleng; }
"%"             { print_token(TK_ARITHOP, yytext); column_num += yyleng; }
"="             { print_token(TK_ARITHOP, yytext); column_num += yyleng; }

";"             { print_token(TK_SEMICOLON, yytext); column_num += yyleng; }
","             { print_token(TK_COMMA, yytext); column_num += yyleng; }
"("             { print_token(TK_LPAREN, yytext); column_num += yyleng; }
")"             { print_token(TK_RPAREN, yytext); column_num += yyleng; }
"{"             { print_token(TK_LBRACE, yytext); column_num += yyleng; }
"}"             { print_token(TK_RBRACE, yytext); column_num += yyleng; }

{INTEGER}       { print_token(TK_INTEGER, yytext); column_num += yyleng; }

-?{DIGIT}+({LETTER}|_)+({LETTER}|{DIGIT}|_)* {
    char error_msg[140];
    sprintf(error_msg, "Número inválido: sufixo inválido em literal inteiro '%s'", yytext);
    report_error(error_msg);
    column_num += yyleng;
}

{IDENTIFIER}    { print_token(TK_ID, yytext); insert_symbol(yytext, TK_ID); column_num += yyleng; }

{WHITESPACE}    { column_num += yyleng; }

{NEWLINE}       { column_num = 1; }

.               { 
    char error_msg[100];
    sprintf(error_msg, "Caractere não reconhecido: '%s'", yytext);
    report_error(error_msg);
    column_num += yyleng;
}

%%


/* Inserir símbolo na tabela (array) */
void insert_symbol(char *lexeme, TokenType token_type) {
    if (lookup_symbol(lexeme) != NULL)
        return; /* Já existe, não insere duplicata */
    if (symbol_count >= SYMBOL_TABLE_SIZE) {
        fprintf(stderr, "Symbol table overflow!\n");
        exit(1);
    }
    symbol_table[symbol_count].id = symbol_count + 1;
    symbol_table[symbol_count].lexeme = strdup(lexeme);
    symbol_table[symbol_count].token_type = token_type;
    symbol_table[symbol_count].line = yylineno;
    symbol_table[symbol_count].column = column_num;
    symbol_count++;
}

/* Buscar símbolo na tabela (array) */
Symbol* lookup_symbol(char *lexeme) {
    for (int i = 0; i < symbol_count; i++) {
        if (strcmp(symbol_table[i].lexeme, lexeme) == 0) {
            return &symbol_table[i];
        }
    }
    return NULL;
}

/* Converter enum em string para impressão */
const char* token_type_to_string(TokenType type) {
    switch (type) {
        case TK_INT: return "TK_INT";
        case TK_BOOL: return "TK_BOOL";
        case TK_IF: return "TK_IF";
        case TK_ELSE: return "TK_ELSE";
        case TK_WHILE: return "TK_WHILE";
        case TK_PRINT: return "TK_PRINT";
        case TK_READ: return "TK_READ";
        case TK_TRUE: return "TK_TRUE";
        case TK_FALSE: return "TK_FALSE";
        case TK_RELOP: return "TK_RELOP";
        case TK_LOP: return "TK_LOP";
        case TK_ARITHOP: return "TK_ARITHOP";
        case TK_SEMICOLON: return "TK_SEMICOLON";
        case TK_COMMA: return "TK_COMMA";
        case TK_LPAREN: return "TK_LPAREN";
        case TK_RPAREN: return "TK_RPAREN";
        case TK_LBRACE: return "TK_LBRACE";
        case TK_RBRACE: return "TK_RBRACE";
        case TK_INTEGER: return "TK_INTEGER";
        case TK_ID: return "TK_ID";
        default: return "UNKNOWN";
    }
}

/* Imprimir token com posição */
void print_token(TokenType token_type, char *lexeme) {
    printf("║ " YELLOW "[%03d:%03d]" RESET " ║ " CYAN "%-20s" RESET " ║ " GREEN "%-69s" RESET " ║\n",
        yylineno,
        column_num,
        token_type_to_string(token_type),
        lexeme
        );
}

/* Reportar erro */
void report_error(char *message) {
    // Imprime a linha de erro usando o mesmo formato de tabela
    printf("║ " BOLD RED "[%03d:%03d]" RESET " ║ " BOLD RED "%-21s" RESET " ║ " BOLD RED "%-69s" RESET "  ║\n",
            yylineno,
            column_num,
            "ERRO LÉXICO",  // O "tipo de token" do erro
            message);  // A descrição do erro
    error_count++;
}

int compare_symbols(const void *a, const void *b) {
    const Symbol *sa = *(const Symbol **)a;
    const Symbol *sb = *(const Symbol **)b;
    if (sa->line != sb->line) 
        return sa->line - sb->line;
    return sa->column - sb->column;
}

/* Imprimir tabela de símbolos */
void print_symbol_table() {
    printf("╔════════════════════════════════════════════════════════════════════╗\n");
    printf("║                     " BOLD MAGENTA "TABELA DE SÍMBOLOS" RESET"                             ║\n");
    printf("╠═══════╦═══════════╦═══════════════════════╦════════════════════════╣\n");
    printf("║ " BOLD BLUE "%-5s" RESET " ║ " BOLD YELLOW "%-9s" RESET " ║ " BOLD CYAN "%-21s" RESET " ║ " BOLD GREEN "%-22s" RESET " ║\n", "[ID]", "[Lin:Col]", "LEXEMA", "TIPO");
    printf("╠═══════╬═══════════╬═══════════════════════╬════════════════════════╣\n");
    for (int i = 0; i < symbol_count; i++) {
        printf("║ " BOLD BLUE "[%03d]" RESET " ║ " BOLD YELLOW "[%03d:%03d]" RESET " ║ " BOLD CYAN "%-21s" RESET " ║ " BOLD GREEN "%-21s" RESET "  ║\n",
                symbol_table[i].id,
                symbol_table[i].line,
                symbol_table[i].column,
                symbol_table[i].lexeme, 
                token_type_to_string(symbol_table[i].token_type));
    }
    printf("╠═══════╩═══════════╩═══════════════════════╩════════════════════════╣\n");
    printf("║ " BOLD "Total de símbolos:" RESET "%-40d         ║\n", symbol_count);
    printf("╚════════════════════════════════════════════════════════════════════╝\n");
}

/* Função principal */
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
    
    /* Inicializar tabela de símbolos (array) */
    symbol_count = 0;
    
    printf("╔══════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                                              " BOLD MAGENTA "ANÁLISE LÉXICA" RESET "                                              ║\n");
    printf("╠═══════════╦══════════════════════╦═══════════════════════════════════════════════════════════════════════╣\n");
    printf("║ " BOLD YELLOW "%-9s" RESET " ║ " BOLD CYAN "%-20s" RESET " ║ " BOLD GREEN "%-69s" RESET " ║\n", "[Lin:Col]", "TOKEN", "LEXEMA");
    printf("╠═══════════╬══════════════════════╬═══════════════════════════════════════════════════════════════════════╣\n");
    /* Executar análise léxica */
    yylex();
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