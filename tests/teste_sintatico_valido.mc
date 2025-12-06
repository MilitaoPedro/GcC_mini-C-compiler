// Testa as regras essenciais de forma mínima.

int x = (3 + 2 * -3 / 4 % 3);
bool y = false;
x = !false;

read(x);       // Testa read
y = true;      // Testa assignment bool

if (x) {
    int b;       // Testa if (block)
    print(x);  // Testa print
    while(y){   // Testa while (block) aninhado
        y = false; // Testa assignment bool, while corpo unico (matched_statement)
        int j = 2;
    }
    int b; 
} else         // Testa else
    int c;     // Testa assignment int (matched_statement)

if(true) if(false) int w=1; else x=2; // Testa dangling else com statement unico

// Fim