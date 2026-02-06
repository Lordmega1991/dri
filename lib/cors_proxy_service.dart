// cors_proxy_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class CORSProxyService {
  static const String scriptUrl =
      'https://script.google.com/macros/s/AKfycbxIUIKMwbP0dgxR3miBXfPStBBdVGp4phxGyX6yrDSPasO2wFZCBmsyv6konZn0V9ooLw/exec';

  // Usar CORS Proxy
  static String getProxiedUrl() {
    return 'https://cors-anywhere.herokuapp.com/$scriptUrl';
    // Ou use: 'https://api.allorigins.win/raw?url=${Uri.encodeFull(scriptUrl)}';
  }

  static Future<Map<String, dynamic>> createFolder(String folderName) async {
    try {
      final body = {
        'action': 'createFolder',
        'folderName': folderName,
        'parentFolderId': '1Fcgk8FIT8a5P5CoLjFPIZS1hMPvL0hlq',
      };

      final response = await http.post(
        Uri.parse(getProxiedUrl()),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
