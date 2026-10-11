import 'package:flutter/material.dart';

/// The 3 primary categories for CampusSetu resumes:
/// - [professional]: ATS-friendly, clean, corporate, executive, and structured resumes.
/// - [designed]: Creative, visual, graphic-rich, schematic, and portfolio-heavy resumes.
/// - [modern]: Sleek, high-contrast, minimalist, cyberpunk, and contemporary tech resumes.
enum ResumeCategory {
  professional,
  designed,
  modern;

  String get id => name;

  String get label {
    switch (this) {
      case ResumeCategory.professional:
        return 'Professional';
      case ResumeCategory.designed:
        return 'Designed';
      case ResumeCategory.modern:
        return 'Modern';
    }
  }

  String get emoji {
    switch (this) {
      case ResumeCategory.professional:
        return '💼';
      case ResumeCategory.designed:
        return '🎨';
      case ResumeCategory.modern:
        return '⚡';
    }
  }

  IconData get icon {
    switch (this) {
      case ResumeCategory.professional:
        return Icons.business_center_rounded;
      case ResumeCategory.designed:
        return Icons.palette_rounded;
      case ResumeCategory.modern:
        return Icons.auto_awesome_rounded;
    }
  }

  String get tagline {
    switch (this) {
      case ResumeCategory.professional:
        return 'Corporate & Executive';
      case ResumeCategory.designed:
        return 'Creative & Portfolio';
      case ResumeCategory.modern:
        return 'Tech & Contemporary';
    }
  }

  String get description {
    switch (this) {
      case ResumeCategory.professional:
        return 'ATS-compliant, structured, and formal layouts tailored for corporate, finance, and executive roles.';
      case ResumeCategory.designed:
        return 'Visually expressive layouts with custom aesthetics, ideal for designers, photographers, and media creators.';
      case ResumeCategory.modern:
        return 'Sleek, minimalist, high-contrast aesthetics suited for tech professionals, startups, and developers.';
    }
  }

  static ResumeCategory fromId(String? id, {ResumeCategory fallback = ResumeCategory.professional}) {
    if (id == null) return fallback;
    final lower = id.toLowerCase().trim();
    for (final cat in ResumeCategory.values) {
      if (cat.name == lower) return cat;
    }
    return fallback;
  }
}
