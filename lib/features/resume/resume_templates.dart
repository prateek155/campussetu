import 'package:flutter/material.dart';

enum ResumeTemplateLayout { band, centered, sidebar, editorial }

class ResumeTemplateSpec {
  final String id;
  final String name;
  final String tagline;
  final bool isPremium;
  final Color accent;
  final ResumeTemplateLayout layout;
  final bool serif;

  const ResumeTemplateSpec({
    required this.id,
    required this.name,
    required this.tagline,
    required this.isPremium,
    required this.accent,
    required this.layout,
    this.serif = false,
  });
}

const resumeTemplates = <ResumeTemplateSpec>[
  ResumeTemplateSpec(
      id: 'modern',
      name: 'Modern',
      tagline: 'Bold header, clean sections',
      isPremium: false,
      accent: Color(0xFF47545A),
      layout: ResumeTemplateLayout.band),
  ResumeTemplateSpec(
      id: 'classic',
      name: 'Classic',
      tagline: 'Traditional and balanced',
      isPremium: false,
      accent: Color(0xFF364E6B),
      layout: ResumeTemplateLayout.centered,
      serif: true),
  ResumeTemplateSpec(
      id: 'minimal',
      name: 'Minimal',
      tagline: 'Simple, generous spacing',
      isPremium: false,
      accent: Color(0xFF252525),
      layout: ResumeTemplateLayout.editorial),
  ResumeTemplateSpec(
      id: 'elegant',
      name: 'Elegant',
      tagline: 'Refined typography',
      isPremium: false,
      accent: Color(0xFF806B63),
      layout: ResumeTemplateLayout.centered,
      serif: true),
  ResumeTemplateSpec(
      id: 'professional',
      name: 'Professional',
      tagline: 'Clear corporate structure',
      isPremium: false,
      accent: Color(0xFF315C70),
      layout: ResumeTemplateLayout.band),
  ResumeTemplateSpec(
      id: 'creative',
      name: 'Creative',
      tagline: 'Colorful with a clear hierarchy',
      isPremium: false,
      accent: Color(0xFF8A4E86),
      layout: ResumeTemplateLayout.sidebar),
  ResumeTemplateSpec(
      id: 'standard',
      name: 'Standard',
      tagline: 'ATS-friendly single column',
      isPremium: false,
      accent: Color(0xFF405B4B),
      layout: ResumeTemplateLayout.editorial),
  ResumeTemplateSpec(
      id: 'basic',
      name: 'Basic',
      tagline: 'Straightforward and readable',
      isPremium: false,
      accent: Color(0xFF4E5968),
      layout: ResumeTemplateLayout.editorial),
  ResumeTemplateSpec(
      id: 'clean',
      name: 'Clean',
      tagline: 'Crisp teal accents',
      isPremium: false,
      accent: Color(0xFF008A91),
      layout: ResumeTemplateLayout.band),
  ResumeTemplateSpec(
      id: 'simple',
      name: 'Simple',
      tagline: 'Centered and understated',
      isPremium: false,
      accent: Color(0xFF777777),
      layout: ResumeTemplateLayout.centered,
      serif: true),
  ResumeTemplateSpec(
      id: 'executive',
      name: 'Executive',
      tagline: 'Confident leadership profile',
      isPremium: true,
      accent: Color(0xFF203A55),
      layout: ResumeTemplateLayout.sidebar,
      serif: true),
  ResumeTemplateSpec(
      id: 'luxury',
      name: 'Luxury',
      tagline: 'Deep charcoal with warm gold',
      isPremium: true,
      accent: Color(0xFFAD873F),
      layout: ResumeTemplateLayout.centered,
      serif: true),
  ResumeTemplateSpec(
      id: 'designer',
      name: 'Designer',
      tagline: 'Portfolio-first composition',
      isPremium: true,
      accent: Color(0xFFB34D48),
      layout: ResumeTemplateLayout.editorial),
  ResumeTemplateSpec(
      id: 'corporate',
      name: 'Corporate',
      tagline: 'Polished, structured layout',
      isPremium: true,
      accent: Color(0xFF123A62),
      layout: ResumeTemplateLayout.sidebar),
  ResumeTemplateSpec(
      id: 'tech',
      name: 'Tech',
      tagline: 'Technical skills up front',
      isPremium: true,
      accent: Color(0xFF4F46A5),
      layout: ResumeTemplateLayout.band),
  ResumeTemplateSpec(
      id: 'artistic',
      name: 'Artistic',
      tagline: 'Distinctive editorial style',
      isPremium: true,
      accent: Color(0xFFB15E35),
      layout: ResumeTemplateLayout.centered,
      serif: true),
  ResumeTemplateSpec(
      id: 'futuristic',
      name: 'Futuristic',
      tagline: 'Sharp lines and vivid contrast',
      isPremium: true,
      accent: Color(0xFF087E8B),
      layout: ResumeTemplateLayout.sidebar),
  ResumeTemplateSpec(
      id: 'elite',
      name: 'Elite',
      tagline: 'Premium executive finish',
      isPremium: true,
      accent: Color(0xFF563E75),
      layout: ResumeTemplateLayout.band,
      serif: true),
  ResumeTemplateSpec(
      id: 'platinum',
      name: 'Platinum',
      tagline: 'Quiet luxury in slate',
      isPremium: true,
      accent: Color(0xFF71808A),
      layout: ResumeTemplateLayout.editorial,
      serif: true),
  ResumeTemplateSpec(
      id: 'premium',
      name: 'Premium',
      tagline: 'Modern signature design',
      isPremium: true,
      accent: Color(0xFF087C73),
      layout: ResumeTemplateLayout.centered),
];

ResumeTemplateSpec? resumeTemplateById(String id) {
  for (final template in resumeTemplates) {
    if (template.id == id) return template;
  }
  return null;
}

Map<String, dynamic> defaultResumeDocument({Map<String, dynamic>? profile}) {
  final user = profile ?? const <String, dynamic>{};
  final name = (user['name'] ?? '').toString();
  return {
    'title': name.isEmpty ? 'My Resume' : '$name Resume',
    'personal': {
      'name': name,
      'headline': '',
      'email': (user['email'] ?? '').toString(),
      'phone': (user['phone'] ?? '').toString(),
      'location': [user['city'], user['state']]
          .where((part) => part != null && part.toString().trim().isNotEmpty)
          .join(', '),
      'linkedin': '',
      'website': '',
      'github': '',
    },
    'personalFields': [
      {'key': 'name', 'label': 'Full name'},
      {'key': 'headline', 'label': 'Professional title'},
      {'key': 'email', 'label': 'Email'},
      {'key': 'phone', 'label': 'Phone'},
      {'key': 'location', 'label': 'City / location'},
      {'key': 'linkedin', 'label': 'LinkedIn URL'},
      {'key': 'website', 'label': 'Portfolio / website'},
      {'key': 'github', 'label': 'GitHub URL'},
    ],
    'sections': _defaultSections(),
  };
}

List<Map<String, dynamic>> _defaultSections() => [
      _section('summary', 'Professional summary', [
        _field('summary', 'Summary', true),
      ]),
      _section('experience', 'Work experience', [
        _field('role', 'Job title / role'),
        _field('organization', 'Company'),
        _field('location', 'City / location'),
        _field('startDate', 'Start date'),
        _field('endDate', 'End date'),
        _field('description', 'Responsibilities and impact', true),
      ]),
      _section('education', 'Education', [
        _field('degree', 'Degree / course'),
        _field('institution', 'College / institution'),
        _field('location', 'City / location'),
        _field('startDate', 'Start date'),
        _field('endDate', 'End date'),
        _field('grade', 'CGPA / grade'),
        _field('description', 'Relevant coursework or details', true),
      ]),
      _section('projects', 'Projects', [
        _field('title', 'Project name'),
        _field('technologies', 'Technologies / tools'),
        _field('url', 'Project URL'),
        _field('description', 'What you built and the impact', true),
      ]),
      _section('skills', 'Skills', [
        _field('skill', 'Skill'),
        _field('level', 'Level / context'),
      ]),
      _section('certifications', 'Certifications', [
        _field('name', 'Certificate'),
        _field('issuer', 'Issuing organization'),
        _field('date', 'Date'),
        _field('url', 'Credential URL'),
      ]),
      _section('languages', 'Languages', [
        _field('language', 'Language'),
        _field('proficiency', 'Proficiency'),
      ]),
      _section('awards', 'Awards and achievements', [
        _field('title', 'Award / achievement'),
        _field('issuer', 'Organization'),
        _field('date', 'Date'),
        _field('description', 'Details', true),
      ]),
      _section('volunteer', 'Volunteer experience', [
        _field('role', 'Role'),
        _field('organization', 'Organization'),
        _field('startDate', 'Start date'),
        _field('endDate', 'End date'),
        _field('description', 'Contribution', true),
      ]),
      _section('publications', 'Publications', [
        _field('title', 'Publication title'),
        _field('publisher', 'Journal / publisher'),
        _field('date', 'Date'),
        _field('url', 'Link'),
      ]),
      _section('interests', 'Interests', [
        _field('interest', 'Interest'),
        _field('description', 'Details', true),
      ]),
      _section('references', 'References', [
        _field('name', 'Name'),
        _field('role', 'Role / relationship'),
        _field('organization', 'Organization'),
        _field('email', 'Email or phone'),
      ]),
    ];

Map<String, dynamic> _section(
        String kind, String title, List<Map<String, dynamic>> fields) =>
    {
      'id': kind,
      'kind': kind,
      'title': title,
      'fields': fields,
      'entries': <Map<String, dynamic>>[],
    };

Map<String, dynamic> _field(String key, String label,
        [bool multiline = false]) =>
    {
      'key': key,
      'label': label,
      'multiline': multiline,
    };

Map<String, dynamic> sampleResumeDocument() => {
      'title': 'Sample resume',
      'personal': {
        'name': 'Diya Agarwal',
        'headline': 'Retail Sales Associate',
        'email': 'd.agarwal@example.com',
        'phone': '+91 11 5555 3345',
        'location': 'New Delhi, India',
        'linkedin': 'linkedin.com/in/diyaagarwal',
        'website': 'diyaagarwal.dev',
        'github': '',
      },
      'personalFields': [
        {'key': 'name', 'label': 'Full name'},
        {'key': 'headline', 'label': 'Professional title'},
        {'key': 'email', 'label': 'Email'},
        {'key': 'phone', 'label': 'Phone'},
        {'key': 'location', 'label': 'City / location'},
        {'key': 'linkedin', 'label': 'LinkedIn URL'},
      ],
      'sections': [
        {
          'id': 'summary',
          'kind': 'summary',
          'title': 'Summary',
          'fields': [_field('summary', 'Summary', true)],
          'entries': [
            {
              'id': 'sample-summary',
              'summary':
                  'Customer-focused retail sales professional with solid understanding of retail dynamics, marketing and customer service. Proven track record of exceeding revenue goals and supporting a positive customer experience.'
            },
          ],
        },
        {
          'id': 'skills',
          'kind': 'skills',
          'title': 'Skills',
          'fields': [_field('skill', 'Skill'), _field('level', 'Level')],
          'entries': [
            {'id': 'sample-s1', 'skill': 'Cash register operation'},
            {'id': 'sample-s2', 'skill': 'Customer service'},
            {'id': 'sample-s3', 'skill': 'Sales operations'},
            {'id': 'sample-s4', 'skill': 'Inventory management'},
          ],
        },
        {
          'id': 'experience',
          'kind': 'experience',
          'title': 'Experience',
          'fields': [
            _field('role', 'Role'),
            _field('organization', 'Company'),
            _field('startDate', 'From'),
            _field('endDate', 'To'),
            _field('description', 'Details', true)
          ],
          'entries': [
            {
              'id': 'sample-e1',
              'role': 'Retail Sales Associate',
              'organization': 'ZARA · New Delhi',
              'startDate': 'Feb 2017',
              'endDate': 'Current',
              'description':
                  'Increased monthly sales by 10% by improving product presentation. Maintained accurate drawers and resolved customer issues.'
            },
            {
              'id': 'sample-e2',
              'role': 'Barista',
              'organization': 'Dunkin’ Donuts · New Delhi',
              'startDate': 'Mar 2015',
              'endDate': 'Jan 2017',
              'description':
                  'Delivered friendly service and trained new staff on store procedures.'
            },
          ],
        },
        {
          'id': 'education',
          'kind': 'education',
          'title': 'Education and training',
          'fields': [
            _field('degree', 'Degree'),
            _field('institution', 'Institution'),
            _field('endDate', 'Year')
          ],
          'entries': [
            {
              'id': 'sample-ed1',
              'degree': 'Diploma in Financial Accounting',
              'institution': 'Oxford Software Institute',
              'endDate': '2016'
            },
          ],
        },
        {
          'id': 'languages',
          'kind': 'languages',
          'title': 'Languages',
          'fields': [
            _field('language', 'Language'),
            _field('proficiency', 'Proficiency')
          ],
          'entries': [
            {'id': 'sample-l1', 'language': 'Hindi', 'proficiency': 'Native'},
            {'id': 'sample-l2', 'language': 'English', 'proficiency': 'C2'},
          ],
        },
      ],
    };
