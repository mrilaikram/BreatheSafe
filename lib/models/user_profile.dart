import 'package:flutter/material.dart';

enum AgeGroup {
  child('Child', '0–12', Icons.child_care),
  youth('Youth', '13–24', Icons.face),
  adult('Adult', '25–60', Icons.person),
  senior('Senior', '60+', Icons.elderly);

  final String label;
  final String range;
  final IconData icon;

  const AgeGroup(this.label, this.range, this.icon);
}

enum RespiratoryCondition {
  none('None / Normal Breathing', Icons.health_and_safety, 'No known respiratory issues'),
  asthma('Asthma', Icons.air, 'Reactive airway condition'),
  chronicWheezing('Chronic Wheezing', Icons.waves, 'Persistent wheezing episodes'),
  dustAllergy('Dust Allergy / Sinusitis', Icons.masks, 'Sensitivity to airborne particles');

  final String label;
  final IconData icon;
  final String description;

  const RespiratoryCondition(this.label, this.icon, this.description);
}

class UserProfile {
  final AgeGroup? ageGroup;
  final Set<RespiratoryCondition> conditions;

  const UserProfile({
    this.ageGroup,
    this.conditions = const {},
  });

  UserProfile copyWith({
    AgeGroup? ageGroup,
    Set<RespiratoryCondition>? conditions,
  }) {
    return UserProfile(
      ageGroup: ageGroup ?? this.ageGroup,
      conditions: conditions ?? this.conditions,
    );
  }

  bool get isComplete => ageGroup != null && conditions.isNotEmpty;
}
