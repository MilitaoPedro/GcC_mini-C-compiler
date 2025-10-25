CC = gcc
CFLAGS = -Wall -g

TARGET = src/compilador

LEX_SRC = src/scanner.l
YACC_SRC = src/parser.y
TRACE_SRC = src/trace_printer.c # <<< ARQUIVO FONTE

LEX_GEN_C = src/lex.yy.c
YACC_GEN_C = src/parser.tab.c
TRACE_OBJ = $(TRACE_SRC:.c=.o)   # <<< ARQUIVO OBJETO

YACC_GEN_H = src/parser.tab.h
TRACE_HDR = src/trace_printer.h # <<< HEADER

all: $(TARGET)

# Linkagem final - inclui o novo objeto .o
$(TARGET): $(LEX_GEN_C) $(YACC_GEN_C) $(TRACE_OBJ)
	@echo "Linkando o executável final..."
	$(CC) $(CFLAGS) $(LEX_GEN_C) $(YACC_GEN_C) $(TRACE_OBJ) -o $(TARGET) -lfl
	@echo "Compilador '$(TARGET)' criado com sucesso!"

# Compila trace_printer.c para trace_printer.o
$(TRACE_OBJ): $(TRACE_SRC) $(TRACE_HDR) src/tokens.h
	@echo "Compilando módulo de impressão do trace..."
	$(CC) $(CFLAGS) -c $(TRACE_SRC) -o $(TRACE_OBJ)

# Regra do Bison
$(YACC_GEN_C) $(YACC_GEN_H): $(YACC_SRC) src/tokens.h
	@echo "Gerando o parser com Bison..."
	bison -d -o $(YACC_GEN_C) $(YACC_SRC)

# Regra do Flex
$(LEX_GEN_C): $(LEX_SRC) $(YACC_GEN_H) src/tokens.h
	@echo "Gerando o scanner com Flex..."
	flex -o $(LEX_GEN_C) $(LEX_SRC)

# Limpeza
clean:
	@echo "Limpando arquivos gerados..."
	rm -f $(TARGET) $(LEX_GEN_C) $(YACC_GEN_C) $(YACC_GEN_H) $(TRACE_OBJ) src/debug_trace.log