#ifndef TRACE_PRINTER_H
#define TRACE_PRINTER_H

#include <stdio.h>

/* Definições de cores ANSI */
#define RESET   "\033[0m"
#define RED     "\033[31m"
#define GREEN   "\033[32m"
#define YELLOW  "\033[33m"
#define BLUE    "\033[34m"
#define MAGENTA "\033[35m"
#define CYAN    "\033[36m"
#define BOLD    "\033[1m"

/* Protótipo da função que imprime a tabela de trace a partir do log */
void print_syntactic_table_from_log(const char* filename);

#endif /* TRACE_PRINTER_H */