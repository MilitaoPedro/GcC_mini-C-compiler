CC = gcc
CFLAGS = -Wall -g # -g adiciona símbolos de debug, -Wall mostra todos os warnings

# Nome do executável final
TARGET = src/compilador

# Nossos arquivos-fonte .l e .y
LEX_SRC = src/scanner.l
YACC_SRC = src/parser.y

# Arquivos C gerados pelo Flex e Bison
LEX_GEN_C = src/lex.yy.c
YACC_GEN_C = src/parser.tab.c

# Header gerado pelo Bison (com a flag -d)
YACC_GEN_H = src/parser.tab.h

# Objetos compilados (não precisamos, mas é boa prática)
# OBJS = $(LEX_GEN_C:.c=.o) $(YACC_GEN_C:.c=.o)

all: $(TARGET)

# Regra para criar o executável final
$(TARGET): $(LEX_GEN_C) $(YACC_GEN_C)
	@echo "Linkando o executável final..."
	$(CC) $(CFLAGS) $(LEX_GEN_C) $(YACC_GEN_C) -o $(TARGET) -lfl
	@echo "Compilador '$(TARGET)' criado com sucesso!"

# Regra para gerar o parser (Bison)
# O parser DEVE ser gerado primeiro, pois ele cria o .h
$(YACC_GEN_C) $(YACC_GEN_H): $(YACC_SRC)
	@echo "Gerando o parser com Bison..."
	bison -d -o $(YACC_GEN_C) $(YACC_SRC)

# Regra para gerar o scanner (Flex)
# Note que ele DEPENDE do header gerado pelo Bison
$(LEX_GEN_C): $(LEX_SRC) $(YACC_GEN_H)
	@echo "Gerando o scanner com Flex..."
	flex -o $(LEX_GEN_C) $(LEX_SRC)

# Regra para limpar os arquivos gerados
clean:
	@echo "Limpando arquivos gerados..."
	rm -f $(TARGET) $(LEX_GEN_C) $(YACC_GEN_C) $(YACC_GEN_H)