import 'package:flutter/material.dart';

enum AchievementRarity { common, rare, epic, legendary }

class Achievement {
  final String id;
  final String name;
  final String description;
  final String category;
  final String conditionType;
  final int conditionValue;
  final int xpReward;
  final AchievementRarity rarity;
  final String imagePath; // Local asset path for badge icon

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.conditionType,
    required this.conditionValue,
    required this.imagePath,
    this.xpReward = 50,
    this.rarity = AchievementRarity.common,
  });

  Color get rarityColor {
    switch (rarity) {
      case AchievementRarity.common:
        return const Color(0xFF9E9E9E);
      case AchievementRarity.rare:
        return const Color(0xFF2196F3);
      case AchievementRarity.epic:
        return const Color(0xFF9C27B0);
      case AchievementRarity.legendary:
        return const Color(0xFFFF9800);
    }
  }

  String get rarityName {
    switch (rarity) {
      case AchievementRarity.common:
        return 'Yaygın';
      case AchievementRarity.rare:
        return 'Nadir';
      case AchievementRarity.epic:
        return 'Destansı';
      case AchievementRarity.legendary:
        return 'Efsanevi';
    }
  }
}

/// 🔥 Ateş Temalı Rozetler - Küçük kullanıcı tabanı için ölçeklendirildi
const List<Achievement> kinnectAchievements = [
  // Sosyal
  Achievement(
    id: 'spark_master',
    name: 'Kıvılcım Ustası',
    description: '10 takipçiye ulaş',
    category: 'social',
    conditionType: 'followers',
    conditionValue: 10,
    imagePath: 'assets/badges/spark_master.png',
    xpReward: 50,
  ),
  Achievement(
    id: 'flame_spreader',
    name: 'Alev Yayıcı',
    description: '25 takipçiye ulaş',
    category: 'social',
    conditionType: 'followers',
    conditionValue: 25,
    imagePath: 'assets/badges/flame_spreader.png',
    xpReward: 100,
    rarity: AchievementRarity.rare,
  ),
  Achievement(
    id: 'hell_king',
    name: 'Cehennem Kralı',
    description: '50 takipçiye ulaş',
    category: 'social',
    conditionType: 'followers',
    conditionValue: 50,
    imagePath: 'assets/badges/hell_king.png',
    xpReward: 200,
    rarity: AchievementRarity.epic,
  ),
  Achievement(
    id: 'phoenix_legend',
    name: 'Anka Efsanesi',
    description: '100 takipçiye ulaş',
    category: 'social',
    conditionType: 'followers',
    conditionValue: 100,
    imagePath: 'assets/badges/phoenix_legend.png',
    xpReward: 500,
    rarity: AchievementRarity.legendary,
  ),

  // İçerik
  Achievement(
    id: 'first_spark',
    name: 'İlk Kıvılcım',
    description: 'İlk postunu paylaş',
    category: 'content',
    conditionType: 'posts',
    conditionValue: 1,
    imagePath: 'assets/badges/first_spark.png',
    xpReward: 25,
  ),
  Achievement(
    id: 'burning_voice',
    name: 'Yanan Ses',
    description: '5 post paylaş',
    category: 'content',
    conditionType: 'posts',
    conditionValue: 5,
    imagePath: 'assets/badges/burning_voice.png',
    xpReward: 50,
  ),
  Achievement(
    id: 'eternal_flame',
    name: 'Sönmeyen Ateş',
    description: '15 post paylaş',
    category: 'content',
    conditionType: 'posts',
    conditionValue: 15,
    imagePath: 'assets/badges/eternal_flame.png',
    xpReward: 100,
    rarity: AchievementRarity.rare,
  ),
  Achievement(
    id: 'wildfire',
    name: 'Orman Yangını',
    description: '30 post paylaş',
    category: 'content',
    conditionType: 'posts',
    conditionValue: 30,
    imagePath: 'assets/badges/wildfire.png',
    xpReward: 200,
    rarity: AchievementRarity.epic,
  ),

  // Etkileşim
  Achievement(
    id: 'match_striker',
    name: 'Kibrit Çakan',
    description: '10 postu alevle',
    category: 'engagement',
    conditionType: 'likes_given',
    conditionValue: 10,
    imagePath: 'assets/badges/match_striker.png',
    xpReward: 30,
  ),
  Achievement(
    id: 'arsonist',
    name: 'Kundakçı',
    description: '50 postu alevle',
    category: 'engagement',
    conditionType: 'likes_given',
    conditionValue: 50,
    imagePath: 'assets/badges/arsonist.png',
    xpReward: 100,
    rarity: AchievementRarity.rare,
  ),
  Achievement(
    id: 'pyromaniac',
    name: 'Piromanyak',
    description: '100 postu alevle',
    category: 'engagement',
    conditionType: 'likes_given',
    conditionValue: 100,
    imagePath: 'assets/badges/pyromaniac.png',
    xpReward: 250,
    rarity: AchievementRarity.epic,
  ),

  // Seri
  Achievement(
    id: 'warming_up',
    name: 'Isınma Turu',
    description: '3 gün üst üste aktif ol',
    category: 'streak',
    conditionType: 'daily_streak',
    conditionValue: 3,
    imagePath: 'assets/badges/warming_up.png',
    xpReward: 30,
  ),
  Achievement(
    id: 'on_fire',
    name: 'Ateştesin!',
    description: '7 gün üst üste aktif ol',
    category: 'streak',
    conditionType: 'daily_streak',
    conditionValue: 7,
    imagePath: 'assets/badges/on_fire.png',
    xpReward: 75,
  ),
  Achievement(
    id: 'unstoppable_blaze',
    name: 'Durdurulamaz Alev',
    description: '14 gün üst üste aktif ol',
    category: 'streak',
    conditionType: 'daily_streak',
    conditionValue: 14,
    imagePath: 'assets/badges/unstoppable_blaze.png',
    xpReward: 150,
    rarity: AchievementRarity.rare,
  ),
  Achievement(
    id: 'eternal_ember',
    name: 'Sonsuz Kor',
    description: '21 gün üst üste aktif ol',
    category: 'streak',
    conditionType: 'daily_streak',
    conditionValue: 21,
    imagePath: 'assets/badges/eternal_ember.png',
    xpReward: 300,
    rarity: AchievementRarity.legendary,
  ),
];
