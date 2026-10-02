import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../models/company_product_model.dart';
import '../services/company_product_service.dart';
import '../screens/product_create_screen.dart';

class CompanyProductsListScreen extends StatefulWidget {
  final int? companyId;

  const CompanyProductsListScreen({super.key, this.companyId});

  @override
  State<CompanyProductsListScreen> createState() =>
      _CompanyProductsListScreenState();
}

class _CompanyProductsListScreenState
    extends State<CompanyProductsListScreen> {
  List<CompanyProduct> _products = [];
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

    final res = await CompanyProductService.getCompanyProducts(
      companyId: widget.companyId,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (res.isSuccess) {
        _products = res.data;
      } else {
        _error = res.message ?? 'Failed to load products';
      }
    });
  }

  void _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductCreateScreen(companyId: widget.companyId),
      ),
    );
    if (created == true && mounted) _load();
  }

  void _openEdit(CompanyProduct p) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit Product feature coming soon')),
    );
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
          'My Products',
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
          'Add Product',
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

    if (_products.isEmpty) return _emptyState();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length,
        itemBuilder: (_, i) => _card(_products[i]),
      ),
    );
  }

  Widget _card(CompanyProduct p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
                child: p.thumbnailUrl.isNotEmpty
                    ? Image.network(
                  p.thumbnailUrl,
                  width: 100,
                  height: 110,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _ph(),
                )
                    : _ph(),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppConstants.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${p.categoryName} • ${p.brandName}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppConstants.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '₹${p.finalPrice}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppConstants.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (p.price != p.finalPrice)
                            Text(
                              '₹${p.price}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppConstants.textLight,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _badge(p.status, _statusColor(p.status)),
                          const SizedBox(width: 4),
                          _badge(
                            'Stock: ${p.stockQuantity}',
                            p.stockQuantity > 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openEdit(p),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return AppConstants.primary;
    }
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _ph() => Container(
    width: 100,
    height: 110,
    color: AppConstants.surfaceColor,
    child: Icon(
      Icons.inventory_2_outlined,
      color: AppConstants.textLight.withOpacity(0.4),
      size: 30,
    ),
  );

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
                isErr ? Icons.error_outline : Icons.inventory_2_outlined,
                size: 56,
                color: (isErr ? AppConstants.error : AppConstants.primary)
                    .withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isErr ? 'Failed to Load' : 'No Products Yet',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppConstants.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Start by adding your first product.',
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
                isErr ? 'Retry' : 'Add Product',
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