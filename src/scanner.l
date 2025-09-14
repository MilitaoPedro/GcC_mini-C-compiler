%option noyywrap yylineno
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Estrutura para a tabela de símbolos */
typedef struct symbol {
    char *lexeme;
    char *token_type;
    int line;
    int column;
    struct symbol *next;
} Symbol;

/* Tabela de símbolos usando hash table */
#define HASH_SIZE 101
Symbol *symbol_table[HASH_SIZE];
int symbol_count = 0;

/* Variáveis para controle de posição */
int column_num = 1;
int error_count = 0;

/* Protótipos das funções */
unsigned int hash_function(char *str);
void insert_symbol(char *lexeme, char *token_type);
Symbol* lookup_symbol(char *lexeme);
void print_symbol_table();
void print_token(char *token_type, char *lexeme);
void report_error(char *message);

FILE *yyin;
FILE *yyout;
%}

/* Definições de padrões */
DIGIT       [0-9]
LETTER      [a-zA-Z]
IDENTIFIER  {LETTER}({LETTER}|{DIGIT}|_)*
INTEGER     -?{DIGIT}+
WHITESPACE  [ \t]+
NEWLINE     \n

%%

"//".*                  { column_num += yyleng; }
"/*"([^*]|\*+[^*/])*\*+"/"  { 
    for(int i = 0; yytext[i]; i++) {
        if(yytext[i] == '\n') {
            yylineno++;
            column_num = 1;
        } else {
            column_num++;
        }
    }
}
"int"           { print_token("KEYWORD", yytext); insert_symbol(yytext, "KEYWORD"); column_num += yyleng; }
"bool"          { print_token("KEYWORD", yytext); insert_symbol(yytext, "KEYWORD"); column_num += yyleng; }
"if"            { print_token("KEYWORD", yytext); insert_symbol(yytext, "KEYWORD"); column_num += yyleng; }
"else"          { print_token("KEYWORD", yytext); insert_symbol(yytext, "KEYWORD"); column_num += yyleng; }
"while"         { print_token("KEYWORD", yytext); insert_symbol(yytext, "KEYWORD"); column_num += yyleng; }
"print"         { print_token("KEYWORD", yytext); insert_symbol(yytext, "KEYWORD"); column_num += yyleng; }
"read"          { print_token("KEYWORD", yytext); insert_symbol(yytext, "KEYWORD"); column_num += yyleng; }
"true"          { print_token("KEYWORD", yytext); insert_symbol(yytext, "KEYWORD"); column_num += yyleng; }
"false"         { print_token("KEYWORD", yytext); insert_symbol(yytext, "KEYWORD"); column_num += yyleng; }

"=="            { print_token("RELATIONAL_OP", yytext); column_num += yyleng; }
"!="            { print_token("RELATIONAL_OP", yytext); column_num += yyleng; }
"<="            { print_token("RELATIONAL_OP", yytext); column_num += yyleng; }
">="            { print_token("RELATIONAL_OP", yytext); column_num += yyleng; }
"<"             { print_token("RELATIONAL_OP", yytext); column_num += yyleng; }
">"             { print_token("RELATIONAL_OP", yytext); column_num += yyleng; }

"&&"            { print_token("LOGICAL_OP", yytext); column_num += yyleng; }
"||"            { print_token("LOGICAL_OP", yytext); column_num += yyleng; }
"!"             { print_token("LOGICAL_OP", yytext); column_num += yyleng; }

"+"             { print_token("ARITHMETIC_OP", yytext); column_num += yyleng; }
"-"             { print_token("ARITHMETIC_OP", yytext); column_num += yyleng; }
"*"             { print_token("ARITHMETIC_OP", yytext); column_num += yyleng; }
"/"             { print_token("ARITHMETIC_OP", yytext); column_num += yyleng; }
"%"             { print_token("ARITHMETIC_OP", yytext); column_num += yyleng; }
"="             { print_token("ASSIGNMENT_OP", yytext); column_num += yyleng; }

";"             { print_token("SEMICOLON", yytext); column_num += yyleng; }
","             { print_token("COMMA", yytext); column_num += yyleng; }
"("             { print_token("LPAREN", yytext); column_num += yyleng; }
")"             { print_token("RPAREN", yytext); column_num += yyleng; }
"{"             { print_token("LBRACE", yytext); column_num += yyleng; }
"}"             { print_token("RBRACE", yytext); column_num += yyleng; }

{INTEGER}       { print_token("INTEGER", yytext); insert_symbol(yytext, "INTEGER"); column_num += yyleng; }

{IDENTIFIER}    { print_token("IDENTIFIER", yytext); insert_symbol(yytext, "IDENTIFIER"); column_num += yyleng; }

{WHITESPACE}    { column_num += yyleng; }

{NEWLINE}       { yylineno++; column_num = 1; }

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
    while (*str) {
        hash = hash * 31 + *str++;
    }
    return hash % HASH_SIZE;
}

/* Inserir símbolo na tabela */
void insert_symbol(char *lexeme, char *token_type) {
    /* Verifica se já existe */
    if (lookup_symbol(lexeme) != NULL) {
        return; /* Já existe, não insere duplicata */
    }
    
    unsigned int index = hash_function(lexeme);
    Symbol *new_symbol = (Symbol*)malloc(sizeof(Symbol));
    
    new_symbol->lexeme = strdup(lexeme);
    new_symbol->token_type = strdup(token_type);
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

/* Imprimir token com posição */
void print_token(char *token_type, char *lexeme) {
    printf("%-15s %-15s Linha: %3d Coluna: %3d\n", 
           token_type, lexeme, yylineno, column_num);
}

/* Reportar erro */
void report_error(char *message) {
    fprintf(stderr, "ERRO: %s na linha %d, coluna %d\n", message, yylineno, column_num);
    error_count++;
}


/* Imprimir tabela de símbolos */
void print_symbol_table() {
    printf("\n============================================================\n");
    printf("TABELA DE SÍMBOLOS\n");
    printf("============================================================\n");
    printf("%-20s %-15s %-8s %-8s\n", "LEXEMA", "TIPO", "LINHA", "COLUNA");
    printf("------------------------------------------------------------\n");
    
    for (int i = 0; i < HASH_SIZE; i++) {
        Symbol *current = symbol_table[i];
        while (current != NULL) {
            printf("%-20s %-15s %-8d %-8d\n", 
                   current->lexeme, current->token_type, 
                   current->line, current->column);
            current = current->next;
        }
    }
    printf("------------------------------------------------------------\n");
    printf("Total de símbolos: %d\n", symbol_count);
    if (error_count > 0) {
        printf("Total de erros encontrados: %d\n", error_count);
    }
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
    
    printf("ANÁLISE LÉXICA\n");
    printf("============================================================\n");
    printf("%-15s %-15s %-12s %-8s\n", "TOKEN", "LEXEMA", "POSIÇÃO", "");
    printf("------------------------------------------------------------\n");
    
    /* Executar análise léxica */
    yylex();
    
    /* Imprimir tabela de símbolos */
    print_symbol_table();
    
    fclose(yyin);
    
    if (error_count == 0) {
        printf("\nAnálise concluída com sucesso!\n");
        return 0;
    } else {
        printf("\nAnálise concluída com %d erro(s).\n", error_count);
        return 1;
    }
}
