import 'package:dio/dio.dart';
import '../models/worker_document_model.dart';

class WorkerDocumentService {
  // Replace with your actual API base URL
  static const String baseUrl = 'http://localhost:5000/api';

  static final Dio _dio = Dio();

  // Fetch worker documents
  static Future<WorkerDocument> fetchWorkerDocuments(
      String workerId, String token) async {
    try {
      // Use GET / to fetch logged-in worker's documents
      final response = await _dio.get(
        '$baseUrl/worker-documents',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          // Handle both formats: {success, data} and direct data
          final docData = data['data'] ?? data;
          return WorkerDocument.fromJson(docData);
        }
        return WorkerDocument.fromJson(data);
      } else {
        throw Exception('Failed to fetch documents: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // No documents found yet - return empty document
        throw Exception('No documents found. Please upload your documents.');
      }
      throw Exception('Error fetching documents: ${e.message}');
    } catch (e) {
      throw Exception('Error fetching documents: $e');
    }
  }

  // Upload all documents at once (works on web and mobile)
  static Future<WorkerDocument> uploadAllDocuments({
    required String workerId,
    required List<int> aadharBytes,
    required String aadharFilename,
    required List<int> panBytes,
    required String panFilename,
    required List<int> policeVerificationBytes,
    required String policeVerificationFilename,
    required List<dynamic> certificationFiles,
    required List<String> certificationTitles,
    required String token,
  }) async {
    try {
      FormData formData = FormData.fromMap({
        'aadhar': MultipartFile.fromBytes(
          aadharBytes,
          filename: aadharFilename,
        ),
        'pan': MultipartFile.fromBytes(
          panBytes,
          filename: panFilename,
        ),
        'policeVerification': MultipartFile.fromBytes(
          policeVerificationBytes,
          filename: policeVerificationFilename,
        ),
      });

      // Add certifications if provided
      for (int i = 0; i < certificationFiles.length; i++) {
        final certFile = certificationFiles[i];
        if (certFile is Map &&
            certFile.containsKey('bytes') &&
            certFile.containsKey('filename')) {
          formData.files.add(
            MapEntry(
              'certifications',
              MultipartFile.fromBytes(
                certFile['bytes'],
                filename: certFile['filename'],
              ),
            ),
          );

          if (i < certificationTitles.length) {
            formData.fields.add(
                MapEntry('certificationTitles[$i]', certificationTitles[i]));
          }
        }
      }

      final response = await _dio.post(
        '$baseUrl/worker-documents',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return WorkerDocument.fromJson(response.data['data'] ?? response.data);
      } else {
        throw Exception(
            response.data['message'] ?? 'Failed to upload documents');
      }
    } catch (e) {
      throw Exception('Error uploading documents: $e');
    }
  }
}
