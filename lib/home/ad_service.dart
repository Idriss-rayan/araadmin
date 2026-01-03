import 'package:araadmin/home/dashboard_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String collectionName = 'ads';

  /// ➕ Créer une publicité
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

  /// 📥 Récupérer toutes les pubs
  Stream<List<Ad>> getAds() {
    return _firestore
        .collection(collectionName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Ad.fromMap(doc.id, doc.data());
          }).toList();
        });
  }

  /// 🗑 Supprimer une pub
  Future<void> deleteAd(String id) async {
    await _firestore.collection(collectionName).doc(id).delete();
  }

  /// ✏️ Modifier une pub
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
