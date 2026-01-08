import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ShoppingAdminPage extends StatefulWidget {
  const ShoppingAdminPage({super.key});

  @override
  State<ShoppingAdminPage> createState() => _ShoppingAdminPageState();
}

class _ShoppingAdminPageState extends State<ShoppingAdminPage> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  File? _image;
  bool _loading = false;

  final ImagePicker _picker = ImagePicker();

  // 📸 Pick image
  Future<void> pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
      });
    }
  }

  // ☁️ Add product with safe image upload
  Future<void> addProduct() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nom et prix obligatoires')));
      return;
    }

    setState(() => _loading = true);

    String? imageUrl;

    // ⬆️ Try upload image
    if (_image != null) {
      try {
        final fileName = DateTime.now().millisecondsSinceEpoch.toString();
        final ref = FirebaseStorage.instance.ref().child(
          'shopping/$fileName.jpg',
        );

        await ref.putFile(_image!);
        imageUrl = await ref.getDownloadURL();
      } catch (_) {
        imageUrl = null;
      }
    }

    try {
      await FirebaseFirestore.instance.collection('shopping_products').add({
        'name': _nameController.text.trim(),
        'price': int.parse(_priceController.text),
        'imageUrl': imageUrl, // peut être null
        'createdAt': Timestamp.now(),
      });

      _nameController.clear();
      _priceController.clear();
      setState(() => _image = null);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Produit ajouté')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }

    setState(() => _loading = false);
  }

  // ❌ Delete product
  Future<void> deleteProduct(String docId) async {
    await FirebaseFirestore.instance
        .collection('shopping_products')
        .doc(docId)
        .delete();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FDFF),
      appBar: AppBar(
        title: const Text(
          'Admin • Shopping',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: const Color(0xFF1565C0),
      ),
      body: Column(
        children: [
          // ➕ ADD PRODUCT
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du produit',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Prix (FCFA)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: pickImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Choisir une image'),
                    ),
                    const SizedBox(width: 12),
                    if (_image != null)
                      const Icon(Icons.check_circle, color: Colors.green),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : addProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Ajouter le produit',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // 📦 PRODUCTS LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shopping_products')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text('Aucun produit'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index];

                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: data['imageUrl'] != null
                            ? Image.network(
                                data['imageUrl'],
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) {
                                  return _defaultIcon();
                                },
                              )
                            : _defaultIcon(),
                      ),
                      title: Text(data['name']),
                      subtitle: Text('${data['price']} FCFA'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => deleteProduct(data.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🧩 Default image icon
  Widget _defaultIcon() {
    return Container(
      width: 50,
      height: 50,
      color: Colors.grey.shade200,
      child: const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
    );
  }
}
