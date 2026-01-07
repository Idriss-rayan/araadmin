import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PressingAdminPage extends StatefulWidget {
  final String categoryName;
  const PressingAdminPage({super.key, required this.categoryName});

  @override
  State<PressingAdminPage> createState() => _PressingAdminPageState();
}

class _PressingAdminPageState extends State<PressingAdminPage> {
  final bool isAdmin = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int selectedServiceIndex = 0;
  List<String> serviceNames = [];

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final snapshot = await _firestore
          .collection('categories')
          .doc(widget.categoryName)
          .collection('services')
          .orderBy('createdAt')
          .get();

      setState(() {
        serviceNames = snapshot.docs.map((e) => e.id).toList();
      });
    } catch (e) {
      print('Erreur lors du chargement des services: $e');
    }
  }

  Stream<QuerySnapshot> _getItemsStream(String serviceName) {
    if (serviceName.isEmpty) {
      return const Stream.empty();
    }

    return _firestore
        .collection('categories')
        .doc(widget.categoryName)
        .collection('services')
        .doc(serviceName)
        .collection('items')
        .orderBy('name')
        .snapshots();
  }

  Future<void> _addService(String name) async {
    if (name.isEmpty) return;

    try {
      await _firestore
          .collection('categories')
          .doc(widget.categoryName)
          .collection('services')
          .doc(name)
          .set({'name': name, 'createdAt': FieldValue.serverTimestamp()});

      await _loadServices();

      final newIndex = serviceNames.indexOf(name);
      if (newIndex != -1) {
        setState(() {
          selectedServiceIndex = newIndex;
        });
      }
    } catch (e) {
      print('Erreur lors de l\'ajout du service: $e');
      _showSnackBar('Erreur: ${e.toString()}');
    }
  }

  Future<void> _addItem(String serviceName, Map<String, dynamic> item) async {
    try {
      await _firestore
          .collection('categories')
          .doc(widget.categoryName)
          .collection('services')
          .doc(serviceName)
          .collection('items')
          .add(item);

      _showSnackBar('Article ajouté avec succès');
    } catch (e) {
      print('Erreur lors de l\'ajout de l\'article: $e');
      _showSnackBar('Erreur: ${e.toString()}');
    }
  }

  Future<void> _deleteItem(String serviceName, String docId) async {
    try {
      await _firestore
          .collection('categories')
          .doc(widget.categoryName)
          .collection('services')
          .doc(serviceName)
          .collection('items')
          .doc(docId)
          .delete();

      _showSnackBar('Article supprimé');
    } catch (e) {
      print('Erreur lors de la suppression: $e');
      _showSnackBar('Erreur: ${e.toString()}');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentService = serviceNames.isEmpty
        ? ''
        : serviceNames[selectedServiceIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.categoryName,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.black87),
              onPressed: () => _showAdminMenu(context),
            ),
        ],
      ),
      body: Column(
        children: [
          if (serviceNames.isNotEmpty)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: serviceNames.length,
                itemBuilder: (context, index) {
                  final selected = index == selectedServiceIndex;
                  return Padding(
                    padding: const EdgeInsets.only(
                      right: 8,
                      top: 12,
                      bottom: 12,
                    ),
                    child: GestureDetector(
                      onTap: () => setState(() => selectedServiceIndex = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? Colors.blue : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? Colors.blue
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          serviceNames[index],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          Expanded(
            child: currentService.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cleaning_services_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Aucun service disponible',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: _getItemsStream(currentService),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Erreur: ${snapshot.error}'));
                      }

                      final items = snapshot.data?.docs ?? [];

                      if (items.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cleaning_services_outlined,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun élément',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ajoutez votre premier article',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final doc = items[index];
                          final item = doc.data() as Map<String, dynamic>;
                          final docId = doc.id;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.dry_cleaning_outlined,
                                  size: 20,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              title: Text(
                                item['name'] ?? 'Sans nom',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                '${item['price']?.toString() ?? '0'} € • ${item['duration'] ?? 'Non spécifié'}',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              trailing: isAdmin
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: Colors.red.shade400,
                                      ),
                                      onPressed: () async {
                                        final confirm = await showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text(
                                              'Confirmer la suppression',
                                            ),
                                            content: Text(
                                              'Supprimer "${item['name']}" ?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Annuler'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text(
                                                  'Supprimer',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          await _deleteItem(
                                            currentService,
                                            docId,
                                          );
                                        }
                                      },
                                    )
                                  : null,
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

  void _showAdminMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.add_business_outlined,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Ajouter un service',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showAddServiceDialog();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.add_circle_outline,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Ajouter un article',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (serviceNames.isNotEmpty) {
                    _showAddItemDialog();
                  } else {
                    _showSnackBar('Veuillez d\'abord créer un service');
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddServiceDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouveau service'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nom du service',
            hintText: 'Ex: Lavage, Repassage...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) {
                _showSnackBar('Veuillez saisir un nom');
                return;
              }
              await _addService(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final durationCtrl = TextEditingController();

    if (serviceNames.isEmpty) return;
    final serviceName = serviceNames[selectedServiceIndex];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Ajouter à "$serviceName"'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'article',
                  hintText: 'Ex: Chemise, Pantalon...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Prix (€)',
                  hintText: 'Ex: 5.99',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Durée',
                  hintText: 'Ex: 24h, 48h...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) {
                _showSnackBar('Veuillez saisir un nom');
                return;
              }

              final price = double.tryParse(priceCtrl.text) ?? 0;
              if (price <= 0) {
                _showSnackBar('Veuillez saisir un prix valide');
                return;
              }

              await _addItem(serviceName, {
                'name': nameCtrl.text.trim(),
                'price': price,
                'duration': durationCtrl.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
              });

              Navigator.pop(context);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}
