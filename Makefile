SRC=src
LEX=$(SRC)/scanner.l
EXEC=$(SRC)/scanner
TEST=tests/teste.txt

all: clean $(EXEC)
	$(EXEC) $(TEST)

$(EXEC): $(SRC)/lex.yy.c
	gcc -o $(EXEC) $(SRC)/lex.yy.c -lfl

$(SRC)/lex.yy.c: $(LEX)
	flex -o $(SRC)/lex.yy.c $(LEX)

clean:
	rm -f $(SRC)/lex.yy.c $(EXEC)
