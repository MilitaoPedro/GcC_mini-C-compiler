/* ======================== Seção de definições ======================== */
%option noyywrap yylineno nounput noinput
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "tokens.h"
#include "parser.tab.h"

/* Faz o lexer "enxergar" a string global do parser */
extern char g_full_trace[];

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
int lexic_error_count = 0;

/* Protótipos das funções */
void insert_symbol(char *lexeme, yytoken_kind_t token_type);
Symbol* lookup_symbol(char *lexeme);
void print_symbol_table();
void print_token(yytoken_kind_t token_type, char *lexeme);
void report_error(char *message);
const char* token_type_to_string(yytoken_kind_t type);

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
"int"           { print_token(TK_INT, yytext); column_num += yyleng; return TK_INT; }
"bool"          { print_token(TK_BOOL, yytext); column_num += yyleng; return TK_BOOL; }
"if"            { print_token(TK_IF, yytext); column_num += yyleng; return TK_IF; }
"else"          { print_token(TK_ELSE, yytext); column_num += yyleng; return TK_ELSE; }
"while"         { print_token(TK_WHILE, yytext); column_num += yyleng; return TK_WHILE; }
"print"         { print_token(TK_PRINT, yytext); column_num += yyleng; return TK_PRINT; }
"read"          { print_token(TK_READ, yytext); column_num += yyleng; return TK_READ; }
"true"          { print_token(TK_TRUE, yytext); column_num += yyleng; return TK_TRUE; }
"false"         { print_token(TK_FALSE, yytext); column_num += yyleng; return TK_FALSE; }

"=="            { print_token(TK_EQ, yytext); column_num += yyleng; return TK_EQ; }
"!="            { print_token(TK_NE, yytext); column_num += yyleng; return TK_NE; }
"<="            { print_token(TK_LE, yytext); column_num += yyleng; return TK_LE; }
">="            { print_token(TK_GE, yytext); column_num += yyleng; return TK_GE; }
"<"             { print_token(TK_LT, yytext); column_num += yyleng; return TK_LT; }
">"             { print_token(TK_GT, yytext); column_num += yyleng; return TK_GT; }

"&&"            { print_token(TK_LOGICAL_AND, yytext); column_num += yyleng; return TK_LOGICAL_AND; }
"||"            { print_token(TK_LOGICAL_OR, yytext); column_num += yyleng; return TK_LOGICAL_OR; }
"!"             { print_token(TK_LOGICAL_NOT, yytext); column_num += yyleng; return TK_LOGICAL_NOT; }

"+"             { print_token(TK_PLUS, yytext); column_num += yyleng; return TK_PLUS; }
"-"             { print_token(TK_MINUS, yytext); column_num += yyleng; return TK_MINUS; }
"*"             { print_token(TK_MULT, yytext); column_num += yyleng; return TK_MULT; }
"/"             { print_token(TK_DIV, yytext); column_num += yyleng; return TK_DIV; }
"%"             { print_token(TK_MOD, yytext); column_num += yyleng; return TK_MOD; }

"="             { print_token(TK_ASSIGN, yytext); column_num += yyleng; return TK_ASSIGN; }

";"             { print_token(TK_SEMICOLON, yytext); column_num += yyleng; return TK_SEMICOLON; }
","             { print_token(TK_COMMA, yytext); column_num += yyleng; return TK_COMMA; }
"("             { print_token(TK_LPAREN, yytext); column_num += yyleng; return TK_LPAREN; }
")"             { print_token(TK_RPAREN, yytext); column_num += yyleng; return TK_RPAREN; }
"{"             { print_token(TK_LBRACE, yytext); column_num += yyleng; return TK_LBRACE; }
"}"             { print_token(TK_RBRACE, yytext); column_num += yyleng; return TK_RBRACE; }

{INTEGER}       { print_token(TK_INTEGER, yytext); column_num += yyleng; return TK_INTEGER; }


-?{DIGIT}+({LETTER}|_)+({LETTER}|{DIGIT}|_)* {
    char error_msg[140];
    sprintf(error_msg, "Número invalido: sufixo invalido em literal inteiro '%s'", yytext);
    report_error(error_msg);
    column_num += yyleng;
    /* Sem return, o parser não recebe token */
}

{IDENTIFIER}    { print_token(TK_ID, yytext); insert_symbol(yytext, TK_ID); column_num += yyleng; return TK_ID; }

{WHITESPACE}    { column_num += yyleng; }

{NEWLINE}       { column_num = 1; }
.               { 
    char error_msg[100];
    sprintf(error_msg, "Caractere não reconhecido: '%s'", yytext);
    report_error(error_msg);
    column_num += yyleng;
    /* Sem return */
}

%%

/* Inserir símbolo na tabela (array) */
void insert_symbol(char *lexeme, yytoken_kind_t token_type) {
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
const char* token_type_to_string(yytoken_kind_t type) {
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
/* Imprimir token com posição */
void print_token(yytoken_kind_t token_type, char *lexeme) {
    /* 1. IMPRIME A TABELA LÉXICA (COMO ANTES) */
    printf("║ " YELLOW "[%03d:%03d]" RESET " ║ " CYAN "%-20s" RESET " ║ " GREEN "%-69s" RESET " ║\n",
        yylineno,
        column_num,
        token_type_to_string(token_type),
        lexeme
    );
    
    /* 2. REGISTRA A AÇÃO "SHIFT" NA ANÁLISE LÉXICA GLOBAL (COM POSIÇÃO) */
    char temp_str[256];
    char token_name_str[50];
    
    strcpy(token_name_str, token_type_to_string(token_type)); 
    
    sprintf(temp_str, "[%03d:%03d]\tSHIFT\t%s (%s)\n", 
            yylineno, 
            column_num, 
            token_name_str, 
            lexeme);
    strcat(g_full_trace, temp_str);
}

/* Reportar erro */
void report_error(char *message) {
    // Imprime a linha de erro usando o mesmo formato de tabela
    printf("║ " BOLD RED "[%03d:%03d]" RESET " ║ " BOLD RED "%-21s" RESET " ║ " BOLD RED "%-69s" RESET "  ║\n",
            yylineno,
            column_num,
            "ERRO LÉXICO",  // O "tipo de token" do erro
            message);  // A descrição do erro
    lexic_error_count++;
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
    printf("║                         " BOLD MAGENTA "TABELA DE SÍMBOLOS" RESET"                         ║\n");
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
