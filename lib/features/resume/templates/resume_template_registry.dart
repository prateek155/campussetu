import '../models/resume_category.dart';
import '../models/resume_template_definition.dart';
import '../resume_templates.dart';

/// Central registry that manages and filters resume designs across the 3 categories:
/// - [ResumeCategory.professional]
/// - [ResumeCategory.designed]
/// - [ResumeCategory.modern]
class ResumeTemplateRegistry {
  ResumeTemplateRegistry._();
  static final ResumeTemplateRegistry instance = ResumeTemplateRegistry._();

  /// Registry of new Canva-style modular definitions (populated as files are built).
  final Map<String, ResumeTemplateDefinition> _modularDefinitions = {};

  /// Register a new Canva-style modular design.
  void registerModularTemplate(ResumeTemplateDefinition definition) {
    _modularDefinitions[definition.id] = definition;
  }

  /// Get a modular template definition by its ID, if available.
  ResumeTemplateDefinition? getModularDefinition(String id) {
    return _modularDefinitions[id];
  }

  /// Check if a template is handled by a modular definition.
  bool isModular(String id) => _modularDefinitions.containsKey(id);

  /// Returns all available resume templates, optionally filtered by [category].
  /// If [category] is null, returns all templates.
  List<ResumeTemplateSpec> getTemplates({ResumeCategory? category}) {
    if (category == null) {
      return resumeTemplates;
    }
    return resumeTemplates
        .where((template) => template.category == category)
        .toList(growable: false);
  }

  /// Returns the number of templates in a specific category, or total if null.
  int count({ResumeCategory? category}) {
    if (category == null) return resumeTemplates.length;
    return resumeTemplates
        .where((template) => template.category == category)
        .length;
  }

  /// Lookup any template spec by its ID.
  ResumeTemplateSpec? getById(String id) => resumeTemplateById(id);
}
