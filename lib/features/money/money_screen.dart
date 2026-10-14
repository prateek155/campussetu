import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers/app_providers.dart';
import 'models/money_models.dart';
import 'services/money_storage_service.dart';

class MoneyScreen extends ConsumerStatefulWidget {
  const MoneyScreen({super.key});

  @override
  ConsumerState<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends ConsumerState<MoneyScreen> {
  final MoneyStorageService _storage = MoneyStorageService.instance;
  bool _isLoading = true;
  int _activeTab = 0; // 0: Home, 1: Activity, 2: Udhaar, 3: Groups, 4: Reports
  String _txFilter = 'all'; // 'all', 'expense', 'income'
  String _searchQuery = '';

  static const Map<String, String> _categories = {
    'Food': '🍜',
    'Travel': '🚌',
    'Shopping': '🛍️',
    'Study': '📚',
    'Rent': '🏠',
    'Bills': '🧾',
    'Fun': '🎮',
    'Health': '💊',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    setState(() => _isLoading = true);
    await _storage.init(user?.id);
    if (mounted) setState(() => _isLoading = false);
  }

  String _formatMoney(double n) {
    final formatter = NumberFormat('#,##0.##', 'en_IN');
    return '₹${formatter.format(n)}';
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'CS';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  // Monthly summary calculations
  double get _currentMonthExpenses {
    final monthKey = DateTime.now().toIso8601String().substring(0, 7);
    return _storage.transactions
        .where((t) => t.type == 'expense' && t.date.startsWith(monthKey))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get _currentMonthIncome {
    final monthKey = DateTime.now().toIso8601String().substring(0, 7);
    return _storage.transactions
        .where((t) => t.type == 'income' && t.date.startsWith(monthKey))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get _currentMonthNet => _currentMonthIncome - _currentMonthExpenses;

  double get _totalOwedToYou {
    return _storage.loans
        .where((l) => l.direction == 'lent')
        .fold(0.0, (sum, l) => sum + l.remaining);
  }

  double get _totalYouOwe {
    return _storage.loans
        .where((l) => l.direction == 'borrowed')
        .fold(0.0, (sum, l) => sum + l.remaining);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    final userName = user?.name ?? 'Campus Student';
    final firstName = userName.split(' ').first;
    final photoUrl = user?.photoUrl;
    final initials = _getInitials(userName);

    // Keep storage in sync with active user ID once loaded
    if (!_isLoading && user?.id != null && _storage.activeUserId != user?.id) {
      Future.microtask(() async {
        if (!mounted) return;
        await _storage.init(user?.id);
        if (mounted) setState(() {});
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C101C),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8C7)))
          : SafeArea(
              top: false,
              bottom: false,
              child: CustomScrollView(
                slivers: [
                  // 1. Top Hero Section with Overlaid Floating Summary Bar
                  SliverToBoxAdapter(
                    child: _buildHeroWithSummaryBar(firstName, userName, photoUrl, initials),
                  ),

                  // 2. 5 Sub-Tabs Navigation Strip
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                      child: _buildSubNavTabs(),
                    ),
                  ),

                  // 3. Tab Content
                  SliverToBoxAdapter(
                    child: _buildActiveTabContent(userName),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            ),
    );
  }

  // ================= 1. TOP HERO BANNER & FLOATING SUMMARY BAR =================
  Widget _buildHeroWithSummaryBar(String firstName, String fullName, String? photoUrl, String initials) {
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime.now());
    const double overlap = 36.0;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // 1. Blue Hero Card Container
        Container(
          margin: const EdgeInsets.only(bottom: overlap),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E2E78), Color(0xFF293C98), Color(0xFF17245E)],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Stack(
            children: [
              // Overlapping decorative circles
              Positioned(
                top: -50,
                right: -40,
                child: Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -70,
                right: 40,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF121E5C).withValues(alpha: 0.7),
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, overlap + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Row + Profile Avatar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3FD8F5), Color(0xFF14B8C7)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF14B8C7).withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  '✦',
                                  style: TextStyle(
                                    color: Color(0xFF0A1C24),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: const TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Campus',
                                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                                      ),
                                      TextSpan(
                                        text: 'Setu ',
                                        style: TextStyle(color: Color(0xFF3FD8F5), fontSize: 16, fontWeight: FontWeight.w900),
                                      ),
                                      TextSpan(
                                        text: 'Money',
                                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                                      ),
                                    ],
                                  ),
                                ),
                                const Text(
                                  'PRIVATE STUDENT SPACE',
                                  style: TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    fontSize: 9,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // User Profile Avatar from Database
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF14B8C7),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10),
                            ],
                          ),
                          child: photoUrl != null && photoUrl.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        initials,
                                        style: const TextStyle(color: Color(0xFF0A1C24), fontWeight: FontWeight.w900, fontSize: 14),
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(color: Color(0xFF0A1C24), fontWeight: FontWeight.w900, fontSize: 14),
                                  ),
                                ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),
                    Text(
                      'Welcome back, $firstName 👋',
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),

                    // Hero Expense Headline + Pill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatMoney(_currentMonthExpenses),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2,
                            height: 1.1,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14B8C7).withValues(alpha: 0.18),
                            border: Border.all(color: const Color(0xFF14B8C7).withValues(alpha: 0.35)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '↘ Monthly spend',
                            style: TextStyle(color: Color(0xFF3FD8F5), fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$monthLabel Overview',
                          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                        ),
                        InkWell(
                          onTap: () => setState(() => _activeTab = 4),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Reports & Budgets ↗',
                              style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. 3-Column Floating Summary Bar (Always on top of the blue card!)
        Positioned(
          bottom: 0,
          left: 18,
          right: 18,
          child: _buildSummaryBar(),
        ),
      ],
    );
  }

  // ================= 2. 3-COLUMN FLOATING SUMMARY BAR =================
  Widget _buildSummaryBar() {
    final net = _currentMonthNet;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141927),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryColumn(
              'INCOME',
              '+${_formatMoney(_currentMonthIncome)}',
              const Color(0xFF10B981),
            ),
          ),
          Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.1)),
          Expanded(
            child: _summaryColumn(
              'EXPENSES',
              _formatMoney(_currentMonthExpenses),
              const Color(0xFFF87171),
            ),
          ),
          Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.1)),
          Expanded(
            child: _summaryColumn(
              'NET BALANCE',
              (net >= 0 ? '+' : '') + _formatMoney(net),
              net >= 0 ? const Color(0xFF3FD8F5) : const Color(0xFFF87171),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryColumn(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8B98AD),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ================= 3. SUB-NAV TABS STRIP =================
  Widget _buildSubNavTabs() {
    final tabs = [
      {'title': 'Home', 'icon': Icons.home_rounded},
      {'title': 'Activity', 'icon': Icons.swap_vert_rounded},
      {'title': 'Udhaar', 'icon': Icons.handshake_outlined},
      {'title': 'Groups', 'icon': Icons.groups_rounded},
      {'title': 'Reports', 'icon': Icons.bar_chart_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF141927),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = _activeTab == i;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = i),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF14B8C7).withValues(alpha: 0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected ? Border.all(color: const Color(0xFF14B8C7).withValues(alpha: 0.35)) : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tabs[i]['icon'] as IconData,
                      size: 18,
                      color: isSelected ? const Color(0xFF3FD8F5) : const Color(0xFF8B98AD),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tabs[i]['title'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? const Color(0xFF3FD8F5) : const Color(0xFF8B98AD),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ================= 4. ACTIVE TAB CONTENT =================
  Widget _buildActiveTabContent(String userName) {
    switch (_activeTab) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildActivityTab();
      case 2:
        return _buildUdhaarTab();
      case 3:
        return _buildGroupsTab(userName);
      case 4:
        return _buildReportsTab();
      default:
        return _buildHomeTab();
    }
  }

  // ---------------- TAB 0: HOME ----------------
  Widget _buildHomeTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Actions Row
          _sectionHeader('Quick Actions', actionText: '+ Quick Entry', onAction: _showAddExpenseModal),
          const SizedBox(height: 10),
          _buildQuickActionButtons(),

          const SizedBox(height: 24),

          // Spending Trend Card
          _sectionHeader('Spending Trend', actionText: 'Analysis →', onAction: () => setState(() => _activeTab = 4)),
          const SizedBox(height: 10),
          _buildSpendingTrendCard(),

          const SizedBox(height: 24),

          // Recent Transactions Card
          _sectionHeader('Recent Transactions', actionText: 'See all →', onAction: () => setState(() => _activeTab = 1)),
          const SizedBox(height: 10),
          _buildRecentTransactionsCard(),

          const SizedBox(height: 24),

          // Friends & Udhaar Preview Card
          _sectionHeader('Friends & Udhaar', actionText: 'View all →', onAction: () => setState(() => _activeTab = 2)),
          const SizedBox(height: 10),
          _buildFriendsPreviewCard(),

          const SizedBox(height: 24),

          // Split Groups Preview Card
          _sectionHeader('Split Groups', actionText: 'View all →', onAction: () => setState(() => _activeTab = 3)),
          const SizedBox(height: 10),
          _buildGroupsPreviewCard(),
        ],
      ),
    );
  }

  Widget _buildQuickActionButtons() {
    final actions = [
      {
        'title': 'Add Expense',
        'icon': '＋',
        'color': const Color(0xFF3FD8F5),
        'bg': const Color(0xFF14B8C7).withValues(alpha: 0.15),
        'onTap': _showAddExpenseModal,
      },
      {
        'title': 'Lend Udhaar',
        'icon': '↗',
        'color': const Color(0xFF818CF8),
        'bg': const Color(0xFF4361EE).withValues(alpha: 0.15),
        'onTap': () => _showAddLoanModal(defaultDir: 'lent'),
      },
      {
        'title': 'Split Bill',
        'icon': '⇄',
        'color': const Color(0xFFC084FC),
        'bg': const Color(0xFFA855F7).withValues(alpha: 0.15),
        'onTap': _showSplitBillModal,
      },
      {
        'title': 'Reports',
        'icon': '▥',
        'color': const Color(0xFF34D399),
        'bg': const Color(0xFF10B981).withValues(alpha: 0.15),
        'onTap': () => setState(() => _activeTab = 4),
      },
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions.map((a) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: a['onTap'] as VoidCallback,
              borderRadius: BorderRadius.circular(18),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: a['bg'] as Color,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: (a['color'] as Color).withValues(alpha: 0.25)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        a['icon'] as String,
                        style: TextStyle(color: a['color'] as Color, fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    a['title'] as String,
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSpendingTrendCard() {
    final now = DateTime.now();
    final months = <Map<String, dynamic>>[];
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      final total = _storage.transactions
          .where((t) => t.type == 'expense' && t.date.startsWith(key))
          .fold(0.0, (sum, t) => sum + t.amount);
      months.add({
        'label': DateFormat('MMM').format(d),
        'amount': total,
      });
    }

    final maxVal = months.map((m) => m['amount'] as double).fold(100.0, (prev, amt) => amt > prev ? amt : prev);

    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatMoney(_currentMonthExpenses), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                    _currentMonthExpenses > 0 ? 'Last 6 months expenses' : 'No expenses recorded this month',
                    style: const TextStyle(color: Color(0xFF8B98AD), fontSize: 11),
                  ),
                ],
              ),
              _pillBadge('6 Months'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: months.asMap().entries.map((entry) {
                final i = entry.key;
                final m = entry.value;
                final amt = m['amount'] as double;
                final prevAmt = i > 0 ? (months[i - 1]['amount'] as double) : amt * 0.7;

                final hasAmt = amt > 0;
                final hasPrev = prevAmt > 0;
                final hMain = hasAmt ? (amt / maxVal).clamp(0.12, 1.0) * 80 : 4.0;
                final hGhost = hasPrev ? (prevAmt / maxVal).clamp(0.08, 1.0) * 65 : 4.0;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 10,
                          height: hGhost,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C2438),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Container(
                          width: 10,
                          height: hMain,
                          decoration: BoxDecoration(
                            gradient: hasAmt
                                ? const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0xFF3FD8F5), Color(0xFF14B8C7)],
                                  )
                                : null,
                            color: hasAmt ? null : const Color(0xFF1C2438),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(m['label'] as String, style: const TextStyle(color: Color(0xFF8B98AD), fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _legendDot(const Color(0xFF14B8C7), 'Current Month'),
              const SizedBox(width: 14),
              _legendDot(const Color(0xFF1C2438), 'Previous Average'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsCard() {
    final recent = _storage.transactions.take(4).toList();
    if (recent.isEmpty) {
      return _cardContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8C7).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF3FD8F5), size: 22),
              ),
              const SizedBox(height: 10),
              const Text('No transactions yet', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Record your food, travel, and campus spending.', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 14),
              _secondaryButton('＋ Add Your First Expense', _showAddExpenseModal),
            ],
          ),
        ),
      );
    }

    return _cardContainer(
      child: Column(
        children: recent.asMap().entries.map((e) {
          final isLast = e.key == recent.length - 1;
          return _transactionTile(e.value, isLast: isLast);
        }).toList(),
      ),
    );
  }

  Widget _buildFriendsPreviewCard() {
    final list = _storage.loans.take(3).toList();
    if (list.isEmpty) {
      return _cardContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: [
              const Text('No friend balances recorded.', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 13)),
              const SizedBox(height: 12),
              _secondaryButton('＋ Record New Friend Balance', () => _showAddLoanModal(defaultDir: 'lent')),
            ],
          ),
        ),
      );
    }

    return _cardContainer(
      child: Column(
        children: [
          ...list.asMap().entries.map((e) => _friendLoanTile(e.value, isLast: e.key == list.length - 1)),
          const SizedBox(height: 10),
          _secondaryButton('＋ Record new friend balance', () => _showAddLoanModal(defaultDir: 'lent')),
        ],
      ),
    );
  }

  Widget _buildGroupsPreviewCard() {
    final list = _storage.groups.take(3).toList();
    if (list.isEmpty) {
      return _cardContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: [
              const Text('No groups yet. Create one to split bills!', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 13)),
              const SizedBox(height: 12),
              _secondaryButton('＋ Create Room / Flat Group', () => _showCreateGroupModal('You')),
            ],
          ),
        ),
      );
    }

    return _cardContainer(
      child: Column(
        children: [
          ...list.asMap().entries.map((e) => _groupTile(e.value, isLast: e.key == list.length - 1)),
          const SizedBox(height: 10),
          _secondaryButton('＋ Create Room / Flat Group', () => _showCreateGroupModal('You')),
        ],
      ),
    );
  }

  // ---------------- TAB 1: ACTIVITY (ALL TRANSACTIONS) ----------------
  Widget _buildActivityTab() {
    final query = _searchQuery.toLowerCase();
    final filtered = _storage.transactions.where((t) {
      final matchesFilter = _txFilter == 'all' || t.type == _txFilter;
      final matchesQuery = query.isEmpty ||
          t.title.toLowerCase().contains(query) ||
          t.category.toLowerCase().contains(query) ||
          t.note.toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('All Transactions', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Complete ledger of personal spending and income.', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 12.5)),
          const SizedBox(height: 16),

          // Search Field
          TextField(
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: '⌕ Search food, canteen, travel, UPI...',
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
              filled: true,
              fillColor: const Color(0xFF141927),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF14B8C7), width: 1.2),
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 12),

          // Segmented Filter
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF141927),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                _filterChip('All', 'all'),
                _filterChip('Expenses', 'expense'),
                _filterChip('Income', 'income'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // List
          _cardContainer(
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: Text('No matching transactions found.', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 13)),
                    ),
                  )
                : Column(
                    children: filtered.asMap().entries.map((e) {
                      final isLast = e.key == filtered.length - 1;
                      return _transactionTile(e.value, isLast: isLast, canDelete: true);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String title, String val) {
    final isSelected = _txFilter == val;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _txFilter = val),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1C2438) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: Colors.white.withValues(alpha: 0.08)) : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF3FD8F5) : const Color(0xFF8B98AD),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- TAB 2: UDHAAR (FRIENDS & KHATA) ----------------
  Widget _buildUdhaarTab() {
    final netUdhaar = _totalOwedToYou - _totalYouOwe;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Friends & Udhaar', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Never lose track of who owes whom in campus.', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 12.5)),
          const SizedBox(height: 16),

          // Udhaar Summary Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF141927),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(child: _summaryColumn('YOU\'RE OWED', _formatMoney(_totalOwedToYou), const Color(0xFF10B981))),
                Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.08)),
                Expanded(child: _summaryColumn('YOU OWE', _formatMoney(_totalYouOwe), const Color(0xFFF87171))),
                Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.08)),
                Expanded(
                  child: _summaryColumn(
                    'NET UDHAAR',
                    (netUdhaar >= 0 ? '+' : '') + _formatMoney(netUdhaar),
                    netUdhaar >= 0 ? const Color(0xFF3FD8F5) : const Color(0xFFF87171),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Friends List
          _cardContainer(
            child: Column(
              children: [
                if (_storage.loans.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: Text('No balances. Record money lent or borrowed!', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 13)),
                    ),
                  )
                else
                  ..._storage.loans.asMap().entries.map((e) => _friendLoanTile(e.value, isLast: e.key == _storage.loans.length - 1)),
                const SizedBox(height: 14),
                _primaryButton('＋ Record Udhaar Entry', () => _showAddLoanModal(defaultDir: 'lent')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- TAB 3: GROUPS ----------------
  Widget _buildGroupsTab(String userName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Split Groups', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  Text('Hostel room, trips, mess, and shared food bills.', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 12.5)),
                ],
              ),
              InkWell(
                onTap: () => _showCreateGroupModal(userName),
                borderRadius: BorderRadius.circular(20),
                child: _pillBadge('＋ New Group'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Groups List
          _cardContainer(
            child: Column(
              children: [
                if (_storage.groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No groups yet. Create one to split bills!', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 13))),
                  )
                else
                  ..._storage.groups.asMap().entries.map((e) => _groupTile(e.value, isLast: e.key == _storage.groups.length - 1)),
                const SizedBox(height: 12),
                _secondaryButton('＋ Create New Roommate Group', () => _showCreateGroupModal(userName)),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _sectionHeader('Recent Shared Bills', actionText: '＋ Split Bill', onAction: _showSplitBillModal),
          const SizedBox(height: 10),

          // Splits List
          _cardContainer(
            child: _storage.splits.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No shared bills recorded yet.', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 13))),
                  )
                : Column(
                    children: _storage.splits.asMap().entries.map((e) {
                      final isLast = e.key == _storage.splits.length - 1;
                      final s = e.value;
                      final g = _storage.groups.firstWhere((grp) => grp.id == s.groupId, orElse: () => SplitGroup(id: '', name: 'Group', members: []));
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4361EE).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(child: Text('⇄', style: TextStyle(color: Color(0xFF818CF8), fontSize: 20))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 3),
                                  Text('${g.name} · Paid by ${s.payer} · ${s.date}', style: const TextStyle(color: Color(0xFF8B98AD), fontSize: 11)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_formatMoney(s.amount), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 2),
                                Text('${s.mode} split', style: const TextStyle(color: Color(0xFF8B98AD), fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------- TAB 4: REPORTS & BUDGETS ----------------
  Widget _buildReportsTab() {
    final monthExpenses = _currentMonthExpenses;
    final budget = _storage.budget;
    final budgetPercent = budget > 0 ? (monthExpenses / budget).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = monthExpenses > budget;

    // Categories breakdown
    final monthKey = DateTime.now().toIso8601String().substring(0, 7);
    final catTotals = <String, double>{};
    for (final t in _storage.transactions.where((t) => t.type == 'expense' && t.date.startsWith(monthKey))) {
      catTotals[t.category] = (catTotals[t.category] ?? 0.0) + t.amount;
    }
    final sortedCats = catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reports & Budgets', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Stay disciplined with monthly caps and category insights.', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 12.5)),
          const SizedBox(height: 16),

          // Total spent card
          _cardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total spent this month', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(_formatMoney(monthExpenses), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    _pillBadge('This Month'),
                  ],
                ),
                const SizedBox(height: 16),

                // Category Progress List
                if (sortedCats.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Add expenses this month to see category breakdown.', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 12)),
                  )
                else
                  ...sortedCats.map((e) {
                    final catName = e.key;
                    final amt = e.value;
                    final pct = monthExpenses > 0 ? (amt / monthExpenses) : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${_categories[catName] ?? '✨'} $catName', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                              Text('${_formatMoney(amt)} (${(pct * 100).toStringAsFixed(0)}%)', style: const TextStyle(color: Color(0xFF3FD8F5), fontSize: 13, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 7,
                              backgroundColor: const Color(0xFF1C2438),
                              valueColor: const AlwaysStoppedAnimation(Color(0xFF14B8C7)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Monthly Budget Target Card
          _cardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Monthly Budget Target', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Set a realistic spending cap for this month.', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 11.5)),
                const SizedBox(height: 12),

                // Budget Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${_formatMoney(monthExpenses)} spent', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                    Text(
                      '${(budgetPercent * 100).toStringAsFixed(0)}% of ${_formatMoney(budget)}',
                      style: TextStyle(
                        color: isOverBudget ? const Color(0xFFF87171) : const Color(0xFF3FD8F5),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: budgetPercent,
                    minHeight: 8,
                    backgroundColor: const Color(0xFF1C2438),
                    valueColor: AlwaysStoppedAnimation(isOverBudget ? const Color(0xFFF87171) : const Color(0xFF14B8C7)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isOverBudget
                      ? '⚠️ Over budget by ${_formatMoney(monthExpenses - budget)}'
                      : 'Remaining: ${_formatMoney(budget - monthExpenses)}',
                  style: TextStyle(
                    color: isOverBudget ? const Color(0xFFF87171) : const Color(0xFF8B98AD),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                _secondaryButton('Adjust Monthly Budget Limit', _showBudgetDialog),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Backup & CSV Card
          _cardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Data Backup & Privacy', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'All financial entries are stored locally on your device for 100% privacy and speed. Export backups regularly.',
                  style: TextStyle(color: Color(0xFF8B98AD), fontSize: 11.5, height: 1.4),
                ),
                const SizedBox(height: 14),
                _secondaryButton('Share / Download JSON Backup ↗', _exportJsonBackup),
                const SizedBox(height: 8),
                _secondaryButton('Export Transactions CSV ↗', _exportCsvData),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= HELPER UI TILES =================
  Widget _transactionTile(MoneyTransaction t, {bool isLast = false, bool canDelete = false}) {
    final isIncome = t.type == 'income';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1C2438),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Center(
              child: Text(_categories[t.category] ?? '✨', style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('${t.category} · ${t.date} · ${t.method}', style: const TextStyle(color: Color(0xFF8B98AD), fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : '−'}${_formatMoney(t.amount)}',
                style: TextStyle(
                  color: isIncome ? const Color(0xFF10B981) : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              if (canDelete)
                InkWell(
                  onTap: () => _deleteTransaction(t.id),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text('Delete', style: TextStyle(color: Color(0xFFF87171), fontSize: 10.5, fontWeight: FontWeight.w700)),
                  ),
                )
              else
                Text(isIncome ? 'Income' : 'Expense', style: const TextStyle(color: Color(0xFF8B98AD), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _friendLoanTile(UdhaarLoan l, {bool isLast = false}) {
    final isLent = l.direction == 'lent';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF14B8C7).withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF14B8C7).withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                _getInitials(l.friend),
                style: const TextStyle(color: Color(0xFF3FD8F5), fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.friend, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  '${isLent ? 'You lent' : 'You borrowed'} · ${l.date} ${l.note.isNotEmpty ? '· ${l.note}' : ''}',
                  style: const TextStyle(color: Color(0xFF8B98AD), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatMoney(l.remaining),
                style: TextStyle(
                  color: isLent ? const Color(0xFF10B981) : const Color(0xFFF87171),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l.remaining == 0 ? 'Settled ✓' : (isLent ? 'Owes you' : 'You owe'),
                style: const TextStyle(color: Color(0xFF8B98AD), fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (l.remaining > 0) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _showSettleLoanDialog(l),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2438),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Settle', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _groupTile(SplitGroup g, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF4361EE).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF4361EE).withValues(alpha: 0.25)),
            ),
            child: const Center(child: Text('👥', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.name, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  '${g.members.length} members: ${g.members.take(3).join(', ')}${g.members.length > 3 ? '...' : ''}',
                  style: const TextStyle(color: Color(0xFF8B98AD), fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF8B98AD)),
            onPressed: () => _deleteGroup(g.id),
          ),
        ],
      ),
    );
  }

  // ================= GENERAL COMMON WIDGETS =================
  Widget _sectionHeader(String title, {String? actionText, VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
        if (actionText != null)
          InkWell(
            onTap: onAction,
            child: Text(actionText, style: const TextStyle(color: Color(0xFF14B8C7), fontSize: 12, fontWeight: FontWeight.w800)),
          ),
      ],
    );
  }

  Widget _cardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141927),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }

  Widget _pillBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF14B8C7).withValues(alpha: 0.15),
        border: Border.all(color: const Color(0xFF14B8C7).withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFF3FD8F5), fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Color(0xFF8B98AD), fontSize: 11)),
      ],
    );
  }

  Widget _primaryButton(String title, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF14B8C7),
          foregroundColor: const Color(0xFF0A1C24),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(title, style: const TextStyle(color: Color(0xFF0A1C24), fontSize: 15, fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _secondaryButton(String title, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFF1C2438),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(title, style: const TextStyle(color: Color(0xFF3FD8F5), fontSize: 12.5, fontWeight: FontWeight.w800)),
      ),
    );
  }

  // ================= MODALS & ACTIONS =================

  // 1. Add Transaction Modal
  void _showAddExpenseModal() {
    String type = 'expense';
    String category = 'Food';
    final amountCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String method = 'UPI';
    final date = DateTime.now().toIso8601String().substring(0, 10);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
              decoration: const BoxDecoration(
                color: Color(0xFF141927),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Add Transaction', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white70), onPressed: () => Navigator.pop(sheetContext)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Expense vs Income toggle
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => type = 'expense'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: type == 'expense' ? const Color(0xFF1C2438) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: type == 'expense' ? Border.all(color: const Color(0xFF14B8C7)) : Border.all(color: Colors.white10),
                              ),
                              child: Center(
                                child: Text('Expense', style: TextStyle(color: type == 'expense' ? const Color(0xFF3FD8F5) : const Color(0xFF8B98AD), fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => type = 'income'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: type == 'income' ? const Color(0xFF1C2438) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: type == 'income' ? Border.all(color: const Color(0xFF10B981)) : Border.all(color: Colors.white10),
                              ),
                              child: Center(
                                child: Text('Income', style: TextStyle(color: type == 'income' ? const Color(0xFF10B981) : const Color(0xFF8B98AD), fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Big amount input
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF3FD8F5), fontSize: 32, fontWeight: FontWeight.w900),
                      decoration: const InputDecoration(
                        hintText: '₹ 0.00',
                        hintStyle: TextStyle(color: Color(0xFF334155), fontSize: 32),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Title
                    _inputField(titleCtrl, 'Title / Description (e.g. Canteen, Chai, Metro)'),
                    const SizedBox(height: 14),

                    // Category picker grid
                    const Text('CATEGORY', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 11, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.entries.map((cat) {
                        final isSel = category == cat.key;
                        return InkWell(
                          onTap: () => setModalState(() => category = cat.key),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF14B8C7).withValues(alpha: 0.18) : const Color(0xFF1C2438),
                              border: Border.all(color: isSel ? const Color(0xFF14B8C7) : Colors.white.withValues(alpha: 0.08)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(cat.value, style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 5),
                                Text(cat.key, style: TextStyle(color: isSel ? const Color(0xFF3FD8F5) : Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Payment Mode dropdown
                    const Text('PAYMENT MODE', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 11, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2438),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: method,
                          dropdownColor: const Color(0xFF1C2438),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          items: ['UPI', 'Cash', 'Debit card', 'Credit card', 'Bank transfer', 'Other']
                              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => method = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Note
                    _inputField(noteCtrl, 'Note (optional)'),
                    const SizedBox(height: 20),

                    // Save Button
                    _primaryButton('Save Transaction ✓', () async {
                      final amt = double.tryParse(amountCtrl.text.trim());
                      final title = titleCtrl.text.trim();
                      if (amt == null || amt <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount')));
                        return;
                      }
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title')));
                        return;
                      }

                      await _storage.addTransaction(
                        MoneyTransaction(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          type: type,
                          amount: amt,
                          title: title,
                          category: category,
                          date: date,
                          method: method,
                          note: noteCtrl.text.trim(),
                        ),
                      );
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      if (!mounted) return;
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction saved ✓')));
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 2. Add Loan / Udhaar Modal
  void _showAddLoanModal({String defaultDir = 'lent'}) {
    String direction = defaultDir;
    final friendCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final date = DateTime.now().toIso8601String().substring(0, 10);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
              decoration: const BoxDecoration(
                color: Color(0xFF141927),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(direction == 'lent' ? 'I Lent Money (They Owe)' : 'I Borrowed (I Owe)', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white70), onPressed: () => Navigator.pop(sheetContext)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Lent vs Borrowed Switch
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => direction = 'lent'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: direction == 'lent' ? const Color(0xFF1C2438) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: direction == 'lent' ? Border.all(color: const Color(0xFF10B981)) : Border.all(color: Colors.white10),
                              ),
                              child: Center(
                                child: Text('I Lent Money', style: TextStyle(color: direction == 'lent' ? const Color(0xFF10B981) : const Color(0xFF8B98AD), fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => direction = 'borrowed'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: direction == 'borrowed' ? const Color(0xFF1C2438) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: direction == 'borrowed' ? Border.all(color: const Color(0xFFF87171)) : Border.all(color: Colors.white10),
                              ),
                              child: Center(
                                child: Text('I Borrowed', style: TextStyle(color: direction == 'borrowed' ? const Color(0xFFF87171) : const Color(0xFF8B98AD), fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _inputField(friendCtrl, 'Friend\'s Name (e.g. Rahul Sharma)'),
                    const SizedBox(height: 12),
                    _inputField(amountCtrl, 'Amount (₹)', isNumber: true),
                    const SizedBox(height: 12),
                    _inputField(noteCtrl, 'Reason / Purpose (e.g. Canteen, Movie, Xerox)'),
                    const SizedBox(height: 20),

                    _primaryButton('Save Udhaar Record ✓', () async {
                      final name = friendCtrl.text.trim();
                      final amt = double.tryParse(amountCtrl.text.trim());
                      if (name.isEmpty || amt == null || amt <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter friend name and amount')));
                        return;
                      }

                      await _storage.addLoan(
                        UdhaarLoan(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          friend: name,
                          direction: direction,
                          amount: amt,
                          remaining: amt,
                          date: date,
                          note: noteCtrl.text.trim(),
                        ),
                      );
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      if (!mounted) return;
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Udhaar record saved ✓')));
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 3. Settle Loan Dialog
  void _showSettleLoanDialog(UdhaarLoan loan) {
    final repayCtrl = TextEditingController(text: loan.remaining.toStringAsFixed(0));
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF141927),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        title: Text('Settle Udhaar: ${loan.friend}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Outstanding: ${_formatMoney(loan.remaining)}', style: const TextStyle(color: Color(0xFF3FD8F5), fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            _inputField(repayCtrl, 'Repayment amount (₹)', isNumber: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF14B8C7), foregroundColor: const Color(0xFF0A1C24)),
            onPressed: () async {
              final amt = double.tryParse(repayCtrl.text.trim());
              if (amt == null || amt <= 0 || amt > loan.remaining) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid repayment amount')));
                return;
              }
              await _storage.settleLoan(loan.id, amt);
              if (!dialogCtx.mounted) return;
              Navigator.pop(dialogCtx);
              if (!mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Repayment saved ✓')));
            },
            child: const Text('Confirm Settle', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 4. Create Group Modal
  void _showCreateGroupModal(String defaultMember) {
    final nameCtrl = TextEditingController();
    final membersCtrl = TextEditingController(text: '$defaultMember, ');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
          decoration: const BoxDecoration(
            color: Color(0xFF141927),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Create Split Group', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              _inputField(nameCtrl, 'Group Name (e.g. Room 204, Goa Trip, Mess)'),
              const SizedBox(height: 12),
              _inputField(membersCtrl, 'Members separated by commas (e.g. You, Rahul, Aditi)'),
              const SizedBox(height: 20),
              _primaryButton('Create Group ✓', () async {
                final gName = nameCtrl.text.trim();
                final rawMembers = membersCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                if (gName.isEmpty || rawMembers.length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter group name and at least 2 members')));
                  return;
                }

                await _storage.addGroup(SplitGroup(id: DateTime.now().millisecondsSinceEpoch.toString(), name: gName, members: rawMembers));
                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                if (!mounted) return;
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group created ✓')));
              }),
            ],
          ),
        );
      },
    );
  }

  // 5. Split Bill Modal
  void _showSplitBillModal() {
    if (_storage.groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create a group first!')));
      _showCreateGroupModal('You');
      return;
    }

    String selectedGroupId = _storage.groups.first.id;
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String payer = _storage.groups.first.members.isNotEmpty ? _storage.groups.first.members.first : 'You';
    String mode = 'Equal';
    Set<String> selectedMembers = Set.from(_storage.groups.first.members);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final currentGroup = _storage.groups.firstWhere((g) => g.id == selectedGroupId, orElse: () => _storage.groups.first);
            final total = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
            final sharePerPerson = selectedMembers.isNotEmpty ? (total / selectedMembers.length) : 0.0;
            final safePayer = currentGroup.members.contains(payer)
                ? payer
                : (currentGroup.members.isNotEmpty ? currentGroup.members.first : 'You');

            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
              decoration: const BoxDecoration(
                color: Color(0xFF141927),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    const Text('Split a Bill', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 14),

                    // Group selector
                    const Text('SELECT GROUP', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 11, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: const Color(0xFF1C2438), border: Border.all(color: Colors.white.withValues(alpha: 0.08)), borderRadius: BorderRadius.circular(14)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedGroupId,
                          dropdownColor: const Color(0xFF1C2438),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          items: _storage.groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedGroupId = val;
                                final newG = _storage.groups.firstWhere((g) => g.id == val);
                                payer = newG.members.isNotEmpty ? newG.members.first : 'You';
                                selectedMembers = Set.from(newG.members);
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _inputField(titleCtrl, 'Bill Name (e.g. Friday Pizza, Wifi Bill)'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Total Bill Amount (₹)',
                        labelStyle: const TextStyle(color: Color(0xFF8B98AD), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF1C2438),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // Paid by
                    const Text('PAID BY', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 11, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: const Color(0xFF1C2438), border: Border.all(color: Colors.white.withValues(alpha: 0.08)), borderRadius: BorderRadius.circular(14)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: currentGroup.members.contains(safePayer) ? safePayer : null,
                          dropdownColor: const Color(0xFF1C2438),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          items: currentGroup.members.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => payer = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Participants Checklist
                    const Text('SPLIT AMONG', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 11, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF1C2438), borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        children: currentGroup.members.map((m) {
                          final isChecked = selectedMembers.contains(m);
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeColor: const Color(0xFF14B8C7),
                            title: Text(m, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
                            value: isChecked,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedMembers.add(m);
                                } else if (selectedMembers.length > 1) {
                                  selectedMembers.remove(m);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Live calculation preview
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF14B8C7).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        '${selectedMembers.length} participants · ${_formatMoney(sharePerPerson)} each',
                        style: const TextStyle(color: Color(0xFF3FD8F5), fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 18),

                    _primaryButton('Record Shared Bill ✓', () async {
                      if (total <= 0 || titleCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid title and amount')));
                        return;
                      }

                      await _storage.addSplit(
                        SplitBill(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          groupId: selectedGroupId,
                          title: titleCtrl.text.trim(),
                          amount: total,
                          payer: payer,
                          mode: mode,
                          date: DateTime.now().toIso8601String().substring(0, 10),
                        ),
                      );
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      if (!mounted) return;
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shared bill recorded ✓')));
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 6. Adjust Budget Dialog
  void _showBudgetDialog() {
    final ctrl = TextEditingController(text: _storage.budget.toStringAsFixed(0));
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141927),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        title: const Text('Set Monthly Budget Target', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
        content: _inputField(ctrl, 'Target budget amount (₹)', isNumber: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF14B8C7), foregroundColor: const Color(0xFF0A1C24)),
            onPressed: () async {
              final val = double.tryParse(ctrl.text.trim());
              if (val != null && val > 0) {
                await _storage.setBudget(val);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monthly budget updated ✓')));
              }
            },
            child: const Text('Save Limit', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 7. Export Handlers
  void _exportJsonBackup() {
    final jsonStr = _storage.exportJson();
    Share.share(jsonStr, subject: 'CampusSetu Money Backup');
  }

  void _exportCsvData() {
    final csvStr = _storage.exportCsv();
    Share.share(csvStr, subject: 'CampusSetu Transactions CSV');
  }

  // Deletions
  Future<void> _deleteTransaction(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141927),
        title: const Text('Delete Transaction?', style: TextStyle(color: Colors.white)),
        content: const Text('This entry will be permanently removed from your ledger.', style: TextStyle(color: Color(0xFFCBD5E1))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF87171)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _storage.deleteTransaction(id);
      setState(() {});
    }
  }

  Future<void> _deleteGroup(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141927),
        title: const Text('Delete Group?', style: TextStyle(color: Colors.white)),
        content: const Text('This will delete the group and its associated bills.', style: TextStyle(color: Color(0xFFCBD5E1))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF87171)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _storage.deleteGroup(id);
      setState(() {});
    }
  }

  Widget _inputField(TextEditingController ctrl, String hint, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF1C2438),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF14B8C7))),
      ),
    );
  }
}
