enum CollectionStatus { signedOut, loading, ready, unavailable }

class PlanetCollection {
  final Set<String> ids;
  final CollectionStatus status;
  PlanetCollection({Set<String> ids = const {}, required this.status})
    : ids = Set.unmodifiable(ids);
}

abstract interface class PlanetCollectionRepository {
  Stream<PlanetCollection> watch();
}
