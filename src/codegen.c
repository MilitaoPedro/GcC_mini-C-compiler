#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include "codegen.h"

int temp_count = 0;
int label_count = 0;
char *emit_buffer = NULL;
int emit_buffer_len = 0;

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

void emitLabel(const char *label) {
    size_t len = strlen(label);

    // realocar espaço para "label:\n" + '\0'
    emit_buffer = realloc(emit_buffer, emit_buffer_len + len + 3);
    
    memcpy(emit_buffer + emit_buffer_len, label, len);
    emit_buffer_len += len;

    emit_buffer[emit_buffer_len++] = ':';
    emit_buffer[emit_buffer_len++] = '\n';
    emit_buffer[emit_buffer_len] = '\0';
}


void emit(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);

    // Calcula tamanho necessário
    char temp[2048];
    int len = vsnprintf(temp, sizeof(temp), fmt, args);
    va_end(args);

    if (len < 0) return;

    // Realoca buffer
    emit_buffer = realloc(emit_buffer, emit_buffer_len + len + 2);
    memcpy(emit_buffer + emit_buffer_len, temp, len);
    emit_buffer_len += len;

    emit_buffer[emit_buffer_len++] = '\n';
    emit_buffer[emit_buffer_len] = '\0';
}

void emit_flush() {
    printf("%s", emit_buffer);
}