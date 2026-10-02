import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_colors.dart';

class EnderecoTela extends StatefulWidget {
  const EnderecoTela({super.key});

  @override
  State<EnderecoTela> createState() => _EnderecoTelaState();
}

class _EnderecoTelaState extends State<EnderecoTela> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController cepController = TextEditingController();
  final TextEditingController ruaController = TextEditingController();
  final TextEditingController numeroController = TextEditingController();
  final TextEditingController complementoController = TextEditingController();
  final TextEditingController bairroController = TextEditingController();
  final TextEditingController cidadeController = TextEditingController();
  final TextEditingController estadoController = TextEditingController();
  final TextEditingController nomeEnderecoController = TextEditingController();

  bool buscandoCep = false;
  bool salvandoEndereco = false;
  bool cepConfirmado = false;
  bool favorito = false;
  bool argumentosCarregados = false;

  String? erroCep;

  static const String _baseUrl = 'http://localhost:3000/api';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (argumentosCarregados) return;

    argumentosCarregados = true;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map) {
      final endereco = Map<String, dynamic>.from(args);

      cepController.text = endereco['cep']?.toString() ?? '';

      ruaController.text =
          endereco['rua']?.toString() ??
          endereco['logradouro']?.toString() ??
          '';

      numeroController.text = endereco['numero']?.toString() ?? '';

      complementoController.text = endereco['complemento']?.toString() ?? '';

      bairroController.text = endereco['bairro']?.toString() ?? '';
      cidadeController.text = endereco['cidade']?.toString() ?? '';
      estadoController.text = endereco['estado']?.toString() ?? '';

      nomeEnderecoController.text =
          endereco['nomeEndereco']?.toString() ??
          endereco['apelido']?.toString() ??
          '';

      favorito = endereco['favorito'] == true || endereco['principal'] == true;

      if (cepController.text.trim().isNotEmpty) {
        cepConfirmado = true;
      }
    }
  }

  @override
  void dispose() {
    cepController.dispose();
    ruaController.dispose();
    numeroController.dispose();
    complementoController.dispose();
    bairroController.dispose();
    cidadeController.dispose();
    estadoController.dispose();
    nomeEnderecoController.dispose();

    super.dispose();
  }

  // ============================================================
  // TOKEN
  // ============================================================

  Future<String> _buscarToken() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('Sessão não encontrada. Faça login novamente.');
    }

    return token;
  }

  // ============================================================
  // MENSAGEM DE ERRO DA API
  // ============================================================

  String _mensagemErro(http.Response response) {
    try {
      final dados = jsonDecode(response.body);

      if (dados is Map<String, dynamic>) {
        if (dados['erro'] != null) {
          return dados['erro'].toString();
        }

        if (dados['message'] != null) {
          return dados['message'].toString();
        }

        if (dados['mensagem'] != null) {
          return dados['mensagem'].toString();
        }
      }
    } catch (_) {}

    return 'Erro ${response.statusCode}';
  }

  // ============================================================
  // CEP
  // ============================================================

  String _somenteNumeros(String valor) {
    return valor.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _formatarCep(String cep) {
    final numeros = _somenteNumeros(cep);

    if (numeros.length != 8) {
      return cep;
    }

    return '${numeros.substring(0, 5)}-${numeros.substring(5)}';
  }

  void _limparEnderecoAutomatico() {
    ruaController.clear();
    bairroController.clear();
    cidadeController.clear();
    estadoController.clear();
  }

  Future<void> _buscarCep() async {
    final cep = _somenteNumeros(cepController.text);

    if (cep.length != 8) {
      setState(() {
        cepConfirmado = false;
        erroCep = 'Informe um CEP válido.';
        _limparEnderecoAutomatico();
      });

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      buscandoCep = true;
      cepConfirmado = false;
      erroCep = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://viacep.com.br/ws/$cep/json/'),
      );

      if (response.statusCode != 200) {
        throw Exception('Erro ao consultar CEP');
      }

      final dados = jsonDecode(response.body) as Map<String, dynamic>;

      if (dados['erro'] == true) {
        if (!mounted) return;

        setState(() {
          buscandoCep = false;
          cepConfirmado = false;
          erroCep = 'Informe um CEP válido.';
          _limparEnderecoAutomatico();
        });

        return;
      }

      if (!mounted) return;

      setState(() {
        buscandoCep = false;
        cepConfirmado = true;
        erroCep = null;

        cepController.text = _formatarCep(cep);

        ruaController.text = dados['logradouro']?.toString().trim() ?? '';

        bairroController.text = dados['bairro']?.toString().trim() ?? '';

        cidadeController.text = dados['localidade']?.toString().trim() ?? '';

        estadoController.text = dados['uf']?.toString().trim() ?? '';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        buscandoCep = false;
        cepConfirmado = false;

        erroCep =
            'Não foi possível consultar o CEP. '
            'Verifique sua conexão e tente novamente.';
      });
    }
  }

  // ============================================================
  // SALVAR ENDEREÇO NO BACKEND
  // ============================================================

  Future<void> _salvarEndereco() async {
    if (salvandoEndereco) return;

    if (!cepConfirmado) {
      setState(() {
        erroCep = 'Confirme o CEP antes de salvar.';
      });

      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      salvandoEndereco = true;
    });

    try {
      final token = await _buscarToken();

      final body = <String, dynamic>{
        'cep': _formatarCep(cepController.text),
        'logradouro': ruaController.text.trim(),
        'numero': numeroController.text.trim(),
        'bairro': bairroController.text.trim(),
        'cidade': cidadeController.text.trim(),
        'estado': estadoController.text.trim().toUpperCase(),
        'principal': favorito,
      };

      final complemento = complementoController.text.trim();

      if (complemento.isNotEmpty) {
        body['complemento'] = complemento;
      }

      final nomeEndereco = nomeEnderecoController.text.trim();

      if (favorito && nomeEndereco.isNotEmpty) {
        body['apelido'] = nomeEndereco;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/meus/enderecos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 201) {
        throw Exception(
          'Não foi possível salvar o endereço: '
          '${_mensagemErro(response)}',
        );
      }

      final dynamic resposta = jsonDecode(response.body);

      if (resposta is! Map) {
        throw Exception('O servidor retornou um endereço inválido.');
      }

      final enderecoSalvo = Map<String, dynamic>.from(resposta);

      final enderecoId = enderecoSalvo['id']?.toString();

      if (enderecoId == null || enderecoId.isEmpty) {
        throw Exception('O servidor não retornou o identificador do endereço.');
      }

      // Montamos o objeto que a Sacola já consegue utilizar.
      final endereco = <String, dynamic>{
        'id': enderecoId,
        'enderecoId': enderecoId,

        'cep':
            enderecoSalvo['cep']?.toString() ??
            _formatarCep(cepController.text),

        'rua':
            enderecoSalvo['logradouro']?.toString() ??
            ruaController.text.trim(),

        'logradouro':
            enderecoSalvo['logradouro']?.toString() ??
            ruaController.text.trim(),

        'numero':
            enderecoSalvo['numero']?.toString() ?? numeroController.text.trim(),

        'complemento':
            enderecoSalvo['complemento']?.toString() ??
            complementoController.text.trim(),

        'bairro':
            enderecoSalvo['bairro']?.toString() ?? bairroController.text.trim(),

        'cidade':
            enderecoSalvo['cidade']?.toString() ?? cidadeController.text.trim(),

        'estado':
            enderecoSalvo['estado']?.toString() ??
            estadoController.text.trim().toUpperCase(),

        'favorito': enderecoSalvo['principal'] == true,

        'principal': enderecoSalvo['principal'] == true,

        'nomeEndereco':
            enderecoSalvo['apelido']?.toString() ??
            nomeEnderecoController.text.trim(),

        'apelido':
            enderecoSalvo['apelido']?.toString() ??
            nomeEnderecoController.text.trim(),
      };

      if (!mounted) return;

      Navigator.pop(context, endereco);
    } catch (erro) {
      if (!mounted) return;

      var mensagem = erro.toString();

      if (mensagem.startsWith('Exception: ')) {
        mensagem = mensagem.substring('Exception: '.length);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          salvandoEndereco = false;
        });
      }
    }
  }

  // ============================================================
  // CAMPOS
  // ============================================================

  Widget _campo({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool obrigatorio = true,
    TextInputType? keyboardType,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.green),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.green, width: 1.5),
          ),
        ),
        validator: (valor) {
          if (!obrigatorio) {
            return null;
          }

          if (valor == null || valor.trim().isEmpty) {
            return 'Informe $label';
          }

          return null;
        },
      ),
    );
  }

  Widget _campoAutomatico({
    required String label,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.green),
          filled: true,
          fillColor: AppColors.softGreen,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.green.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.green, width: 1.5),
          ),
        ),
        validator: (valor) {
          if (valor == null || valor.trim().isEmpty) {
            return 'Informe $label';
          }

          return null;
        },
      ),
    );
  }

  Widget _campoCep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: cepController,
          keyboardType: TextInputType.number,
          maxLength: 9,
          textInputAction: TextInputAction.search,
          onChanged: (_) {
            if (cepConfirmado || erroCep != null) {
              setState(() {
                cepConfirmado = false;
                erroCep = null;

                _limparEnderecoAutomatico();
              });
            }
          },
          onFieldSubmitted: (_) {
            _buscarCep();
          },
          decoration: InputDecoration(
            labelText: 'CEP',
            hintText: '00000-000',
            counterText: '',
            prefixIcon: const Icon(
              Icons.location_searching,
              color: AppColors.green,
            ),
            suffixIcon: buscandoCep
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.green,
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Buscar CEP',
                    onPressed: _buscarCep,
                    icon: const Icon(Icons.search, color: AppColors.green),
                  ),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.green, width: 1.5),
            ),
          ),
        ),

        if (cepConfirmado)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.green, size: 20),
                SizedBox(width: 8),
                Text(
                  'CEP confirmado',
                  style: TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

        if (erroCep != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    erroCep!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _favorito() {
    return Container(
      decoration: BoxDecoration(
        color: favorito ? AppColors.softGreen : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: favorito ? AppColors.green : Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: favorito,
            activeThumbColor: AppColors.green,
            secondary: Icon(
              favorito ? Icons.star : Icons.star_border,
              color: favorito ? AppColors.green : AppColors.mutedText,
            ),
            title: const Text(
              'Salvar como favorito',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Use este endereço mais rapidamente nos próximos pedidos.',
            ),
            onChanged: salvandoEndereco
                ? null
                : (valor) {
                    setState(() {
                      favorito = valor;

                      if (!favorito) {
                        nomeEnderecoController.clear();
                      }
                    });
                  },
          ),

          if (favorito)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: TextFormField(
                controller: nomeEnderecoController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Nome do endereço',
                  hintText: 'Ex.: Casa, Trabalho',
                  prefixIcon: const Icon(
                    Icons.bookmark_outline,
                    color: AppColors.green,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (valor) {
                  if (!favorito) return null;

                  if (valor == null || valor.trim().isEmpty) {
                    return 'Informe um nome para o endereço';
                  }

                  return null;
                },
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // TELA
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: salvandoEndereco
              ? null
              : () {
                  Navigator.pop(context);
                },
        ),
        title: const Text(
          'Endereço',
          style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800),
        ),
      ),

      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    _EnderecoIcon(),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Onde devemos entregar?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Informe o CEP para localizar seu endereço.',
                            style: TextStyle(
                              color: AppColors.mutedText,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              const Text(
                'Localizar endereço',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),

              const SizedBox(height: 12),

              _campoCep(),

              if (cepConfirmado) ...[
                const SizedBox(height: 26),

                const Text(
                  'Detalhes do endereço',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Confira os dados e complete as informações da entrega.',
                  style: TextStyle(color: AppColors.mutedText),
                ),

                const SizedBox(height: 16),

                _campoAutomatico(
                  label: 'Rua',
                  icon: Icons.route_outlined,
                  controller: ruaController,
                ),

                _campoAutomatico(
                  label: 'Bairro',
                  icon: Icons.location_city_outlined,
                  controller: bairroController,
                ),

                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _campoAutomatico(
                        label: 'Cidade',
                        icon: Icons.apartment_outlined,
                        controller: cidadeController,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      flex: 2,
                      child: _campoAutomatico(
                        label: 'Estado',
                        icon: Icons.map_outlined,
                        controller: estadoController,
                      ),
                    ),
                  ],
                ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _campo(
                        label: 'Número',
                        icon: Icons.numbers,
                        controller: numeroController,
                        keyboardType: TextInputType.number,
                        hint: '123',
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      flex: 3,
                      child: _campo(
                        label: 'Complemento',
                        icon: Icons.home_work_outlined,
                        controller: complementoController,
                        obrigatorio: false,
                        hint: 'Apto, bloco...',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                _favorito(),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: buscandoCep || salvandoEndereco
                        ? null
                        : _salvarEndereco,
                    icon: salvandoEndereco
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      salvandoEndereco ? 'Salvando...' : 'Salvar endereço',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EnderecoIcon extends StatelessWidget {
  const _EnderecoIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.delivery_dining,
        color: AppColors.green,
        size: 28,
      ),
    );
  }
}
