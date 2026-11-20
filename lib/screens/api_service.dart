import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

// Recommended: Use a config file for production apps.
// Local server: http://localhost:5000/api
// Production: https://callkaarigar.onrender.com/api
const String _baseUrl = "http://localhost:5000/api";

class ApiService {
  /// Fetches a user's profile using an authentication token.
  /// Returns a Map containing user data on success, or an error map on failure.
  static Future<Map<String, dynamic>> getUserProfile(String token) async {
    if (token.isEmpty) {
      return {
        'error': 'no_token',
        'message': 'Authentication token is missing.'
      };
    }

    final url = Uri.parse("$_baseUrl/users/profile");

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (kDebugMode) {
        print("📡 API Request → GET $url");
        print("🔑 Token: $token");
        print("📨 Status Code: ${response.statusCode}");
        print("📨 Response Body: ${response.body}");
      }

      final dynamic data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // This log was incorrect based on the API response,
        // as the 'workerProfileId' field is not present here.
        // if (kDebugMode && data is Map<String, dynamic> && data["workerProfileId"] != null) {
        //   print("🆔 Worker Profile ID: ${data["workerProfileId"]}");
        // }
        return data as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        return {
          'error': 'unauthorized',
          'message': 'Session expired. Please log in again.',
        };
      } else {
        return {
          'error': 'api_error',
          'message': 'Server responded with status code ${response.statusCode}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ API Exception: $e");
      }
      return {
        'error': 'exception',
        'message': e.toString(),
      };
    }
  }

  /// Fetches a specific worker profile by their user ID.
  /// Returns a Map containing worker profile data on success, or an error map on failure.
  static Future<Map<String, dynamic>> getWorkerProfileById(
      String workerUserId) async {
    if (workerUserId.isEmpty) {
      return {'error': 'invalid_id', 'message': 'Worker user ID is missing.'};
    }

    // This URL is incorrect. The provided screenshot shows the endpoint is /worker-profile with an ID in the body, but your log shows /worker-profile/user/:id, which is better.
    // The screenshot also shows a GET for all workers. To get a specific worker by user ID, the endpoint should be /worker-profile/user/:id as per your log.

    // final url = Uri.parse("$_baseUrl/worker-profile/user/$workerUserId");
    // The screenshot of Postman shows the endpoint to be `https://callkaarigar.onrender.com/api/worker-profile`
    // but the log in your terminal shows the call is being made to `https://callkaarigar.onrender.com/api/worker-profile/user/:id`.
    // We'll stick with the correct call you were making, since the general endpoint is for all workers.

    final url = Uri.parse("$_baseUrl/worker-profile/user/$workerUserId");

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
        },
      );

      if (kDebugMode) {
        print("📡 API Request → GET $url");
        print("📨 Status Code: ${response.statusCode}");
        print("📨 Response Body: ${response.body}");
      }

      final dynamic data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // The API response for a single worker is an array containing one object.
        // We need to return that object, not the whole map.
        if (data is Map<String, dynamic> &&
            data['data'] is List &&
            data['data'].isNotEmpty) {
          return data['data'][0] as Map<String, dynamic>;
        } else {
          return {
            'error': 'not_found',
            'message': 'Worker profile not found.',
          };
        }
      } else {
        return {
          'error': 'api_error',
          'message':
              'Failed to fetch worker profile. Status: ${response.statusCode}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ API Exception: $e");
      }
      return {
        'error': 'exception',
        'message': e.toString(),
      };
    }
  }

  /// Fetches worker documents and verification status.
  /// Returns a Map containing document data on success, or an error map on failure.
  static Future<Map<String, dynamic>> getWorkerDocuments(String token) async {
    if (token.isEmpty) {
      return {
        'error': 'no_token',
        'message': 'Authentication token is missing.'
      };
    }

    final url = Uri.parse("$_baseUrl/worker-documents");

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (kDebugMode) {
        print("📡 API Request → GET $url");
        print("📨 Status Code: ${response.statusCode}");
        print("📨 Response Body: ${response.body}");
      }

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        // Normalize responses so callers always receive a Map with a 'data' key.
        if (data is List) {
          return {
            'success': true,
            'count': data.length,
            'data': data,
          };
        }

        // Extract the actual document data from response when it's a Map
        if (data is Map<String, dynamic>) {
          if (data.containsKey('data') && data['data'] != null) {
            final documentData = data['data'];
            if (documentData is List) {
              return {
                'success': data['success'] ?? false,
                'count': data['count'] ?? 0,
                'data': documentData,
              };
            }
            // If data['data'] is a Map, return it wrapped as a Map with 'data'
            return {'success': data['success'] ?? false, 'data': documentData};
          }
          // If response is already a Map representing the document, return it
          return data as Map<String, dynamic>;
        }

        // Fallback: wrap unknown response types
        return {'data': data};
      } else if (response.statusCode == 401) {
        return {
          'error': 'unauthorized',
          'message': 'Session expired. Please log in again.',
        };
      } else if (response.statusCode == 404) {
        return {
          'error': 'not_found',
          'message': 'No documents found for this worker.',
        };
      } else {
        return {
          'error': 'api_error',
          'message': 'Server responded with status code ${response.statusCode}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ API Exception: $e");
      }
      return {
        'error': 'exception',
        'message': e.toString(),
      };
    }
  }

  /// Fetches the current worker's profile from the server.
  /// Uses the authenticated token to fetch the worker profile.
  /// Returns a Map containing worker profile data on success, or an error map on failure.
  static Future<Map<String, dynamic>> getWorkerProfile(String token) async {
    if (token.isEmpty) {
      return {
        'error': 'no_token',
        'message': 'Authentication token is missing.'
      };
    }

    final url = Uri.parse("$_baseUrl/worker-profile");

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (kDebugMode) {
        print("📡 API Request → GET $url");
        print("📨 Status Code: ${response.statusCode}");
        print("📨 Response Body: ${response.body}");
      }

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        // Extract worker profile from response
        // Handle array responses by extracting first element
        if (data is Map<String, dynamic>) {
          if (data.containsKey('data') && data['data'] != null) {
            final dataValue = data['data'];
            // If data is an array, extract the first element
            if (dataValue is List && dataValue.isNotEmpty) {
              final firstItem = dataValue.first;
              if (firstItem is Map<String, dynamic>) {
                return firstItem;
              }
            }
            // If data is already a Map, return it
            if (dataValue is Map<String, dynamic>) {
              return dataValue;
            }
          }
          return data;
        }
        return data as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        return {
          'error': 'unauthorized',
          'message': 'Session expired. Please log in again.',
        };
      } else if (response.statusCode == 404) {
        return {
          'error': 'not_found',
          'message': 'Worker profile not found.',
        };
      } else {
        return {
          'error': 'api_error',
          'message': 'Server responded with status code ${response.statusCode}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ API Exception: $e");
      }
      return {
        'error': 'exception',
        'message': e.toString(),
      };
    }
  }

  /// Updates the worker's profile with new data.
  /// Sends an update request to the workerProfileController.
  /// Returns a Map containing updated profile data on success, or an error map on failure.
  static Future<Map<String, dynamic>> updateWorkerProfile(
    String token,
    String workerId,
    Map<String, dynamic> updateData,
  ) async {
    if (token.isEmpty) {
      return {
        'error': 'no_token',
        'message': 'Authentication token is missing.'
      };
    }

    if (workerId.isEmpty) {
      return {'error': 'invalid_id', 'message': 'Worker ID is missing.'};
    }

    final url = Uri.parse("$_baseUrl/worker-profile/$workerId");

    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updateData),
      );

      if (kDebugMode) {
        print("📡 API Request → PUT $url");
        print("📤 Request Body: ${jsonEncode(updateData)}");
        print("📨 Status Code: ${response.statusCode}");
        print("📨 Response Body: ${response.body}");
      }

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        // Extract updated profile from response
        if (data is Map<String, dynamic>) {
          if (data.containsKey('data') && data['data'] != null) {
            return data['data'] as Map<String, dynamic>;
          }
          return data;
        }
        return data as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        return {
          'error': 'unauthorized',
          'message': 'Session expired. Please log in again.',
        };
      } else if (response.statusCode == 403) {
        return {
          'error': 'forbidden',
          'message': 'Not authorized to update this profile.',
        };
      } else if (response.statusCode == 404) {
        return {
          'error': 'not_found',
          'message': 'Worker profile not found.',
        };
      } else {
        return {
          'error': 'api_error',
          'message': 'Server responded with status code ${response.statusCode}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ API Exception: $e");
      }
      return {
        'error': 'exception',
        'message': e.toString(),
      };
    }
  }

  /// Updates worker availability preferences.
  /// Sends an update request to set auto-accept and max jobs per day.
  /// Returns a Map containing updated profile data on success, or an error map on failure.
  static Future<Map<String, dynamic>> updateWorkerAvailability(
    String token,
    String workerId,
    bool autoAccept,
    int maxJobsPerDay,
  ) async {
    if (token.isEmpty) {
      return {
        'error': 'no_token',
        'message': 'Authentication token is missing.'
      };
    }

    final url = Uri.parse("$_baseUrl/worker-profile/$workerId/availability");

    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'availabilitySlots': {
            'autoAccept': autoAccept,
            'maxJobsPerDay': maxJobsPerDay,
          }
        }),
      );

      if (kDebugMode) {
        print("📡 API Request → PUT $url");
        print("📨 Status Code: ${response.statusCode}");
        print("📨 Response Body: ${response.body}");
      }

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        // Extract updated profile from response
        if (data is Map<String, dynamic>) {
          if (data.containsKey('data') && data['data'] != null) {
            return data['data'] as Map<String, dynamic>;
          }
          return data;
        }
        return data as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        return {
          'error': 'unauthorized',
          'message': 'Session expired. Please log in again.',
        };
      } else if (response.statusCode == 404) {
        return {
          'error': 'not_found',
          'message': 'Worker profile not found.',
        };
      } else {
        return {
          'error': 'api_error',
          'message': 'Server responded with status code ${response.statusCode}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ API Exception: $e");
      }
      return {
        'error': 'exception',
        'message': e.toString(),
      };
    }
  }

  /// Upload worker documents (Aadhar, PAN, Police Verification, and optionally Certifications)
  /// Requires multipart form-data with file fields:
  /// - aadhar: Aadhar card file
  /// - pan: PAN card file
  /// - policeVerification: Police verification file
  /// - certifications: Optional certification files
  static Future<Map<String, dynamic>> uploadDocuments(
    String token,
    Map<String, String> filePaths, {
    List<String>? certificationTitles,
  }) async {
    if (token.isEmpty) {
      return {
        'error': 'no_token',
        'message': 'Authentication token is missing.'
      };
    }

    // Validate required files
    final requiredFiles = ['aadhar', 'pan', 'policeVerification'];
    for (final file in requiredFiles) {
      if (!filePaths.containsKey(file) || filePaths[file]!.isEmpty) {
        return {
          'error': 'missing_files',
          'message': 'Missing required file: $file'
        };
      }
    }

    final url = Uri.parse("$_baseUrl/worker-documents");

    try {
      // Create multipart request
      final request = http.MultipartRequest('POST', url);

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add files to request
      for (final entry in filePaths.entries) {
        final filePath = entry.value;
        if (filePath.isNotEmpty) {
          final file = await http.MultipartFile.fromPath(entry.key, filePath);
          request.files.add(file);
        }
      }

      // Add certification titles if provided
      if (certificationTitles != null && certificationTitles.isNotEmpty) {
        for (int i = 0; i < certificationTitles.length; i++) {
          request.fields['certificationTitles[$i]'] = certificationTitles[i];
        }
      }

      if (kDebugMode) {
        print("📡 API Request → POST $url");
        print("📦 Files: ${filePaths.keys.join(', ')}");
        print("📦 Certifications: ${certificationTitles?.length ?? 0}");
      }

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (kDebugMode) {
        print("📨 Status Code: ${response.statusCode}");
        print("📨 Response Body: ${response.body}");
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (kDebugMode) {
          print("✅ Documents uploaded successfully");
        }
        return data;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        return {
          'error': 'validation_error',
          'message': data['message'] ??
              'Invalid file format or missing required fields',
        };
      } else if (response.statusCode == 401) {
        return {
          'error': 'unauthorized',
          'message': 'Session expired. Please log in again.',
        };
      } else if (response.statusCode == 413) {
        return {
          'error': 'file_too_large',
          'message': 'File size exceeds maximum limit',
        };
      } else {
        return {
          'error': 'api_error',
          'message': 'Server responded with status code ${response.statusCode}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Upload Exception: $e");
      }
      return {
        'error': 'exception',
        'message': e.toString(),
      };
    }
  }
}
