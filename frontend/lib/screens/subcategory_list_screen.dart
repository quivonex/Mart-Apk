import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../models/subcategory_model.dart';
import '../services/subcategory_service.dart';
import 'subcategory_create_edit_screen.dart';

class SubCategoryListScreen extends StatefulWidget {
  const SubCategoryListScreen({super.key});

  @override
  State<SubCategoryListScreen> createState() =>
      _SubCategoryListScreenState();
}

class _SubCategoryListScreenState extends State<SubCategoryListScreen> {
  List<SubCategory> _items = [];
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

    final res = await SubCategoryService.getSubCategoryList();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (res.isSuccess) {
        _items = res.data;
      } else {
        _error = res.message ?? 'Failed to load sub categories';
      }
    });
  }

  void _openCreate() async {
    final r = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SubCategoryCreateEditScreen(),
      ),
    );
    if (r == true) _load();
  }

  void _openEdit(SubCategory sc) async {
    final r = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubCategoryCreateEditScreen(existing: sc),
      ),
    );
    if (r == true) _load();
  }

  Future<void> _toggleStatus(SubCategory sc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          sc.isActive ? 'Deactivate Sub Category?' : 'Reactivate Sub Category?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          sc.isActive
              ? 'This sub category will be marked as inactive.'
              : 'This sub category will be activated again.',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
              sc.isActive ? AppConstants.error : AppConstants.primary,
            ),
            child: Text(sc.isActive ? 'Deactivate' : 'Reactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final res = sc.isActive
        ? await SubCategoryService.softDeleteSubCategory(sc.id)
        : await SubCategoryService.restoreSubCategory(sc.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.displayMessage),
        backgroundColor:
        res.isSuccess ? Colors.green : const Color(0xFFD32F2F),
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
        backgroundColor: AppConstants.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Sub Categories',
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
        backgroundColor: AppConstants.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Sub Category',
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
          valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primary),
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

  Widget _card(SubCategory sc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
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
                  color: AppConstants.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.category_outlined,
                  color: AppConstants.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sc.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    if (sc.categoryName.isNotEmpty)
                      Text(
                        sc.categoryName,
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
                  color: (sc.isActive ? Colors.green : Colors.red)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sc.isActive ? 'Active' : 'Inactive',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: sc.isActive ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          if (sc.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              sc.description,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppConstants.textSecondary,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openEdit(sc),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(
                    'Edit',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.primary,
                    side: BorderSide(
                        color: AppConstants.primary.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _toggleStatus(sc),
                  icon: Icon(
                    sc.isActive
                        ? Icons.toggle_off_outlined
                        : Icons.toggle_on_outlined,
                    size: 16,
                  ),
                  label: Text(
                    sc.isActive ? 'Deactivate' : 'Reactivate',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    sc.isActive ? AppConstants.error : Colors.green,
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
                color: (isErr ? AppConstants.error : AppConstants.primary)
                    .withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isErr ? Icons.error_outline : Icons.category_outlined,
                size: 56,
                color: (isErr ? AppConstants.error : AppConstants.primary)
                    .withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isErr ? 'Failed to Load' : 'No Sub Categories Yet',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppConstants.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Start by adding your first sub category.',
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
                backgroundColor:
                isErr ? AppConstants.error : AppConstants.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(isErr ? Icons.refresh : Icons.add,
                  color: Colors.white, size: 18),
              label: Text(
                isErr ? 'Retry' : 'Add Sub Category',
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