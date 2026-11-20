// add_service_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // Required for jsonEncode
import 'api_service.dart';
import 'worker_services_api.dart';

class AddServicePage extends StatefulWidget {
  final String workerId; // Add workerId as a final variable

  const AddServicePage(
      {super.key, required this.workerId}); // Update the constructor

  @override
  State<AddServicePage> createState() => _AddServicePageState();
}

class _AddServicePageState extends State<AddServicePage> {
  final _serviceNameController = TextEditingController();
  final _priceController = TextEditingController();
  final _experienceController = TextEditingController();
  final _descriptionController = TextEditingController();

  // ⚠️ CHANGE THIS TO YOUR LOCAL MACHINE IP OR PRODUCTION URL
  // For emulator: http://10.0.2.2:5000 (Android) or http://127.0.0.1:5000 (iOS)
  // For physical device: http://YOUR_MACHINE_IP:5000 (e.g., http://192.168.x.x:5000)
  // For production: https://callkaarigar.onrender.com
  static const String apiHost = 'http://localhost:5000'; // Change this!

  List<dynamic> _availableServices = [];
  String? _selectedServiceId;
  List<dynamic> _categories = [];
  String? _selectedCategoryId;

  bool _isLoading = true;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    print('DEBUG: AddServicePage initState - workerId: ${widget.workerId}');
    _checkVerificationStatus();
    _fetchCategories();
  }

  Future<void> _checkVerificationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Check both profile and document verification status
      bool profileVerified = false;
      bool documentVerified = false;

      // Check worker profile
      final profileResponse = await ApiService.getWorkerProfile(token);
      if (profileResponse['isVerified'] != null &&
          profileResponse['isVerified'] is bool) {
        profileVerified = profileResponse['isVerified'];
      } else if (profileResponse['data'] is Map &&
          profileResponse['data']['isVerified'] != null) {
        profileVerified = profileResponse['data']['isVerified'] == true;
      } else if (profileResponse['data'] is List &&
          profileResponse['data'].isNotEmpty) {
        final first = profileResponse['data'][0];
        if (first is Map && first['isVerified'] != null)
          profileVerified = first['isVerified'] == true;
      }

      // Check document verification status
      final docResponse = await ApiService.getWorkerDocuments(token);
      if (docResponse['error'] == null) {
        final documentData = docResponse['data'];
        if (documentData is Map && documentData['status'] != null) {
          documentVerified = documentData['status'] == 'verified';
        }
      }

      setState(() {
        // Worker must be verified in both profile AND documents
        _isVerified = profileVerified && documentVerified;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitService() async {
    // Basic validation
    if (_priceController.text.isEmpty ||
        _experienceController.text.isEmpty ||
        _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Validate price is a positive number
    final priceValue =
        double.tryParse(_priceController.text.replaceAll(',', '').trim());
    if (priceValue == null || priceValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive price.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    if (_selectedServiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a service.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    final Map<String, dynamic> requestBody = {
      'serviceId': _selectedServiceId,
      'price': _priceController.text,
      'experience': _experienceController.text,
      'description': _descriptionController.text,
    };

    print('DEBUG: Submitting service with body: ${json.encode(requestBody)}');

    try {
      final success = await WorkerServicesApi.addWorkerService(requestBody);
      print('DEBUG: addWorkerService returned: $success');
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service submitted for admin approval!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Submission failed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final url = Uri.parse('$apiHost/api/categories');
      print('DEBUG: Fetching categories from $url');
      final response = await http.get(url);
      print('DEBUG: Categories response status: ${response.statusCode}');
      print('DEBUG: Categories response body: ${response.body}');

      if (response.statusCode == 200) {
        final resp = json.decode(response.body);
        final data = resp['data'] ?? resp;
        print('DEBUG: Parsed categories data: ${json.encode(data)}');

        if (data is List) {
          print('DEBUG: Categories is a List with ${data.length} items');
          setState(() {
            _categories = data;
            _selectedCategoryId = _categories.isNotEmpty
                ? _categories[0]['_id']?.toString()
                : null;
          });
          print('DEBUG: Selected first category ID: $_selectedCategoryId');

          if (_selectedCategoryId != null) {
            print(
                'DEBUG: Fetching services for category: $_selectedCategoryId');
            await _fetchServicesForCategory(_selectedCategoryId!);
          }
        } else {
          print(
              'DEBUG: ERROR - Categories data is not a List, got: ${data.runtimeType}');
        }
      } else {
        print(
            'DEBUG: ERROR - Failed to fetch categories, status: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: ERROR - Exception in _fetchCategories: $e');
    }
  }

  Future<void> _fetchServicesForCategory(String categoryId) async {
    try {
      final url =
          Uri.parse('$apiHost/api/services/category/$categoryId');
      print('\n===== DEBUG: _fetchServicesForCategory START =====');
      print('DEBUG: Category ID: $categoryId');
      print('DEBUG: URL: $url');
      print('DEBUG: Full URL string: ${url.toString()}');

      final response = await http.get(url);
      print('DEBUG: Response status code: ${response.statusCode}');
      print('DEBUG: Response headers: ${response.headers}');
      print('DEBUG: Response body length: ${response.body.length}');
      print('DEBUG: Full response body:\n${response.body}');

      if (response.statusCode == 200) {
        final resp = json.decode(response.body);
        print('DEBUG: Decoded JSON response: ${json.encode(resp)}');

        final data = resp['data'] ?? resp;
        print('DEBUG: Extracted data type: ${data.runtimeType}');
        print('DEBUG: Data content: ${json.encode(data)}');

        if (data is List) {
          print('DEBUG: ✓ Data is a List');
          setState(() {
            _availableServices = data;
            _selectedServiceId = _availableServices.isNotEmpty
                ? _availableServices[0]['_id']?.toString()
                : null;
            print('DEBUG: Selected first service ID: $_selectedServiceId');

            if (_selectedServiceId != null &&
                _priceController.text.trim().isEmpty) {
              final base = _availableServices[0]['basePrice'] ??
                  _availableServices[0]['baseprice'];
              if (base != null) {
                _priceController.text = base.toString();
                print('DEBUG: Preloaded price: ${base.toString()}');
              }
            }
          });
        } else {
          print(
              'DEBUG: ERROR - Services data is not a List, got: ${data.runtimeType}');
          setState(() {
            _availableServices = [];
            _selectedServiceId = null;
          });
        }
      } else {
        print(
            'DEBUG: ERROR - Failed to fetch services, status: ${response.statusCode}');
        setState(() {
          _availableServices = [];
          _selectedServiceId = null;
        });
      }
    } catch (e) {
      print('DEBUG: ERROR - Exception in _fetchServicesForCategory: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Add a Service'),
          backgroundColor: const Color(0xFFFF7043),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isVerified) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Add a Service'),
          backgroundColor: const Color(0xFFFF7043),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: Colors.orange.shade200,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Account Not Verified',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your documents are pending admin approval. Once your profile is verified by the admin, you will be able to add services and accept jobs from customers.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _checkVerificationStatus,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7043),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a Service'),
        backgroundColor: const Color(0xFFFF7043),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your service details below. Once submitted, it will be reviewed by an admin.',
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            // Category selector
            _categories.isNotEmpty
                ? DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    items: _categories
                        .map((c) => DropdownMenuItem(
                              value: c['_id']?.toString(),
                              child:
                                  Text(c['name'] ?? c['title'] ?? 'Category'),
                            ))
                        .toList(),
                    onChanged: (v) async {
                      print('DEBUG: Category changed to: $v');
                      setState(() {
                        _selectedCategoryId = v;
                        _availableServices = [];
                        _selectedServiceId = null;
                      });
                      if (v != null) {
                        print(
                            'DEBUG: Calling _fetchServicesForCategory with ID: $v');
                        await _fetchServicesForCategory(v);
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Select Category',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'No service categories available. Please refresh or contact admin.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _fetchCategories,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh Categories'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 12),

            // Service selector (depends on selected category)
            _availableServices.isNotEmpty
                ? DropdownButtonFormField<String>(
                    value: _selectedServiceId,
                    items: _availableServices
                        .map((s) => DropdownMenuItem(
                              value: s['_id']?.toString(),
                              child: Text(s['title'] ?? s['name'] ?? 'Service'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      print('DEBUG: Service changed to: $v');
                      setState(() {
                        _selectedServiceId = v;
                      });
                      if (v != null) {
                        final sel = _availableServices.firstWhere(
                            (e) => e['_id']?.toString() == v,
                            orElse: () => null);
                        if (sel != null) {
                          print(
                              'DEBUG: Selected service data: ${json.encode(sel)}');
                          final base = sel['basePrice'] ?? sel['baseprice'];
                          if (base != null &&
                              _priceController.text.trim().isEmpty) {
                            setState(
                                () => _priceController.text = base.toString());
                            print('DEBUG: Preloaded base price: $base');
                          }
                          final desc = sel['description'] ??
                              sel['desc'] ??
                              sel['details'];
                          if (desc != null &&
                              _descriptionController.text.trim().isEmpty) {
                            setState(() =>
                                _descriptionController.text = desc.toString());
                            print('DEBUG: Preloaded description: $desc');
                          }
                        } else {
                          print(
                              'DEBUG: ERROR - Service $v not found in _availableServices');
                        }
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Select Service',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.handyman),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'No services available for this category. Please refresh or contact admin.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          if (_selectedCategoryId != null) {
                            _fetchServicesForCategory(_selectedCategoryId!);
                          } else {
                            _fetchCategories();
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh Services'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Price (e.g., ₹1500)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _experienceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Years of Experience',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.workspace_premium),
              ),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description of Service',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 80),
                  child: Icon(Icons.description),
                ),
              ),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submitService,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7043),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Submit Service',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
