/// User persona model (20 dimensions for recommendation algorithm)
class UserPersona {
  // Main Category (6 dimensions)
  final double foodCafe;
  final double cultureArt;
  final double activitySports;
  final double natureHealing;
  final double craftExperience;
  final double shopping;

  // Atmosphere (6 dimensions)
  final double quiet;
  final double romantic;
  final double trendy;
  final double privateVibe;
  final double artistic;
  final double energetic;

  // Experience Type (4 dimensions)
  final double passiveEnjoyment;
  final double activeParticipation;
  final double socialBonding;
  final double relaxationFocused;

  // Space Characteristics (4 dimensions)
  final double indoorRatio;
  final double crowdednessExpected;
  final double photoWorthiness;
  final double scenicView;

  UserPersona({
    required this.foodCafe,
    required this.cultureArt,
    required this.activitySports,
    required this.natureHealing,
    required this.craftExperience,
    required this.shopping,
    required this.quiet,
    required this.romantic,
    required this.trendy,
    required this.privateVibe,
    required this.artistic,
    required this.energetic,
    required this.passiveEnjoyment,
    required this.activeParticipation,
    required this.socialBonding,
    required this.relaxationFocused,
    required this.indoorRatio,
    required this.crowdednessExpected,
    required this.photoWorthiness,
    required this.scenicView,
  });

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() {
    return {
      'food_cafe': foodCafe,
      'culture_art': cultureArt,
      'activity_sports': activitySports,
      'nature_healing': natureHealing,
      'craft_experience': craftExperience,
      'shopping': shopping,
      'quiet': quiet,
      'romantic': romantic,
      'trendy': trendy,
      'private_vibe': privateVibe,
      'artistic': artistic,
      'energetic': energetic,
      'passive_enjoyment': passiveEnjoyment,
      'active_participation': activeParticipation,
      'social_bonding': socialBonding,
      'relaxation_focused': relaxationFocused,
      'indoor_ratio': indoorRatio,
      'crowdedness_expected': crowdednessExpected,
      'photo_worthiness': photoWorthiness,
      'scenic_view': scenicView,
    };
  }

  /// Create from JSON response
  factory UserPersona.fromJson(Map<String, dynamic> json) {
    return UserPersona(
      foodCafe: (json['food_cafe'] ?? 0.0).toDouble(),
      cultureArt: (json['culture_art'] ?? 0.0).toDouble(),
      activitySports: (json['activity_sports'] ?? 0.0).toDouble(),
      natureHealing: (json['nature_healing'] ?? 0.0).toDouble(),
      craftExperience: (json['craft_experience'] ?? 0.0).toDouble(),
      shopping: (json['shopping'] ?? 0.0).toDouble(),
      quiet: (json['quiet'] ?? 0.0).toDouble(),
      romantic: (json['romantic'] ?? 0.0).toDouble(),
      trendy: (json['trendy'] ?? 0.0).toDouble(),
      privateVibe: (json['private_vibe'] ?? 0.0).toDouble(),
      artistic: (json['artistic'] ?? 0.0).toDouble(),
      energetic: (json['energetic'] ?? 0.0).toDouble(),
      passiveEnjoyment: (json['passive_enjoyment'] ?? 0.0).toDouble(),
      activeParticipation: (json['active_participation'] ?? 0.0).toDouble(),
      socialBonding: (json['social_bonding'] ?? 0.0).toDouble(),
      relaxationFocused: (json['relaxation_focused'] ?? 0.0).toDouble(),
      indoorRatio: (json['indoor_ratio'] ?? 0.0).toDouble(),
      crowdednessExpected: (json['crowdedness_expected'] ?? 0.0).toDouble(),
      photoWorthiness: (json['photo_worthiness'] ?? 0.0).toDouble(),
      scenicView: (json['scenic_view'] ?? 0.0).toDouble(),
    );
  }
}
