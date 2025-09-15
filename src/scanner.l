/* ======================== Seção de definições ======================== */
%option noyywrap yylineno
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tokens.h"

#define BOLD_RED "\033[1;31m"
#define BOLD_GREEN "\033[1;32m"
#define RESET_COLOR "\033[0;0m"

/* Tabela de símbolos (declaração e estado) */
#define HASH_SIZE 101
Symbol *symbol_table[HASH_SIZE];
int symbol_count = 0;

/* Variáveis para controle de posição */
int column_num = 1;
int error_count = 0;

/* Protótipos das funções */
unsigned int hash_function(char *str);
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
INTEGER     -?{DIGIT}+([+-]?e{DIGIT}+)?
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

{DIGIT}+({LETTER}|_)+({LETTER}|{DIGIT}|_)* {
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

/* Função hash simples */
unsigned int hash_function(char *str) {
    unsigned int hash = 0;
    while (*str)
        hash = hash * 31 + *str++;
    return hash % HASH_SIZE;
}

/* Inserir símbolo na tabela */
void insert_symbol(char *lexeme, TokenType token_type) {
    /* Verifica se já existe */
    if (lookup_symbol(lexeme) != NULL)
        return; /* Já existe, não insere duplicata */
    
    unsigned int index = hash_function(lexeme);
    Symbol *new_symbol = (Symbol*)malloc(sizeof(Symbol));
    
    new_symbol->lexeme = strdup(lexeme);
    new_symbol->token_type = token_type;
    new_symbol->line = yylineno;
    new_symbol->column = column_num;
    new_symbol->next = symbol_table[index];
    
    symbol_table[index] = new_symbol;
    symbol_count++;
}

/* Buscar símbolo na tabela */
Symbol* lookup_symbol(char *lexeme) {
    unsigned int index = hash_function(lexeme);
    Symbol *current = symbol_table[index];
    
    while (current != NULL) {
        if (strcmp(current->lexeme, lexeme) == 0) {
            return current;
        }
        current = current->next;
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
    printf("%-15s %-15s Linha: %3d Coluna: %3d\n", 
           token_type_to_string(token_type), lexeme, yylineno, column_num);
}

/* Reportar erro */
void report_error(char *message) {
    fprintf(stderr, BOLD_RED "ERRO: %s na linha %d, coluna %d\n" RESET_COLOR, message, yylineno, column_num);
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
    printf("\n============================================================\n");
    printf("TABELA DE SÍMBOLOS\n");
    printf("============================================================\n");
    printf("%-20s %-15s %-8s %-8s\n", "LEXEMA", "TIPO", "LINHA", "COLUNA");
    printf("------------------------------------------------------------\n");
    
    // If para não fazer malloc se não houver símbolos
    if (symbol_count > 0) {
        /* Coletar símbolos em um vetor para ordenar por lexema */
        int count = 0;
        Symbol **all = (Symbol**)malloc(sizeof(Symbol*) * (symbol_count > 0 ? symbol_count : 1));
        for (int i = 0; i < HASH_SIZE; i++) {
            Symbol *current = symbol_table[i];
            while (current != NULL) {
                all[count++] = current;
                current = current->next;
            }
        }

        /* Ordenar símbolos para impressão determinística */
        if (count > 1) 
            qsort(all, count, sizeof(Symbol*), compare_symbols);

        /* Imprimir símbolos ordenados */
        for (int i = 0; i < count; i++) {
            Symbol *current = all[i];
            printf("%-20s %-15s %-8d %-8d\n", 
                    current->lexeme, token_type_to_string(current->token_type), 
                    current->line, current->column);
        }
    } else;

    printf("------------------------------------------------------------\n");
    printf("Total de símbolos: %d\n", symbol_count);
    if (error_count > 0) 
        printf("Total de erros encontrados: %d\n", error_count);
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
    
    /* Inicializar tabela de símbolos */
    for (int i = 0; i < HASH_SIZE; i++) {
        symbol_table[i] = NULL;
    }
    
    printf("\n\nANÁLISE LÉXICA\n");
    printf("============================================================\n");
    printf("%-15s %-15s %-12s %-8s\n", "TOKEN", "LEXEMA", "POSIÇÃO", "");
    printf("------------------------------------------------------------\n");
    
    /* Executar análise léxica */
    yylex();
    
    /* Imprimir tabela de símbolos */
    print_symbol_table();
    
    fclose(yyin);
    
    if (error_count == 0) {
        printf(BOLD_GREEN "\nAnálise concluída com sucesso!\n" RESET_COLOR);
        return 0;
    } else {
        printf(BOLD_RED "\nAnálise concluída com %d erro(s)." RESET_COLOR, error_count);
        return 1;
    }
}