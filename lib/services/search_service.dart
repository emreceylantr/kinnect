import 'package:kinnect/repositories/profile_repository.dart';

class SearchService {
  final ProfileRepository _profileRepository;

  SearchService(this._profileRepository);

  /// Search ekranında kullanılan stream
  Stream<List<Map<String, dynamic>>> searchProfiles(String query) {
    return _profileRepository.searchProfilesByUsername(query);
  }
}
