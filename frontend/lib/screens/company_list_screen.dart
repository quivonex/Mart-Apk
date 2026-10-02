import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../models/company_model.dart';
import '../services/company_service.dart';
import '../utils/company_payment_helper.dart';
import 'company_create_edit_screen.dart';
import 'company_detail_screen.dart';

// Colours used only on this screen (the rest come from DT).
class _C {
  static const navy1 = Color(0xFF1B223C);
  static const navy3 = Color(0xFF242E54);
  static const blue600 = Color(0xFF2563EB);
  static const emerald600 = Color(0xFF059669);
  static const emerald700 = Color(0xFF047857);
}

enum _Filter { all, paid, pending }

class CompanyListScreen extends StatefulWidget {
  const CompanyListScreen({super.key});

  @override
  State<CompanyListScreen> createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  final _searchCtrl = TextEditingController();

  List<Company> _companies = [];
  bool _isLoading = true;
  String? _error;
  _Filter _filter = _Filter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // =================================================================
  // DATA
  // =================================================================
  Future<void> _load() async {
    setState(() {
      _isLoading = _companies.isEmpty; // keep list visible on pull-to-refresh
      _error = null;
    });

    try {
      final response = await CompanyService.getMyCompanies();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (response.isSuccess) {
          _companies = response.data;
        } else {
          _error = response.message ?? 'Could not load companies';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  bool _isPaid(Company c) => c.paymentStatus.toLowerCase() == 'paid';

  int get _paidCount => _companies.where(_isPaid).length;
  int get _pendingCount => _companies.length - _paidCount;

  List<Company> get _visible {
    final q = _query.trim().toLowerCase();
    return _companies.where((c) {
      final matchesFilter = switch (_filter) {
        _Filter.all => true,
        _Filter.paid => _isPaid(c),
        _Filter.pending => !_isPaid(c),
      };
      if (!matchesFilter) return false;
      if (q.isEmpty) return true;
      return [c.name, c.ownerName, c.district, c.state, c.gstNumber, c.email]
          .any((f) => f.toLowerCase().contains(q));
    }).toList();
  }

  // =================================================================
  // NAVIGATION
  // =================================================================
  Future<void> _openCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CompanyCreateEditScreen()),
    );
    if (result == true) _load();
  }

  Future<void> _openEdit(Company company) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyCreateEditScreen(existing: company),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _openDetail(Company company) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CompanyDetailScreen(company: company)),
    );
    _load(); // detail screen can pay / edit / deactivate
  }

  Future<void> _onPay(Company company) async {
    final paid = await CompanyPaymentHelper.pay(context, company);
    if (paid) _load();
  }

  // =================================================================
  // BUILD
  // =================================================================
  @override
  Widget build(BuildContext context) {
    final showFab = !_isLoading && _companies.isNotEmpty;

    return Scaffold(
      backgroundColor: DT.background,
      appBar: _buildAppBar(),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: _buildBody(),
      ),
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: _C.navy3,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DT.rLg),
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Add Company',
          style: DT.text(
              size: 13.5, weight: FontWeight.w700, color: Colors.white),
        ),
      )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final count = _companies.length;
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: DT.border)),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: DT.onyx700),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Companies',
                          style: DT.text(
                            size: 17,
                            weight: FontWeight.w700,
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          _isLoading
                              ? 'Loading…'
                              : count == 1
                              ? '1 company'
                              : '$count companies',
                          style: DT.text(
                              size: 11.5,
                              weight: FontWeight.w500,
                              color: DT.slate500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add company',
                    onPressed: _openCreate,
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: DT.blue50,
                        borderRadius: BorderRadius.circular(DT.rMd),
                      ),
                      child: const Icon(Icons.add_business_outlined,
                          color: _C.blue600, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildSkeleton();
    if (_error != null && _companies.isEmpty) return _buildErrorState();
    if (_companies.isEmpty) return _buildEmptyState();

    final visible = _visible;

    return RefreshIndicator(
      color: _C.navy3,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _buildSummary(),
          const SizedBox(height: 14),
          _buildSearch(),
          const SizedBox(height: 12),
          _buildFilterChips(),
          const SizedBox(height: 14),
          if (_error != null) ...[
            _buildInlineError(),
            const SizedBox(height: 12),
          ],
          if (visible.isEmpty)
            _buildNoMatches()
          else
            for (final c in visible) ...[
              _CompanyCard(
                company: c,
                isPaid: _isPaid(c),
                onOpen: () => _openDetail(c),
                onEdit: () => _openEdit(c),
                onPay: () => _onPay(c),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  // ---------- Summary strip ----------
  Widget _buildSummary() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.navy3, Color(0xFF1D2645), Color(0xFF161D36)],
        ),
        borderRadius: BorderRadius.circular(DT.rLg),
        boxShadow: DT.shadowM3,
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _stat('Total', _companies.length, Colors.white),
            _divider(),
            _stat('Paid', _paidCount, const Color(0xFF6EE7B7)),
            _divider(),
            _stat('Payment pending', _pendingCount, const Color(0xFFFCD34D)),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int value, Color valueColor) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: DT.text(
              size: 20,
              weight: FontWeight.w800,
              color: valueColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: DT.text(size: 11, weight: FontWeight.w500, color: DT.slate300),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, color: const Color(0x33FFFFFF));

  // ---------- Search ----------
  Widget _buildSearch() {
    return TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _query = v),
      textInputAction: TextInputAction.search,
      style: DT.text(size: 13.5, weight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: 'Search by name, owner, district or GST',
        hintStyle: DT.text(size: 13, color: DT.slate400),
        prefixIcon: const Icon(Icons.search_rounded, color: DT.slate500, size: 20),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
          tooltip: 'Clear',
          icon: const Icon(Icons.close_rounded,
              color: DT.slate400, size: 18),
          onPressed: () {
            _searchCtrl.clear();
            setState(() => _query = '');
          },
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DT.rMd),
          borderSide: const BorderSide(color: DT.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DT.rMd),
          borderSide: const BorderSide(color: _C.blue600, width: 1.5),
        ),
      ),
    );
  }

  // ---------- Filter chips ----------
  Widget _buildFilterChips() {
    Widget chip(_Filter f, String label, int count) {
      final selected = _filter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: () => setState(() => _filter = f),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? DT.onyx900 : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? DT.onyx900 : DT.slate200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: DT.text(
                    size: 12,
                    weight: FontWeight.w600,
                    color: selected ? Colors.white : DT.onyx700,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0x33FFFFFF) : DT.slate100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: DT.text(
                      size: 10.5,
                      weight: FontWeight.w700,
                      color: selected ? Colors.white : DT.onyx600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(_Filter.all, 'All', _companies.length),
          chip(_Filter.paid, 'Paid', _paidCount),
          chip(_Filter.pending, 'Payment pending', _pendingCount),
        ],
      ),
    );
  }

  // ---------- States ----------
  Widget _buildSkeleton() {
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: DT.slate100,
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 76,
          decoration: BoxDecoration(
            color: DT.slate200,
            borderRadius: BorderRadius.circular(DT.rLg),
          ),
        ),
        const SizedBox(height: 14),
        bar(double.infinity, 46),
        const SizedBox(height: 14),
        for (var i = 0; i < 3; i++) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(DT.rLg),
              border: Border.all(color: DT.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    bar(56, 56),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          bar(160, 14),
                          const SizedBox(height: 8),
                          bar(110, 10),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                bar(double.infinity, 10),
                const SizedBox(height: 8),
                bar(200, 10),
                const SizedBox(height: 16),
                bar(double.infinity, 38),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return _StateView(
      icon: Icons.business_outlined,
      iconBg: DT.blue50,
      iconFg: _C.blue600,
      title: 'No companies yet',
      message:
      'Add your first company to list products, branches and receive enquiries.',
      buttonLabel: 'Add Company',
      buttonIcon: Icons.add_rounded,
      onPressed: _openCreate,
      onRefresh: _load,
    );
  }

  Widget _buildErrorState() {
    return _StateView(
      icon: Icons.cloud_off_rounded,
      iconBg: DT.errorBg,
      iconFg: DT.error,
      title: "Couldn't load your companies",
      message: _error ?? '',
      buttonLabel: 'Try again',
      buttonIcon: Icons.refresh_rounded,
      onPressed: _load,
      onRefresh: _load,
    );
  }

  Widget _buildInlineError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DT.errorBg,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.errorBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: DT.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Couldn't refresh. Showing your last loaded list.",
              style: DT.text(size: 12, weight: FontWeight.w500, color: DT.error),
            ),
          ),
          TextButton(
            onPressed: _load,
            child: Text('Retry',
                style: DT.text(
                    size: 12, weight: FontWeight.w700, color: DT.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMatches() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, color: DT.slate400, size: 34),
          const SizedBox(height: 10),
          Text('No companies match',
              style: DT.text(size: 14, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Try a different search or filter.',
            style: DT.text(size: 12, color: DT.onyx600),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              _searchCtrl.clear();
              setState(() {
                _query = '';
                _filter = _Filter.all;
              });
            },
            child: Text('Clear search & filters',
                style: DT.text(
                    size: 12.5, weight: FontWeight.w700, color: _C.blue600)),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// COMPANY CARD
// =====================================================================
class _CompanyCard extends StatelessWidget {
  final Company company;
  final bool isPaid;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onPay;

  const _CompanyCard({
    required this.company,
    required this.isPaid,
    required this.onOpen,
    required this.onEdit,
    required this.onPay,
  });

  String get _location => [company.district, company.state]
      .where((s) => s.trim().isNotEmpty)
      .join(', ');

  @override
  Widget build(BuildContext context) {
    final showPay = company.isPaymentPending;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DT.rLg),
        side: const BorderSide(color: DT.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------- Header ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Logo(url: company.logo, name: company.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          company.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(
                            size: 15,
                            weight: FontWeight.w700,
                            letterSpacing: -0.2,
                            height: 1.25,
                          ),
                        ),
                        if (company.companySlogan.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            company.companySlogan,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DT.text(
                                size: 11.5,
                                color: DT.slate500,
                                height: 1.3),
                          ),
                        ],
                        if (company.ownerName.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded,
                                  size: 13, color: DT.slate400),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  company.ownerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: DT.text(
                                      size: 11.5,
                                      weight: FontWeight.w600,
                                      color: DT.onyx700),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(isPaid: isPaid),
                ],
              ),
            ),

            // ---------- Details ----------
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DT.slate50,
                borderRadius: BorderRadius.circular(DT.rMd),
                border: Border.all(color: DT.slate100),
              ),
              child: Column(
                children: [
                  if (_location.isNotEmpty)
                    _InfoRow(Icons.location_on_outlined, _location),
                  if (company.phoneNumber.isNotEmpty)
                    _InfoRow(Icons.phone_outlined, company.phoneNumber),
                  if (company.email.isNotEmpty)
                    _InfoRow(Icons.mail_outline_rounded, company.email),
                  if (company.gstNumber.isNotEmpty)
                    _InfoRow(Icons.receipt_long_outlined,
                        'GST  ${company.gstNumber}',
                        mono: true),
                  if (_location.isEmpty &&
                      company.phoneNumber.isEmpty &&
                      company.email.isEmpty &&
                      company.gstNumber.isEmpty)
                    _InfoRow(Icons.info_outline_rounded,
                        'No contact details added yet'),
                ],
              ),
            ),

            // ---------- Actions ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text('Edit details',
                            style: DT.text(
                                size: 12.5,
                                weight: FontWeight.w700,
                                color: DT.onyx800)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DT.onyx800,
                          side: const BorderSide(color: DT.slate300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DT.rMd),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showPay) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: onPay,
                          icon: const Icon(Icons.payments_outlined, size: 16),
                          label: Text('Pay now',
                              style: DT.text(
                                  size: 12.5,
                                  weight: FontWeight.w700,
                                  color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DT.amber600,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(DT.rMd),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final String url;
  final String name;

  const _Logo({required this.url, required this.name});

  String get _initials {
    final words =
    name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '';
    return words.take(2).map((w) => w[0]).join().toUpperCase();
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [_C.navy1, _C.navy3, _C.blue600],
        ),
      ),
      alignment: Alignment.center,
      child: _initials.isEmpty
          ? const Icon(Icons.business_outlined, color: Colors.white, size: 26)
          : Text(
        _initials,
        style: DT.text(
            size: 18, weight: FontWeight.w800, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: DT.slate100,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.slate200),
      ),
      child: url.isNotEmpty
          ? Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: DT.slate100),
        errorBuilder: (_, __, ___) => _fallback(),
      )
          : _fallback(),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isPaid;

  const _StatusPill({required this.isPaid});

  @override
  Widget build(BuildContext context) {
    final fg = isPaid ? _C.emerald700 : DT.amber800;
    final bg = isPaid ? DT.emerald50 : DT.amber50;
    final border = isPaid ? DT.emerald200 : DT.amber200;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 12,
            color: isPaid ? _C.emerald600 : DT.amber600,
          ),
          const SizedBox(width: 4),
          Text(
            isPaid ? 'Paid' : 'Pending',
            style: DT.text(size: 10.5, weight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool mono;

  const _InfoRow(this.icon, this.text, {this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: DT.slate400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DT.text(
                size: 12,
                weight: mono ? FontWeight.w600 : FontWeight.w500,
                color: DT.onyx700,
                letterSpacing: mono ? 0.4 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen empty / error view that still supports pull-to-refresh.
class _StateView extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String message;
  final String buttonLabel;
  final IconData buttonIcon;
  final VoidCallback onPressed;
  final Future<void> Function() onRefresh;

  const _StateView({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.onPressed,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _C.navy3,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration:
                      BoxDecoration(color: iconBg, shape: BoxShape.circle),
                      child: Icon(icon, size: 42, color: iconFg),
                    ),
                    const SizedBox(height: 20),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: DT.text(size: 17, weight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: DT.text(size: 13, color: DT.onyx600, height: 1.5),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: onPressed,
                        icon: Icon(buttonIcon, size: 18),
                        label: Text(buttonLabel,
                            style: DT.text(
                                size: 13.5,
                                weight: FontWeight.w700,
                                color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.navy3,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DT.rMd),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}