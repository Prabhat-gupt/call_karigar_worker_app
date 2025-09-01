
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:call_karigar_worker_application/screens/add_service_page.dart';

class ServicesByCategoryPage extends StatefulWidget {
  final String categoryId;

  const ServicesByCategoryPage({super.key, required this.categoryId});

  @override
  State<ServicesByCategoryPage> createState() => _ServicesByCategoryPageState();
}

class _ServicesByCategoryPageState extends State<ServicesByCategoryPage> {
  List<dynamic> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    final response = await http.get(Uri.parse('https://call-kaarigar-server.onrender.com/api/services'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final allServices = data['data'] as List;
      final filteredServices = allServices.where((service) {
        final category = service['service_categoryId'];
        return category != null && category['_id'] == widget.categoryId;
      }).toList();

      if (mounted) {
        setState(() {
          _services = filteredServices;
          _isLoading = false;
        });
      }
    } else {
      // Handle error
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load services.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Services'),
        backgroundColor: const Color(0xFFFF7043),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFFFF3E0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: _services.isEmpty
                        ? const Center(child: Text('No services found for this category.'))
                        : ListView.separated(
                            itemCount: _services.length,
                            separatorBuilder: (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final service = _services[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                title: Text(
                                  service['title'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                subtitle: Text(
                                  service['description'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                onTap: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  final workerId = prefs.getString('workerId');
                                  if (workerId != null && mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddServicePage(workerId: workerId),
                                      ),
                                    );
                                  } else if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('User not found. Please log in again.')),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7043),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final workerId = prefs.getString('workerId');
                        if (workerId != null && mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddServicePage(workerId: workerId),
                            ),
                          );
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('User not found. Please log in again.')),
                          );
                        }
                      },
                      child: const Text(
                        'Add a Service',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
