// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Gerçek cihazda bilgisayarının IP'si, emülatörde 10.0.2.2
  //static const String baseUrl = 'http://192.168.1.179:8000';//ev
  static const String baseUrl = 'http://10.111.129.19:8000';//yurt


  // Chatbot
  static Future<String> chat(String question, {String? userContext}) async {
    final fullQuestion = userContext != null
        ? '$userContext\n\nSoru: $question'
        : question;

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'question': fullQuestion}),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        return jsonDecode(res.body)['answer'] as String;
      }
      return 'Bağlantı hatası oluştu.';
    } catch (e) {
      return 'Sunucuya ulaşılamıyor. API çalışıyor mu?';
    }
  }
}