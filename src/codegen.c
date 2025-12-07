#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include "codegen.h"

/* Definições de Cores (Copiadas para consistência visual) */
#define RESET   "\033[0m"
#define GREEN   "\033[32m"
#define BLUE    "\033[34m"
#define MAGENTA "\033[35m"
#define CYAN    "\033[36m"
#define YELLOW  "\033[33m"
#define BOLD    "\033[1m"

int temp_count = 0;
int label_count = 0;
char *emit_buffer = NULL;
int emit_buffer_len = 0;

/* Função auxiliar para adicionar strings ao buffer global */
void append_to_buffer(const char *str) {
    size_t len = strlen(str);
    emit_buffer = realloc(emit_buffer, emit_buffer_len + len + 1);
    memcpy(emit_buffer + emit_buffer_len, str, len);
    emit_buffer_len += len;
    emit_buffer[emit_buffer_len] = '\0';
}

char* newTemp() {
    char buffer[20];
    sprintf(buffer, "t%d", temp_count++);
    return strdup(buffer);
}

char* newLabel() {
    char buffer[20];
    sprintf(buffer, "L%d", label_count++);
    return strdup(buffer);
}

/* Emite um LABEL.
   Formato visual: Ocupa a coluna da esquerda, destaque em MAGENTA.
*/
void emitLabel(const char *label) {
    char line[256];
    char label_with_colon[50];
    
    // Adiciona ':' ao label para exibição
    snprintf(label_with_colon, sizeof(label_with_colon), "%s:", label);

    // Formata a linha da tabela:
    // Coluna 1 (Labels): 10 espaços
    // Coluna 2 (Código): 65 espaços
    sprintf(line, "║ " BOLD MAGENTA "%-10s" RESET " ║ %-67s ║\n", 
            label_with_colon, 
            ""); // Coluna de código vazia para labels
    
    append_to_buffer(line);
}

/* Emite uma INSTRUÇÃO.
   Formato visual: Coluna da esquerda vazia, instrução na direita.
*/
void emit(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);

    // 1. Formata a instrução crua (ex: "t1 = x + 1")
    char raw_instruction[1024];
    vsnprintf(raw_instruction, sizeof(raw_instruction), fmt, args);
    va_end(args);

    // 2. Formata a linha da tabela com alinhamento
    char line[2048];
    // Coluna 1 vazia, Coluna 2 com a instrução (CYAN ou cor padrão)
    sprintf(line, "║ %-10s ║ " CYAN "%-67s" RESET " ║\n", 
            "", 
            raw_instruction);

    append_to_buffer(line);
}

/* Imprime o buffer acumulado com Cabeçalho e Rodapé de Tabela 
*/
void emit_flush() {
    if (emit_buffer == NULL) return; // Nada para imprimir

    printf("\n");
    // Cabeçalho da Tabela
    printf("╔══════════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                      " BOLD YELLOW "CÓDIGO INTERMEDIÁRIO (IR - 3 ENDEREÇOS)" RESET "                     ║\n");
    printf("╠════════════╦═════════════════════════════════════════════════════════════════════╣\n");
    printf("║   " BOLD BLUE "LABELS" RESET "   ║ " BOLD GREEN "INSTRUÇÕES" RESET "                                                          ║\n");
    printf("╠════════════╬═════════════════════════════════════════════════════════════════════╣\n");

    // Conteúdo (já formatado com as bordas laterais ║)
    printf("%s", emit_buffer);

    // Rodapé da Tabela
    printf("╚════════════╩═════════════════════════════════════════════════════════════════════╝\n");
    printf("\n");

    // Limpeza
    free(emit_buffer);
    emit_buffer = NULL;
    emit_buffer_len = 0;
}