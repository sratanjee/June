import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/checkin.dart';

// Phase 0 backend lives on the host machine. iOS sim sees the Mac at 127.0.0.1;
// Android emulator uses 10.0.2.2. Override JUNE_API_BASE with --dart-define
// when running on a real device on the same Wi-Fi.
String _defaultBase() {
  const fromEnv = String.fromEnvironment('JUNE_API_BASE');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (Platform.isAndroid) return 'http://10.0.2.2:4000';
  return 'http://127.0.0.1:4000';
}

class JuneClient {
  final String baseUrl;
  JuneClient({String? baseUrl}) : baseUrl = baseUrl ?? _defaultBase();

  Future<CheckIn> generateCheckIn({
    required DateTime today,
    required Map<String, dynamic> context,
  }) async {
    final url = Uri.parse('$baseUrl/checkin/generate');
    final res = await http.post(
      url,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'today':
            '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
        'context': context,
      }),
    );

    if (res.statusCode != 200) {
      throw JuneApiException(res.statusCode, res.body);
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return CheckIn.fromJson(json);
  }
}

class JuneApiException implements Exception {
  final int status;
  final String body;
  JuneApiException(this.status, this.body);
  @override
  String toString() => 'JuneApiException($status): $body';
}
