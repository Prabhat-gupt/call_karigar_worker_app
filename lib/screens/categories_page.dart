
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:call_karigar_worker_application/screens/services_by_category_page.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<dynamic> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    final response = await http.get(Uri.parse('https://call-kaarigar-server.onrender.com/api/service-categories'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _categories = data['data'];
        _isLoading = false;
      });
    } else {
      // Handle error
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load categories.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Categories'),
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
            : ListView.separated(
                itemCount: _categories.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    title: Text(
                      category['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      category['description'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ServicesByCategoryPage(categoryId: category['_id']),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
