import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  final ImagePicker picker = ImagePicker();

  String categoria = "Pizzas";
  Uint8List? imagemBytes;
  String? imagemNome;
  String? imagemAtualUrl;

  bool get editando => widget.produto != null;

  final categorias = ["Pizzas", "Lanches", "Massas", "Bebidas", "Sobremesas"];

  @override
  void initState() {
    super.initState();

    if (widget.produto != null) {
      nomeController.text = widget.produto!["nome"]?.toString() ?? "";
      descricaoController.text = widget.produto!["descricao"]?.toString() ?? "";
      precoController.text = widget.produto!["preco"]?.toString() ?? "";

      final categoriaRecebida = widget.produto!["categoria"]?.toString();
      if (categoriaRecebida != null && categorias.contains(categoriaRecebida)) {
        categoria = categoriaRecebida;
      }

      final imagem =
          widget.produto!["imagemUrl"] ??
          widget.produto!["imagem_url"] ??
          widget.produto!["imagem"];

      if (imagem != null) {
        final valor = imagem.toString().trim();
        if (valor.startsWith("http://") || valor.startsWith("https://")) {
          imagemAtualUrl = valor;
        }
      }
    }
  }

  Future<void> escolherImagem() async {
    try {
      final XFile? arquivo = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (arquivo == null) return;

      final bytes = await arquivo.readAsBytes();

      if (!mounted) return;

      setState(() {
        imagemBytes = bytes;
        imagemNome = arquivo.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Não foi possível carregar a imagem: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void salvarProduto() {
    final nome = nomeController.text.trim();
    final descricao = descricaoController.text.trim();
    final preco = double.tryParse(
      precoController.text.trim().replaceAll(",", "."),
    );

    if (nome.isEmpty || preco == null || preco <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha nome e preço corretamente")),
      );
      return;
    }

    final novoProduto = <String, dynamic>{
      "nome": nome,
      "descricao": descricao,
      "preco": preco,
      "categoria": categoria,
      if (widget.produto?["categoriaId"] != null)
        "categoriaId": widget.produto!["categoriaId"],
      if (imagemAtualUrl != null) "imagem": imagemAtualUrl,
      if (imagemBytes != null) "imagemBytes": imagemBytes,
      if (imagemNome != null) "imagemNome": imagemNome,
    };

    Navigator.pop(context, novoProduto);
  }

  Widget _imagem() {
    if (imagemBytes != null) {
      return Image.memory(
        imagemBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 160,
        gaplessPlayback: true,
      );
    }

    if (imagemAtualUrl != null) {
      return Image.network(
        imagemAtualUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 160,
        errorBuilder: (_, __, ___) => _placeholderImagem(),
      );
    }

    return _placeholderImagem();
  }

  Widget _placeholderImagem() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo, size: 45, color: Colors.green),
        SizedBox(height: 10),
        Text(
          "Adicionar imagem",
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  void dispose() {
    nomeController.dispose();
    descricaoController.dispose();
    precoController.dispose();
    super.dispose();
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
                    onPressed: () => Navigator.pop(context),
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
                    GestureDetector(
                      onTap: escolherImagem,
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green, width: 2),
                        ),
                        child: _imagem(),
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
                      items: categorias
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (valor) {
                        if (valor != null) {
                          setState(() => categoria = valor);
                        }
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
      keyboardType: texto == "Preço"
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: texto,
        prefixIcon: Icon(icone, color: Colors.green),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
