// Testa vários erros sintáticos e recuperação de forma mínima.

int a b = 5;        // Erro 1 (esperado ',' ou ';', encontrou 'b')

read(a+);           // Erro 2 (esperado ')', encontrou '+')

if (a > ) print(a;  // Erro 3 (esperado expr após '>')

while (true {       // Erro 4 (inesperado '{')
    a = ;           // Recuperção
    } else          // Erro 5 (inesperado '}')
    b = 1           

int z               // Não houve recuperação pois não encontrou ',' nem '}'

