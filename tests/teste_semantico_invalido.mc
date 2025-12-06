// teste_semantico_erros.mc
int a;
bool a;        // Erro 1: Redeclaração de 'a' no mesmo escopo
x = 10;        // Erro 2: Variável 'x' não declarada
int b = true;  // Erro 3: Inicialização incompatível (int recebe bool)
b = 1 + true;  // Erro 4: Operação '+' requer inteiros (recebeu bool)
if (10) b = 0; // Erro 5: Condição do 'if' deve ser booleana (recebeu int)

int x = 2, y = a, z = (3*4+6);