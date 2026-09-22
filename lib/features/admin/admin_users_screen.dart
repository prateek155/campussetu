// lib/features/admin/admin_users_screen.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const _bg       = Color(0xFF0D0F1A);
  static const _card     = Color(0xFF141728);
  static const _cardAlt  = Color(0xFF1C2033);
  static const _border   = Color(0xFF252840);
  static const _cyan     = Color(0xFF3FD8F5);
  static const _green    = Color(0xFF22C55E);
  static const _red      = Color(0xFFEF4444);
  static const _purple   = Color(0xFF8B5CF6);
  static const _inkSoft  = Color(0xFF9CA3AF);

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool? _filterBanned; // null = all, true = banned, false = active

  // Location & College Filters
  String? _filterState;
  String? _filterCity;
  String? _filterCollege;

  // View Mode: 0 = Flat List, 1 = By College, 2 = By City & State
  int _viewMode = 0;

  // Meta data for dropdowns
  List<String> _metaStates = [];
  List<String> _metaCities = [];
  List<String> _metaColleges = [];

  // Expanded groups tracker for segregated view
  final Set<String> _expandedGroups = {};

  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _fetchMeta();
    _fetchUsers(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _fetchUsers(reset: true));
  }

  Future<void> _fetchMeta() async {
    try {
      final res = await ApiService().getAdminUsersMeta();
      if (mounted) {
        setState(() {
          _metaStates = List<String>.from(res['states'] ?? []);
          _metaCities = List<String>.from(res['cities'] ?? []);
          _metaColleges = List<String>.from(res['colleges'] ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchUsers({bool reset = false}) async {
    if (!reset && (!_hasMore || _loadingMore)) return;
    if (reset) {
      setState(() { _loading = true; _page = 1; _hasMore = true; _error = null; });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) ApiService().setToken(token);
      }
      final pageNum = reset ? 1 : _page;
      final data = await ApiService().getAdminUsers(
        page: pageNum,
        q: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        isBanned: _filterBanned,
        state: _filterState,
        city: _filterCity,
        college: _filterCollege,
      );

      final raw = data['users'] ?? data['data'] ?? data['results'] ?? data['items'] ?? [];
      final list = (raw is List)
          ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];

      if (mounted) {
        setState(() {
          if (reset) {
            _users = list;
            _page = 2;
          } else {
            _users.addAll(list);
            _page++;
          }
          _hasMore = list.length >= 20;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _loadingMore = false; _error = e.toString(); });
      }
    }
  }

  Future<void> _toggleBlock(Map<String, dynamic> user) async {
    final id = (user['_id'] ?? user['id'] ?? '').toString();
    if (id.isEmpty) return;
    final isBanned = user['is_banned'] ?? user['isBanned'] ?? false;
    try {
      if (isBanned == true) {
        await ApiService().unblockUser(id);
      } else {
        await ApiService().blockUser(id);
      }
      _fetchUsers(reset: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isBanned == true ? 'User unblocked successfully' : 'User blocked successfully'),
          backgroundColor: isBanned == true ? _green : _red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  void _showUserSheet(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserDetailSheet(
        user: user,
        onBlockToggle: () => _toggleBlock(user),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        String? tempState = _filterState;
        String? tempCity = _filterCity;
        String? tempCollege = _filterCollege;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: _card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _border)),
              title: Row(
                children: [
                  const Icon(Icons.filter_alt_outlined, color: _cyan, size: 22),
                  const SizedBox(width: 8),
                  const Text('Filter Users', style: TextStyle(color: Color(0xFFE9EBEE), fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: _inkSoft, size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // State Filter
                      const Text('State', style: TextStyle(color: _inkSoft, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _buildDropdown(
                        hint: 'All States',
                        value: tempState,
                        items: _metaStates,
                        onChanged: (val) => setModalState(() => tempState = val),
                      ),
                      const SizedBox(height: 16),

                      // City Filter
                      const Text('City', style: TextStyle(color: _inkSoft, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _buildDropdown(
                        hint: 'All Cities',
                        value: tempCity,
                        items: _metaCities,
                        onChanged: (val) => setModalState(() => tempCity = val),
                      ),
                      const SizedBox(height: 16),

                      // College Filter
                      const Text('College', style: TextStyle(color: _inkSoft, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _buildDropdown(
                        hint: 'All Colleges',
                        value: tempCollege,
                        items: _metaColleges,
                        onChanged: (val) => setModalState(() => tempCollege = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filterState = null;
                      _filterCity = null;
                      _filterCollege = null;
                    });
                    Navigator.pop(context);
                    _fetchUsers(reset: true);
                  },
                  child: const Text('Reset All', style: TextStyle(color: _red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cyan,
                    foregroundColor: const Color(0xFF0D0F1A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    setState(() {
                      _filterState = tempState;
                      _filterCity = tempCity;
                      _filterCollege = tempCollege;
                    });
                    Navigator.pop(context);
                    _fetchUsers(reset: true);
                  },
                  child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _cardAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: _inkSoft, fontSize: 13)),
          isExpanded: true,
          dropdownColor: _cardAlt,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _inkSoft),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(hint, style: const TextStyle(color: _inkSoft, fontSize: 13)),
            ),
            ...items.map((item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(color: Color(0xFFE9EBEE), fontSize: 13), overflow: TextOverflow.ellipsis),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  // Grouped maps for segregation
  Map<String, List<Map<String, dynamic>>> _getGroupedUsers() {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final u in _users) {
      String key;
      if (_viewMode == 1) {
        // College wise
        final clg = (u['college'] ?? u['college_name'] ?? '').toString().trim();
        key = clg.isNotEmpty ? clg : 'Unspecified College';
      } else {
        // City & State wise
        final city = (u['city'] ?? '').toString().trim();
        final state = (u['state'] ?? '').toString().trim();
        if (city.isNotEmpty && state.isNotEmpty) {
          key = '$city, $state';
        } else if (city.isNotEmpty) {
          key = city;
        } else if (state.isNotEmpty) {
          key = state;
        } else {
          key = 'Unspecified Location';
        }
      }
      groups.putIfAbsent(key, () => []).add(u);
    }
    return groups;
  }

  bool get _hasActiveLocationFilter =>
      _filterState != null || _filterCity != null || _filterCollege != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          // ── Header & Filter Bar ───────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            decoration: const BoxDecoration(
              color: _card,
              border: Border(bottom: BorderSide(color: _border, width: 1)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Title & Top Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('User Management', style: TextStyle(color: Color(0xFFE9EBEE), fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        'Total ${_users.length} loaded • Segregate by city, state & college',
                        style: const TextStyle(color: _inkSoft, fontSize: 12),
                      ),
                    ],
                  ),
                  // Filter button
                  GestureDetector(
                    onTap: _showFilterDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _hasActiveLocationFilter ? _cyan.withValues(alpha: 0.15) : _cardAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _hasActiveLocationFilter ? _cyan : _border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, color: _hasActiveLocationFilter ? _cyan : _inkSoft, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _hasActiveLocationFilter ? 'Filters (Active)' : 'Filter Locations',
                            style: TextStyle(
                              color: _hasActiveLocationFilter ? _cyan : const Color(0xFFE9EBEE),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search Bar
              Container(
                decoration: BoxDecoration(color: _cardAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Color(0xFFE9EBEE), fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search by name, email, campus ID, college...',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Status Filter & View Mode Controls
              Row(
                children: [
                  // Status chips
                  _FilterChip(label: 'All', isSelected: _filterBanned == null, onTap: () { setState(() => _filterBanned = null); _fetchUsers(reset: true); }),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Active', isSelected: _filterBanned == false, color: _green, onTap: () { setState(() => _filterBanned = false); _fetchUsers(reset: true); }),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Banned', isSelected: _filterBanned == true, color: _red, onTap: () { setState(() => _filterBanned = true); _fetchUsers(reset: true); }),

                  const Spacer(),

                  // Segregation View Mode Switcher
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: _cardAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
                    child: Row(
                      children: [
                        _ModeTab(icon: Icons.list_rounded, label: 'List', isSelected: _viewMode == 0, onTap: () => setState(() => _viewMode = 0)),
                        _ModeTab(icon: Icons.school_outlined, label: 'College', isSelected: _viewMode == 1, onTap: () => setState(() => _viewMode = 1)),
                        _ModeTab(icon: Icons.location_on_outlined, label: 'City/State', isSelected: _viewMode == 2, onTap: () => setState(() => _viewMode = 2)),
                      ],
                    ),
                  ),
                ],
              ),

              // Active filter tags bar
              if (_hasActiveLocationFilter) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_filterState != null)
                      _ActiveTag(label: 'State: $_filterState', onClear: () { setState(() => _filterState = null); _fetchUsers(reset: true); }),
                    if (_filterCity != null)
                      _ActiveTag(label: 'City: $_filterCity', onClear: () { setState(() => _filterCity = null); _fetchUsers(reset: true); }),
                    if (_filterCollege != null)
                      _ActiveTag(label: 'College: $_filterCollege', onClear: () { setState(() => _filterCollege = null); _fetchUsers(reset: true); }),
                    TextButton(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                      onPressed: () {
                        setState(() {
                          _filterState = null;
                          _filterCity = null;
                          _filterCollege = null;
                        });
                        _fetchUsers(reset: true);
                      },
                      child: const Text('Clear all', style: TextStyle(color: _cyan, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ]),
          ),

          // ── User List / Segregated View ───────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _cyan))
                : _error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, color: _red, size: 48),
                    const SizedBox(height: 12),
                    const Text('Failed to load users', style: TextStyle(color: Color(0xFFE9EBEE), fontSize: 15)),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(_error!, style: const TextStyle(color: _inkSoft, fontSize: 12), textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => _fetchUsers(reset: true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: _cyan.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _cyan.withValues(alpha: 0.4)),
                        ),
                        child: const Text('Retry', style: TextStyle(color: _cyan, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]))
                : _users.isEmpty
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.people_outline, color: _inkSoft, size: 52),
                    SizedBox(height: 12),
                    Text('No users match the selected filters', style: TextStyle(color: _inkSoft, fontSize: 14)),
                  ]))
                : RefreshIndicator(
                    color: _cyan,
                    backgroundColor: _card,
                    onRefresh: () => _fetchUsers(reset: true),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 950;

                        if (_viewMode == 0) {
                          // Standard flat list or 2-column desktop grid
                          return _buildFlatListView(isDesktop);
                        } else {
                          // Segregated accordion view (by College or City/State)
                          return _buildSegregatedView(isDesktop);
                        }
                      },
                    ),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _buildFlatListView(bool isDesktop) {
    if (isDesktop) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.6,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: _users.length + (_hasMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == _users.length) return _buildLoadMoreTile();
          final u = _users[i];
          return _UserCard(user: u, onTap: () => _showUserSheet(u), onBlockToggle: () => _toggleBlock(u));
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _users.length + (_hasMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == _users.length) return _buildLoadMoreTile();
        final u = _users[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _UserCard(user: u, onTap: () => _showUserSheet(u), onBlockToggle: () => _toggleBlock(u)),
        ).animate(delay: (i * 15).ms).fadeIn(duration: 220.ms);
      },
    );
  }

  Widget _buildSegregatedView(bool isDesktop) {
    final groups = _getGroupedUsers();
    final groupKeys = groups.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: groupKeys.length,
      itemBuilder: (ctx, idx) {
        final key = groupKeys[idx];
        final groupUsers = groups[key]!;
        final isExpanded = _expandedGroups.contains(key) || _expandedGroups.isEmpty && idx == 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              // Group Header
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    if (_expandedGroups.contains(key)) {
                      _expandedGroups.remove(key);
                    } else {
                      _expandedGroups.add(key);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (_viewMode == 1 ? _purple : _cyan).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _viewMode == 1 ? Icons.school_rounded : Icons.location_on_rounded,
                          color: _viewMode == 1 ? _purple : _cyan,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          key,
                          style: const TextStyle(color: Color(0xFFE9EBEE), fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _cyan.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _cyan.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '${groupUsers.length} students',
                          style: const TextStyle(color: _cyan, fontWeight: FontWeight.w600, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: _inkSoft,
                      ),
                    ],
                  ),
                ),
              ),

              // Group User Cards
              if (isExpanded) ...[
                const Divider(height: 1, color: _border),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: isDesktop
                      ? GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.6,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: groupUsers.length,
                          itemBuilder: (ctx, i) {
                            final u = groupUsers[i];
                            return _UserCard(user: u, onTap: () => _showUserSheet(u), onBlockToggle: () => _toggleBlock(u));
                          },
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: groupUsers.length,
                          itemBuilder: (ctx, i) {
                            final u = groupUsers[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _UserCard(user: u, onTap: () => _showUserSheet(u), onBlockToggle: () => _toggleBlock(u)),
                            );
                          },
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadMoreTile() {
    return _loadingMore
        ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _cyan)))
        : Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: () => _fetchUsers(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _cyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _cyan.withValues(alpha: 0.3)),
                  ),
                  child: const Text('Load more', style: TextStyle(color: _cyan, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
            ),
          );
  }
}

// ── Helper Widgets ──────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF3FD8F5);
    const card = Color(0xFF141728);
    const border = Color(0xFF252840);
    const inkSoft = Color(0xFF9CA3AF);
    final c = color ?? cyan;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? c.withValues(alpha: 0.15) : card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? c.withValues(alpha: 0.5) : border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? c : inkSoft,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeTab({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF3FD8F5);
    const inkSoft = Color(0xFF9CA3AF);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? cyan.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? cyan : inkSoft),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: isSelected ? cyan : inkSoft, fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveTag extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const _ActiveTag({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF3FD8F5).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3FD8F5).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF3FD8F5), fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close, size: 12, color: Color(0xFF3FD8F5)),
          ),
        ],
      ),
    );
  }
}

// ── User Card ────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  final VoidCallback onBlockToggle;

  const _UserCard({required this.user, required this.onTap, required this.onBlockToggle});

  @override
  Widget build(BuildContext context) {
    const card    = Color(0xFF141728);
    const border  = Color(0xFF252840);
    const cyan    = Color(0xFF3FD8F5);
    const green   = Color(0xFF22C55E);
    const red     = Color(0xFFEF4444);
    const orange  = Color(0xFFF59E0B);
    const purple  = Color(0xFF8B5CF6);

    final name        = (user['name']           ?? user['full_name']     ?? user['displayName'] ?? 'Unknown').toString();
    final email       = (user['email']           ?? '').toString();
    final college     = (user['college']         ?? user['college_name'] ?? '').toString();
    final state       = (user['state']           ?? '').toString().trim();
    final city        = (user['city']            ?? '').toString().trim();
    final year        = (user['year']            ?? user['year_of_study'] ?? '').toString();
    final points      = (user['points']          ?? 0).toString();
    final posts       = (user['posts_count']     ?? user['post_count']   ?? 0).toString();
    final conns       = (user['connections_count']?? user['connectionsCount'] ?? 0).toString();
    final isBanned    = user['is_banned']        ?? user['isBanned']     ?? false;
    final isAdmin     = user['is_admin']         ?? user['isAdmin']      ?? false;
    final initial     = name.isNotEmpty ? name[0].toUpperCase() : '?';

    Color statusColor; String statusText;
    if (isBanned == true)  { statusColor = red;   statusText = 'Banned'; }
    else if (isAdmin == true) { statusColor = cyan;  statusText = 'Admin';  }
    else                   { statusColor = green; statusText = 'Active'; }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Avatar
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isBanned == true
                    ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                    : [const Color(0xFF3FD8F5), const Color(0xFF1BA8C4)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(name, style: const TextStyle(color: Color(0xFFE9EBEE), fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 2),
              Text(email, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11), overflow: TextOverflow.ellipsis),
              
              // College tag
              if (college.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.school_rounded, color: purple, size: 12),
                  const SizedBox(width: 4),
                  Expanded(child: Text(
                    college + (year.isNotEmpty && year != 'null' ? ' • Yr $year' : ''),
                    style: const TextStyle(color: Color(0xFFE9EBEE), fontSize: 11, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  )),
                ]),
              ],

              // Location tag (City, State)
              if (city.isNotEmpty || state.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.location_on_rounded, color: cyan, size: 11),
                  const SizedBox(width: 3),
                  Expanded(child: Text(
                    '${city.isNotEmpty ? city : ''}${city.isNotEmpty && state.isNotEmpty ? ', ' : ''}${state.isNotEmpty ? state : ''}',
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  )),
                ]),
              ],

              const SizedBox(height: 6),
              Row(children: [
                _MiniStat(icon: Icons.star_rounded, value: points, color: orange),
                const SizedBox(width: 10),
                _MiniStat(icon: Icons.feed_rounded, value: posts, color: cyan),
                const SizedBox(width: 10),
                _MiniStat(icon: Icons.people_rounded, value: conns, color: green),
              ]),
            ]),
          ),

          const SizedBox(width: 8),

          // Block button
          GestureDetector(
            onTap: onBlockToggle,
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: isBanned == true ? green.withValues(alpha: 0.1) : red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isBanned == true ? green.withValues(alpha: 0.3) : red.withValues(alpha: 0.3)),
              ),
              child: Icon(
                isBanned == true ? Icons.lock_open_rounded : Icons.block_rounded,
                color: isBanned == true ? green : red,
                size: 16,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _MiniStat({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 11),
      const SizedBox(width: 3),
      Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ]);
  }
}

// ── User Detail Bottom Sheet ─────────────────────────────────

class _UserDetailSheet extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onBlockToggle;

  const _UserDetailSheet({required this.user, required this.onBlockToggle});

  @override
  Widget build(BuildContext context) {
    const cardAlt = Color(0xFF1C2033);
    const border  = Color(0xFF252840);
    const cyan    = Color(0xFF3FD8F5);
    const green   = Color(0xFF22C55E);
    const red     = Color(0xFFEF4444);
    const orange  = Color(0xFFF59E0B);

    final name      = (user['name']            ?? user['full_name']      ?? user['displayName']     ?? 'Unknown').toString();
    final email     = (user['email']           ?? '').toString();
    final campusId  = (user['campus_id']       ?? user['campusId']       ?? '').toString();
    final college   = (user['college']         ?? user['college_name']   ?? '').toString();
    final state     = (user['state']           ?? '').toString();
    final city      = (user['city']            ?? '').toString();
    final year      = (user['year']            ?? user['year_of_study']  ?? '').toString();
    final branch    = (user['branch']          ?? '').toString();
    final points    = (user['points']          ?? 0).toString();
    final posts     = (user['posts_count']     ?? user['post_count']     ?? 0).toString();
    final conns     = (user['connections_count']?? user['connectionsCount']?? 0).toString();
    final isBanned  = user['is_banned']        ?? user['isBanned']       ?? false;
    final isAdmin   = user['is_admin']         ?? user['isAdmin']        ?? false;
    final initial   = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Color(0xFF141728),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(margin: const EdgeInsets.only(top: 14, bottom: 22), width: 40, height: 4, decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2))),

          // Avatar
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isBanned == true
                    ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                    : [const Color(0xFF3FD8F5), const Color(0xFF1BA8C4)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28))),
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(color: Color(0xFFE9EBEE), fontSize: 20, fontWeight: FontWeight.w700)),
          if (campusId.isNotEmpty && campusId != 'null') ...[
            const SizedBox(height: 4),
            Text(campusId, style: const TextStyle(color: Color(0xFF3FD8F5), fontSize: 13, fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: 2),
          Text(email, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),

          const SizedBox(height: 22),

          // Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(children: [
                if (college.isNotEmpty)
                  _Row(label: 'College', value: college),
                if (state.isNotEmpty || city.isNotEmpty)
                  _Row(label: 'Location', value: '$city${city.isNotEmpty && state.isNotEmpty ? ', ' : ''}$state'),
                if (year.isNotEmpty && year != 'null')
                  _Row(label: 'Year', value: 'Year $year'),
                if (branch.isNotEmpty && branch != 'null')
                  _Row(label: 'Branch', value: branch),
                _Row(
                  label: 'Status',
                  value: isAdmin == true ? 'Admin' : isBanned == true ? 'Banned' : 'Active',
                  valueColor: isAdmin == true ? cyan : isBanned == true ? red : green,
                ),
              ]),
            ),
          ),

          const SizedBox(height: 16),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              _StatTile(icon: Icons.star_rounded,   label: 'Points',   value: points, color: orange),
              const SizedBox(width: 10),
              _StatTile(icon: Icons.feed_rounded,   label: 'Posts',    value: posts,  color: cyan),
              const SizedBox(width: 10),
              _StatTile(icon: Icons.people_rounded, label: 'Connects', value: conns,  color: green),
            ]),
          ),

          const SizedBox(height: 20),

          // Block/Unblock action
          if (isAdmin != true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onBlockToggle();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isBanned == true ? green.withValues(alpha: 0.1) : red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isBanned == true ? green.withValues(alpha: 0.4) : red.withValues(alpha: 0.4)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(isBanned == true ? Icons.lock_open_rounded : Icons.block_rounded, color: isBanned == true ? green : red, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isBanned == true ? 'Unblock User' : 'Block User',
                      style: TextStyle(color: isBanned == true ? green : red, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ]),
                ),
              ),
            ),

          const SizedBox(height: 36),
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _Row({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13))),
        Text(value, style: TextStyle(color: valueColor ?? const Color(0xFFE9EBEE), fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
        ]),
      ),
    );
  }
}
