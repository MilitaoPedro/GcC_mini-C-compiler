/* ======================== Seção de Definições (Bison) ======================== */
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ------------------------- Protótipos e Globais do Lexer ------------------------- */
/* Declarações 'extern' informam ao Bison que estas funções/variáveis existem
   em outro arquivo (gerado pelo Flex, scanner.l) e serão ligadas na compilação. */

extern int yylex();                 // Função principal do analisador léxico (retorna o próximo token).
extern FILE *yyin;                  // Ponteiro para o arquivo de entrada sendo lido.
extern int yylineno;                // Variável global do Flex que armazena o número da linha atual.
extern int lexic_error_count;       // Contador de erros léxicos (definido no scanner.l).
extern int column_num;              // Contador de coluna atual (definido no scanner.l).

/* Funções auxiliares que ainda estão no scanner.l */
extern void print_symbol_table();   // Função para imprimir a tabela de símbolos (do lexer).

/* Contador de erros sintáticos (definido neste arquivo). */
int sintatic_error_count = 0;

/* Protótipo da função que adiciona uma entrada ao trace de redução. */
void add_reduce_trace(const char *rule);

/* Definições de cores ANSI para formatação da saída no terminal. */
#define RESET   "\033[0m"
#define RED     "\033[31m"
#define GREEN   "\033[32m"
#define YELLOW  "\033[33m"
#define BLUE    "\033[34m"
#define MAGENTA "\033[35m"
#define CYAN    "\033[36m"
#define BOLD    "\033[1m"

/* A função de erro que o Bison vai chamar automaticamente ao detectar um erro sintático. */
void yyerror(const char *s);

/* Variavel global para armazenar a string completa do trace de parsing (Shift/Reduce/Erro). */
char g_full_trace[65536] = "AÇÃO\tDETALHE\n"; // Buffer inicializado com o cabeçalho.

%}

/* ------------------------------ Definição de Tokens ------------------------------ */
/* Lista todos os tokens terminais que o analisador léxico (yylex) pode retornar.
   O Bison usa esses nomes para gerar as definições numéricas em parser.tab.h. */

%token TK_INT TK_BOOL TK_IF TK_ELSE TK_WHILE TK_PRINT
%token TK_READ TK_TRUE TK_FALSE                                         /* TK_RELOP TK_LOP TK_ARITHOP <- Removidos/Substituídos */
%token TK_SEMICOLON TK_COMMA TK_LPAREN TK_RPAREN TK_LBRACE TK_RBRACE
%token TK_INTEGER TK_ID
%token TK_EQ TK_NE TK_LE TK_GE TK_LT TK_GT                              // Tokens específicos para operadores relacionais
%token TK_LOGICAL_AND TK_LOGICAL_OR TK_LOGICAL_NOT                      // Tokens específicos para operadores lógicos
%token TK_PLUS TK_MINUS TK_MULT TK_DIV TK_MOD                           // Tokens específicos para operadores aritméticos
%token TK_ASSIGN                                                        // Token específico para atribuição

/* Diretiva para habilitar mensagens de erro mais detalhadas passadas para yyerror. */
%define parse.error verbose

/* Define o símbolo inicial da gramática (o não-terminal raiz). */
%start program

/* ------------------------------ PRECEDÊNCIA E ASSOCIATIVIDADE DOS OPERADORES ------------------------------ */
/* Define a ordem e como os operadores se agrupam em expressões. Linhas mais baixas têm MAIOR precedência. */

%left TK_LOGICAL_OR                 /* || (menor precedência, associa à esquerda) */
%left TK_LOGICAL_AND                /* && (associa à esquerda) */
%left TK_EQ TK_NE                   /* == != (associa à esquerda) */
%left TK_LT TK_LE TK_GT TK_GE       /* < <= > >= (associa à esquerda) */
%left TK_PLUS TK_MINUS              /* + - binários (associa à esquerda) */
%left TK_MULT TK_DIV TK_MOD         /* * / % (associa à esquerda) */
%right TK_LOGICAL_NOT               /* ! unário (associa à direita) */
%right UMINUS                       /* Pseudo-token para Menos Unário (alta precedência, associa à direita) */

/* ======================================= Seção de Regras (Gramática) ======================================= */
%%

/* Um programa é definido como uma sequência de 'statements'. */
program:
                        statements                                                                      { add_reduce_trace("program -> statements");} /* Ação executada ao reconhecer o programa inteiro */
                        ;

/* 'statements' representa uma lista de zero ou mais 'statement'. */
statements:
                        /* epsilon */                                                                   { add_reduce_trace("statements ->");} /* Regra para lista vazia */
                        | statements statement                                                          { add_reduce_trace("statements -> statements statement");} /* Regra recursiva: adiciona um statement à lista */

                        /* Regras de recuperação de erro em modo pânico: */
                        | statements error TK_SEMICOLON /* Descarta tokens até encontrar ';' */         { yyerrok; add_reduce_trace("statements -> statements error ; (Recuperacao)"); } /* yyerrok sai do modo erro */
                        | statements error TK_RBRACE    /* Descarta tokens até encontrar '}' */         { /* Não precisa yyerrok aqui, '}' fecha o contexto */ add_reduce_trace("statements -> statements error } (Recuperacao Fim Bloco)"); }
                        ;

/* 'statement' define os tipos de comandos individuais permitidos na linguagem.
   Usa a divisão matched/unmatched para resolver a ambiguidade do 'dangling else'. */
statement:
                        matched_statement                                                               { add_reduce_trace("statement -> matched_statement"); } /* Um statement pode ser um 'matched' */
                        | unmatched_statement                                                           { add_reduce_trace("statement -> unmatched_statement"); } /* Ou um 'unmatched' */
    ;

/* MATCHE_STATEMENT: Qualquer comando que está sintaticamente "completo"
   e não termina ambiguamente com um IF sem ELSE. */
matched_statement:
                        declaration                                                                     { add_reduce_trace("matched_statement -> declaration"); }
                        | assignment                                                                    { add_reduce_trace("matched_statement -> assignment"); }
                        | read                                                                          { add_reduce_trace("matched_statement -> read"); }
                        | print                                                                         { add_reduce_trace("matched_statement -> print"); }
                        | while_stmt                                                                    { add_reduce_trace("matched_statement -> while_stmt"); }

                        /* Um IF-ELSE completo é um matched_statement SE AMBOS os corpos (then/else)
                           também forem matched_statements. Isso força o ELSE a se ligar ao IF interno. */
                        | TK_IF TK_LPAREN expression TK_RPAREN then TK_ELSE then                        { add_reduce_trace("matched_statement -> IF ( expr ) then ELSE then"); }
                        ;

/* UNMATCHED_STATEMENT: Um comando que termina em um IF sem ELSE,
   criando a potencial ambiguidade. */
unmatched_statement:
                        /* Um IF sem ELSE. O corpo (then) pode ser qualquer tipo de statement. */
                        TK_IF TK_LPAREN expression TK_RPAREN then                                       { add_reduce_trace("unmatched_statement -> IF ( expr ) then"); }

                        /* Um IF-ELSE onde a parte ELSE é ela mesma um unmatched_statement. */
                        | TK_IF TK_LPAREN expression TK_RPAREN then TK_ELSE unmatched_statement         { add_reduce_trace("unmatched_statement -> IF ( expr ) then ELSE unmatched_stmt"); }
                        ;

/* 'then' representa o corpo de um comando IF ou WHILE.
   Pode ser um bloco {} ou um único matched_statement (para evitar ambiguidade). */
then:                   TK_LBRACE statements TK_RBRACE                                                  { add_reduce_trace("then -> { statements }"); }
                        | matched_statement                                                             { add_reduce_trace("then -> matched_statement"); }
                        ;


/* Regra para declaração de variáveis. */
declaration:            type id_list TK_SEMICOLON                                                       { add_reduce_trace("declaration -> type id_list TK_SEMICOLON");}
                        ;

/* Regra para os tipos de dados permitidos. */
type:                   TK_INT                                                                          { add_reduce_trace("type -> TK_INT");}
                        | TK_BOOL                                                                       { add_reduce_trace("type -> TK_BOOL");}
                        ;

/* Regra para lista de identificadores em declarações (separados por vírgula). */
id_list:                TK_ID                                                                           { add_reduce_trace("id_list -> TK_ID");} /* Lista com um ID */
                        | id_list TK_COMMA TK_ID                                                        { add_reduce_trace("id_list -> id_list TK_COMMA TK_ID");} /* Lista com mais IDs */
                        ;

/* Regra para comando de atribuição. */
assignment:             TK_ID TK_ASSIGN expression TK_SEMICOLON                                         { add_reduce_trace("assignment -> TK_ID TK_ASSIGN expression TK_SEMICOLON");}
                        ;

/* Regra para comando de leitura. */
read:                   TK_READ TK_LPAREN TK_ID TK_RPAREN TK_SEMICOLON                                  { add_reduce_trace("read -> TK_READ ( TK_ID ) TK_SEMICOLON");}
                        ;

/* Regra para comando de impressão. */
print:                  TK_PRINT TK_LPAREN expression TK_RPAREN TK_SEMICOLON                            { add_reduce_trace("print -> TK_PRINT ( expression ) TK_SEMICOLON");}
                        ;

/* Regra para o comando 'while'. O corpo deve ser um bloco ou um matched_statement. */
while_stmt:
                        TK_WHILE TK_LPAREN expression TK_RPAREN TK_LBRACE statements TK_RBRACE          { add_reduce_trace("while_stmt -> WHILE ( expr ) { statements }"); }
                        | TK_WHILE TK_LPAREN expression TK_RPAREN matched_statement                     { add_reduce_trace("while_stmt -> WHILE ( expr ) matched_statement"); }
                        ;

/* Regra para expressões. Cobre literais, identificadores, parênteses e todas as operações.
   A precedência e associatividade são resolvidas pelas diretivas %left/%right/%prec. */
expression:             TK_INTEGER                                                                      { add_reduce_trace("expression -> TK_INTEGER");}
                        | TK_TRUE                                                                       { add_reduce_trace("expression -> TK_TRUE");}
                        | TK_FALSE                                                                      { add_reduce_trace("expression -> TK_FALSE");}
                        | TK_ID                                                                         { add_reduce_trace("expression -> TK_ID");}
                        | TK_LPAREN expression TK_RPAREN                                                { add_reduce_trace("expression -> ( expression )");}

                        /* Expressões Aritméticas */
                        | expression TK_PLUS expression                                                 { add_reduce_trace("expression -> expression + expression");}
                        | expression TK_MINUS expression                                                { add_reduce_trace("expression -> expression - expression");}
                        | expression TK_MULT expression                                                 { add_reduce_trace("expression -> expression * expression");}
                        | expression TK_DIV expression                                                  { add_reduce_trace("expression -> expression / expression");}
                        | expression TK_MOD expression                                                  { add_reduce_trace("expression -> expression % expression");}

                        /* Menos Unário (usa %prec UMINUS para maior precedência) */
                        | TK_MINUS expression %prec UMINUS                                              { add_reduce_trace("expression -> - expression (Unary)");}

                        /* Expressões Relacionais */
                        | expression TK_EQ expression                                                   { add_reduce_trace("expression -> expression == expression");}
                        | expression TK_NE expression                                                   { add_reduce_trace("expression -> expression != expression");}
                        | expression TK_LT expression                                                   { add_reduce_trace("expression -> expression < expression");}
                        | expression TK_LE expression                                                   { add_reduce_trace("expression -> expression <= expression");}
                        | expression TK_GT expression                                                   { add_reduce_trace("expression -> expression > expression");}
                        | expression TK_GE expression                                                   { add_reduce_trace("expression -> expression >= expression");}

                        /* Expressões Lógicas */
                        | expression TK_LOGICAL_AND expression                                          { add_reduce_trace("expression -> expression && expression");}
                        | expression TK_LOGICAL_OR expression                                           { add_reduce_trace("expression -> expression || expression");}
                        | TK_LOGICAL_NOT expression                                                     { add_reduce_trace("expression -> ! expression");}
                        ;
%%
/* ======================================= Seção de Código C ======================================= */

/*
   Esta função é invocada automaticamente pelo parser quando um erro sintático
   é detectado. Ela formata a mensagem de erro (removendo prefixos genéricos
   se %define parse.error verbose estiver ativo), adiciona a posição do erro
   e registra a mensagem na string global g_full_trace para impressão posterior.
   Também incrementa o contador de erros sintáticos.
 */
void yyerror(const char *s) {
    char temp_str[512]; // Buffer para a linha completa do trace.
    char error_detail[400]; // Buffer para a mensagem de erro específica.

    // Tenta remover o prefixo "syntax error, " para obter a mensagem mais útil.
    if (strncmp(s, "syntax error, ", 14) == 0) {
        strncpy(error_detail, s + 14, sizeof(error_detail) - 1);
    } else {
        strncpy(error_detail, s, sizeof(error_detail) - 1);
    }
    error_detail[sizeof(error_detail) - 1] = '\0'; // Garante terminação.

    // Formata a entrada do trace no padrão: "[Lin:Col]\tERRO\tDetalhe do erro\n"
    sprintf(temp_str, "[%03d:%03d]\tERRO\t%s\n",
            yylineno,     // Número da linha atual (do lexer).
            column_num,   // Número da coluna atual (do lexer).
            error_detail);// Mensagem específica do Bison.

    // Adiciona a linha de erro formatada ao buffer global do trace.
    strcat(g_full_trace, temp_str);
    sintatic_error_count++; // Incrementa o contador de erros sintáticos.
}

/*
   Esta função é chamada nas ações de cada regra gramatical. Ela formata
   a string da regra de redução junto com a posição atual (linha e coluna
   do último token consumido pela regra) e a anexa à string global g_full_trace.
 */
void add_reduce_trace(const char *rule) {
    char temp_str[256];             // Buffer aumentado para regras mais longas.

    // Formata a entrada do trace: "[Lin:Col]\tREDUCE\tDescrição da Regra\n"
    sprintf(temp_str, "[%03d:%03d]\tREDUCE\t%s\n", yylineno, column_num, rule);
    strcat(g_full_trace, temp_str); // Anexa ao buffer global.
}

/*
   Esta função lê a string global g_full_trace (preenchida durante o parsing),
   quebra-a em linhas e colunas (usando strtok_r e sscanf), e imprime
   uma tabela formatada no console com as colunas Posição, Ação e Detalhe.
   Linhas de erro são destacadas em vermelho.
 */
void parsing_table(){
    printf("\n"); // Adiciona um espaço antes da tabela.
    // Imprime o cabeçalho da tabela com bordas.
    printf("╔══════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                                      " BOLD MAGENTA "ANÁLISE SINTÁTICA (Shift-Reduce)" RESET "                                    ║\n");
    printf("╠═══════════╦═══════════╦══════════════════════════════════════════════════════════════════════════════════╣\n");
    printf("║ " BOLD YELLOW "%-9s" RESET " ║ " BOLD CYAN "  %-9s" RESET " ║ " BOLD GREEN "%-82s" RESET " ║\n", "[Lin:Col]", "AÇÃO", "DETALHE (Token ou Produção)");
    printf("╠═══════════╬═══════════╬══════════════════════════════════════════════════════════════════════════════════╣\n");

    char* saved_ptr; // Ponteiro de contexto para strtok_r.
    char* trace_copy = strdup(g_full_trace); // Cria uma cópia, pois strtok_r modifica a string.
    if (!trace_copy) { perror("Falha ao duplicar trace string para parsing_table"); return; }

    char* line = strtok_r(trace_copy, "\n", &saved_ptr); // Primeira chamada (pega o cabeçalho "AÇÃO\tDETALHE").
    line = strtok_r(NULL, "\n", &saved_ptr); // Segunda chamada (pega a primeira linha real do trace).

    // Itera sobre cada linha do trace.
    while (line != NULL) {
        char position[20], action[100], detail[200];
        // Tenta parsear a linha no formato "POSICAO \t ACAO \t DETALHE".
        if (sscanf(line, "%[^\t]\t%[^\t]\t%[^\n]", position, action, detail) == 3) {
             // Verifica se a ação é um erro para aplicar a cor vermelha.
             if (strcmp(action, "ERRO") == 0) {
                 printf("║ " BOLD YELLOW "%-9s" RESET " ║ " BOLD RED "%-9s" RESET " ║ " BOLD RED "%-80s" RESET " ║\n",
                        position, action, detail);
             } else { // Imprime linhas normais (SHIFT ou REDUCE).
                    printf("║ " BOLD YELLOW "%-9s" RESET " ║ " CYAN "%-9s" RESET " ║ " GREEN "%-80s" RESET " ║\n",
                        position, action, detail);
             }
        } else {
             // Linha mal formatada no trace (não deve acontecer se add_reduce_trace e yyerror estiverem corretos)
             fprintf(stderr, "Aviso: Linha mal formatada no trace interno: %s\n", line);
        }
        line = strtok_r(NULL, "\n", &saved_ptr); // Pega a próxima linha.
    }
    free(trace_copy); // Libera a memória da cópia da string do trace.

    // Imprime o rodapé da tabela com o status final.
    printf("╠═══════════╩═══════════╩══════════════════════════════════════════════════════════════════════════════════╣\n");
    if (sintatic_error_count == 0) {
        printf("║ " BOLD GREEN "Análise Sintática concluída com sucesso!                                                                 "RESET"║\n");
    } else{
        // Usa %.3d para garantir 3 dígitos na contagem (ex: 001 erro).
        printf("║ " BOLD RED "Análise Sintática concluída com %.3d erro(s).                                                             "RESET"║\n", sintatic_error_count);
    }
    printf("╚══════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n");
}

/*
   Responsável por:
   1. Validar argumentos de linha de comando.
   2. Abrir o arquivo de entrada.
   3. Imprimir o cabeçalho da tabela de análise léxica.
   4. Chamar yyparse() para iniciar a análise sintática (que por sua vez chama yylex()).
   5. Imprimir o rodapé e status da análise léxica.
   6. Chamar parsing_table() para imprimir a tabela de trace sintático.
   7. Imprimir o status da análise sintática.
   8. Chamar print_symbol_table() para imprimir a tabela de símbolos (preenchida pelo lexer).
   9. Fechar o arquivo e retornar o status de sucesso (0) ou erro (1).
 */
int main(int argc, char *argv[]) {
    // Verifica se o nome do arquivo foi passado como argumento.
    if (argc < 2) {
        fprintf(stderr, "Uso: %s <arquivo>\n", argv[0]);
        return 1; // Retorna erro.
    }

    // Tenta abrir o arquivo de entrada para leitura.
    yyin = fopen(argv[1], "r");
    if (!yyin) {
        perror("Erro ao abrir o arquivo"); // Exibe erro do sistema.
        return 1; // Retorna erro.
    }

    /* Inicialização da tabela de símbolos (se necessário) - atualmente feita no lexer. */
    /* symbol_count = 0; */

    /* Imprime o cabeçalho da tabela de ANÁLISE LÉXICA. */
    printf("╔══════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                                              " BOLD MAGENTA "ANÁLISE LÉXICA" RESET "                                              ║\n");
    printf("╠═══════════╦══════════════════════╦═══════════════════════════════════════════════════════════════════════╣\n");
    printf("║ " BOLD YELLOW "%-9s" RESET " ║ " BOLD CYAN "%-20s" RESET " ║ " BOLD GREEN "%-69s" RESET " ║\n", "[Lin:Col]", "TOKEN", "LEXEMA");
    printf("╠═══════════╬══════════════════════╬═══════════════════════════════════════════════════════════════════════╣\n");

    /* Chama a função principal do Bison para iniciar o parsing.
       yyparse() chamará yylex() repetidamente para obter tokens.
       yylex() chamará print_token(), que imprime a tabela léxica e preenche g_full_trace com SHIFTs.
       As ações das regras gramaticais chamarão add_reduce_trace(), preenchendo g_full_trace com REDUCEs.
       Se ocorrer um erro sintático, yyerror() será chamada, preenchendo g_full_trace com ERROs. */
    yyparse();

    /* Imprime o rodapé e o status da ANÁLISE LÉXICA. */
    printf("╠═══════════╩══════════════════════╩═══════════════════════════════════════════════════════════════════════╣\n");
    if (lexic_error_count == 0) {
        printf("║ " BOLD GREEN "Análise Léxica concluída com sucesso!                                                                    " RESET "║\n");
    } else{
        printf("║ " BOLD RED "Análise Léxica concluída com %.3d erro(s).                                                                " RESET "║\n", lexic_error_count);
    }
    printf("╚══════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n");


    /* Imprime a tabela de ANÁLISE SINTÁTICA (trace) que foi preenchida durante o yyparse(). */
    parsing_table();

    /* Imprime a TABELA DE SÍMBOLOS que foi preenchida pelo analisador léxico. */
    print_symbol_table();

    // Fecha o arquivo de entrada.
    fclose(yyin);

    // Retorna 0 se não houve erros, 1 caso contrário.
    return (lexic_error_count == 0 && sintatic_error_count == 0) ? 0 : 1;
}