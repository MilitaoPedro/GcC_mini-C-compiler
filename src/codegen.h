#ifndef CODEGEN_H
#define CODEGEN_H

// Gera um novo temporário (ex: "t1", "t2")
char* newTemp();

// Gera um novo label (ex: "L1", "L2")
char* newLabel();

// Emite uma instrução de 3 endereços
void emit(const char *fmt, ...);

// Emite um label
void emitLabel(const char *label);

#endif