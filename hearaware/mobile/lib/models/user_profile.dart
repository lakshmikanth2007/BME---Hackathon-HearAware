enum UserProfile {
  blind('Blind', 'Audio output'),
  deaf('Deaf', 'Visual alerts');

  const UserProfile(this.label, this.outputLabel);
  final String label;
  final String outputLabel;

  static UserProfile? fromName(String? n) {
    for (final p in UserProfile.values) {
      if (p.name == n) return p;
    }
    return null;
  }
}

enum AwarenessMode { real, demo }
