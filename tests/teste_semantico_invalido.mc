// teste_semantico_erros.mc
int a;
bool a;        // Erro 1: Redeclaração de 'a' no mesmo escopo
x = 10;        // Erro 2: Variável 'x' não declarada
int b = true;  // Erro 3: Inicialização incompatível (int recebe bool)
a = 5;         // Erro 4: Atribuição incompatível (bool recebe int)
b = 1 + true;  // Erro 5: Operação '+' requer inteiros (recebeu bool)
if (10) b = 0; // Erro 6: Condição do 'if' deve ser booleana (recebeu int)