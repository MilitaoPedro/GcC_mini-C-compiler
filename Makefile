CC = gcc
CFLAGS = -Wall -g # -g adiciona símbolos de debug, -Wall mostra todos os warnings

# Nome do executável final
TARGET = src/compilador

# Nossos arquivos-fonte .l e .y
LEX_SRC = src/scanner.l
YACC_SRC = src/parser.y

# --- Arquivos Gerados ---
LEX_GEN_C = src/lex.yy.c
YACC_GEN_C = src/parser.tab.c
YACC_GEN_H = src/parser.tab.h
YACC_GEN_DOT = src/automato.dot
YACC_OUTPUT = src/parser.output # Arquivo de log do Bison

# --- Target de Imagem Vetorial (SVG) ---
SVG_TARGET = src/automato.svg

# --- Flags de Otimização do Graphviz ---
# -G<attr>=<val> : Adiciona um Atributo de Grafo
# overlap=scale   : Redimensiona o gráfico para evitar sobreposição de nós (ESSENCIAL)
# ranksep=1.5     : Aumenta a distância vertical entre "camadas" de nós
# nodesep=0.5     : Aumenta a distância horizontal mínima entre nós
# splines=true    : Usa linhas curvas (pode ser 'ortho' para linhas retas)
GRAPHVIZ_FLAGS = -Goverlap=scale -Granksep=1.5 -Gnodesep=0.5 -Gsplines=true

# Target padrão: construir o compilador E a imagem
all: $(TARGET) $(SVG_TARGET)

# Regra para criar o executável final
$(TARGET): $(LEX_GEN_C) $(YACC_GEN_C)
	@echo "Linkando o executável final..."
	$(CC) $(CFLAGS) $(LEX_GEN_C) $(YACC_GEN_C) -o $(TARGET) -lfl
	@echo "Compilador '$(TARGET)' criado com sucesso!"

# Regra para gerar o parser (Bison)
$(YACC_GEN_C) $(YACC_GEN_H) $(YACC_GEN_DOT) $(YACC_OUTPUT): $(YACC_SRC)
	@echo "Gerando o parser com Bison (e o automato.dot)..."
	bison -d -v --graph=$(YACC_GEN_DOT) -o $(YACC_GEN_C) $(YACC_SRC)

# Regra para gerar o scanner (Flex)
$(LEX_GEN_C): $(LEX_SRC) $(YACC_GEN_H)
	@echo "Gerando o scanner com Flex..."
	flex -o $(LEX_GEN_C) $(LEX_SRC)

# Regra para gerar o SVG (com otimizações)
$(SVG_TARGET): $(YACC_GEN_DOT)
	@echo "Gerando a imagem vetorial do automato ($(SVG_TARGET))..."
	dot -Tsvg $(GRAPHVIZ_FLAGS) $(YACC_GEN_DOT) -o $(SVG_TARGET)
	@echo "Imagem '$(SVG_TARGET)' gerada. Abra-a em um navegador para dar zoom."

# Regra para limpar os arquivos gerados
clean:
	@echo "Limpando arquivos gerados..."
	rm -f $(TARGET) $(LEX_GEN_C) $(YACC_GEN_C) $(YACC_GEN_H) $(YACC_GEN_DOT) $(SVG_TARGET) $(YACC_OUTPUT)