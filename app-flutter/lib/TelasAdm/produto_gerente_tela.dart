import 'package:flutter/material.dart';

class ProdutoGerenteTela extends StatefulWidget {
  final Map<String, dynamic>? produto;

  const ProdutoGerenteTela({super.key, this.produto});

  @override
  State<ProdutoGerenteTela> createState() => _ProdutoGerenteTelaState();
}

class _ProdutoGerenteTelaState extends State<ProdutoGerenteTela> {
  final nomeController = TextEditingController();

  final descricaoController = TextEditingController();

  final precoController = TextEditingController();

  String categoria = "Pizzas";

  bool get editando => widget.produto != null;

  @override
  void initState() {
    super.initState();

    if (widget.produto != null) {
      nomeController.text = widget.produto!["nome"] ?? "";

      descricaoController.text = widget.produto!["descricao"] ?? "";

      precoController.text = widget.produto!["preco"].toString();
    }
  }

  void salvarProduto() {
    if (nomeController.text.isEmpty || precoController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Preencha nome e preço")));

      return;
    }

    final novoProduto = <String, dynamic>{
      "nome": nomeController.text,

      "descricao": descricaoController.text,

      "preco":
          double.tryParse(precoController.text.replaceAll(",", ".")) ?? 0.0,

      "categoria": categoria,
    };

    Navigator.pop(context, novoProduto);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),

              decoration: const BoxDecoration(
                color: Colors.green,

                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),

                  bottomRight: Radius.circular(30),
                ),
              ),

              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,

                      color: Colors.white,
                    ),

                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),

                  Expanded(
                    child: Text(
                      editando ? "Editar Produto" : "Adicionar Produto",

                      textAlign: TextAlign.center,

                      style: const TextStyle(
                        color: Colors.white,

                        fontSize: 25,

                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: 45),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),

                child: Column(
                  children: [
                    campo("Nome do produto", Icons.fastfood, nomeController),

                    const SizedBox(height: 20),

                    DropdownButtonFormField<String>(
                      initialValue: categoria,

                      decoration: InputDecoration(
                        labelText: "Categoria",

                        prefixIcon: const Icon(
                          Icons.category,

                          color: Colors.green,
                        ),

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),

                      items: const [
                        DropdownMenuItem(
                          value: "Pizzas",

                          child: Text("Pizzas"),
                        ),

                        DropdownMenuItem(
                          value: "Lanches",

                          child: Text("Lanches"),
                        ),

                        DropdownMenuItem(
                          value: "Bebidas",

                          child: Text("Bebidas"),
                        ),

                        DropdownMenuItem(
                          value: "Sobremesas",

                          child: Text("Sobremesas"),
                        ),
                      ],

                      onChanged: (valor) {
                        setState(() {
                          categoria = valor!;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    campo(
                      "Descrição",

                      Icons.description,

                      descricaoController,

                      linhas: 3,
                    ),

                    const SizedBox(height: 20),

                    campo("Preço", Icons.attach_money, precoController),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,

                      height: 55,

                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,

                          foregroundColor: Colors.white,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),

                        onPressed: salvarProduto,

                        child: Text(
                          editando ? "Atualizar Produto" : "Adicionar Produto",

                          style: const TextStyle(
                            fontSize: 18,

                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget campo(
    String texto,

    IconData icone,

    TextEditingController controller, {

    int linhas = 1,
  }) {
    return TextField(
      controller: controller,

      maxLines: linhas,

      decoration: InputDecoration(
        labelText: texto,

        prefixIcon: Icon(icone, color: Colors.green),

        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
