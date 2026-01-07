import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_animate/flutter_animate.dart';

class FashionAdminPage extends StatefulWidget {
  final String categoryName;
  const FashionAdminPage({super.key, required this.categoryName});

  @override
  State<FashionAdminPage> createState() => _FashionAdminPageState();
}

class _FashionAdminPageState extends State<FashionAdminPage> {
  final bool isAdmin = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  int _selectedCategoryIndex = 0; // Pour Confection/Prêt-à-porter/Retouches
  int selectedServiceIndex = 0;
  List<String> serviceNames = [];
  List<String> subCategories = ['Confection', 'Prêt-à-porter', 'Retouches'];

  // Contrôleurs pour le scroll
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    if (_selectedCategoryIndex == 2) return; // Pas de services pour Retouches

    try {
      final snapshot = await _firestore
          .collection('fashion')
          .doc(subCategories[_selectedCategoryIndex])
          .collection('services')
          .orderBy('createdAt')
          .get();

      setState(() {
        serviceNames = snapshot.docs.map((e) => e.id).toList();
        if (serviceNames.isNotEmpty &&
            selectedServiceIndex >= serviceNames.length) {
          selectedServiceIndex = 0;
        }
      });
    } catch (e) {
      print('Erreur lors du chargement des services: $e');
    }
  }

  Future<String?> _uploadImage(File imageFile, String serviceName) async {
    try {
      final fileName = path.basename(imageFile.path);
      final storageRef = _storage.ref().child(
        'fashion/${subCategories[_selectedCategoryIndex]}/$serviceName/$fileName',
      );

      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() => null);
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Erreur lors de l\'upload de l\'image: $e');
      return null;
    }
  }

  Stream<QuerySnapshot> _getItemsStream(String serviceName) {
    if (serviceName.isEmpty || _selectedCategoryIndex == 2) {
      return const Stream.empty();
    }

    return _firestore
        .collection('fashion')
        .doc(subCategories[_selectedCategoryIndex])
        .collection('services')
        .doc(serviceName)
        .collection('items')
        .orderBy('createdAt')
        .snapshots();
  }

  Future<void> _addService(String name) async {
    if (name.isEmpty || _selectedCategoryIndex == 2) return;

    try {
      await _firestore
          .collection('fashion')
          .doc(subCategories[_selectedCategoryIndex])
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

  Future<void> _addItem(
    String serviceName,
    Map<String, dynamic> item, {
    File? imageFile,
  }) async {
    try {
      // Si une image est fournie, l'uploader
      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await _uploadImage(imageFile, serviceName);
        if (imageUrl != null) {
          item['imageUrl'] = imageUrl;
        }
      }

      await _firestore
          .collection('fashion')
          .doc(subCategories[_selectedCategoryIndex])
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
      // Récupérer l'item pour supprimer l'image associée
      final doc = await _firestore
          .collection('fashion')
          .doc(subCategories[_selectedCategoryIndex])
          .collection('services')
          .doc(serviceName)
          .collection('items')
          .doc(docId)
          .get();

      final data = doc.data() as Map<String, dynamic>?;

      // Supprimer l'image de Firebase Storage si elle existe
      if (data != null && data['imageUrl'] != null) {
        try {
          final imageUrl = data['imageUrl'] as String;
          final ref = _storage.refFromURL(imageUrl);
          await ref.delete();
        } catch (e) {
          print('Erreur lors de la suppression de l\'image: $e');
        }
      }

      // Supprimer le document Firestore
      await _firestore
          .collection('fashion')
          .doc(subCategories[_selectedCategoryIndex])
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
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF004D40),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(String itemName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Confirmer la suppression',
          style: TextStyle(color: Color(0xFF004D40)),
        ),
        content: Text('Supprimer "$itemName" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Confection':
        return Icons.cut;
      case 'Prêt-à-porter':
        return Icons.shopping_bag;
      case 'Retouches':
        return Icons.content_cut;
      default:
        return Icons.checkroom;
    }
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

              // Afficher l'option "Ajouter un service" seulement si ce n'est pas "Retouches"
              if (_selectedCategoryIndex != 2)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.add_business_outlined,
                      color: const Color(0xFF004D40),
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Ajouter un service',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF004D40),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddServiceDialog();
                  },
                ),

              // Afficher l'option "Ajouter un article" seulement si ce n'est pas "Retouches"
              if (_selectedCategoryIndex != 2)
                Column(
                  children: [
                    if (_selectedCategoryIndex != 2) const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.add_circle_outline,
                          color: const Color(0xFF004D40),
                          size: 24,
                        ),
                      ),
                      title: const Text(
                        'Ajouter un article',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF004D40),
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
                  ],
                ),

              // Option pour Retouches
              if (_selectedCategoryIndex == 2)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: const Color(0xFF004D40),
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Gestion des demandes de retouches',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF004D40),
                    ),
                  ),
                  subtitle: const Text(
                    'Les demandes sont gérées via WhatsApp',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showSnackBar(
                      'Les retouches sont gérées manuellement via WhatsApp',
                    );
                  },
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FDFF),
      body: Column(
        children: [
          // Header animé
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: const [
                  Color(0xFF004D40),
                  Color(0xFF00695C),
                  Color(0xFF4DB6AC),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF004D40).withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Effets de bulles
                ...List.generate(5, (index) {
                  return Positioned(
                    left: 20 + (index * 70) % screenWidth,
                    top: 50 + (index * 20) % 100,
                    child: Container(
                      width: 40 + index * 10,
                      height: 40 + index * 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ).animate().fadeIn(delay: (index * 200).ms);
                }),

                Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 20,
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (isAdmin)
                            IconButton(
                              onPressed: () => _showAdminMenu(context),
                              icon: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.more_vert,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.categoryName,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 28 : 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Onglets de sous-catégories
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: subCategories.asMap().entries.map((entry) {
                  final index = entry.key;
                  final category = entry.value;
                  final isSelected = _selectedCategoryIndex == index;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategoryIndex = index;
                          selectedServiceIndex = 0;
                        });
                        _loadServices();
                      },
                      child: AnimatedContainer(
                        duration: 300.ms,
                        constraints: BoxConstraints(
                          minWidth: isSmallScreen ? 100 : 120,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF004D40),
                                    Color(0xFF00695C),
                                  ],
                                )
                              : null,
                          color: isSelected ? null : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Onglets des services (uniquement pour Confection et Prêt-à-porter)
          if (_selectedCategoryIndex != 2 && serviceNames.isNotEmpty)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
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
                          color: selected
                              ? const Color(0xFF4DB6AC)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF4DB6AC)
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

          // Contenu principal
          Expanded(
            child: _selectedCategoryIndex == 2
                ? _buildRepairsSection()
                : _buildFashionSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildFashionSection() {
    final currentService = serviceNames.isEmpty
        ? ''
        : serviceNames[selectedServiceIndex];

    return Column(
      children: [
        if (serviceNames.isEmpty)
          Expanded(child: _buildEmptyState())
        else
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getItemsStream(currentService),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoading();
                }

                if (snapshot.hasError) {
                  return _buildError(snapshot.error.toString());
                }

                final items = snapshot.data?.docs ?? [];

                if (items.isEmpty) {
                  return _buildEmptyItemsState();
                }

                return _buildItemsList(items, currentService);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRepairsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF004D40).withOpacity(0.1),
                  const Color(0xFF4DB6AC).withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF004D40).withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.content_cut_rounded,
                  size: 60,
                  color: const Color(0xFF004D40),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Service de Retouches',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF004D40),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Gérez les demandes de retouches reçues via WhatsApp',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Comment fonctionnent les retouches ?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF004D40),
            ),
          ),
          const SizedBox(height: 16),
          ..._buildRepairSteps(),
          const SizedBox(height: 32),
          const Text(
            'Conseils pour la gestion des retouches',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF004D40),
            ),
          ),
          const SizedBox(height: 12),
          ..._buildRepairTips(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  List<Widget> _buildRepairSteps() {
    return [
      _buildStepItem(
        icon: Icons.chat_bubble_outline,
        title: '1. Réception des demandes',
        description:
            'Les clients envoient leurs demandes via WhatsApp avec photos et détails',
      ),
      const SizedBox(height: 12),
      _buildStepItem(
        icon: Icons.assessment_outlined,
        title: '2. Évaluation technique',
        description:
            'Analysez la demande pour déterminer le temps et le coût nécessaires',
      ),
      const SizedBox(height: 12),
      _buildStepItem(
        icon: Icons.phone,
        title: '3. Contact client',
        description:
            'Contactez le client pour confirmer les détails et donner un devis',
      ),
      const SizedBox(height: 12),
      _buildStepItem(
        icon: Icons.schedule,
        title: '4. Suivi des retouches',
        description: 'Gardez une trace des retouches en cours et des délais',
      ),
    ];
  }

  List<Widget> _buildRepairTips() {
    return [
      _buildTipItem(tip: 'Toujours demander des photos sous plusieurs angles'),
      _buildTipItem(tip: 'Estimez le temps de travail avant de donner un prix'),
      _buildTipItem(
        tip: 'Gardez une liste des retouches fréquentes pour optimiser',
      ),
      _buildTipItem(
        tip: 'Communiquez régulièrement avec le client sur l\'avancement',
      ),
    ];
  }

  Widget _buildStepItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF004D40)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF004D40),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem({required String tip}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            size: 20,
            color: const Color(0xFF004D40).withOpacity(0.7),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.checkroom_outlined,
              size: 48,
              color: Color(0xFF004D40),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _selectedCategoryIndex == 0
                ? 'Aucun service disponible'
                : 'Aucun article disponible',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF004D40),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedCategoryIndex == 0
                ? 'Ajoutez votre premier service'
                : 'Ajoutez votre premier article',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          if (isAdmin)
            ElevatedButton(
              onPressed: _selectedCategoryIndex == 0
                  ? _showAddServiceDialog
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004D40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(
                _selectedCategoryIndex == 0
                    ? 'Créer un service'
                    : 'Ajouter un article',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF004D40)),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Erreur de chargement',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyItemsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _getCategoryIcon(subCategories[_selectedCategoryIndex]),
              size: 48,
              color: const Color(0xFF004D40),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Aucun article',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF004D40),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez votre premier article',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(
    List<QueryDocumentSnapshot> items,
    String serviceName,
  ) {
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // Image de l'article
              if (item['imageUrl'] != null)
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    image: DecorationImage(
                      image: NetworkImage(item['imageUrl']),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

              // Détails de l'article
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icône si pas d'image
                        if (item['imageUrl'] == null)
                          Container(
                            width: 50,
                            height: 50,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2F1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getCategoryIcon(
                                subCategories[_selectedCategoryIndex],
                              ),
                              size: 24,
                              color: const Color(0xFF004D40),
                            ),
                          ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] ?? 'Sans nom',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Color(0xFF004D40),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item['price']?.toString() ?? '0'} €',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Bouton suppression
                        if (isAdmin)
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.red.shade400,
                            ),
                            onPressed: () async {
                              final confirm = await _showDeleteConfirmation(
                                item['name'],
                              );
                              if (confirm == true) {
                                await _deleteItem(serviceName, docId);
                              }
                            },
                          ),
                      ],
                    ),

                    // Catégorie et description
                    if (item['category'] != null && item['category'].isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF004D40).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item['category'],
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFF004D40),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                    if (item['description'] != null &&
                        item['description'].isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          item['description'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    // Informations spécifiques pour Prêt-à-porter
                    if (_selectedCategoryIndex == 1)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item['size'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.straighten,
                                    size: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Taille: ${item['size']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (item['available'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    item['available'] == true
                                        ? Icons.check_circle_outline
                                        : Icons.remove_circle_outline,
                                    size: 14,
                                    color: item['available'] == true
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    item['available'] == true
                                        ? 'En stock'
                                        : 'Rupture de stock',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: item['available'] == true
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddServiceDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Nouveau service',
          style: TextStyle(
            color: Color(0xFF004D40),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nom du service',
            hintText: subCategories[_selectedCategoryIndex] == 'Confection'
                ? 'Ex: Robes, Costumes, Tenues traditionnelles...'
                : 'Ex: T-shirts, Jeans, Robes...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0F2F1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4DB6AC), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004D40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Ajouter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddItemDialog() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final sizeCtrl = TextEditingController();
    File? selectedImage;
    bool available = true;

    if (serviceNames.isEmpty) return;
    final serviceName = serviceNames[selectedServiceIndex];

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> _pickImage() async {
            final XFile? image = await _picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 1200,
              maxHeight: 1200,
              imageQuality: 85,
            );

            if (image != null) {
              setState(() {
                selectedImage = File(image.path);
              });
            }
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Ajouter à "$serviceName"',
              style: const TextStyle(
                color: Color(0xFF004D40),
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image picker
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF4DB6AC),
                          width: 2,
                          style: selectedImage == null
                              ? BorderStyle.none
                              : BorderStyle.solid,
                        ),
                      ),
                      child: selectedImage == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 40,
                                  color: Color(0xFF004D40),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Ajouter une photo',
                                  style: TextStyle(
                                    color: Color(0xFF004D40),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                selectedImage!,
                                fit: BoxFit.cover,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Nom
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Nom de l\'article',
                      hintText: 'Ex: Robe de soirée, Costume...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0F2F1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF4DB6AC),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Prix
                  TextField(
                    controller: priceCtrl,
                    decoration: InputDecoration(
                      labelText: 'Prix (€)',
                      hintText: 'Ex: 59.99',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0F2F1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF4DB6AC),
                          width: 2,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Catégorie (Homme/Femme/Enfant)
                  TextField(
                    controller: categoryCtrl,
                    decoration: InputDecoration(
                      labelText: 'Catégorie',
                      hintText: 'Ex: Homme, Femme, Enfant...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0F2F1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF4DB6AC),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Taille (spécial pour Prêt-à-porter)
                  if (_selectedCategoryIndex == 1)
                    TextField(
                      controller: sizeCtrl,
                      decoration: InputDecoration(
                        labelText: 'Taille disponible',
                        hintText: 'Ex: S, M, L, XL...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0F2F1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF4DB6AC),
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                  if (_selectedCategoryIndex == 1) const SizedBox(height: 12),

                  // Disponibilité (spécial pour Prêt-à-porter)
                  if (_selectedCategoryIndex == 1)
                    Row(
                      children: [
                        Checkbox(
                          value: available,
                          onChanged: (value) {
                            setState(() {
                              available = value ?? true;
                            });
                          },
                          activeColor: const Color(0xFF004D40),
                        ),
                        const Text('En stock'),
                      ],
                    ),

                  // Description
                  TextField(
                    controller: descriptionCtrl,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'Ex: Taille standard, tissu inclus...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0F2F1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF4DB6AC),
                          width: 2,
                        ),
                      ),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Annuler',
                  style: TextStyle(color: Colors.grey),
                ),
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

                  final itemData = {
                    'name': nameCtrl.text.trim(),
                    'price': price,
                    'category': categoryCtrl.text.trim(),
                    'description': descriptionCtrl.text.trim(),
                    'subCategory': subCategories[_selectedCategoryIndex],
                    'createdAt': FieldValue.serverTimestamp(),
                  };

                  // Ajouter les champs spécifiques au Prêt-à-porter
                  if (_selectedCategoryIndex == 1) {
                    itemData['size'] = sizeCtrl.text.trim();
                    itemData['available'] = available;
                  }

                  await _addItem(
                    serviceName,
                    itemData,
                    imageFile: selectedImage,
                  );

                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Ajouter',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
