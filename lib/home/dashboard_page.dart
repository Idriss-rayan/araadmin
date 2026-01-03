import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// MODELE PUBLICITÉ
class Ad {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;

  Ad({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  // 🔥 Convertir en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {'title': title, 'description': description, 'createdAt': createdAt};
  }

  // 🔥 Créer depuis Firestore
  factory Ad.fromMap(String id, Map<String, dynamic> map) {
    return Ad(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

/// SERVICE FIREBASE
class AdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName = 'ads';

  // ➕ Créer une pub
  Future<void> createAd({
    required String title,
    required String description,
  }) async {
    await _firestore.collection(collectionName).add({
      'title': title,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 📥 Stream pour récupérer toutes les pubs
  Stream<List<Ad>> getAds() {
    return _firestore
        .collection(collectionName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Ad.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  // 🗑 Supprimer une pub
  Future<void> deleteAd(String id) async {
    await _firestore.collection(collectionName).doc(id).delete();
  }

  // ✏️ Modifier une pub
  Future<void> updateAd({
    required String id,
    required String title,
    required String description,
  }) async {
    await _firestore.collection(collectionName).doc(id).update({
      'title': title,
      'description': description,
    });
  }
}

final AdService adService = AdService();

/// DASHBOARD PAGE
class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  void createAd() async {
    if (titleController.text.isEmpty || descController.text.isEmpty) return;

    await adService.createAd(
      title: titleController.text,
      description: descController.text,
    );

    titleController.clear();
    descController.clear();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Publicité créée')));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Créer une publicité',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: createAd,
                child: const Text('Créer la publicité'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdsListPage()),
                  );
                },
                child: const Text('Voir les publicités'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// PAGE LISTE DES PUBLICITÉS
class AdsListPage extends StatelessWidget {
  const AdsListPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publicités')),
      body: StreamBuilder<List<Ad>>(
        stream: adService.getAds(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucune publicité'));
          }
          final ads = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: ads.length,
            itemBuilder: (context, index) {
              final ad = ads[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.campaign),
                  title: Text(ad.title),
                  subtitle: Text(ad.description),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EditAdPage(ad: ad)),
                        );
                      }
                      if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Supprimer'),
                            content: const Text('Supprimer cette publicité ?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Annuler'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Supprimer'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await adService.deleteAd(ad.id);
                        }
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Modifier')),
                      PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// PAGE MODIFIER UNE PUB
class EditAdPage extends StatefulWidget {
  final Ad ad;
  const EditAdPage({Key? key, required this.ad}) : super(key: key);

  @override
  State<EditAdPage> createState() => _EditAdPageState();
}

class _EditAdPageState extends State<EditAdPage> {
  late TextEditingController titleController;
  late TextEditingController descController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.ad.title);
    descController = TextEditingController(text: widget.ad.description);
  }

  void saveChanges() async {
    await adService.updateAd(
      id: widget.ad.id,
      title: titleController.text,
      description: descController.text,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier la publicité')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Titre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveChanges,
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
