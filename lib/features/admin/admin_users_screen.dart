// lib/features/admin/admin_users_screen.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import 'widgets/admin_toast.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  // ── Palette matching the modern dark design ────────────────────────────────
  static const _bg       = Color(0xFF090D16);
  static const _card     = Color(0xFF0D121E);
  static const _cardAlt  = Color(0xFF121725);
  static const _border   = Color(0xFF1A2234);
  static const _cyan     = Color(0xFF38BDF8);
  static const _red      = Color(0xFFEF4444);
  static const _textMuted= Color(0xFF64748B);
  static const _textLight= Color(0xFFE2E8F0);

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _activeFilter = 'all'; // 'all' | 'active' | 'faculty' | 'admins' | 'banned'

  // Location & College Filters
  String? _filterState;
  String? _filterCity;
  String? _filterCollege;

  // View Mode: 0 = List, 1 = College, 2 = City/State
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
  String? _selectedUserId;

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
    _debounce = Timer(const Duration(milliseconds: 400), () => _fetchUsers(reset: true));
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
        isBanned: _activeFilter == 'banned' ? true : (_activeFilter == 'active' ? false : null),
        state: _filterState,
        city: _filterCity,
        college: _filterCollege,
        role: _activeFilter == 'faculty' ? 'faculty' : null,
        isAdmin: _activeFilter == 'admins' ? true : null,
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
        if (isBanned == true) {
          AdminToast.success(context, 'User unblocked successfully');
        } else {
          AdminToast.warning(context, 'User blocked successfully');
        }
      }
    } catch (e) {
      if (mounted) {
        AdminToast.error(context, 'Error: $e');
      }
    }
  }

  void _showUserSheet(Map<String, dynamic> user) {
    setState(() => _selectedUserId = (user['_id'] ?? user['id'])?.toString());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserDetailSheet(
        user: user,
        onBlockToggle: () => _toggleBlock(user),
      ),
    ).then((_) {
      if (mounted) setState(() => _selectedUserId = null);
    });
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
                  const Icon(Icons.tune_rounded, color: _cyan, size: 22),
                  const SizedBox(width: 8),
                  const Text('Filter Locations', style: TextStyle(color: _textLight, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: _textMuted, size: 20), onPressed: () => Navigator.pop(context)),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('State', style: TextStyle(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _buildDropdown(
                        hint: 'All States',
                        value: tempState,
                        items: _metaStates,
                        onChanged: (val) => setModalState(() => tempState = val),
                      ),
                      const SizedBox(height: 16),
                      const Text('City', style: TextStyle(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _buildDropdown(
                        hint: 'All Cities',
                        value: tempCity,
                        items: _metaCities,
                        onChanged: (val) => setModalState(() => tempCity = val),
                      ),
                      const SizedBox(height: 16),
                      const Text('College', style: TextStyle(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
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
                    foregroundColor: const Color(0xFF090D16),
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
          hint: Text(hint, style: const TextStyle(color: _textMuted, fontSize: 13)),
          isExpanded: true,
          dropdownColor: _cardAlt,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _textMuted),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(hint, style: const TextStyle(color: _textMuted, fontSize: 13)),
            ),
            ...items.map((item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(color: _textLight, fontSize: 13), overflow: TextOverflow.ellipsis),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  // Grouped maps for segregation (College / City & State)
  Map<String, List<Map<String, dynamic>>> _getGroupedUsers(List<Map<String, dynamic>> userList) {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final u in userList) {
      String key;
      if (_viewMode == 1) {
        final clg = (u['college'] ?? u['college_name'] ?? '').toString().trim();
        key = clg.isNotEmpty ? clg : 'Unspecified College';
      } else {
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

  static bool isFacultyUser(Map<String, dynamic> u) {
    final role = (u['role'] ?? '').toString().trim().toLowerCase();
    return role == 'faculty' || u['is_faculty'] == true || u['isFaculty'] == true;
  }

  static bool isAdminUser(Map<String, dynamic> u) {
    final role = (u['role'] ?? '').toString().trim().toLowerCase();
    return u['is_admin'] == true || u['isAdmin'] == true || role == 'admin';
  }

  // Filter users by client-side active filter
  List<Map<String, dynamic>> get _displayedUsers {
    if (_activeFilter == 'faculty') {
      return _users.where((u) => isFacultyUser(u)).toList();
    }
    if (_activeFilter == 'admins') {
      return _users.where((u) => isAdminUser(u)).toList();
    }
    if (_activeFilter == 'active') {
      return _users.where((u) => u['is_banned'] != true && u['isBanned'] != true).toList();
    }
    if (_activeFilter == 'banned') {
      return _users.where((u) => u['is_banned'] == true || u['isBanned'] == true).toList();
    }
    return _users;
  }

  // Counts for pills
  int get _countAll => _users.length;
  int get _countActive => _users.where((u) => (u['is_banned'] != true && u['isBanned'] != true)).length;
  int get _countFaculties => _users.where((u) => isFacultyUser(u)).length;
  int get _countAdmins => _users.where((u) => isAdminUser(u)).length;
  int get _countBanned => _users.where((u) => (u['is_banned'] == true || u['isBanned'] == true)).length;

  @override
  Widget build(BuildContext context) {
    final displayedList = _displayedUsers;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── TOP HEADER (Matches Image) ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + "Filter locations" Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Users',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${displayedList.length} of ${_users.length} users',
                            style: const TextStyle(color: _textMuted, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      // "Filter locations" Pill Button
                      GestureDetector(
                        onTap: _showFilterDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: _hasActiveLocationFilter ? _cyan.withOpacity(0.15) : const Color(0xFF131826),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _hasActiveLocationFilter ? _cyan : const Color(0xFF1E2638)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.filter_list_rounded, color: _hasActiveLocationFilter ? _cyan : Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _hasActiveLocationFilter ? 'Filters (Active)' : 'Filter locations',
                                style: TextStyle(
                                  color: _hasActiveLocationFilter ? _cyan : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── SEARCH BAR (Matches Image) ────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D121F),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1A2234)),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search name, email, campus ID, college',
                        hintStyle: TextStyle(color: Color(0xFF5A6882), fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF5A6882), size: 20),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── FILTER PILLS & VIEW MODE ROW (Matches Image) ───────────
                  Row(
                    children: [
                      // Status Pills: All | Active | Admins | Banned
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _StatusFilterPill(
                                label: 'All',
                                count: _countAll,
                                isSelected: _activeFilter == 'all',
                                selectedBg: const Color(0xFF3FD8F5),
                                selectedTextColor: Colors.black,
                                onTap: () {
                                  setState(() => _activeFilter = 'all');
                                  _fetchUsers(reset: true);
                                },
                              ),
                              const SizedBox(width: 10),
                              _StatusFilterPill(
                                label: 'Active',
                                count: _countActive,
                                isSelected: _activeFilter == 'active',
                                selectedBg: const Color(0xFF10B981),
                                selectedTextColor: Colors.white,
                                onTap: () {
                                  setState(() => _activeFilter = 'active');
                                  _fetchUsers(reset: true);
                                },
                              ),
                              const SizedBox(width: 10),
                              _StatusFilterPill(
                                label: 'Faculty',
                                count: _countFaculties,
                                isSelected: _activeFilter == 'faculty',
                                selectedBg: const Color(0xFF818CF8),
                                selectedTextColor: Colors.white,
                                onTap: () {
                                  setState(() => _activeFilter = 'faculty');
                                  _fetchUsers(reset: true);
                                },
                              ),
                              const SizedBox(width: 10),
                              _StatusFilterPill(
                                label: 'Admins',
                                count: _countAdmins,
                                isSelected: _activeFilter == 'admins',
                                selectedBg: const Color(0xFF38BDF8),
                                selectedTextColor: Colors.black,
                                onTap: () {
                                  setState(() => _activeFilter = 'admins');
                                  _fetchUsers(reset: true);
                                },
                              ),
                              const SizedBox(width: 10),
                              _StatusFilterPill(
                                label: 'Banned',
                                count: _countBanned,
                                isSelected: _activeFilter == 'banned',
                                selectedBg: const Color(0xFFEF4444),
                                selectedTextColor: Colors.white,
                                onTap: () {
                                  setState(() => _activeFilter = 'banned');
                                  _fetchUsers(reset: true);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // View Mode Switcher: List | College | City/State
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D121F),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1A2234)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ViewModeItem(
                              icon: Icons.list_rounded,
                              label: 'List',
                              isSelected: _viewMode == 0,
                              onTap: () => setState(() => _viewMode = 0),
                            ),
                            _ViewModeItem(
                              icon: Icons.school_outlined,
                              label: 'College',
                              isSelected: _viewMode == 1,
                              onTap: () => setState(() => _viewMode = 1),
                            ),
                            _ViewModeItem(
                              icon: Icons.location_on_outlined,
                              label: 'City/State',
                              isSelected: _viewMode == 2,
                              onTap: () => setState(() => _viewMode = 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Active Filter Tags
                  if (_hasActiveLocationFilter) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (_filterState != null)
                          _ActiveTag(label: 'State: $_filterState', onClear: () { setState(() => _filterState = null); _fetchUsers(reset: true); }),
                        if (_filterCity != null)
                          _ActiveTag(label: 'City: $_filterCity', onClear: () { setState(() => _filterCity = null); _fetchUsers(reset: true); }),
                        if (_filterCollege != null)
                          _ActiveTag(label: 'College: $_filterCollege', onClear: () { setState(() => _filterCollege = null); _fetchUsers(reset: true); }),
                        TextButton(
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
                ],
              ),
            ),

            // ── COLUMN HEADERS (Matches Image Table Header) ─────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                if (!isWide || _viewMode != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(40, 4, 40, 8),
                  child: Row(
                    children: const [
                      Expanded(flex: 4, child: Text('User', style: TextStyle(color: Color(0xFF5A6882), fontSize: 13, fontWeight: FontWeight.w600))),
                      Expanded(flex: 3, child: Text('College', style: TextStyle(color: Color(0xFF5A6882), fontSize: 13, fontWeight: FontWeight.w600))),
                      Expanded(flex: 2, child: Text('Activity', style: TextStyle(color: Color(0xFF5A6882), fontSize: 13, fontWeight: FontWeight.w600))),
                      SizedBox(width: 200, child: Text('Role & Status', style: TextStyle(color: Color(0xFF5A6882), fontSize: 13, fontWeight: FontWeight.w600))),
                    ],
                  ),
                );
              },
            ),

            // ── USER LIST / ACCORDION VIEWS ──────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _cyan))
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: _red, size: 48),
                          const SizedBox(height: 12),
                          const Text('Failed to load users', style: TextStyle(color: Colors.white, fontSize: 15)),
                          const SizedBox(height: 8),
                          Text(_error!, style: const TextStyle(color: _textMuted, fontSize: 12)),
                          const SizedBox(height: 16),
                          FilledButton(onPressed: () => _fetchUsers(reset: true), child: const Text('Retry')),
                        ],
                      ),
                    )
                  : displayedList.isEmpty
                  ? const Center(
                      child: Text('No users match your criteria', style: TextStyle(color: _textMuted, fontSize: 14)),
                    )
                  : RefreshIndicator(
                      color: _cyan,
                      backgroundColor: _card,
                      onRefresh: () => _fetchUsers(reset: true),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 720;
                          if (_viewMode == 0) {
                            return _buildFlatListView(displayedList, isWide);
                          } else {
                            return _buildSegregatedView(displayedList, isWide);
                          }
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatListView(List<Map<String, dynamic>> userList, bool isWide) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 30),
      itemCount: userList.length + (_hasMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == userList.length) return _buildLoadMoreTile();
        final u = userList[i];
        final id = (u['_id'] ?? u['id'])?.toString();
        final isSelected = id != null && id == _selectedUserId;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _UserRowCard(
            user: u,
            isWide: isWide,
            isSelected: isSelected,
            onTap: () => _showUserSheet(u),
            onBlockToggle: () => _toggleBlock(u),
          ),
        );
      },
    );
  }

  Widget _buildSegregatedView(List<Map<String, dynamic>> userList, bool isWide) {
    final groups = _getGroupedUsers(userList);
    final groupKeys = groups.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      itemCount: groupKeys.length,
      itemBuilder: (ctx, idx) {
        final key = groupKeys[idx];
        final groupUsers = groups[key]!;
        final isExpanded = _expandedGroups.contains(key) || (_expandedGroups.isEmpty && idx == 0);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
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
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(
                    children: [
                      Icon(_viewMode == 1 ? Icons.school_rounded : Icons.location_on_rounded, color: _cyan, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          key,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _cyan.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${groupUsers.length} users',
                          style: const TextStyle(color: _cyan, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: _textMuted),
                    ],
                  ),
                ),
              ),
              if (isExpanded) ...[
                const Divider(height: 1, color: _border),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: groupUsers.map((u) {
                      final id = (u['_id'] ?? u['id'])?.toString();
                      final isSelected = id != null && id == _selectedUserId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _UserRowCard(
                          user: u,
                          isWide: isWide,
                          isSelected: isSelected,
                          onTap: () => _showUserSheet(u),
                          onBlockToggle: () => _toggleBlock(u),
                        ),
                      );
                    }).toList(),
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
              child: OutlinedButton(
                onPressed: () => _fetchUsers(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _cyan,
                  side: const BorderSide(color: Color(0xFF1E283C)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Load more'),
              ),
            ),
          );
  }
}

// ── Status Filter Pill (All 5, Active 4, etc.) ─────────────────────────────────
class _StatusFilterPill extends StatelessWidget {
  const _StatusFilterPill({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.selectedBg,
    required this.selectedTextColor,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final Color selectedBg;
  final Color selectedTextColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : const Color(0xFF0D121F),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? selectedBg : const Color(0xFF1A2234),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? selectedTextColor : const Color(0xFF94A3B8),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black.withOpacity(0.18) : const Color(0xFF161E2E),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? selectedTextColor : const Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── View Mode Switcher Item ────────────────────────────────────────────────────
class _ViewModeItem extends StatelessWidget {
  const _ViewModeItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF162235) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── User Row Card (Exact Match to User's Design Image) ─────────────────────────
class _UserRowCard extends StatelessWidget {
  const _UserRowCard({
    required this.user,
    required this.isWide,
    required this.isSelected,
    required this.onTap,
    required this.onBlockToggle,
  });

  final Map<String, dynamic> user;
  final bool isWide;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onBlockToggle;

  static Color _getAvatarColor(String name) {
    const colors = [
      Color(0xFF8B5CF6), // Purple
      Color(0xFFF59E0B), // Orange
      Color(0xFF10B981), // Green
      Color(0xFFEC4899), // Pink / Coral
      Color(0xFF3B82F6), // Blue
      Color(0xFF06B6D4), // Cyan
    ];
    if (name.isEmpty) return colors[0];
    final hash = name.codeUnits.fold(0, (sum, char) => sum + char);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final name     = (user['name'] ?? user['full_name'] ?? user['displayName'] ?? 'Unknown').toString();
    final email    = (user['email'] ?? '').toString();
    final college  = (user['college'] ?? user['college_name'] ?? '').toString().trim();
    final year     = (user['year'] ?? user['year_of_study'] ?? '').toString();
    final points   = (user['points'] ?? 0).toString();
    final posts    = (user['posts_count'] ?? user['post_count'] ?? 0).toString();
    final conns    = (user['connections_count'] ?? user['connectionsCount'] ?? 0).toString();
    final isBanned = user['is_banned'] == true || user['isBanned'] == true;
    final isAdmin  = _AdminUsersScreenState.isAdminUser(user);
    final isFaculty = _AdminUsersScreenState.isFacultyUser(user);
    final initial  = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final avatarColor = _getAvatarColor(name);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D121E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF171E2D),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF38BDF8).withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: isWide
            ? Row(
                children: [
                  // 1. USER COLUMN (Avatar + Name & Email)
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: avatarColor,
                          child: Text(
                            initial,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. COLLEGE COLUMN
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        const Icon(Icons.school_outlined, color: Color(0xFF818CF8), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            college.isNotEmpty
                                ? (college + (year.isNotEmpty && year != 'null' ? ' · Yr $year' : ''))
                                : 'College not set',
                            style: TextStyle(
                              color: college.isNotEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontStyle: college.isEmpty ? FontStyle.italic : FontStyle.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. ACTIVITY COLUMN (Star, Post, Conns)
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        const Icon(Icons.star_border_rounded, color: Color(0xFFF59E0B), size: 17),
                        const SizedBox(width: 4),
                        Text(points, style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(width: 12),
                        const Icon(Icons.calendar_today_outlined, color: Color(0xFF38BDF8), size: 14),
                        const SizedBox(width: 4),
                        Text(posts, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(width: 12),
                        const Icon(Icons.people_outline, color: Color(0xFF34D399), size: 16),
                        const SizedBox(width: 4),
                        Text(conns, style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  ),

                  // 4. ROLE, STATUS & BLOCK ACTION
                  SizedBox(
                    width: 200,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isFaculty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1B4B),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: const Color(0xFF4338CA).withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(color: Color(0xFF818CF8), shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'Faculty',
                                  style: TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ] else if (isAdmin) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF092330),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: const Color(0xFF0369A1).withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(color: Color(0xFF38BDF8), shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'Admin',
                                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],

                        // Status badge (● Active / ● Banned)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: isBanned ? const Color(0xFF2C1014) : const Color(0xFF09291E),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isBanned ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isBanned ? 'Banned' : 'Active',
                                style: TextStyle(
                                  color: isBanned ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Ban / Block Action Button
                        GestureDetector(
                          onTap: onBlockToggle,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1114),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF3B151C)),
                            ),
                            child: Icon(
                              isBanned ? Icons.lock_open_rounded : Icons.block_rounded,
                              color: const Color(0xFFEF4444),
                              size: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: avatarColor,
                        child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                            Text(email, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (isFaculty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1B4B),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: const Color(0xFF4338CA).withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF818CF8), shape: BoxShape.circle)),
                                  const SizedBox(width: 4),
                                  const Text('Faculty', style: TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            )
                          else if (isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF092330),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: const Color(0xFF0369A1).withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF38BDF8), shape: BoxShape.circle)),
                                  const SizedBox(width: 4),
                                  const Text('Admin', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isBanned ? const Color(0xFF2C1014) : const Color(0xFF09291E),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isBanned ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isBanned ? 'Banned' : 'Active',
                                  style: TextStyle(
                                    color: isBanned ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onBlockToggle,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1114),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF3B151C)),
                          ),
                          child: Icon(
                            isBanned ? Icons.lock_open_rounded : Icons.block_rounded,
                            color: const Color(0xFFEF4444),
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.school_outlined, color: Color(0xFF818CF8), size: 15),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          college.isNotEmpty ? (college + (year.isNotEmpty && year != 'null' ? ' · Yr $year' : '')) : 'College not set',
                          style: TextStyle(
                            color: college.isNotEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                            fontSize: 12,
                            fontStyle: college.isEmpty ? FontStyle.italic : FontStyle.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star_border_rounded, color: Color(0xFFF59E0B), size: 15),
                      const SizedBox(width: 4),
                      Text(points, style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(width: 12),
                      const Icon(Icons.calendar_today_outlined, color: Color(0xFF38BDF8), size: 13),
                      const SizedBox(width: 4),
                      Text(posts, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(width: 12),
                      const Icon(Icons.people_outline, color: Color(0xFF34D399), size: 15),
                      const SizedBox(width: 4),
                      Text(conns, style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF38BDF8).withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close, size: 12, color: Color(0xFF38BDF8)),
          ),
        ],
      ),
    );
  }
}

// ── User Detail Bottom Sheet (Preserves All Original Admin Actions) ───────────
class _UserDetailSheet extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onBlockToggle;

  const _UserDetailSheet({required this.user, required this.onBlockToggle});

  @override
  Widget build(BuildContext context) {
    const cardAlt = Color(0xFF121725);
    const border  = Color(0xFF1E283C);
    const cyan    = Color(0xFF38BDF8);
    const green   = Color(0xFF10B981);
    const red     = Color(0xFFEF4444);
    const orange  = Color(0xFFF59E0B);

    final name      = (user['name'] ?? user['full_name'] ?? user['displayName'] ?? 'Unknown').toString();
    final email     = (user['email'] ?? '').toString();
    final campusId  = (user['campus_id'] ?? user['campusId'] ?? '').toString();
    final college   = (user['college'] ?? user['college_name'] ?? '').toString();
    final state     = (user['state'] ?? '').toString();
    final city      = (user['city'] ?? '').toString();
    final year      = (user['year'] ?? user['year_of_study'] ?? '').toString();
    final branch    = (user['branch'] ?? '').toString();
    final points    = (user['points'] ?? 0).toString();
    final posts     = (user['posts_count'] ?? user['post_count'] ?? 0).toString();
    final conns     = (user['connections_count'] ?? user['connectionsCount'] ?? 0).toString();
    final isBanned  = user['is_banned'] == true || user['isBanned'] == true;
    final isAdmin   = _AdminUsersScreenState.isAdminUser(user);
    final isFaculty = _AdminUsersScreenState.isFacultyUser(user);
    final subject   = (user['subject'] ?? user['department'] ?? '').toString();
    final initial   = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Color(0xFF0E1320),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 14, bottom: 22), width: 40, height: 4, decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2))),
            CircleAvatar(
              radius: 34,
              backgroundColor: _UserRowCard._getAvatarColor(name),
              child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28)),
            ),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            if (campusId.isNotEmpty && campusId != 'null') ...[
              const SizedBox(height: 4),
              Text(campusId, style: const TextStyle(color: cyan, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 2),
            Text(email, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'Role',
                      value: isAdmin ? 'Admin' : isFaculty ? 'Faculty' : 'Student',
                      valueColor: isAdmin ? cyan : isFaculty ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
                    ),
                    if (isFaculty && subject.isNotEmpty && subject != 'null')
                      _DetailRow(label: 'Subject', value: subject),
                    if (college.isNotEmpty) _DetailRow(label: 'College', value: college),
                    if (state.isNotEmpty || city.isNotEmpty)
                      _DetailRow(label: 'Location', value: '$city${city.isNotEmpty && state.isNotEmpty ? ', ' : ''}$state'),
                    if (year.isNotEmpty && year != 'null') _DetailRow(label: 'Year', value: 'Year $year'),
                    if (branch.isNotEmpty && branch != 'null') _DetailRow(label: 'Branch', value: branch),
                    _DetailRow(
                      label: 'Status',
                      value: isBanned ? 'Banned' : 'Active',
                      valueColor: isBanned ? red : green,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _DetailStatTile(icon: Icons.star_rounded, label: 'Points', value: points, color: orange),
                  const SizedBox(width: 10),
                  _DetailStatTile(icon: Icons.feed_rounded, label: 'Posts', value: posts, color: cyan),
                  const SizedBox(width: 10),
                  _DetailStatTile(icon: Icons.people_rounded, label: 'Connects', value: conns, color: green),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
                      color: isBanned == true ? green.withOpacity(0.12) : red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isBanned == true ? green.withOpacity(0.4) : red.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isBanned == true ? Icons.lock_open_rounded : Icons.block_rounded, color: isBanned == true ? green : red, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          isBanned == true ? 'Unblock User' : 'Block User',
                          style: TextStyle(color: isBanned == true ? green : red, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13))),
          Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DetailStatTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _DetailStatTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
            Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
