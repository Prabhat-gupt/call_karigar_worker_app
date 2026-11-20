import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../screens/api_service.dart';
import 'documents_api.dart';

class DocumentVerificationPage extends StatefulWidget {
  final VoidCallback? onDocumentsUploaded;

  const DocumentVerificationPage({
    super.key,
    this.onDocumentsUploaded,
  });

  @override
  State<DocumentVerificationPage> createState() =>
      _DocumentVerificationPageState();
}

class _DocumentVerificationPageState extends State<DocumentVerificationPage> {
  PlatformFile? aadhaarFile;
  PlatformFile? photoFile;
  PlatformFile? panFile;
  PlatformFile? ITIFile;
  PlatformFile? PoliceFile;

  Future<void> pickDocument(String type) async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null) {
      setState(() {
        switch (type) {
          case 'aadhaar':
            aadhaarFile = result.files.single;
            break;
          case 'photo':
            photoFile = result.files.single;
            break;
          case 'pan':
            panFile = result.files.single;
            break;
          case 'ITI':
            ITIFile = result.files.single;
            break;
          case 'Police':
            PoliceFile = result.files.single;
            break;
        }
      });
    }
  }

  void removeFile(String type) {
    setState(() {
      switch (type) {
        case 'aadhaar':
          aadhaarFile = null;
          break;
        case 'photo':
          photoFile = null;
          break;
        case 'pan':
          panFile = null;
          break;
        case 'ITI':
          ITIFile = null;
          break;
        case 'Police':
          PoliceFile = null;
          break;
      }
    });
  }

  Future<void> submitDocuments() async {
    if (aadhaarFile == null || photoFile == null || panFile == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Incomplete Upload"),
          content: const Text("Please upload Aadhaar, Photo, and PAN Card."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            )
          ],
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");
      String? workerId = prefs.getString("workerId");

      if (token == null || workerId == null) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Authentication failed. Please login again.")),
        );
        return;
      }

      // Prepare file paths
      final filePaths = {
        'aadhar': aadhaarFile!.path ?? '',
        'pan': panFile!.path ?? '',
        'policeVerification':
            photoFile!.path ?? '', // Using photo as police verification
      };

      if (kDebugMode) {
        print("📤 Uploading documents:");
        print("   Aadhar: ${aadhaarFile!.name}");
        print("   PAN: ${panFile!.name}");
        print("   Police Verification: ${photoFile!.name}");
        if (ITIFile != null) print("   ITI: ${ITIFile!.name}");
      }

      // Upload documents using the API
      final response = await ApiService.uploadDocuments(
        token,
        filePaths,
        certificationTitles: ITIFile != null ? ['ITI Certification'] : null,
      );

      Navigator.pop(context); // Close loading dialog

      if (response['error'] == null && response['success'] == true) {
        if (kDebugMode) {
          print("✅ Documents uploaded successfully");
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Documents uploaded successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        // Close verification page and return to profile
        if (mounted) {
          Navigator.pop(context);
          if (widget.onDocumentsUploaded != null) {
            widget.onDocumentsUploaded!();
          }
        }
      } else {
        if (kDebugMode) {
          print("❌ Upload failed: ${response['message']}");
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? "Failed to upload documents"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      if (kDebugMode) {
        print("❌ Error submitting documents: $e");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error submitting documents: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget documentUploadTile({
    required String title,
    required String type,
    required PlatformFile? file,
    required VoidCallback onUpload,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: onUpload,
          icon: const Icon(Icons.upload_file),
          label: Text("Upload $title"),
        ),
        if (file != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: Text("Selected: ${file.name}",
                      style: const TextStyle(fontSize: 14)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => removeFile(type),
                  tooltip: 'Remove $title',
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Document Verification")),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFFFF3E0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                "Please upload all required documents for verification:",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              documentUploadTile(
                title: "Aadhaar Card",
                type: "aadhaar",
                file: aadhaarFile,
                onUpload: () => pickDocument('aadhaar'),
              ),
              documentUploadTile(
                title: "Photo",
                type: "photo",
                file: photoFile,
                onUpload: () => pickDocument('photo'),
              ),
              documentUploadTile(
                title: "PAN Card",
                type: "pan",
                file: panFile,
                onUpload: () => pickDocument('pan'),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submitDocuments,
                  child: const Text("Submit Documents"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
