#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "trace_printer.h" // Inclui cores, protótipo e externs
// sei la
/* Declaração externa do array de regras definido em parser.y */
/* Array para mapear número da regra para sua string (Necessário para trace_printer.c) */
const char *g_bison_rule_strings[] = {
    /* Índice 0 */ "$accept -> program $end",
    /* Regra 1 */ "program -> statements",
    /* Regra 2 */ "block -> TK_LBRACE statements TK_RBRACE",
    /* Regra 3 */ "statements -> /* epsilon */",
    /* Regra 4 */ "statements -> statement statements",
    /* Regra 5 */ "statement -> declaration",
    /* Regra 6 */ "statement -> assignment",
    /* Regra 7 */ "statement -> read",
    /* Regra 8 */ "statement -> print",
    /* Regra 9 */ "statement -> while",
    /* Regra 10*/ "statement -> if",
    /* Regra 11*/ "declaration -> type id_list TK_SEMICOLON",
    /* Regra 12*/ "type -> TK_INT",
    /* Regra 13*/ "type -> TK_BOOL",
    /* Regra 14*/ "id_list -> TK_ID",
    /* Regra 15*/ "id_list -> id_list TK_COMMA TK_ID",
    /* Regra 16*/ "assignment -> TK_ID TK_ASSIGN expression TK_SEMICOLON",
    /* Regra 17*/ "read -> TK_READ TK_LPAREN TK_ID TK_RPAREN TK_SEMICOLON",
    /* Regra 18*/ "print -> TK_PRINT TK_LPAREN expression TK_RPAREN TK_SEMICOLON",
    /* Regra 19*/ "while -> TK_WHILE TK_LPAREN expression TK_RPAREN then",
    /* Regra 20*/ "if -> TK_IF TK_LPAREN expression TK_RPAREN then else",
    /* Regra 21*/ "else -> TK_ELSE then",
    /* Regra 22*/ "else -> /* epsilon */",
    /* Regra 23*/ "then -> statement",
    /* Regra 24*/ "then -> block",
    /* Regra 25*/ "expression -> TK_INTEGER",
    /* Regra 26*/ "expression -> TK_TRUE",
    /* Regra 27*/ "expression -> TK_FALSE",
    /* Regra 28*/ "expression -> TK_ID",
    /* Regra 29*/ "expression -> TK_LPAREN expression TK_RPAREN",
    /* Regra 30*/ "expression -> expression TK_PLUS expression",
    /* Regra 31*/ "expression -> expression TK_MINUS expression",
    /* Regra 32*/ "expression -> expression TK_MULT expression",
    /* Regra 33*/ "expression -> expression TK_DIV expression",
    /* Regra 34*/ "expression -> expression TK_MOD expression",
    /* Regra 35*/ "expression -> TK_MINUS expression (%prec UMINUS)",
    /* Regra 36*/ "expression -> expression TK_EQ expression",
    /* Regra 37*/ "expression -> expression TK_NE expression",
    /* Regra 38*/ "expression -> expression TK_LT expression",
    /* Regra 39*/ "expression -> expression TK_LE expression",
    /* Regra 40*/ "expression -> expression TK_GT expression",
    /* Regra 41*/ "expression -> expression TK_GE expression",
    /* Regra 42*/ "expression -> expression TK_LOGICAL_AND expression",
    /* Regra 43*/ "expression -> expression TK_LOGICAL_OR expression",
    /* Regra 44*/ "expression -> TK_LOGICAL_NOT expression"};
const int g_bison_rule_count = sizeof(g_bison_rule_strings) / sizeof(g_bison_rule_strings[0]);

//-----------------------------------------------------------------------------
// Estruturas e Funções Auxiliares
//-----------------------------------------------------------------------------

// Estrutura para lista dinâmica de strings (lookaheads)
typedef struct
{
    char **tokens;
    int count;
    int capacity;
} LookaheadList;

// Estrutura para pilha dinâmica de strings (símbolos)
typedef struct
{
    char **symbols;
    int top; // Índice do topo (-1 para vazia)
    int capacity;
} SymbolStack;

// ============================================================================
// NOVA FUNÇÃO AUXILIAR PARA ABREVIAR STRINGS
// ============================================================================
/**
 * Abrevia uma string se ela for muito longa, mostrando "...[final da string]".
 * Retorna um ponteiro para a string original se couber, ou para o buffer
 * temporário se foi abreviada.
 * NOTA: Esta versão simplificada ignora códigos de cor ANSI no cálculo do comprimento.
 */
const char *abbreviate_string(const char *original, int max_visible_width, char *buffer, size_t buffer_size)
{
    int visible_len = strlen(original);

    if (visible_len <= max_visible_width)
    {
        return original; // Cabe, retorna a original
    }
    else
    {
        // Garante que o buffer seja grande o suficiente para "..." + NUL
        if (buffer_size < 4)
        {
            // Se o buffer for muito pequeno, retorna uma string estática segura
            // (idealmente, você trataria esse erro de forma mais robusta)
            if (buffer_size > 0)
                buffer[0] = '\0';
            return "...";
        }

        // Calcula quantos caracteres do final mostrar
        int chars_to_show = max_visible_width - 3; // 3 para "..."
        if (chars_to_show < 1)
            chars_to_show = 1; // Mostra pelo menos 1 caractere

        // Garante que não tentaremos ler antes do início da string original
        const char *start_copy = original;
        if (visible_len > chars_to_show)
        {
            start_copy = original + visible_len - chars_to_show;
        }
        else
        {
            // Caso raro: max_visible_width < 3, chars_to_show > visible_len
            chars_to_show = visible_len;
            start_copy = original; // Mostra a string inteira (embora vá estourar)
        }

        // Copia "..." para o buffer, garantindo espaço para o NUL
        strncpy(buffer, "...", buffer_size - 1);
        buffer[3] = '\0'; // Coloca NUL após "..."

        // Concatena a parte final no buffer (com segurança)
        // Deixa espaço para o NUL final
        strncat(buffer, start_copy, buffer_size - strlen(buffer) - 1);
        buffer[buffer_size - 1] = '\0'; // Garante terminação NUL final

        return buffer; // Retorna o buffer com a string abreviada
    }
}

// Função para adicionar um token à lista dinâmica de lookaheads
void add_lookahead(LookaheadList *list, const char *token)
{
    if (list->count >= list->capacity)
    {
        list->capacity = (list->capacity == 0) ? 10 : list->capacity * 2;
        list->tokens = (char **)realloc(list->tokens, list->capacity * sizeof(char *));
        if (!list->tokens)
        {
            perror("Falha ao realocar memória para lookaheads");
            exit(EXIT_FAILURE);
        }
    }
    list->tokens[list->count] = strdup(token);
    if (!list->tokens[list->count])
    {
        perror("Falha ao duplicar string do lookahead");
        exit(EXIT_FAILURE);
    }
    list->count++;
}

// Função para liberar a memória da lista de lookaheads
void free_lookahead_list(LookaheadList *list)
{
    if (list->tokens)
    {
        for (int i = 0; i < list->count; i++)
            free(list->tokens[i]);
        free(list->tokens);
    }
    *list = (LookaheadList){NULL, 0, 0}; // Reseta a struct
}

// Função para inicializar a pilha de símbolos
void init_symbol_stack(SymbolStack *stack)
{
    stack->symbols = NULL;
    stack->top = -1;
    stack->capacity = 0;
}

// Função para empilhar um símbolo
void push_symbol(SymbolStack *stack, const char *symbol)
{
    if (stack->top + 1 >= stack->capacity)
    {
        stack->capacity = (stack->capacity == 0) ? 10 : stack->capacity * 2;
        stack->symbols = (char **)realloc(stack->symbols, stack->capacity * sizeof(char *));
        if (!stack->symbols)
        {
            perror("Falha ao realocar memória para pilha de símbolos");
            exit(EXIT_FAILURE);
        }
    }
    stack->top++;
    stack->symbols[stack->top] = strdup(symbol);
    if (!stack->symbols[stack->top])
    {
        perror("Falha ao duplicar string do símbolo");
        exit(EXIT_FAILURE);
    }
}

// Função para desempilhar N símbolos
void pop_symbols(SymbolStack *stack, int count)
{
    if (count <= 0)
        return;
    if (stack->top < count - 1)
    {
        fprintf(stderr, "Erro: Tentativa de desempilhar %d símbolos, mas só existem %d na pilha.\n", count, stack->top + 1);
        // Pode ser um erro no parse_rule_string ou no log
        return;
    }
    for (int i = 0; i < count; i++)
    {
        free(stack->symbols[stack->top]); // Libera a string duplicada
        stack->top--;
    }
}

// Função para formatar a pilha de símbolos para impressão
void format_symbol_stack(SymbolStack *stack, char *buffer, size_t buffer_size)
{
    buffer[0] = '\0';                                        // Limpa o buffer
    strncat(buffer, "$ ", buffer_size - strlen(buffer) - 1); // Adiciona marcador inicial
    for (int i = 0; i <= stack->top; i++)
    {
        const char *symbol_to_print = stack->symbols[i];
        if (strcmp(symbol_to_print, "\"end of file\"") == 0)
        {
            symbol_to_print = "$";
        }
        // Verifica se há espaço antes de concatenar (incluindo o espaço e o NUL)
        if (strlen(buffer) + strlen(symbol_to_print) + 2 < buffer_size)
        {
            strncat(buffer, symbol_to_print, buffer_size - strlen(buffer) - 1);
            strncat(buffer, " ", buffer_size - strlen(buffer) - 1);
        }
        else
        {
            // Se não couber mais, adiciona reticências
            if (strlen(buffer) + 4 < buffer_size)
            {
                strncat(buffer, "...", buffer_size - strlen(buffer) - 1);
            }
            break; // Para de adicionar
        }
    }
    // Remove o último espaço adicionado, se houver e couber
    if (strlen(buffer) > 2 && buffer[strlen(buffer) - 1] == ' ')
    {
        buffer[strlen(buffer) - 1] = '\0';
    }
}

// Função para liberar a memória da pilha de símbolos
void free_symbol_stack(SymbolStack *stack)
{
    if (stack->symbols)
    {
        for (int i = 0; i <= stack->top; i++)
            free(stack->symbols[i]);
        free(stack->symbols);
    }
    *stack = (SymbolStack){NULL, -1, 0}; // Reseta a struct
}

// Função auxiliar para contar símbolos no RHS e pegar o LHS de uma regra
// Retorna o número de símbolos no RHS. Preenche lhs_buffer.
// Função auxiliar para contar símbolos no RHS e pegar o LHS de uma regra
// Retorna o número de símbolos no RHS. Preenche lhs_buffer.
int parse_rule_string(const char *rule_string, char *lhs_buffer, size_t lhs_buffer_size)
{
    lhs_buffer[0] = '\0';
    int rhs_count = 0;

    const char *arrow_pos = strstr(rule_string, "->");
    if (!arrow_pos)
        return -1; // Indica erro de formato

    // Pega o LHS (lado esquerdo)
    const char *lhs_start = rule_string;
    while (lhs_start < arrow_pos && isspace((unsigned char)*lhs_start))
        lhs_start++;
    const char *lhs_end = arrow_pos - 1;
    while (lhs_end > lhs_start && isspace((unsigned char)*lhs_end))
        lhs_end--;
    int lhs_len = lhs_end - lhs_start + 1;
    if (lhs_len > 0 && (size_t)lhs_len < lhs_buffer_size)
    {
        strncpy(lhs_buffer, lhs_start, lhs_len);
        lhs_buffer[lhs_len] = '\0';
    }
    else
    {
        strncpy(lhs_buffer, "ERRO_LHS", lhs_buffer_size - 1); // LHS inválido ou buffer pequeno
        lhs_buffer[lhs_buffer_size - 1] = '\0';
        return -1; // Indica erro
    }

    // Analisa o RHS (lado direito)
    const char *rhs_full_start = arrow_pos + 2; // Pula "->"
    char rhs_trimmed[512];                      // Buffer para a string RHS sem espaços nas pontas

    // Copia e remove espaços do início do RHS
    const char *rhs_content_start = rhs_full_start;
    while (*rhs_content_start && isspace((unsigned char)*rhs_content_start))
        rhs_content_start++;

    // Copia para o buffer de trim
    strncpy(rhs_trimmed, rhs_content_start, sizeof(rhs_trimmed) - 1);
    rhs_trimmed[sizeof(rhs_trimmed) - 1] = '\0';

    // Remove espaços do fim do RHS
    char *rhs_content_end = rhs_trimmed + strlen(rhs_trimmed) - 1;
    while (rhs_content_end >= rhs_trimmed && isspace((unsigned char)*rhs_content_end))
        rhs_content_end--;
    *(rhs_content_end + 1) = '\0';

    // --- CORREÇÃO PRINCIPAL: Checa Epsilon ANTES do strtok ---
    // Checa se o RHS é explicitamente "/* epsilon */" ou completamente vazio
    if (strcmp(rhs_trimmed, "/* epsilon */") == 0 || strlen(rhs_trimmed) == 0)
    {
        return 0; // Regra Epsilon -> 0 símbolos no RHS
    }
    // --- FIM DA CORREÇÃO ---

    // Se não for epsilon, conta os símbolos usando strtok
    char *token;
    // Usa a string já trimada (rhs_trimmed) para strtok
    token = strtok(rhs_trimmed, " \t\n\r");
    while (token != NULL)
    {
        // Ignora marcadores como (%prec ...)
        // Não precisa mais ignorar comentários, pois já tratamos epsilon
        if (strcmp(token, "(%prec") != 0 && strcmp(token, "UMINUS)") != 0)
        {
            rhs_count++;
        }
        token = strtok(NULL, " \t\n\r");
    }

    return rhs_count;
}

//-----------------------------------------------------------------------------
// Função Principal de Impressão da Tabela Sintática
//-----------------------------------------------------------------------------
void print_syntactic_table_from_log(const char *filename)
{
    FILE *file;
    char line[512];
    int reading_token_line = 0;

    // --- Passada 1: Coletar Lookaheads ---
    LookaheadList lookaheads = {NULL, 0, 0};
    file = fopen(filename, "r");
    if (!file)
    {
        perror("Erro ao abrir o arquivo de trace do Bison (Passada 1)");
        return;
    }

    while (fgets(line, sizeof(line), file))
    {
        char *start = line;
        while (isspace((unsigned char)*start))
            start++;
        char *end = start + strlen(start) - 1;
        while (end > start && isspace((unsigned char)*end))
            end--;
        *(end + 1) = 0;
        if (strlen(start) == 0)
            continue;

        if (strcmp(start, "Reading a token") == 0)
        {
            reading_token_line = 1;
        }
        else if (reading_token_line && strncmp(start, "Next token is ", 14) == 0)
        {
            char lookahead_token[100];
            char *token_part = start + 14;
            if (strncmp(token_part, "token ", 6) == 0)
                token_part += 6;
            char *paren = strchr(token_part, '(');
            if (paren)
            {
                char *end_token = paren - 1;
                while (end_token > token_part && isspace((unsigned char)*end_token))
                    end_token--;
                strncpy(lookahead_token, token_part, end_token - token_part + 1);
                lookahead_token[end_token - token_part + 1] = '\0';
            }
            else
                strcpy(lookahead_token, token_part);
            add_lookahead(&lookaheads, lookahead_token);
            reading_token_line = 0;
        }
        else if (strcmp(start, "Now at end of input.") == 0)
        {
            add_lookahead(&lookaheads, "$");
        }
        else
        {
            reading_token_line = 0;
        }
    }
    fclose(file);

    // --- Passada 2: Simular Pilha e Imprimir Tabela ---
    SymbolStack symbol_stack;
    init_symbol_stack(&symbol_stack);

    char current_state_stack_str[512] = "0"; // Começa no estado 0
    int lookahead_idx = 0;
    char formatted_symbol_stack[1024];
    // <<< NOVOS BUFFERS TEMPORÁRIOS PARA ABREVIAÇÃO >>>
    char abbreviated_state_stack[512];
    char abbreviated_symbol_stack[1024];

    // <<< LARGURAS DAS COLUNAS DEFINIDAS AQUI >>>
    const int state_stack_width = 32;
    const int symbol_stack_width = 49;
    const int lookahead_width = 14;
    const int action_width = 80;
    file = fopen(filename, "r");
    if (!file)
    {
        perror("Erro ao abrir o arquivo de trace do Bison (Passada 2)");
        free_lookahead_list(&lookaheads);
        return;
    }

    printf("\n\n");
    printf("╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                                                                              " BOLD MAGENTA "TRACE SINTÁTICO (Shift-Reduce)" RESET "                                                                              ║\n");
    printf("╠══════════════════════════════════╦═══════════════════════════════════════════════════╦════════════════╦══════════════════════════════════════════════════════════════════════════════════╣\n");
    printf("║ " BOLD YELLOW "%-32s" RESET " ║ " BOLD BLUE "%-50s" RESET " ║ " BOLD CYAN "%-14s" RESET " ║ " BOLD GREEN "%-82s" RESET " ║\n", "PILHA (Estados)", "PILHA (Símbolos)", "LOOKAHEAD", "AÇÃO");
    printf("╠══════════════════════════════════╬═══════════════════════════════════════════════════╬════════════════╬══════════════════════════════════════════════════════════════════════════════════╣\n");

    while (fgets(line, sizeof(line), file))
    {
        char *start = line;
        while (isspace((unsigned char)*start))
            start++;
        char *end = start + strlen(start) - 1;
        while (end > start && isspace((unsigned char)*end))
            end--;
        *(end + 1) = 0;
        if (strlen(start) == 0)
            continue;

        // 1. Captura a Pilha de Estados (Guarda)
        if (strncmp(start, "Stack now ", 10) == 0)
        {
            sscanf(start, "Stack now %[^\n]", current_state_stack_str);
        }
        // 2. Captura a Ação SHIFT (Gatilho de Impressão e Ação na Pilha de Símbolos)
        else if (strncmp(start, "Shifting token ", 15) == 0)
        {
            char action_detail[256];
            char shifted_token[100];
            char *token_part = start + 15;
            char *paren = strchr(token_part, '(');
            if (paren)
            {
                char *end_token = paren - 1;
                while (end_token > token_part && isspace((unsigned char)*end_token))
                    end_token--;
                strncpy(shifted_token, token_part, end_token - token_part + 1);
                shifted_token[end_token - token_part + 1] = '\0';
            }
            else
                strcpy(shifted_token, token_part);
            snprintf(action_detail, sizeof(action_detail), "Shift %s", shifted_token);

            const char *display_token = shifted_token;
            if (strcmp(shifted_token, "\"end of file\"") == 0)
            {
                display_token = "$";
            }
            snprintf(action_detail, sizeof(action_detail), "Shift %s", display_token);

            // IMPRIME A LINHA
            format_symbol_stack(&symbol_stack, formatted_symbol_stack, sizeof(formatted_symbol_stack));
            const char* current_lookahead_str = (lookahead_idx < lookaheads.count) ? lookaheads.tokens[lookahead_idx] : "???";

            // <<< ABREVIA AS PILHAS ANTES DE IMPRIMIR >>>
            const char* state_stack_to_print = abbreviate_string(current_state_stack_str, state_stack_width, abbreviated_state_stack, sizeof(abbreviated_state_stack));
            const char* symbol_stack_to_print = abbreviate_string(formatted_symbol_stack, symbol_stack_width, abbreviated_symbol_stack, sizeof(abbreviated_symbol_stack));

            // <<< PRINTF ATUALIZADO COM LARGURAS E STRINGS ABREVIADAS >>>
            printf("║ " YELLOW "%-*s" RESET " ║ " BLUE "%-*s" RESET " ║ " CYAN "%-*s" RESET " ║ " GREEN "%-*s" RESET " ║\n",
                   state_stack_width, state_stack_to_print,
                   symbol_stack_width, symbol_stack_to_print,
                   lookahead_width, current_lookahead_str,
                   action_width, action_detail);

            // ATUALIZA A PILHA DE SÍMBOLOS E LOOKAHEAD
            push_symbol(&symbol_stack, display_token);
            lookahead_idx++;
        }
        // 3. Captura a Ação REDUCE (Gatilho de Impressão e Ação na Pilha de Símbolos)
        else if (strncmp(start, "Reducing stack by rule ", 23) == 0)
        {
            char action_detail[256] = "";
            char rule_string[256] = ""; // Buffer para a string da regra
            char lhs_symbol[100];
            int rhs_count = 0; // <<< VARIÁVEL USADA AQUI (CORREÇÃO 2)
            int rule_num = -1;

            if (sscanf(start, "Reducing stack by rule %d", &rule_num) == 1)
            {
                if (rule_num >= 0 && rule_num < g_bison_rule_count)
                {
                    // Copia a string da regra do array global
                    strncpy(rule_string, g_bison_rule_strings[rule_num], sizeof(rule_string) - 1);
                    rule_string[sizeof(rule_string) - 1] = '\0';

                    rhs_count = parse_rule_string(rule_string, lhs_symbol, sizeof(lhs_symbol));

                    // snprintf mais seguro
                    int max_rule_len = sizeof(action_detail) - strlen("Reduce ()") - 1;
                    if (max_rule_len < 0)
                        max_rule_len = 0;
                    snprintf(action_detail, sizeof(action_detail), "Reduce (%d): %.*s", rule_num, max_rule_len, rule_string);
                }
                else
                {
                    snprintf(action_detail, sizeof(action_detail), "Reduce (Regra %d - Inválida!)", rule_num);
                }
            }
            else
            {
                snprintf(action_detail, sizeof(action_detail), "Reduce (Erro ao ler nº da regra)");
            }

            // IMPRIME A LINHA
            format_symbol_stack(&symbol_stack, formatted_symbol_stack, sizeof(formatted_symbol_stack));
            const char* current_lookahead_str = (lookahead_idx < lookaheads.count) ? lookaheads.tokens[lookahead_idx] : "???";

            // <<< ABREVIA AS PILHAS ANTES DE IMPRIMIR >>>
            const char* state_stack_to_print = abbreviate_string(current_state_stack_str, state_stack_width, abbreviated_state_stack, sizeof(abbreviated_state_stack));
            const char* symbol_stack_to_print = abbreviate_string(formatted_symbol_stack, symbol_stack_width, abbreviated_symbol_stack, sizeof(abbreviated_symbol_stack));

            // <<< PRINTF ATUALIZADO COM LARGURAS E STRINGS ABREVIADAS >>>
            printf("║ " YELLOW "%-*s" RESET " ║ " BLUE "%-*s" RESET " ║ " CYAN "%-*s" RESET " ║ " GREEN "%-*s" RESET " ║\n",
                   state_stack_width, state_stack_to_print,
                   symbol_stack_width, symbol_stack_to_print,
                   lookahead_width, current_lookahead_str,
                   action_width, action_detail);

            // ATUALIZA A PILHA DE SÍMBOLOS
            pop_symbols(&symbol_stack, rhs_count);
            if (strlen(lhs_symbol) > 0 && rule_num != 0) {
                 push_symbol(&symbol_stack, lhs_symbol);
            }
            // NÃO avança o índice do lookahead
        }
        // Ignora outras linhas
    }

    // Imprime o estado final (Aceitação)
    format_symbol_stack(&symbol_stack, formatted_symbol_stack, sizeof(formatted_symbol_stack));
    printf("║ " YELLOW "%-32s" RESET " ║ " BLUE "%-49s" RESET " ║ " CYAN "%-14s" RESET " ║ " GREEN "%-80s" RESET " ║\n", current_state_stack_str, formatted_symbol_stack, "", "(Accept)");

    printf("╚══════════════════════════════════╩═══════════════════════════════════════════════════╩════════════════╩══════════════════════════════════════════════════════════════════════════════════╝\n");

    fclose(file);
    free_lookahead_list(&lookaheads); // Libera a memória alocada
    free_symbol_stack(&symbol_stack); // Libera a memória alocada

} 