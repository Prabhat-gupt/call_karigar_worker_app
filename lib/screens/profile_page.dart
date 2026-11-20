import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../models/worker_profile_model.dart';
import '../models/worker_document_model.dart';
import '../widgets/profile_image_picker.dart';
import 'worker_documents_screen.dart';
import '../verification/document_verification_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  WorkerProfileModel? _profile;
  WorkerDocument? _workerDocument;
  bool _isLoading = true;
  String? _workerId;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    final userId = prefs.getString("workerId") ??
        prefs.getString("id") ??
        prefs.getString("userId");

    if (token == null || userId == null) {
      _handleError('Authentication token or user ID missing');
      if (kDebugMode) {
        print("❌ Token: $token");
        print("❌ UserID: $userId");
        print("❌ Available keys: ${prefs.getKeys()}");
      }
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _workerId = userId);
    await _fetchProfileFromAPI(token);
    await _fetchDocumentsFromAPI(token);
  }

  Future<void> _fetchProfileFromAPI(String token) async {
    try {
      final response = await ApiService.getWorkerProfile(token);

      if (response['error'] != null) {
        _handleError(response['message'] ?? 'Failed to fetch profile');
        return;
      }

      setState(() {
        _profile = WorkerProfileModel.fromJson(response);
      });

      if (kDebugMode) {
        print("✅ Worker profile loaded successfully");
        print("Status: ${_profile?.status}");
        print("Verified: ${_profile?.isVerified}");
      }
    } catch (e) {
      if (kDebugMode) print("❌ Profile fetch error: $e");
      _handleError('Error loading profile: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDocumentsFromAPI(String token) async {
    try {
      final response = await ApiService.getWorkerDocuments(token);

      if (response['error'] == null) {
        setState(() {
          // Handle different response formats
          final documentData = response['data'];

          if (documentData is List) {
            // If data is an array, check if it has documents
            if (documentData.isNotEmpty) {
              // Parse first document from array
              _workerDocument = WorkerDocument.fromJson(
                documentData[0] as Map<String, dynamic>,
              );
            } else {
              // Empty array means no documents
              _workerDocument = null;
            }
          } else if (documentData is Map<String, dynamic>) {
            // If data is a Map, parse it directly
            _workerDocument = WorkerDocument.fromJson(documentData);
          } else {
            // Try to parse the entire response as a document
            _workerDocument = WorkerDocument.fromJson(response);
          }
        });

        if (kDebugMode) {
          print("✅ Worker documents loaded");
          if (_workerDocument != null) {
            print("KYC Complete: ${_workerDocument?.isKYCComplete}");
          } else {
            print("No documents found for this worker");
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print("⚠️ Documents fetch error: $e");
    }
  }

  void _handleError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showEditDialog(String field, String currentValue,
      {String? label, int maxLines = 1}) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${label ?? field}'),
        content: TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: 'Enter ${label?.toLowerCase() ?? field.toLowerCase()}',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newValue = controller.text.trim();
              if (newValue.isEmpty) {
                _handleError('Field cannot be empty');
                return;
              }

              await _updateProfile(field, newValue);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfile(String field, String value) async {
    if (_profile == null || _workerId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      _handleError('Authentication token missing');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updateData = {field: value};
      final response = await ApiService.updateWorkerProfile(
        token,
        _workerId!,
        updateData,
      );

      if (response['error'] != null) {
        _handleError(response['message'] ?? 'Update failed');
        return;
      }

      setState(() {
        _profile = WorkerProfileModel.fromJson(response);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      if (kDebugMode) print("✅ Profile updated: $field = $value");
    } catch (e) {
      _handleError('Error updating profile: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAvailability(bool autoAccept, int maxJobs) async {
    if (_workerId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      _handleError('Authentication token missing');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.updateWorkerAvailability(
        token,
        _workerId!,
        autoAccept,
        maxJobs,
      );

      if (response['error'] != null) {
        _handleError(response['message'] ?? 'Update failed');
        return;
      }

      setState(() {
        _profile = WorkerProfileModel.fromJson(response);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Availability updated successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _handleError('Error updating availability: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Failed to load profile. Please try again.'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initializeProfile,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: const Text('Worker Profile'),
        elevation: 0,
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header Card
            _buildProfileHeader(),
            const SizedBox(height: 20),

            // Status & Verification
            _buildStatusCard(),
            const SizedBox(height: 20),

            // Personal Information
            _buildPersonalInfoCard(),
            const SizedBox(height: 20),

            // Professional Stats
            _buildStatsCard(),
            const SizedBox(height: 20),

            // Preferences
            _buildPreferencesCard(),
            const SizedBox(height: 20),

            // Documents Section
            if (_workerDocument != null) ...[
              _buildDocumentsSection(),
              const SizedBox(height: 20),
            ],

            // Skills Section
            _buildSkillsCard(),
            const SizedBox(height: 20),

            // Rating Section
            _buildRatingCard(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: _profile!.photo.startsWith('http')
                ? NetworkImage(_profile!.photo)
                : null,
            child: _profile!.photo.startsWith('http')
                ? null
                : const Icon(Icons.person, size: 50),
          ),
          const SizedBox(height: 12),
          Text(
            'Worker ID: ${_profile!.id.substring(0, 8)}...',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            _profile!.phoneNumber,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            _profile!.email,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final statusColor = _profile!.status == 'active'
        ? Colors.green
        : _profile!.status == 'pending'
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(20),
        border: Border.all(color: statusColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _profile!.isVerified ? Icons.check_circle : Icons.pending,
            color: _profile!.isVerified ? Colors.green : Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Status',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  _profile!.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (_profile!.isVerified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '✓ Verified',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return _buildEditableCard(
      title: 'Personal Information',
      icon: Icons.person,
      children: [
        _buildInfoRow(
          'Phone',
          _profile!.phoneNumber,
          'phoneNumber',
          editable: false,
        ),
        _buildInfoRow(
          'Email',
          _profile!.email,
          'email',
          editable: false,
        ),
        _buildInfoRow(
          'Bio',
          _profile!.bio,
          'bio',
          editable: true,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    String field, {
    bool editable = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (editable)
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _showEditDialog(field, value,
                  label: label, maxLines: maxLines),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return _buildEditableCard(
      title: 'Work Statistics',
      icon: Icons.bar_chart,
      children: [
        _buildStatRow(
          'Total Jobs',
          _profile!.stats.totalJobs.toString(),
          Icons.assignment,
        ),
        _buildStatRow(
          'Completed',
          _profile!.stats.completedJobs.toString(),
          Icons.check_circle,
        ),
        _buildStatRow(
          'Cancelled',
          _profile!.stats.cancelledJobs.toString(),
          Icons.cancel,
        ),
        _buildStatRow(
          'Total Earnings',
          '₹${_profile!.stats.totalEarnings.toStringAsFixed(2)}',
          Icons.attach_money,
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preferences & Settings',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 16),
          _buildSwitchRow(
            'Notifications',
            _profile!.preferences.notifications,
            (value) async {
              final updated = {
                'preferences': {
                  'notifications': value,
                }
              };
              // await _updateProfile('preferences', updated['preferences']!['language']!);
              // await _updateProfile('preferences', value);
            },
          ),
          const Divider(height: 16),
          _buildSwitchRow(
            'Auto Accept Jobs',
            _profile!.preferences.autoAccept,
            (value) =>
                _updateAvailability(value, _profile!.preferences.maxJobsPerDay),
          ),
          const Divider(height: 16),
          _buildSliderRow(
            'Max Jobs Per Day',
            _profile!.preferences.maxJobsPerDay.toDouble(),
            1,
            10,
            (value) => _updateAvailability(
              _profile!.preferences.autoAccept,
              value.toInt(),
            ),
          ),
          const Divider(height: 16),
          _buildLanguageDropdown(),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            Text(
              value.toInt().toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: 10,
          activeColor: Colors.orange,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildLanguageDropdown() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Language', style: TextStyle(fontSize: 14)),
        DropdownButton<String>(
          value: _profile!.preferences.language,
          items: const [
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'hi', child: Text('हिन्दी')),
          ],
          onChanged: (value) {
            if (value != null) {
              // final updated = {'preferences': {'language': value}};
              _updateProfile('preferences', value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildDocumentsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Verification Documents',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _workerDocument!.isKYCComplete
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _workerDocument!.isKYCComplete
                      ? 'KYC Complete'
                      : 'KYC Pending',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _workerDocument!.isKYCComplete
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Text(
            'Status: ${_workerDocument!.status.toUpperCase()}',
            style: TextStyle(
              fontSize: 14,
              color: _workerDocument!.status == 'verified'
                  ? Colors.green
                  : _workerDocument!.status == 'rejected'
                      ? Colors.red
                      : Colors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('token');
                  if (mounted && _workerId != null && token != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkerDocumentsScreen(
                          initialDocument: _workerDocument,
                          workerId: _workerId!,
                          token: token,
                        ),
                      ),
                    ).then((result) {
                      // If documents were uploaded, refresh the profile
                      if (result == true && mounted) {
                        _initializeProfile();
                      }
                    });
                  }
                },
                icon: const Icon(Icons.document_scanner),
                label: const Text('View All Documents'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsCard() {
    return _buildEditableCard(
      title: 'Skills & Services',
      icon: Icons.build,
      children: [
        if (_profile!.skills.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No skills added yet',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _profile!.skills
                .map(
                  (skill) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      skill,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildRatingCard() {
    final ratingPercentage =
        (_profile!.ratingCount > 0 ? _profile!.ratingAverage / 5 * 100 : 0)
            .toStringAsFixed(1);

    return _buildEditableCard(
      title: 'Rating & Reviews',
      icon: Icons.star,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              children: [
                Text(
                  _profile!.ratingAverage.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < _profile!.ratingAverage
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.orange,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_profile!.ratingCount} Reviews',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$ratingPercentage% positive',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditableCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 16),
          ...children,
        ],
      ),
    );
  }
}
