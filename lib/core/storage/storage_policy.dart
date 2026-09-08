class StoragePolicy {
  const StoragePolicy();
  bool usesCloud(String membershipType) => membershipType != 'free';
}
