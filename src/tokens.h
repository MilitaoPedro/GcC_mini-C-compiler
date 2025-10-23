#ifndef TOKENS_H
#define TOKENS_H
#include "parser.tab.h"

/* Estrutura para a tabela de símbolos */
typedef struct symbol {
    int id;                 /* Identificador único do token na tabela de símbolos*/
    char *lexeme;           /* O texto do token ("int", "main", "x") */
    yytoken_kind_t token_type;   /* Tipo do token (enum) */
    int line;               /* Linha onde aparece */
    int column;             /* Coluna onde inicia */
} Symbol;

#endif /* TOKENS_H */