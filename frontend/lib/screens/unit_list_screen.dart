import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../models/unit_model.dart';
import '../services/unit_service.dart';
import 'unit_create_edit_screen.dart';
import 'package:qnx_mart/l10n/app_language.dart';
// ── QNX MART logo colours (private to this screen) ──────────────
//   #093C71 brand (all buttons) · red = errors · orange = conditions
const _kBrand = Color(0xFF093C71);
const _kBrandDark = Color(0xFF062A50);
const _kBrandLight = Color(0xFF1E5A9C);
const _kRed = Color(0xFFC62828);
const _kHeader = LinearGradient(
  colors: [_kBrandDark, _kBrand, _kBrandLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class UnitListScreen extends StatefulWidget {
  const UnitListScreen({super.key});

  @override
  State<UnitListScreen> createState() => _UnitListScreenState();
}

class _UnitListScreenState extends State<UnitListScreen> {
  List<Unit> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await UnitService.getUnitList();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (res.isSuccess) {
        _items = res.data;
      } else {
        _error = res.message ?? tr('Failed to load units');
      }
    });
  }

  void _openCreate() async {
    final r = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const UnitCreateEditScreen(),
      ),
    );
    if (r == true) _load();
  }

  void _openEdit(Unit u) async {
    final r = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UnitCreateEditScreen(existing: u),
      ),
    );
    if (r == true) _load();
  }

  Future<void> _toggleStatus(Unit u) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          u.isActive ? tr('Deactivate Unit?') : tr('Reactivate Unit?'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          u.isActive
              ? tr('This unit will be marked as inactive.')
              : tr('This unit will be activated again.'),
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBrand, // buttons: only #093C71
            ),
            child: Text(u.isActive ? tr('Deactivate') : tr('Reactivate')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final res = u.isActive
        ? await UnitService.softDeleteUnit(u.id)
        : await UnitService.restoreUnit(u.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(res.displayMessage)),
        backgroundColor:
        res.isSuccess ? const Color(0xFF10B981) : Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (res.isSuccess) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.surfaceColor,
      appBar: AppBar(
        backgroundColor: _kBrand,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeader)),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          tr('Units'),
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: _kBrand,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          tr('Add Unit'),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_kBrand),
        ),
      );
    }

    if (_items.isEmpty) return _emptyState();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (_, i) => _card(_items[i]),
      ),
    );
  }

  Widget _card(Unit u) {
    return GestureDetector(
      // ✅ Card tap kelyavar Edit screen open
      onTap: () => _openEdit(u),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kBrand.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.straighten_outlined,
                    color: _kBrand,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trData(u.name),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppConstants.textPrimary,
                        ),
                      ),
                      if (u.shortName.isNotEmpty)
                        Text(
                          tr('Short: {0}', [u.shortName]),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppConstants.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (u.isActive ? const Color(0xFF10B981) : Color(0xFFC62828))
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    u.isActive ? tr('Active') : tr('Inactive'),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: u.isActive ? const Color(0xFF10B981) : Color(0xFFC62828),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // ✅ Chevron hint — user la kळavnyasathi card clickable ahe
                Icon(
                  Icons.chevron_right,
                  color: AppConstants.textLight,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openEdit(u),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(
                      tr('Edit'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kBrand,
                      side: BorderSide(
                          color: _kBrand.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleStatus(u),
                    icon: Icon(
                      u.isActive
                          ? Icons.toggle_off_outlined
                          : Icons.toggle_on_outlined,
                      size: 16,
                    ),
                    label: Text(
                      u.isActive ? tr('Deactivate') : tr('Reactivate'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBrand, // buttons: only #093C71
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    final isErr = _error != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (isErr ? _kRed : _kBrand)
                    .withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isErr ? Icons.error_outline : Icons.straighten_outlined,
                size: 56,
                color: (isErr ? _kRed : _kBrand)
                    .withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isErr ? tr('Failed to Load') : tr('No Units Yet'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppConstants.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? tr('Start by adding your first unit.'),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppConstants.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isErr ? _load : _openCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBrand, // buttons: only #093C71
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(isErr ? Icons.refresh : Icons.add,
                  color: Colors.white, size: 18),
              label: Text(
                isErr ? tr('Retry') : tr('Add Unit'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}