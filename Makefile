CC = gcc
CFLAGS = -Wall -g # -g adiciona símbolos de debug, -Wall mostra todos os warnings

# Nome do executável final
TARGET = src/compilador

# Nossos arquivos-fonte .l e .y
LEX_SRC = src/scanner.l
YACC_SRC = src/parser.y

# Arquivos fonte C auxiliares (codegen, tabela de simbolos se estiver separada, etc)
C_SRCS = src/codegen.c 

# --- Arquivos Gerados ---
LEX_GEN_C = src/lex.yy.c
YACC_GEN_C = src/parser.tab.c
YACC_GEN_H = src/parser.tab.h
YACC_GEN_DOT = src/automato.dot   # Bison ainda gera o .dot
YACC_OUTPUT = src/parser.output # Arquivo de log/conflitos do Bison

# --- Target de Imagem Vetorial (SVG) ---
SVG_TARGET = src/automato.svg

# --- Flags de Otimização do Graphviz ---
GRAPHVIZ_FLAGS = -Goverlap=scale -Granksep=1.5 -Gnodesep=0.5 -Gsplines=true

# Target padrão: construir APENAS o compilador
all: $(TARGET)

# Regra para criar o executável final
$(TARGET): $(LEX_GEN_C) $(YACC_GEN_C) $(C_SRCS)
	@echo "Linkando o executável final..."
	$(CC) $(CFLAGS) $(LEX_GEN_C) $(YACC_GEN_C) $(C_SRCS) -o $(TARGET)
	@echo "Compilador '$(TARGET)' criado com sucesso!"

# Regra para gerar o parser (Bison) - Ainda gera o .dot e .output
$(YACC_GEN_C) $(YACC_GEN_H) $(YACC_GEN_DOT) $(YACC_OUTPUT): $(YACC_SRC)
	@echo "Gerando o parser com Bison (e arquivos .dot/.output)..."
	bison -d -v --graph=$(YACC_GEN_DOT) -Wcounterexamples -o $(YACC_GEN_C) $(YACC_SRC)

# Regra para gerar o scanner (Flex)
$(LEX_GEN_C): $(LEX_SRC) $(YACC_GEN_H)
	@echo "Gerando o scanner com Flex..."
	flex -o $(LEX_GEN_C) $(LEX_SRC)

# --- NOVA REGRA: Target específico para gerar o gráfico ---
graph: $(SVG_TARGET)

# Regra para gerar o SVG a partir do .dot (só executada com 'make graph')
$(SVG_TARGET): $(YACC_GEN_DOT)
	@echo "Gerando a imagem vetorial do automato ($(SVG_TARGET))..."
	dot -Tsvg $(GRAPHVIZ_FLAGS) $(YACC_GEN_DOT) -o $(SVG_TARGET)
	@echo "Imagem '$(SVG_TARGET)' gerada. Abra-a em um navegador para dar zoom."

# Regra para limpar os arquivos gerados (mantém a limpeza do .svg)
clean:
	@echo "Limpando arquivos gerados..."
	rm -f $(TARGET) $(LEX_GEN_C) $(YACC_GEN_C) $(YACC_GEN_H) $(YACC_GEN_DOT) $(YACC_OUTPUT)