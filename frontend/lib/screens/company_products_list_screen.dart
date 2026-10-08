// lib/screens/company_products_list_screen.dart
//
// Kept for existing navigation (company detail "Products" tile, account screen…).
// It now opens the redesigned My Products screen.

import 'package:flutter/material.dart';
import 'my_products_screen.dart';

class CompanyProductsListScreen extends StatelessWidget {
  final int? companyId;
  final String? companyName;

  const CompanyProductsListScreen({super.key, this.companyId, this.companyName});

  @override
  Widget build(BuildContext context) =>
      MyProductsScreen(companyId: companyId, companyName: companyName);
}