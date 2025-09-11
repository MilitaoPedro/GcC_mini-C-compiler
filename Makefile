SRC=src
LEX=$(SRC)/scanner.l
EXEC=$(SRC)/scanner

all: $(EXEC)

$(EXEC): $(SRC)/lex.yy.c
	gcc -o $(EXEC) $(SRC)/lex.yy.c -lfl

$(SRC)/lex.yy.c: $(LEX)
	flex -o $(SRC)/lex.yy.c $(LEX)

run: $(EXEC)
	$(EXEC) ./tests/teste.txt

clean:
	rm -f $(SRC)/lex.yy.c $(EXEC)
