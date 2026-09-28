import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AdicionarGerenteTela extends StatefulWidget {
  const AdicionarGerenteTela({super.key});

  @override
  State<AdicionarGerenteTela> createState() => _AdicionarGerenteTelaState();
}

class _AdicionarGerenteTelaState extends State<AdicionarGerenteTela> {
  static const String categoriasUrl =
      'http://localhost:3000/api/restaurantes/sabor-express/categorias';

  final nomeController = TextEditingController();
  final descricaoController = TextEditingController();
  final precoController = TextEditingController();

  final ImagePicker picker = ImagePicker();

  File? imagem;

  List<Map<String, dynamic>> categorias = [];

  String? categoriaIdSelecionada;

  bool carregandoCategorias = true;

  @override
  void initState() {
    super.initState();
    carregarCategorias();
  }

  // ============================================================
  // CARREGAR CATEGORIAS DO BANCO
  // ============================================================

  Future<void> carregarCategorias() async {
    try {
      final response = await http.get(
        Uri.parse(categoriasUrl),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Erro ao carregar categorias: ${response.statusCode}');
      }

      final dynamic dados = jsonDecode(response.body);

      if (dados is! List) {
        throw Exception('Formato de categorias inválido.');
      }

      final lista = dados
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => item['ativo'] != false)
          .toList();

      if (!mounted) return;

      setState(() {
        categorias = lista;

        if (categorias.isNotEmpty) {
          categoriaIdSelecionada = categorias.first['id'].toString();
        }

        carregandoCategorias = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        carregandoCategorias = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível carregar as categorias: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // ESCOLHER IMAGEM
  // ============================================================

  Future<void> escolherImagem() async {
    final XFile? arquivo = await picker.pickImage(source: ImageSource.gallery);

    if (arquivo != null) {
      setState(() {
        imagem = File(arquivo.path);
      });
    }
  }

  // ============================================================
  // SALVAR
  // ============================================================

  void salvarProduto() {
    final nome = nomeController.text.trim();

    final descricao = descricaoController.text.trim();

    final preco = double.tryParse(
      precoController.text.trim().replaceAll(',', '.'),
    );

    if (nome.isEmpty) {
      _mostrarMensagem('Preencha o nome do produto.');
      return;
    }

    if (preco == null || preco <= 0) {
      _mostrarMensagem('Informe um preço válido.');
      return;
    }

    if (categoriaIdSelecionada == null) {
      _mostrarMensagem('Selecione uma categoria.');
      return;
    }

    final categoriaSelecionada = categorias.firstWhere(
      (item) => item['id'].toString() == categoriaIdSelecionada,
    );

    final produto = <String, dynamic>{
      'nome': nome,
      'descricao': descricao,
      'preco': preco,

      // UUID utilizado pelo backend.
      'categoriaId': categoriaIdSelecionada,

      // Nome utilizado pela interface.
      'categoria': categoriaSelecionada['nome'].toString(),
    };

    Navigator.pop(context, produto);
  }

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    nomeController.dispose();
    descricaoController.dispose();
    precoController.dispose();

    super.dispose();
  }

  // ============================================================
  // TELA
  // ============================================================

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
                      'Adicionar Produto',

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
                                    'Adicionar imagem',

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

                    campo('Nome do produto', Icons.fastfood, nomeController),

                    const SizedBox(height: 20),

                    // ==========================================
                    // CATEGORIA
                    // ==========================================
                    carregandoCategorias
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              color: Colors.green,
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            initialValue: categoriaIdSelecionada,

                            decoration: InputDecoration(
                              labelText: 'Categoria',

                              prefixIcon: const Icon(
                                Icons.category,
                                color: Colors.green,
                              ),

                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),

                            items: categorias.map((categoria) {
                              return DropdownMenuItem<String>(
                                value: categoria['id'].toString(),

                                child: Text(categoria['nome'].toString()),
                              );
                            }).toList(),

                            onChanged: (valor) {
                              setState(() {
                                categoriaIdSelecionada = valor;
                              });
                            },
                          ),

                    const SizedBox(height: 20),

                    campo(
                      'Descrição',
                      Icons.description,
                      descricaoController,
                      linhas: 3,
                    ),

                    const SizedBox(height: 20),

                    campo('Preço', Icons.attach_money, precoController),

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

                        onPressed: carregandoCategorias ? null : salvarProduto,

                        child: const Text(
                          'Salvar Produto',

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

      keyboardType: texto == 'Preço'
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
