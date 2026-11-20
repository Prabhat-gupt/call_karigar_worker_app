import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/worker_document_model.dart';
import '../services/worker_document_service.dart';

class FileData {
  final List<int> bytes;
  final String filename;

  FileData({required this.bytes, required this.filename});
}

class WorkerDocumentsScreen extends StatefulWidget {
  final WorkerDocument? initialDocument;
  final String workerId;
  final String token;

  const WorkerDocumentsScreen({
    this.initialDocument,
    required this.workerId,
    required this.token,
    super.key,
  });

  @override
  State<WorkerDocumentsScreen> createState() => _WorkerDocumentsScreenState();
}

class _WorkerDocumentsScreenState extends State<WorkerDocumentsScreen> {
  late WorkerDocument? document;
  bool isLoading = false;
  Map<String, FileData?> selectedFiles = {
    'aadhar': null,
    'pan': null,
    'policeVerification': null,
    'certification': null,
  };
  List<FileData> certificationFiles = [];
  List<String> certificationTitles = [];
  String? uploadError;

  @override
  void initState() {
    super.initState();
    document = widget.initialDocument;
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final fetchedDocument = await WorkerDocumentService.fetchWorkerDocuments(
        widget.workerId,
        widget.token,
      );
      if (mounted) {
        setState(() => document = fetchedDocument);
      }
    } catch (e) {
      if (mounted) {
        print('Error loading documents: $e');
        // Don't show error snackbar if it's first time (no documents yet)
        if (!e.toString().contains('No documents found')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading documents: $e')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _pickFile(String documentType, bool isImage) async {
    try {
      FileData? pickedFile;

      if (isImage) {
        final ImagePicker picker = ImagePicker();
        final XFile? image =
            await picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          final bytes = await image.readAsBytes();
          pickedFile = FileData(
            bytes: bytes,
            filename: image.name,
          );
        }
      } else {
        final result = await FilePicker.platform.pickFiles();
        if (result != null && result.files.single.bytes != null) {
          pickedFile = FileData(
            bytes: result.files.single.bytes!,
            filename: result.files.single.name,
          );
        }
      }

      if (pickedFile != null) {
        setState(() {
          selectedFiles[documentType] = pickedFile;
          uploadError = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _uploadAllDocuments() async {
    // Validate required documents
    if (selectedFiles['aadhar'] == null ||
        selectedFiles['pan'] == null ||
        selectedFiles['policeVerification'] == null) {
      setState(() {
        uploadError =
            'Please upload all required documents (Aadhar, PAN, Police Verification)';
      });
      return;
    }

    setState(() {
      isLoading = true;
      uploadError = null;
    });

    try {
      final uploadedDocument = await WorkerDocumentService.uploadAllDocuments(
        workerId: widget.workerId,
        aadharBytes: selectedFiles['aadhar']!.bytes,
        aadharFilename: selectedFiles['aadhar']!.filename,
        panBytes: selectedFiles['pan']!.bytes,
        panFilename: selectedFiles['pan']!.filename,
        policeVerificationBytes: selectedFiles['policeVerification']!.bytes,
        policeVerificationFilename:
            selectedFiles['policeVerification']!.filename,
        certificationFiles: certificationFiles
            .map((f) => {'bytes': f.bytes, 'filename': f.filename})
            .toList(),
        certificationTitles: certificationTitles,
        token: widget.token,
      );

      setState(() {
        document = uploadedDocument;
        selectedFiles = {
          'aadhar': null,
          'pan': null,
          'policeVerification': null,
        };
        certificationFiles = [];
        certificationTitles = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documents uploaded successfully!')),
      );

      // Auto-pop after 2 seconds to refresh parent
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate refresh needed
      }
    } catch (e) {
      setState(() {
        uploadError = 'Upload failed: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _addCertification() {
    // Show dialog to add certification
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Certification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                label: Text('Certification Title'),
                hintText: 'e.g., Basic Plumbing Course',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await _pickFile('certification', false);
                if (mounted && selectedFiles['certification'] != null) {
                  setState(() {
                    certificationFiles.add(selectedFiles['certification']!);
                    certificationTitles.add(titleController.text.isNotEmpty
                        ? titleController.text
                        : 'Certification ${certificationFiles.length}');
                    selectedFiles['certification'] = null;
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Pick File'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && document == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Documents'),
          elevation: 1,
          backgroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // If no document exists yet, show the upload form for first-time upload
    if (document == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Upload Documents'),
          elevation: 1,
          backgroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[300]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'First Time Upload',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Please upload all required documents to complete your KYC verification',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Required Documents'),
              const SizedBox(height: 12),
              _buildDocumentCard('Aadhar', null, 'aadhar'),
              const SizedBox(height: 12),
              _buildDocumentCard('PAN', null, 'pan'),
              const SizedBox(height: 12),
              _buildDocumentCard(
                'Police Verification',
                null,
                'policeVerification',
              ),
              const SizedBox(height: 24),
              if (uploadError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red[300]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          uploadError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              if (uploadError != null) const SizedBox(height: 16),
              // Add certifications section
              _buildSectionTitle('Certifications (Optional)'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (int i = 0; i < certificationFiles.length; i++)
                    Chip(
                      label: Text(certificationTitles[i]),
                      onDeleted: () {
                        setState(() {
                          certificationFiles.removeAt(i);
                          certificationTitles.removeAt(i);
                        });
                      },
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Add Certification'),
                    onPressed: _addCertification,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _uploadAllDocuments,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.blue,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Upload Documents',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final statusColor = _getStatusColor(document!.status);
    final statusText = document!.status.toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        elevation: 1,
        backgroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha((0.1 * 255).round()),
                      border: Border.all(color: statusColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getStatusIcon(document!.status),
                          color: statusColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Verification Status',
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (document!.isKYCComplete)
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 24),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // KYC Completion
                  _buildKYCSection(),
                  const SizedBox(height: 24),

                  // Error message
                  if (uploadError != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red[300]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              uploadError!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (uploadError != null) const SizedBox(height: 16),

                  // Required Documents Section
                  _buildSectionTitle('Required Documents'),
                  const SizedBox(height: 12),
                  _buildDocumentCard('Aadhar', document?.aadhar, 'aadhar'),
                  const SizedBox(height: 12),
                  _buildDocumentCard('PAN', document?.pan, 'pan'),
                  const SizedBox(height: 12),
                  _buildDocumentCard(
                    'Police Verification',
                    document?.policeVerification,
                    'policeVerification',
                  ),
                  const SizedBox(height: 24),

                  // Certifications Section
                  if (document!.certifications.isNotEmpty) ...[
                    _buildSectionTitle('Certifications'),
                    const SizedBox(height: 12),
                    for (var i = 0; i < document!.certifications.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildCertificationCard(
                          document!.certifications[i],
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],

                  // Add certifications
                  Wrap(
                    spacing: 8,
                    children: [
                      for (int i = 0; i < certificationFiles.length; i++)
                        Chip(
                          label: Text(certificationTitles[i]),
                          onDeleted: () {
                            setState(() {
                              certificationFiles.removeAt(i);
                              certificationTitles.removeAt(i);
                            });
                          },
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: const Text('Add Certification'),
                        onPressed: _addCertification,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Timestamps
                  _buildTimestampSection(),
                  const SizedBox(height: 24),

                  // Upload button
                  if (document!.status == 'pending' ||
                      document!.status == 'rejected')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _uploadAllDocuments,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.blue,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Upload Documents',
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildKYCSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            document!.isKYCComplete ? Icons.check_circle : Icons.pending,
            color: document!.isKYCComplete ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('KYC Status',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  document!.isKYCComplete ? 'Complete' : 'Incomplete',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(String label, Document? doc, String docType) {
    final selectedFile = selectedFiles[docType];
    final isUploaded = doc != null;
    final isSelected = selectedFile != null;

    if (!isUploaded && !isSelected) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red[300]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text('Not uploaded',
                          style: TextStyle(fontSize: 12, color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
              SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Choose File'),
                onPressed: () => _pickFile(docType, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[100],
                  foregroundColor: Colors.orange[700],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isSelected && !isUploaded) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.amber[400]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.amber[50],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check, color: Colors.amber[400]),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Selected: ${selectedFile!.filename}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Change'),
                    onPressed: () => _pickFile(docType, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[100],
                      foregroundColor: Colors.amber[700],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Remove'),
                  onPressed: () {
                    setState(() {
                      selectedFiles[docType] = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[100],
                    foregroundColor: Colors.red[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Document already uploaded
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[300]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.file_present, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  doc!.fileType,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _openDocument(doc.url),
            child: Row(
              children: [
                const Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'View Document',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[600],
                      decoration: TextDecoration.underline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificationCard(Certification cert) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  cert.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (cert.verified)
                const Icon(Icons.verified, color: Colors.green, size: 20)
              else
                const Icon(Icons.pending, color: Colors.orange, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Status: ${cert.verified ? 'Verified' : 'Pending'}',
            style: TextStyle(
              fontSize: 12,
              color: cert.verified ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.file_present, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(cert.fileType,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _openDocument(cert.url),
            child: Row(
              children: [
                const Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'View Document',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[600],
                      decoration: TextDecoration.underline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildTimestampSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Submitted',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(
                _formatDate(document!.createdAt),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Last Updated',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(
                _formatDate(document!.updatedAt),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.pending;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _openDocument(String url) {
    // TODO: Implement document viewer (PDF, image, etc.)
    print('Opening document: $url');
  }
}
