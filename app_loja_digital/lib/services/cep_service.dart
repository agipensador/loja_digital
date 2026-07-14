import 'dart:convert';

import 'package:app_loja_digital/models/address.dart';
import 'package:http/http.dart' as http;

class CepAbertoException implements Exception {
  CepAbertoException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Busca endereço a partir do CEP usando a API pública do ViaCEP.
class CepService {
  Future<Address> getAddressFromCep(String cep) async {
    final cleanCep = cep.replaceAll(RegExp(r'\D'), '');

    if (cleanCep.length != 8) {
      throw CepAbertoException('CEP inválido');
    }

    final uri = Uri.parse('https://viacep.com.br/ws/$cleanCep/json/');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw CepAbertoException('Falha ao consultar CEP');
    }

    final Map<String, dynamic> data =
        json.decode(response.body) as Map<String, dynamic>;

    if (data['erro'] == true) {
      throw CepAbertoException('CEP não encontrado');
    }

    return Address(
      street: (data['logradouro'] ?? '') as String,
      district: (data['bairro'] ?? '') as String,
      city: (data['localidade'] ?? '') as String,
      state: (data['uf'] ?? '') as String,
      zipCode: cleanCep,
    );
  }
}
