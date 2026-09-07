import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AdicionarGerenteTela extends StatefulWidget {
  const AdicionarGerenteTela({super.key});

  @override
  State<AdicionarGerenteTela> createState() => _AdicionarGerenteTelaState();
}

class _AdicionarGerenteTelaState extends State<AdicionarGerenteTela> {
  final nomeController = TextEditingController();

  final descricaoController = TextEditingController();

  final precoController = TextEditingController();

  File? imagem;

  String categoria = "Pizzas";

  final ImagePicker picker = ImagePicker();

  Future<void> escolherImagem() async {
    final XFile? arquivo = await picker.pickImage(source: ImageSource.gallery);

    if (arquivo != null) {
      setState(() {
        imagem = File(arquivo.path);
      });
    }
  }

  void salvarProduto() {
    if (nomeController.text.isEmpty || precoController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Preencha nome e preço")));

      return;
    }

    final produto = {
      "nome": nomeController.text,

      "descricao": descricaoController.text,

      "preco":
          double.tryParse(precoController.text.replaceAll(",", ".")) ?? 0.0,

      "categoria": categoria,

      "imagem": imagem?.path,
    };

    Navigator.pop(context, produto);
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

                  const Expanded(
                    child: Text(
                      "Adicionar Produto",

                      textAlign: TextAlign.center,

                      style: TextStyle(
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
                    GestureDetector(
                      onTap: escolherImagem,

                      child: Container(
                        height: 150,

                        width: double.infinity,

                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,

                          borderRadius: BorderRadius.circular(20),

                          border: Border.all(color: Colors.green, width: 2),
                        ),

                        child: imagem == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,

                                children: [
                                  Icon(
                                    Icons.add_a_photo,

                                    size: 45,

                                    color: Colors.green,
                                  ),

                                  SizedBox(height: 10),

                                  Text(
                                    "Adicionar imagem",

                                    style: TextStyle(
                                      color: Colors.green,

                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(18),

                                child: Image.file(
                                  imagem!,

                                  fit: BoxFit.cover,

                                  width: double.infinity,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 25),

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

                        child: const Text(
                          "Salvar Produto",

                          style: TextStyle(
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
