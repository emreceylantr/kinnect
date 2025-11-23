import 'dart:io';

import 'package:kinnect/repositories/profile_repository.dart';

class ProfileService {
  final ProfileRepository _repository;

  ProfileService(this._repository);

  // Create / Update profile
  Future<void> createOrUpdateProfile({
    required String userId,
    required String username,
    required String fullName,
    String? bio,
    File? avatarFile,
  }) async {
    await _repository.upsertProfile(
      userId: userId,
      username: username,
      fullName: fullName,
      bio: bio,
      avatarFile: avatarFile,
    );
  }

  Future<Map<String, dynamic>?> fetchProfile(String userId) {
    return _repository.getProfileById(userId);
  }

  Future<(int, int, int)> getProfileStats(String userId) {
    return _repository.getProfileStats(userId);
  }
}
