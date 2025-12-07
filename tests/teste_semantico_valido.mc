// teste_semantico_valido.mc
// Testa: Tipos, Escopos (Shadowing), Aritmética, Lógica, Relacional e Fluxo.

int g;          // Declaração Global
bool b;

int x = 10; // Inicialização INT

// Testa: Aritmética (+, *, -, /) e Menos Unário
x = x + 5 * -2 / 1; 

// Testa: Relacional (>, <, ==) retornando BOOL
b = x > 0 == true;

// Testa: Lógica (&&, ||, !) e Controle de Fluxo (IF requer BOOL)
if (!b || x != 10) {
    
    // Testa: Shadowing (Redeclaração legal em novo escopo)
    bool x = false; 
    
    // Testa: Controle de Fluxo (WHILE requer BOOL)
    while (x == false) {
        print(g);   // Acesso a global dentro de escopo aninhado
        read(g);
        x = true;   // Atribuição na variável local (bool)
    }
}

print(y);