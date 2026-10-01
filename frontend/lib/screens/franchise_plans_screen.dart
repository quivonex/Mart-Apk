import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../models/franchise_plan_model.dart';
import '../services/franchise_plan_service.dart';
import 'franchise_apply_screen.dart';

class FranchisePlansScreen extends StatefulWidget {
  final String productSlug;
  final String productName;

  const FranchisePlansScreen({
    super.key,
    required this.productSlug,
    required this.productName,
  });

  @override
  State<FranchisePlansScreen> createState() => _FranchisePlansScreenState();
}

class _FranchisePlansScreenState extends State<FranchisePlansScreen> {
  List<FranchisePlan> _plans = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isApiSuccess = false;

  // ✅ Auto-select first plan
  int? _selectedPlanId;

  @override
  void initState() {
    super.initState();
    _loadFranchisePlans();
  }

  Future<void> _loadFranchisePlans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isApiSuccess = false;
      _selectedPlanId = null;
    });

    final request = FranchisePlanRequest(slug: widget.productSlug);
    final response = await FranchisePlanService.getFranchisePlans(request);

    if (!mounted) return;

    setState(() {
      _isLoading = false;

      if (response.hasPlans) {
        // ✅ Case 1: Plans found
        _isApiSuccess = true;
        _plans = response.data;
        _selectedPlanId = _plans.first.id; // auto-select first plan
        _errorMessage = null;
      } else if (response.message != null &&
          response.message!.toLowerCase().contains('no franchise plans')) {
        // ✅ Case 2: Backend says "No franchise plans found." — valid empty state
        _isApiSuccess = true; // blue info state
        _plans = [];
        _errorMessage = response.message;
      } else {
        // ❌ Case 3: Actual API error
        _isApiSuccess = false; // red error state
        _plans = [];
        _errorMessage = response.message ?? 'Failed to load franchise plans.';
      }
    });
  }

  void _handleApplyPlan(FranchisePlan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FranchiseApplyScreen(
          productSlug: widget.productSlug,
          productName: widget.productName,
          plan: plan,
        ),
      ),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Franchise Plans',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              widget.productName,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white70,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: _buildBody(),
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

    if (_plans.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadFranchisePlans,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _plans.length,
        itemBuilder: (context, index) {
          return _buildPlanCard(_plans[index], index);
        },
      ),
    );
  }

  Widget _buildPlanCard(FranchisePlan plan, int index) {
    final Color accent =
    index % 2 == 0 ? AppConstants.primary : AppConstants.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- Header ----------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withOpacity(0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.storefront,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.planName,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${plan.amount}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ---------- Description ----------
          if (plan.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(
                plan.description,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppConstants.textSecondary,
                  height: 1.4,
                ),
              ),
            ),

          // ---------- Products Included ----------
          if (plan.planProducts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Includes ${plan.planProducts.length} items',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppConstants.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.surfaceColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: plan.planProducts.map((product) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            product.itemName,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppConstants.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${product.quantity} ${product.unit}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppConstants.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // ---------- Apply Button ----------
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _handleApplyPlan(plan),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Apply for This Plan',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Empty state — handles both "no plans" (BLUE) and "error" (RED)
  Widget _buildEmptyState() {
    final bool isNoPlansCase = _isApiSuccess;

    final Color iconColor = isNoPlansCase
        ? AppConstants.primary.withOpacity(0.5)
        : AppConstants.error.withOpacity(0.5);

    final Color iconBgColor = isNoPlansCase
        ? AppConstants.primary.withOpacity(0.08)
        : AppConstants.error.withOpacity(0.08);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNoPlansCase
                    ? Icons.store_mall_directory_outlined
                    : Icons.error_outline,
                size: 56,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isNoPlansCase ? 'No Franchise Plans' : 'Failed to Load',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppConstants.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  (isNoPlansCase
                      ? 'No franchise plans available for this product.'
                      : 'Something went wrong. Please try again.'),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppConstants.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadFranchisePlans,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                isNoPlansCase ? AppConstants.primary : AppConstants.error,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
              label: Text(
                isNoPlansCase ? 'Refresh' : 'Retry',
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