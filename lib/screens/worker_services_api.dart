import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WorkerServicesApi {
  // ⚠️ CHANGE THIS TO YOUR LOCAL MACHINE IP OR PRODUCTION URL
  // For emulator: http://10.0.2.2:5000 (Android) or http://127.0.0.1:5000 (iOS)
  // For physical device: http://YOUR_MACHINE_IP:5000 (e.g., http://192.168.x.x:5000)
  // For production: https://callkaarigar.onrender.com
  static const String apiHost = 'http://localhost:5000'; // Change this!

  static const String baseUrl = "$apiHost/api/worker-services";

  /// GET: Fetch all services for a specific worker
  static Future<List<dynamic>> getWorkerServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final workerId = prefs.getString('workerId');

      if (token == null || workerId == null) {
        throw Exception("Token or Worker ID not found in storage");
      }

      final url = Uri.parse("$baseUrl/service/$workerId");
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data; // Assuming API returns a list of services
      } else {
        throw Exception("Failed to fetch services: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error fetching services: $e");
    }
  }

  /// POST: Add a new service for a worker
  static Future<bool> addWorkerService(Map<String, dynamic> serviceData) async {
    print(
        'DEBUG: addWorkerService called with data: ${jsonEncode(serviceData)}');

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final workerId = prefs.getString('workerId');

      if (token == null || workerId == null) {
        throw Exception("Token or Worker ID not found in storage");
      }

      print('DEBUG: addWorkerService - Token: ${token.substring(0, 20)}...');
      print('DEBUG: addWorkerService - WorkerId: $workerId');
      print(
          'DEBUG: addWorkerService - Request body before normalization: ${jsonEncode(serviceData)}');

      // Normalize price to a number when possible (backend expects numeric comparison)
      if (serviceData.containsKey('price')) {
        final raw = serviceData['price'];
        if (raw is String) {
          final parsed = double.tryParse(raw.replaceAll(',', '').trim());
          if (parsed != null) serviceData['price'] = parsed;
        }
      }

      print(
          'DEBUG: addWorkerService - Request body after normalization: ${jsonEncode(serviceData)}');

      final url = Uri.parse(baseUrl);
      print('DEBUG: addWorkerService - Posting to: $url');
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(serviceData),
      );

      print(
          'DEBUG: addWorkerService - Response status: ${response.statusCode}');
      print('DEBUG: addWorkerService - Response body: ${response.body}');

      if (response.statusCode == 201) {
        print('DEBUG: addWorkerService - SUCCESS');
        return true;
      } else {
        print(
            "DEBUG: addWorkerService failed (${response.statusCode}): ${response.body}");
        return false;
      }
    } catch (e) {
      print('DEBUG: addWorkerService - Exception: $e');
      throw Exception("Error adding service: $e");
    }
  }
}
