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

# Arquivo .dot gerado pelo Bison (com a flag --graph)
YACC_GEN_DOT = src/automato.dot

# Imagem SVG final gerada pelo Graphviz
SVG_TARGET = src/automato.svg


# 'all' é o target padrão (o que 'make' executa)
# Agora ele constrói o compilador E a imagem do autômato
all: $(TARGET) $(SVG_TARGET)

# Regra para criar o executável final
$(TARGET): $(LEX_GEN_C) $(YACC_GEN_C)
	@echo "Linkando o executável final..."
	$(CC) $(CFLAGS) $(LEX_GEN_C) $(YACC_GEN_C) -o $(TARGET) -lfl
	@echo "Compilador '$(TARGET)' criado com sucesso!"

# Regra para gerar o parser (Bison)
# O parser DEVE ser gerado primeiro, pois ele cria o .h
# Adicionamos $(YACC_GEN_DOT) como um "target" oficial desta regra
$(YACC_GEN_C) $(YACC_GEN_H) $(YACC_GEN_DOT): $(YACC_SRC)
	@echo "Gerando o parser com Bison (e o automato.dot)..."
	# -v gera o .output, --graph gera o .dot
	bison -d -v --graph=$(YACC_GEN_DOT) -o $(YACC_GEN_C) $(YACC_SRC)

# Regra para gerar o scanner (Flex)
# Note que ele DEPENDE do header gerado pelo Bison
$(LEX_GEN_C): $(LEX_SRC) $(YACC_GEN_H)
	@echo "Gerando o scanner com Flex..."
	flex -o $(LEX_GEN_C) $(LEX_SRC)

# --- NOVA REGRA ---
# Regra para gerar o .svg a partir do .dot
# Esta regra DEPENDE do .dot gerado pelo Bison
$(SVG_TARGET): $(YACC_GEN_DOT)
	@echo "Gerando a imagem do automato ($(SVG_TARGET)) com Graphviz..."
	dot -Tsvg $(YACC_GEN_DOT) -o $(SVG_TARGET)

# Regra para limpar os arquivos gerados
# Adicionamos os novos arquivos .dot e .svg
clean:
	@echo "Limpando arquivos gerados..."
	rm -f $(TARGET) $(LEX_GEN_C) $(YACC_GEN_C) $(YACC_GEN_H) $(YACC_GEN_DOT) $(SVG_TARGET) src/parser.output