// lib/screens/company_detail_screen.dart
//
// Opened when a company card is tapped in CompanyListScreen.
// Loads fresh data from /company/company/single-retrieve/ and links to:
//   edit, pay, products, suppliers, stock, photos, deactivate/restore.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/design_tokens.dart';
import '../models/company_model.dart';
import '../services/company_service.dart';
import '../utils/company_payment_helper.dart';
import '../widgets/company_ui.dart';
import 'company_create_edit_screen.dart';
import 'company_photos_screen.dart';
import 'company_products_list_screen.dart';
import 'company_stock_screen.dart';
import 'supplier_list_screen.dart';

class CompanyDetailScreen extends StatefulWidget {
  final Company company;

  const CompanyDetailScreen({super.key, required this.company});

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  late Company _c = widget.company;
  bool _refreshing = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _refreshing = true;
      _error = null;
    });
    final res = await CompanyService.getCompanyDetail(_c.id);
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      if (res.isSuccess) {
        _c = res.data!;
      } else {
        _error = res.message ?? 'Could not refresh company';
      }
    });
  }

  // =================================================================
  // ACTIONS
  // =================================================================
  Future<void> _open(Widget page, {bool reload = true}) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (reload || result == true) _load();
  }

  Future<void> _pay() async {
    final paid = await CompanyPaymentHelper.pay(context, _c);
    if (paid) _load();
  }

  Future<void> _toggleActive() async {
    final deactivate = _c.isActive;
    final ok = await confirmAction(
      context,
      title: deactivate ? 'Deactivate ${_c.name}?' : 'Restore ${_c.name}?',
      message: deactivate
          ? 'The company and its listings will be hidden from buyers. '
          'You can restore it any time from this screen.'
          : 'The company will be visible to buyers again.',
      confirmLabel: deactivate ? 'Deactivate' : 'Restore',
      destructive: deactivate,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    final res = deactivate
        ? await CompanyService.softDeleteCompany(_c.id)
        : await CompanyService.restoreCompany(_c.id);
    if (!mounted) return;
    setState(() => _busy = false);
    showCompanySnack(context, res.message, error: !res.isSuccess);
    if (res.isSuccess) _load();
  }

  Future<void> _launch(String raw) async {
    var url = raw.trim();
    if (url.isEmpty) return;
    if (!url.contains(':')) url = 'https://$url';
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) showCompanySnack(context, 'Could not open $raw', error: true);
  }

  String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  // =================================================================
  // BUILD
  // =================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.background,
      appBar: CompanyTopBar(
        title: _c.name,
        subtitle: _refreshing ? 'Refreshing…' : 'Company details',
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () => _open(CompanyCreateEditScreen(existing: _c)),
            icon: const Icon(Icons.edit_outlined, color: DT.onyx700),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: DT.blue800,
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (_error != null) ...[_errorBanner(), const SizedBox(height: 12)],
                _header(),
                if (_c.isPaymentPending) ...[const SizedBox(height: 12), _payBanner()],
                if (!_c.isActive) ...[const SizedBox(height: 12), _inactiveBanner()],
                const SizedBox(height: 16),
                _actions(),
                const SizedBox(height: 16),
                _contactSection(),
                const SizedBox(height: 12),
                _addressSection(),
                const SizedBox(height: 12),
                _businessSection(),
                if (_hasOnline) ...[const SizedBox(height: 12), _onlineSection()],
                if (_c.shortDescription.isNotEmpty || _c.longDescription.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _aboutSection(),
                ],
                const SizedBox(height: 12),
                _photosSection(),
                const SizedBox(height: 24),
                _dangerZone(),
              ],
            ),
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66FFFFFF),
                child: Center(child: CircularProgressIndicator(color: DT.blue800)),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- Header ----------
  Widget _header() {
    final pill = !_c.isActive
        ? _pill('Inactive', DT.slate100, DT.onyx600)
        : _c.isPaid
        ? _pill('Paid', DT.emerald50, DT.emerald700)
        : _pill('Payment pending', DT.amber50, DT.amber800);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CompanyLogo(url: _c.logo, name: _c.name, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_c.name,
                    style: DT.text(size: 18, weight: FontWeight.w800, letterSpacing: -0.4)),
                if (_c.companySlogan.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_c.companySlogan,
                      style: DT.text(size: 12.5, color: DT.slate500, height: 1.35)),
                ],
                if (_c.ownerName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Owned by ${_c.ownerName}',
                      style: DT.text(size: 12, weight: FontWeight.w600, color: DT.onyx700)),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    pill,
                    if (_c.isoCertified) _pill('ISO', DT.blue50, DT.blue800),
                    if (_c.isiCertified) _pill('ISI', DT.blue50, DT.blue800),
                    if (_c.codAvailable) _pill('COD', DT.teal50, DT.teal800),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
    child: Text(text, style: DT.text(size: 11, weight: FontWeight.w700, color: fg)),
  );

  Widget _payBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DT.amber50,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.amber200),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: DT.amber700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Registration fee not paid',
                    style: DT.text(size: 13.5, weight: FontWeight.w700, color: DT.amber900)),
                const SizedBox(height: 2),
                Text('Pay to activate the admin panel and shipping pickup.',
                    style: DT.text(size: 12, color: DT.amber800, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _pay,
            style: ElevatedButton.styleFrom(
              backgroundColor: DT.amber600,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
            ),
            child: Text('Pay now',
                style: DT.text(size: 12.5, weight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _inactiveBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DT.slate100,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.slate200),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_off_outlined, color: DT.onyx600),
          const SizedBox(width: 12),
          Expanded(
            child: Text('This company is deactivated and hidden from buyers.',
                style: DT.text(size: 12.5, color: DT.onyx700, height: 1.4)),
          ),
          TextButton(
            onPressed: _toggleActive,
            child: Text('Restore',
                style: DT.text(size: 13, weight: FontWeight.w700, color: DT.blue800)),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: DT.errorBg,
      borderRadius: BorderRadius.circular(DT.rMd),
      border: Border.all(color: DT.errorBorder),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, size: 18, color: DT.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text('$_error. Showing saved details.',
              style: DT.text(size: 12, color: DT.error, weight: FontWeight.w600)),
        ),
        GestureDetector(
          onTap: _load,
          child: Text('Retry',
              style: DT.text(size: 12, weight: FontWeight.w700, color: DT.error)),
        ),
      ],
    ),
  );

  // ---------- Actions grid ----------
  Widget _actions() {
    final tiles = <_ActionTile>[
      _ActionTile(Icons.inventory_2_outlined, 'Products',
              () => _open(CompanyProductsListScreen(companyId: _c.id), reload: false)),
      _ActionTile(Icons.local_shipping_outlined, 'Suppliers',
              () => _open(SupplierListScreen(company: _c), reload: false)),
      _ActionTile(Icons.bar_chart_rounded, 'Stock',
              () => _open(CompanyStockScreen(company: _c), reload: false)),
      _ActionTile(Icons.photo_library_outlined,
          _c.images.isEmpty ? 'Photos' : 'Photos (${_c.images.length})',
              () => _open(CompanyPhotosScreen(company: _c))),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.95,
      children: [
        for (final t in tiles)
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DT.rMd),
              side: const BorderSide(color: DT.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(DT.rMd),
              onTap: t.onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(t.icon, color: DT.blue800, size: 24),
                  const SizedBox(height: 6),
                  Text(t.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 11.5, weight: FontWeight.w700, color: DT.onyx800)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ---------- Sections ----------
  Widget _contactSection() {
    final extraEmails = _c.multipleEmailIds.where((e) => e != _c.email).join(', ');
    final extraPhones = _c.contacts.where((e) => e != _c.phoneNumber).join(', ');
    return SectionCard(
      title: 'Contact',
      child: Column(children: [
        InfoLine(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: _c.phoneNumber,
            onTap: () => _launch('tel:${_digits(_c.phoneNumber)}')),
        InfoLine(
            icon: Icons.chat_outlined,
            label: 'WhatsApp',
            value: _c.whatsappNo,
            onTap: () {
              final d = _digits(_c.whatsappNo);
              _launch('https://wa.me/${d.length == 10 ? '91$d' : d}');
            }),
        InfoLine(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: _c.email,
            onTap: () => _launch('mailto:${_c.email}')),
        InfoLine(icon: Icons.alternate_email_rounded, label: 'Other emails', value: extraEmails),
        InfoLine(icon: Icons.contacts_outlined, label: 'Other phones', value: extraPhones),
        if ([_c.phoneNumber, _c.whatsappNo, _c.email, extraEmails, extraPhones]
            .every((s) => s.trim().isEmpty))
          _emptyLine('No contact details yet. Tap edit to add them.'),
      ]),
    );
  }

  Widget _addressSection() {
    final area = [_c.village, _c.taluka, _c.district, _c.state]
        .where((s) => s.trim().isNotEmpty)
        .join(', ');
    final hasMap = _c.latitude.isNotEmpty && _c.longitude.isNotEmpty;
    return SectionCard(
      title: 'Address',
      trailing: hasMap
          ? TextButton.icon(
        onPressed: () => _launch(
            'https://www.google.com/maps/search/?api=1&query=${_c.latitude},${_c.longitude}'),
        icon: const Icon(Icons.map_outlined, size: 16),
        label: Text('Map',
            style: DT.text(size: 12, weight: FontWeight.w700, color: DT.blue800)),
        style: TextButton.styleFrom(
          foregroundColor: DT.blue800,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 32),
        ),
      )
          : null,
      child: Column(children: [
        InfoLine(icon: Icons.home_work_outlined, label: 'Address', value: _c.address),
        InfoLine(icon: Icons.location_on_outlined, label: 'Area', value: area),
        InfoLine(icon: Icons.markunread_mailbox_outlined, label: 'Pincode', value: _c.pincode),
        InfoLine(
            icon: Icons.local_shipping_outlined, label: 'Pickup', value: _c.pickupLocation),
        if ([_c.address, area, _c.pincode, _c.pickupLocation].every((s) => s.trim().isEmpty))
          _emptyLine('No address yet.'),
      ]),
    );
  }

  Widget _businessSection() {
    return SectionCard(
      title: 'Business details',
      child: Column(children: [
        InfoLine(icon: Icons.receipt_long_outlined, label: 'GST', value: _c.gstNumber),
        InfoLine(icon: Icons.badge_outlined, label: 'PAN', value: _c.companyPanNo),
        InfoLine(
            icon: Icons.assignment_outlined, label: 'Registration', value: _c.registrationNo),
        InfoLine(icon: Icons.numbers_rounded, label: 'IAN no.', value: _c.ianNo),
        InfoLine(
            icon: Icons.event_outlined, label: 'Since', value: _c.farmRegistrationYear),
        InfoLine(icon: Icons.schedule_outlined, label: 'Joined', value: _fmtDate(_c.createdAt)),
      ]),
    );
  }

  bool get _hasOnline => [
    _c.websiteUrl,
    _c.facebookUrl,
    _c.instagramUrl,
    _c.linkedinUrl,
    _c.youtubeUrl,
    _c.privacyPolicyUrl,
    _c.termsConditionsUrl,
  ].any((s) => s.trim().isNotEmpty);

  Widget _onlineSection() {
    InfoLine link(IconData i, String l, String v) =>
        InfoLine(icon: i, label: l, value: _short(v), onTap: () => _launch(v));
    return SectionCard(
      title: 'Online',
      child: Column(children: [
        link(Icons.language_rounded, 'Website', _c.websiteUrl),
        link(Icons.facebook_rounded, 'Facebook', _c.facebookUrl),
        link(Icons.camera_alt_outlined, 'Instagram', _c.instagramUrl),
        link(Icons.work_outline_rounded, 'LinkedIn', _c.linkedinUrl),
        link(Icons.smart_display_outlined, 'YouTube', _c.youtubeUrl),
        link(Icons.privacy_tip_outlined, 'Privacy', _c.privacyPolicyUrl),
        link(Icons.gavel_outlined, 'Terms', _c.termsConditionsUrl),
      ]),
    );
  }

  Widget _aboutSection() {
    return SectionCard(
      title: 'About',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_c.shortDescription.isNotEmpty)
            Text(_c.shortDescription,
                style: DT.text(size: 13, weight: FontWeight.w600, height: 1.5)),
          if (_c.shortDescription.isNotEmpty && _c.longDescription.isNotEmpty)
            const SizedBox(height: 8),
          if (_c.longDescription.isNotEmpty)
            Text(_c.longDescription,
                style: DT.text(size: 12.5, color: DT.onyx600, height: 1.55)),
        ],
      ),
    );
  }

  Widget _photosSection() {
    return SectionCard(
      title: 'Photos',
      trailing: TextButton(
        onPressed: () => _open(CompanyPhotosScreen(company: _c)),
        child: Text(_c.images.isEmpty ? 'Add' : 'Manage',
            style: DT.text(size: 12.5, weight: FontWeight.w700, color: DT.blue800)),
      ),
      child: _c.images.isEmpty
          ? _emptyLine('Add photos of your shop, warehouse or products.')
          : SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _c.images.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => ClipRRect(
            borderRadius: BorderRadius.circular(DT.rMd),
            child: Image.network(
              _c.images[i].displayUrl,
              width: 84,
              height: 84,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 84,
                height: 84,
                color: DT.slate100,
                child: const Icon(Icons.broken_image_outlined, color: DT.slate400),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dangerZone() {
    final deactivate = _c.isActive;
    return OutlinedButton.icon(
      onPressed: _busy ? null : _toggleActive,
      icon: Icon(
          deactivate ? Icons.visibility_off_outlined : Icons.restore_rounded, size: 18),
      label: Text(deactivate ? 'Deactivate company' : 'Restore company',
          style: DT.text(
              size: 13.5,
              weight: FontWeight.w700,
              color: deactivate ? DT.error : DT.blue800)),
      style: OutlinedButton.styleFrom(
        foregroundColor: deactivate ? DT.error : DT.blue800,
        side: BorderSide(color: deactivate ? DT.errorBorder : DT.blue200),
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
      ),
    );
  }

  Widget _emptyLine(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(text, style: DT.text(size: 12.5, color: DT.slate500, height: 1.4)),
  );

  String _short(String url) =>
      url.replaceFirst(RegExp(r'^https?://(www\.)?'), '').replaceFirst(RegExp(r'/$'), '');

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final l = d.toLocal();
    return '${l.day} ${m[l.month - 1]} ${l.year}';
  }
}

class _ActionTile {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _ActionTile(this.icon, this.label, this.onTap);
}