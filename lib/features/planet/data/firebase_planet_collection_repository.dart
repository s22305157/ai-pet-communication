import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../domain/planet_collection_repository.dart';

class FirebasePlanetCollectionRepository implements PlanetCollectionRepository {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  FirebasePlanetCollectionRepository({
    required this.auth,
    required this.firestore,
  });

  @override
  Stream<PlanetCollection> watch() => auth.authStateChanges().switchMap((user) {
    if (user == null) {
      return Stream.value(PlanetCollection(status: CollectionStatus.signedOut));
    }
    return firestore
        .collection('users')
        .doc(user.uid)
        .collection('planetCards')
        .snapshots()
        .map(
          (snapshot) => PlanetCollection(
            ids: snapshot.docs.map((doc) => doc.id).toSet(),
            status: CollectionStatus.ready,
          ),
        )
        .onErrorReturn(PlanetCollection(status: CollectionStatus.unavailable))
        .startWith(PlanetCollection(status: CollectionStatus.loading));
  });
}
