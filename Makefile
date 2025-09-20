SRC=src
LEX=$(SRC)/scanner.l
EXEC=$(SRC)/scanner
TEST=tests/Valid_Toy_Test.txt

all: clean $(EXEC)
	$(EXEC) $(TEST)

$(EXEC): $(SRC)/lex.yy.c
	gcc -o src/scanner src/lex.yy.c

$(SRC)/lex.yy.c: $(LEX)
	flex -o $(SRC)/lex.yy.c $(LEX)

clean:
	rm -f $(SRC)/lex.yy.c $(EXEC)
