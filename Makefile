# Nome do executável
EXEC=scanner

# Diretórios
SRC=src
TESTS=tests

# Arquivo do Flex
LEX=$(SRC)/scanner.l

# Regras
all: $(EXEC)

$(EXEC): lex.yy.c
	gcc -o $(EXEC) lex.yy.c -ll

lex.yy.c: $(LEX)
	flex $(LEX)

run: $(EXEC)
	./$(EXEC) < $(TESTS)/teste.txt

clean:
	rm -f lex.yy.c $(EXEC)
