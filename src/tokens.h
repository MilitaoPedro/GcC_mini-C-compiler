#ifndef TOKENS_H
#define TOKENS_H

/* Enum para tipos de tokens */
typedef enum {
    TK_INT, TK_BOOL, TK_IF, TK_ELSE, TK_WHILE, TK_PRINT,
    TK_READ, TK_TRUE, TK_FALSE, TK_RELOP, TK_LOP, TK_ARITHOP,
    TK_SEMICOLON, TK_COMMA, TK_LPAREN, TK_RPAREN, TK_LBRACE, TK_RBRACE, TK_INTEGER, TK_ID
} TokenType;

/* Estrutura para a tabela de símbolos */
typedef struct symbol {
    char *lexeme;           /* O texto do token ("int", "main", "x") */
    TokenType token_type;   /* Tipo do token (enum) */
    int line;               /* Linha onde aparece */
    int column;             /* Coluna onde inicia */
    struct symbol *next;    /* Próximo na lista (para colisões) */
} Symbol;

#endif /* TOKENS_H */

