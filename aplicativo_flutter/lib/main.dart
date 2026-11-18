import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://127.0.0.1:8080',
);

typedef Veiculo = Map<String, dynamic>;

const tinta = Color(0xFF142B3A);
const verde = Color(0xFF0F9B8E);
const fundo = Color(0xFFF3F6F5);
const textoEscuro = Color(0xFF1E3039);

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: verde,
        primary: verde,
        secondary: tinta,
        surface: Colors.white,
        error: const Color(0xFFB54747),
      ),
      scaffoldBackgroundColor: fundo,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: tinta,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: tinta,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        titleLarge: TextStyle(
          color: tinta,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(color: textoEscuro, fontSize: 14),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7F9F8),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E8E5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E8E5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: verde, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tinta,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE6ECE9)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    home: const Catalogo(),
  ),
);

class Catalogo extends StatefulWidget {
  const Catalogo({super.key});
  @override
  State<Catalogo> createState() => _CatalogoState();
}

class _CatalogoState extends State<Catalogo> {
  final usuario = TextEditingController(text: 'aluno');
  final senha = TextEditingController();
  String? token;
  List<Veiculo> veiculos = [];
  bool ocupado = false;
  String erro = '';

  @override
  void dispose() {
    usuario.dispose();
    senha.dispose();
    super.dispose();
  }

  Future<Object?> solicitar(
    String metodo,
    String caminho,
    int status, {
    Veiculo? dados,
  }) async {
    final pedido = http.Request(metodo, Uri.parse('$apiUrl$caminho'));
    if (token != null) pedido.headers['Authorization'] = 'Bearer $token';
    if (dados != null) {
      pedido.headers['Content-Type'] = 'application/json; charset=utf-8';
      pedido.body = jsonEncode(dados);
    }
    final resposta = await pedido
        .send()
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 10));
    final texto = utf8.decode(resposta.bodyBytes);
    final json = texto.isEmpty ? null : jsonDecode(texto);
    if (resposta.statusCode != status) {
      if (resposta.statusCode == 401 && caminho != '/login') {
        token = null;
        veiculos = [];
      }
      throw Exception(
        json is Map ? json['erro'] : 'HTTP ${resposta.statusCode}',
      );
    }
    return json;
  }

  Future<void> executar(Future<void> Function() operacao) async {
    if (ocupado) return;
    setState(() {
      ocupado = true;
      erro = '';
    });
    try {
      await operacao();
    } catch (falha) {
      erro = falha.toString();
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> entrar() => executar(() async {
    final login = await solicitar(
      'POST',
      '/login',
      200,
      dados: {'usuario': usuario.text.trim(), 'senha': senha.text},
    ) as Veiculo;
    if (!mounted) return;
    token = login['access_token'] as String;
    senha.clear();
    await listar();
  });

  Future<void> listar() async {
    final lista = await solicitar('GET', '/veiculos', 200) as List;
    veiculos = lista.cast<Veiculo>();
  }

  Future<void> editar([Veiculo? original]) async {
    final dados = await showDialog<Veiculo>(
      context: context,
      builder: (_) => FormularioVeiculo(original: original),
    );
    if (!mounted || dados == null) return;
    await executar(() async {
      if (original == null) {
        await solicitar('POST', '/veiculos', 201, dados: dados);
      } else {
        await solicitar(
          'PUT',
          '/veiculos/${original['id']}',
          204,
          dados: dados,
        );
      }
      await listar();
    });
  }

  Future<void> excluir(Veiculo veiculo) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: Color(0xFFB54747)),
        title: const Text('Excluir veículo?'),
        content: Text(
          '${veiculo['marca']} ${veiculo['modelo']}',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (!mounted || confirmou != true) return;
    await executar(() async {
      await solicitar('DELETE', '/veiculos/${veiculo['id']}', 204);
      await listar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tinta,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.directions_car_filled_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GARAGEM',
                  style: TextStyle(
                    color: tinta,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'CATÁLOGO DE VEÍCULOS',
                  style: TextStyle(
                    color: Color(0xFF72817E),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (token != null)
            IconButton(
              tooltip: 'Atualizar catálogo',
              onPressed: ocupado ? null : () => executar(listar),
              icon: const Icon(Icons.refresh_rounded),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          if (ocupado) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final largura = constraints.maxWidth;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: token == null
                        ? _telaLogin(largura)
                        : _telaCatalogo(largura),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _telaLogin(double largura) {
    final painel = _painelBoasVindas(compacto: largura < 700);
    final formulario = _cartaoLogin();
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: largura < 600 ? 20 : 32,
        vertical: 32,
      ),
      child: largura >= 760
          ? Row(
              children: [
                Expanded(flex: 11, child: painel),
                const SizedBox(width: 28),
                Expanded(flex: 9, child: formulario),
              ],
            )
          : Column(
              children: [
                painel,
                const SizedBox(height: 20),
                formulario,
              ],
            ),
    );
  }

  Widget _painelBoasVindas({required bool compacto}) {
    return Container(
      constraints: BoxConstraints(minHeight: compacto ? 220 : 420),
      padding: EdgeInsets.all(compacto ? 25 : 38),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF19394A), tinta],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            bottom: -30,
            child: Icon(
              Icons.directions_car_filled_rounded,
              size: compacto ? 120 : 190,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: verde.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'GESTÃO SIMPLES, VISÃO COMPLETA',
                  style: TextStyle(
                    color: Color(0xFF77E0D3),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Sua garagem,\nem um só lugar.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compacto ? 29 : 38,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Acesse seu catálogo e mantenha cada veículo organizado.',
                style: TextStyle(
                  color: Color(0xFFC3D1D4),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cartaoLogin() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bem-vindo de volta',
              style: TextStyle(
                color: tinta,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Entre com seus dados para continuar.',
              style: TextStyle(color: Color(0xFF72817E), fontSize: 14),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: usuario,
              decoration: const InputDecoration(
                labelText: 'Usuário',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: senha,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            if (erro.isNotEmpty) ...[
              const SizedBox(height: 16),
              _avisoErro(),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: ocupado ? null : entrar,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Entrar no catálogo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _telaCatalogo(double largura) {
    final colunas = largura >= 980 ? 3 : largura >= 640 ? 2 : 1;
    return ListView(
      padding: EdgeInsets.fromLTRB(largura < 600 ? 20 : 32, 30, largura < 600 ? 20 : 32, 40),
      children: [
        Container(
          padding: EdgeInsets.all(largura < 600 ? 22 : 32),
          decoration: BoxDecoration(
            color: tinta,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 20,
            spacing: 20,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 510),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SEU ESPAÇO DE MOBILIDADE',
                      style: TextStyle(
                        color: Color(0xFF77E0D3),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Sua coleção em movimento.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${veiculos.length} ${veiculos.length == 1 ? 'veículo cadastrado' : 'veículos cadastrados'}',
                      style: const TextStyle(
                        color: Color(0xFFC3D1D4),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: ocupado ? null : () => editar(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar veículo'),
                style: FilledButton.styleFrom(
                  backgroundColor: verde,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        if (erro.isNotEmpty) ...[
          const SizedBox(height: 18),
          _avisoErro(),
        ],
        const SizedBox(height: 30),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Veículos',
                style: TextStyle(
                  color: tinta,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            Text(
              veiculos.length.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: Color(0xFF72817E),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (veiculos.isEmpty && !ocupado && erro.isEmpty)
          _estadoVazio()
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: veiculos.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: colunas,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 192,
            ),
            itemBuilder: (context, index) => _cartaoVeiculo(veiculos[index]),
          ),
      ],
    );
  }

  Widget _cartaoVeiculo(Veiculo veiculo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5F2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.directions_car_filled_rounded,
                    color: verde,
                    size: 23,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Editar',
                  onPressed: ocupado ? null : () => editar(veiculo),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: tinta,
                    backgroundColor: const Color(0xFFF3F6F5),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Excluir',
                  onPressed: ocupado ? null : () => excluir(veiculo),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFFB54747),
                    backgroundColor: const Color(0xFFFBF0EF),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${veiculo['marca']} ${veiculo['modelo']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: tinta,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6F5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'ANO ${veiculo['ano']}',
                style: const TextStyle(
                  color: Color(0xFF61716E),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _estadoVazio() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5F2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.directions_car_outlined,
                color: verde,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sua garagem está pronta',
              style: TextStyle(
                color: tinta,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Adicione o primeiro veículo para começar seu catálogo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF72817E), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avisoErro() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF0EF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1D8D5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB54747)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              erro,
              style: const TextStyle(color: Color(0xFF8F3939), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class FormularioVeiculo extends StatefulWidget {
  const FormularioVeiculo({super.key, this.original});
  final Veiculo? original;
  @override
  State<FormularioVeiculo> createState() => _FormularioVeiculoState();
}

class _FormularioVeiculoState extends State<FormularioVeiculo> {
  final form = GlobalKey<FormState>();
  late final marca = TextEditingController(
    text: widget.original?['marca'] as String?,
  );
  late final modelo = TextEditingController(
    text: widget.original?['modelo'] as String?,
  );
  late final ano = TextEditingController(
    text: widget.original?['ano']?.toString(),
  );

  @override
  void dispose() {
    marca.dispose();
    modelo.dispose();
    ano.dispose();
    super.dispose();
  }

  String? obrigatorio(String? valor) =>
      (valor ?? '').trim().isEmpty ? 'Preencha este campo.' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5F2),
          borderRadius: BorderRadius.circular(17),
        ),
        child: const Icon(
          Icons.directions_car_filled_rounded,
          color: verde,
        ),
      ),
      title: Text(
        widget.original == null ? 'Novo veículo' : 'Editar veículo',
        textAlign: TextAlign.center,
      ),
      content: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: marca,
                validator: obrigatorio,
                decoration: const InputDecoration(
                  labelText: 'Marca',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: modelo,
                validator: obrigatorio,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  prefixIcon: Icon(Icons.drive_file_rename_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: ano,
                keyboardType: TextInputType.number,
                validator: (valor) =>
                    (int.tryParse(valor?.trim() ?? '') ?? 0) > 0
                    ? null
                    : 'Informe um ano inteiro positivo.',
                decoration: const InputDecoration(
                  labelText: 'Ano',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!form.currentState!.validate()) return;
            Navigator.pop<Veiculo>(context, {
              'marca': marca.text.trim(),
              'modelo': modelo.text.trim(),
              'ano': int.parse(ano.text.trim()),
            });
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}